import 'package:file/memory.dart';
import 'package:smf_contracts/lego_core.dart';
import 'package:smf_pipeline/src/access.dart';
import 'package:smf_pipeline/src/choices.dart';
import 'package:smf_pipeline/src/collector.dart';
import 'package:smf_pipeline/src/environment.dart';
import 'package:smf_pipeline/src/errors.dart';
import 'package:smf_pipeline/src/host.dart';
import 'package:smf_pipeline/src/pubspec.dart';
import 'package:smf_pipeline/src/registry.dart';
import 'package:smf_pipeline/src/render.dart';
import 'package:smf_pipeline/src/resolver.dart';
import 'package:smf_pipeline/src/templates.dart';
import 'package:smf_pipeline/src/testing/file_indexer.dart';
import 'package:smf_pipeline/src/validation.dart';
import 'package:yaml/yaml.dart';

/// One app the harness builds to check a module or a role: the modules
/// asked for and the provider picked for each role.
final class ContractCase {
  /// Creates the case [name].
  const ContractCase(
    this.name, {
    required this.requested,
    this.picks = const {},
    this.roleOptions = const {},
  });

  /// What the case checks, such as `home (bloc) with analytics`.
  final String name;

  /// The modules asked for.
  final List<ModuleId> requested;

  /// The provider of each role that has several in the registry.
  final Map<Role, ModuleId> picks;

  /// Values of role options by name, as `--start /home` on the command
  /// line, for the choices of the roles when the app of the case is
  /// rendered.
  final Map<String, String?> roleOptions;

  @override
  String toString() => name;
}

/// What the harness found in one [ContractCase].
final class ContractResult {
  /// Creates the result.
  const ContractResult(
    this.contractCase,
    this.issues, {
    this.resolution,
    this.collection,
    this.validation,
    this.choices,
    this.app,
  });

  /// The case.
  final ContractCase contractCase;

  /// The errors and warnings found.
  final List<SmfIssue> issues;

  /// The modules of the app, if the case resolved.
  final Resolution? resolution;

  /// The contributions of the app, if the case resolved.
  final Collection? collection;

  /// The result of stage 5, with the order of every socket and the merged
  /// pubspec, if the case resolved.
  final ValidationResult? validation;

  /// The results of the roles' choices, if the harness rendered the app.
  final Map<Role, Object?>? choices;

  /// The rendered app, if the harness rendered it: when it renders apps and
  /// the stages before found no error.
  final RenderedApp? app;

  /// This result with [more] issues, and with the [choices] and the [app]
  /// if they are given.
  ContractResult _with(
    List<SmfIssue> more, {
    Map<Role, Object?>? choices,
    RenderedApp? app,
  }) =>
      ContractResult(
        contractCase,
        [...issues, ...more],
        resolution: resolution,
        collection: collection,
        validation: validation,
        choices: choices ?? this.choices,
        app: app ?? this.app,
      );

  /// The errors among [issues].
  List<SmfIssue> get errors => [
        for (final issue in issues)
          if (issue.isError) issue,
      ];

  /// The modules of the app with their variants, which tell apart the apps
  /// of different cases, or `null` if the case did not resolve.
  String? get appKey => switch (resolution) {
        null => null,
        final resolution => ([
            for (final module in resolution.modules)
              '${module.id}(${module.variant ?? ''})',
          ]..sort())
              .join(','),
      };
}

/// The contract test harness: checks that the modules and roles of a
/// registry follow the rules of the lego model, the way the pipeline would
/// generate them in every combination that matters.
///
/// For a module it builds an app for every provider of the role of its
/// variants, every provider of each role it requires that has several, and
/// each subset of the roles it only uses; for a role, the same for each of
/// its providers. Each app goes through the stages 3 to 5 of the pipeline,
/// in a run without a terminal that skips external setup, as the Flutter
/// job generates apps; stage 5 includes [checkTemplateTags], and the
/// harness adds [missingTemplateTags] and reports templates with `{{`
/// that mason would copy as they are. Unless [render] is off, the harness
/// then makes the roles' choices (stage 7) with the options of the case,
/// renders the app in memory (stage 8) and checks the rendered code with
/// [checkRendered].
///
/// It depends on no test framework, so the tests of any package can use it.
final class ContractHarness {
  /// Creates the harness for [registry], generating apps described by
  /// [context], and rendering them unless [render] is `false`, with the
  /// [roleOptions] of every case.
  ContractHarness(
    this.registry, {
    this.context = defaultContext,
    this.render = true,
    this.roleOptions = const {},
  });

  /// The context of the apps the harness builds.
  static const defaultContext = ModuleContext(
    appName: 'contract_app',
    orgName: 'com.example',
    appIdentity: AppIdentity(
      androidApplicationId: 'com.example.contract_app',
      iosBundleId: 'com.example.contract-app',
      androidNamespace: 'com.example.contract_app',
    ),
  );

  /// The modules and roles to check.
  final ModuleRegistry registry;

  /// The context of the apps the harness builds.
  final ModuleContext context;

  /// Whether the harness renders the app of every case that has no errors
  /// and checks the rendered code.
  final bool render;

  /// Values of role options by name for every case, such as the start route
  /// of an app with several screens that can start it; the options of a
  /// case override them.
  final Map<String, String?> roleOptions;

  /// The cases of the module [id]:
  /// - every provider of the role of its variants, also one without a
  ///   variant, which the pipeline rejects;
  /// - every provider of each role the module requires that has several;
  /// - each subset of the roles the module only uses, the largest first,
  ///   with the first registered provider of each.
  ///
  /// A role left out of a subset is still present when a module of the case
  /// brings it, such as a provider of several roles or a module that
  /// requires it. [checkAll] then leaves out the case, since the case of a
  /// larger subset built its app already and names the roles it has.
  List<ContractCase> casesOfModule(ModuleId id) {
    final module = registry[id];
    if (module == null) throw ArgumentError.value(id, 'id', 'Not registered');
    final descriptor = module.descriptor;
    final used = [
      for (final role in descriptor.effectiveUses)
        if (registry.providersOf(role).isNotEmpty) role,
    ];
    return [
      for (final picks in _picksOf([
        if (descriptor.variants case final variants?) variants.role,
        ...descriptor.effectiveRequires,
      ]))
        for (final subset in _subsets(used))
          _case(
            [
              id.value,
              if (picks.isNotEmpty) '(${picks.values.join(', ')})',
              if (subset.isNotEmpty)
                'with ${subset.map((role) => role.id).join(', ')}',
            ].join(' '),
            [id],
            picks: picks,
            present: subset,
          ),
    ];
  }

  /// The cases of [role]: each of its providers, with every provider of
  /// each role the provider requires that has several, and each subset of
  /// the roles the role uses.
  List<ContractCase> casesOfRole(Role role) {
    final used = [
      for (final other in role.uses)
        if (registry.providersOf(other).isNotEmpty) other,
    ];
    return [
      for (final provider in registry.providersOf(role))
        for (final picks in _picksOf(
          provider.descriptor.effectiveRequires.toList(),
        ))
          for (final subset in _subsets(used))
            _case(
              [
                '${role.id} by ${provider.descriptor.id}',
                if (picks.isNotEmpty) '(${picks.values.join(', ')})',
                if (subset.isNotEmpty)
                  'with ${subset.map((role) => role.id).join(', ')}',
              ].join(' '),
              [provider.descriptor.id],
              picks: {...picks, role: provider.descriptor.id},
              present: subset,
            ),
    ];
  }

  /// Every combination of providers of those [roles] that have several in
  /// the registry.
  List<Map<Role, ModuleId>> _picksOf(List<Role> roles) {
    var combinations = <Map<Role, ModuleId>>[{}];
    for (final role in {...roles}) {
      final providers = registry.providersOf(role);
      if (providers.length < 2) continue;
      combinations = [
        for (final combination in combinations)
          for (final provider in providers)
            {...combination, role: provider.descriptor.id},
      ];
    }
    return combinations;
  }

  ContractCase _case(
    String name,
    List<ModuleId> requested, {
    required Map<Role, ModuleId> picks,
    required List<Role> present,
  }) {
    final all = {...picks};
    for (final role in registry.roles) {
      final providers = registry.providersOf(role);
      if (providers.isNotEmpty) {
        all.putIfAbsent(role, () => providers.first.descriptor.id);
      }
    }
    return ContractCase(
      name,
      requested: [
        ...requested,
        for (final role in present)
          if (!requested.contains(all[role])) all[role]!,
      ],
      picks: all,
    );
  }

  /// Runs the stages 3 to 5 of the pipeline and [missingTemplateTags] for
  /// [contractCase], then, if [render] is on and they found no error, the
  /// stages 7 and 8 and [checkRendered].
  Future<ContractResult> check(ContractCase contractCase) async {
    final environment = PipelineEnvironment(
      _silentHost,
      interactive: false,
      skipExternalSetup: true,
    );
    final ResolverResult resolved;
    try {
      resolved = await resolve(
        requested: contractCase.requested,
        registry: registry,
        environment: environment,
        answers: {...contractCase.picks},
      );
    } on SmfUsageException catch (error) {
      return ContractResult(contractCase, [SmfIssue(error.message)]);
    }
    final resolution = resolved.resolution;
    if (resolution == null) {
      return ContractResult(contractCase, resolved.issues);
    }
    final collection = collect(resolution, context);
    final validation = validate(
      registry: registry,
      resolution: resolution,
      collection: collection,
      context: context,
      interactive: environment.interactive,
      skipExternalSetup: environment.skipExternalSetup,
    );
    final checked = ContractResult(
      contractCase,
      [
        ...resolved.issues,
        ...validation.issues,
        ...missingTemplateTags(
          registry: registry,
          resolution: resolution,
          collection: collection,
        ),
        ..._copiedTemplateIssues(collection),
      ],
      resolution: resolution,
      collection: collection,
      validation: validation,
    );
    if (!render || checked.errors.isNotEmpty) return checked;

    final Map<Role, Object?> choices;
    final RenderedApp app;
    try {
      choices = await chooseRoles(
        registry: registry,
        resolution: resolution,
        collection: collection,
        optionValues: {...roleOptions, ...contractCase.roleOptions},
        environment: environment,
        context: context,
      );
      app = renderApp(
        registry: registry,
        resolution: resolution,
        collection: collection,
        context: context,
        choices: choices,
        pubspec: validation.pubspec,
      );
    } on SmfUsageException catch (error) {
      return checked._with([SmfIssue(error.message)]);
    } on GenerationFailedException catch (error) {
      return checked._with([
        if (error.issues.isEmpty) SmfIssue(error.message),
        ...error.issues,
      ]);
    }
    final rendered = checked._with(const [], choices: choices, app: app);
    return rendered._with(checkRendered(rendered, app));
  }

  /// Checks every case of every module and every role of the registry, and
  /// returns the results of the cases whose app no case before built.
  Future<List<ContractResult>> checkAll() async {
    final results = <ContractResult>[];
    final apps = <String>{};
    for (final contractCase in [
      for (final module in registry.modules)
        ...casesOfModule(module.descriptor.id),
      for (final role in registry.roles) ...casesOfRole(role),
    ]) {
      final result = await check(contractCase);
      final key = result.appKey;
      if (key == null || apps.add(key)) results.add(result);
    }
    return results;
  }

  /// Indexes the Dart files among [files], the text files of the rendered
  /// app of [result] by path, runs the structural rules of its present roles
  /// with the data it collected and the texts, and checks the symbols of
  /// their interfaces.
  ///
  /// [owners] names who generated each file; the rules of the roles check
  /// only files with an owner.
  ///
  /// Throws an [ArgumentError] if the case of [result] did not resolve.
  List<SmfIssue> checkStructure(
    ContractResult result, {
    required Map<String, String> files,
    required Map<String, ContributionOrigin> owners,
  }) {
    final (:indexes, :issues) = _index(files, owners);
    return [...issues, ..._structureIssues(result, indexes, files, owners)];
  }

  /// Checks [app], the rendered app of [result]:
  /// - the structural rules and symbols of the roles, see [checkStructure];
  /// - every import or export of a file of the app finds the file, or a
  ///   file that code generation or Flutter's localizations generate;
  /// - every imported or exported package is a dependency of the app, a
  ///   regular one for the code in `lib/` and `bin/`;
  /// - a file imports and exports only files that its owner may use, and
  ///   the pipeline added only imports that the contributors of the
  ///   fragments may use: their own files, the files of the modules they
  ///   depend on directly, the files of the roles they provide,
  ///   require or use (the files of each role's template and the files of
  ///   its required symbols), and, for the template and the providers of a
  ///   role, the files of those who contribute data to the role, which they
  ///   render. The cases the harness builds have one provider of each
  ///   role, so there a provider cannot reach the files of another through
  ///   the data.
  ///
  /// Throws an [ArgumentError] if the case of [result] did not resolve.
  List<SmfIssue> checkRendered(ContractResult result, RenderedApp app) {
    final owners = app.owners;
    final texts = app.texts;
    final (:indexes, :issues) = _index(texts, owners);
    issues
      ..addAll(_structureIssues(result, indexes, texts, owners))
      ..addAll(_importIssues(result, app, indexes));
    return issues;
  }

  /// The templates among [collection]'s bricks that have `{{` but no tag
  /// that mason renders, so mason copies them with the braces as they are.
  List<SmfIssue> _copiedTemplateIssues(Collection collection) => [
        for (final collected in collection.applyingOf<BrickContribution>())
          for (final MapEntry(key: path, value: text) in templateFilesOf(
            collected.contribution as BrickContribution,
          ).entries)
            if (text.contains('{{') && !masonTag.hasMatch(text))
              SmfIssue(
                'The template $path of ${collected.origin} has "{{" but no '
                'tag that mason renders, one without ",", ";" or "=", so '
                'mason copies it with the braces as they are.',
                hint: 'Write a literal brace as {{__LEFT_CURLY_BRACKET__}}.',
                origin: collected.origin,
                path: path,
              ),
      ];

  /// The indexes of the Dart files among [files], and a problem for every
  /// file that does not parse.
  ({Map<String, DartFileIndex> indexes, List<SmfIssue> issues}) _index(
    Map<String, String> files,
    Map<String, ContributionOrigin> owners,
  ) {
    final issues = <SmfIssue>[];
    final indexes = <String, DartFileIndex>{};
    for (final MapEntry(key: path, value: text) in files.entries) {
      if (!path.endsWith('.dart')) continue;
      final (:index, :errors) = DartFileIndexer.parse(path, text);
      indexes[path] = index;
      for (final error in errors) {
        issues.add(
          SmfIssue(
            '$path does not parse: $error',
            path: path,
            origin: owners[path],
          ),
        );
      }
    }
    return (indexes: indexes, issues: issues);
  }

  List<SmfIssue> _structureIssues(
    ContractResult result,
    Map<String, DartFileIndex> indexes,
    Map<String, String> texts,
    Map<String, ContributionOrigin> owners,
  ) {
    final (:resolution, :collection) = _resolved(result);
    final request = StructuralRuleRequest(
      hook: hookRequest(
        registry: registry,
        resolution: resolution,
        collection: collection,
        context: context,
        choices: result.choices ?? const {},
      ),
      files: indexes,
      texts: texts,
      owners: owners,
      modules: [for (final module in resolution.modules) module.descriptor],
    );
    return [
      for (final role in resolution.presentRoles) ...[
        ...role.checkStructure(request),
        ...role.interface.checkSymbols(indexes),
      ],
    ];
  }

  ({Resolution resolution, Collection collection}) _resolved(
    ContractResult result,
  ) {
    final resolution = result.resolution;
    final collection = result.collection;
    if (resolution == null || collection == null) {
      throw ArgumentError.value(
        result,
        'result',
        'The case ${result.contractCase} did not resolve',
      );
    }
    return (resolution: resolution, collection: collection);
  }

  /// The problems of the imports of the Dart files of [app]; see
  /// [checkRendered].
  List<SmfIssue> _importIssues(
    ContractResult result,
    RenderedApp app,
    Map<String, DartFileIndex> indexes,
  ) {
    final (:resolution, :collection) = _resolved(result);
    final appName = context.appName;
    final pubspec = result.validation?.pubspec;
    // The code of the app itself may use only its dependencies; tests and
    // tools may use its dev dependencies too, as depend_on_referenced_packages
    // has it.
    final dependencies = {appName, ...?pubspec?.dependencies.keys};
    final devDependencies = {...?pubspec?.devDependencies.keys};

    // The template and the providers of a role render the data of its
    // contributors, so they may import their files.
    final dataContributors = <Role, Set<ContributionOrigin>>{};
    for (final data in collection.roleData) {
      if (data.origin case final origin?) {
        dataContributors.putIfAbsent(data.role, () => {}).add(ownerOf(origin));
      }
    }

    bool mayImport(ContributionOrigin who, String target) {
      final owner = ownerOf(app.files[target]!.owner);
      final user = ownerOf(who);
      if (owner == user) return true;
      // A module knows only the modules it depends on directly.
      if ((user, owner)
          case (ModuleOrigin(:final module), ModuleOrigin(module: final other))
          when resolution
                  .module(module)
                  ?.descriptor
                  .dependsOn
                  .contains(other) ??
              false) {
        return true;
      }
      final roles = rolesOf(who, registry, resolution).access;
      for (final role in roles) {
        if (owner == RoleTemplateOrigin(role) ||
            role.interface.files.contains(target) ||
            role.interface.symbols.any((symbol) => symbol.path == target)) {
          return true;
        }
      }
      for (final role in resolution.presentRoles) {
        final renders = user == RoleTemplateOrigin(role) ||
            resolution.providersOf(role).any((module) => module.origin == user);
        if (renders && (dataContributors[role]?.contains(owner) ?? false)) {
          return true;
        }
      }
      return false;
    }

    final generated = {
      ..._flutterOutputs(app, pubspec),
      for (final collected in collection.applyingOf<CodegenRequest>())
        ...(collected.contribution as CodegenRequest).outputs,
    };
    final issues = <SmfIssue>[];
    for (final MapEntry(key: path, value: index) in indexes.entries) {
      final file = app.files[path];
      if (file == null) continue;
      final added = <String, Set<ContributionOrigin>>{};
      for (final import in file.addedImports) {
        added
            .putIfAbsent(
              '${import.import.uri} as ${import.import.prefix}',
              () => {},
            )
            .add(import.contributor);
      }
      final public = path.startsWith('lib/') || path.startsWith('bin/');
      final packages =
          public ? dependencies : {...dependencies, ...devDependencies};
      for (final (verb, import) in [
        for (final import in index.imports) ('imports', import),
        for (final export in index.exports) ('exports', export),
      ]) {
        final uri = import.uri;
        if (uri.startsWith('dart:')) continue;
        final target = _appPathOf(uri, path, appName);
        if (target == null) {
          final package = uri.startsWith('package:')
              ? uri.substring('package:'.length).split('/').first
              : null;
          if (package != null && !packages.contains(package)) {
            issues.add(
              SmfIssue(
                devDependencies.contains(package)
                    ? '$path $verb $uri, but $package is only a dev '
                        'dependency of the app.'
                    : '$path $verb $uri, but the app does not depend on '
                        '$package.',
                origin: file.owner,
                path: path,
              ),
            );
          }
          continue;
        }
        if (generated.contains(target)) continue;
        if (!app.files.containsKey(target)) {
          issues.add(
            SmfIssue(
              '$path $verb $uri, but the app has no $target.',
              origin: file.owner,
              path: path,
            ),
          );
          continue;
        }
        final key = '${_packageUriOf(uri, path, appName)} as ${import.prefix}';
        final byPipeline = verb == 'imports' && added.containsKey(key);
        for (final who in byPipeline ? added[key]! : {file.owner}) {
          if (mayImport(who, target)) continue;
          final by =
              byPipeline ? 'for a fragment of $who' : 'in the template of $who';
          issues.add(
            SmfIssue(
              '$path $verb $target $by, but that file is of '
              '${app.files[target]!.owner}, which $who neither depends on '
              'nor knows through a role.',
              origin: who,
              path: path,
            ),
          );
        }
      }
    }
    return issues;
  }
}

/// The files of the app that Flutter generates when `flutter pub get` runs
/// after rendering: with `generate: true` in [pubspec], the localizations
/// that `l10n.yaml` describes, in `output-dir`, or else in `arb-dir`, which
/// is `lib/l10n` unless set.
Set<String> _flutterOutputs(RenderedApp app, MergedPubspec? pubspec) {
  final l10n = app.files['l10n.yaml'];
  if (!(pubspec?.generate ?? false) || l10n == null) return const {};
  final Object? yaml;
  try {
    yaml = loadYaml(l10n.text);
  } on YamlException {
    return const {};
  }
  String? read(String key) => switch (yaml) {
        YamlMap(:final nodes) => switch (nodes[key]?.value) {
            final String value => value,
            _ => null,
          },
        _ => null,
      };
  String clean(String path) => [
        for (final segment in path.split('/'))
          if (segment.isNotEmpty && segment != '.') segment,
      ].join('/');
  final directory = clean(read('output-dir') ?? read('arb-dir') ?? 'lib/l10n');
  final file = read('output-localization-file') ?? 'app_localizations.dart';
  return {'$directory/$file'};
}

/// The path relative to the root of the app of the file of the app that
/// [uri] imports in the file at [from], or `null` for a library outside the
/// app.
String? _appPathOf(String uri, String from, String appName) {
  if (uri.startsWith('package:$appName/')) {
    return 'lib/${uri.substring('package:$appName/'.length)}';
  }
  if (uri.contains(':')) return null;
  return Uri.parse(from).resolve(uri).path;
}

/// [uri] as a `package:` URI when it imports a file of the app in `lib/`
/// relatively from [from], which is in `lib/` too; otherwise [uri].
String _packageUriOf(String uri, String from, String appName) {
  final path = _appPathOf(uri, from, appName);
  if (path == null || !path.startsWith('lib/')) return uri;
  return 'package:$appName/${path.substring('lib/'.length)}';
}

/// The subsets of [roles], the largest first.
List<List<Role>> _subsets(List<Role> roles) => [
      for (var size = roles.length; size >= 0; size--)
        for (var mask = 0; mask < 1 << roles.length; mask++)
          if (_bitCount(mask) == size)
            [
              for (var i = 0; i < roles.length; i++)
                if (mask & (1 << i) != 0) roles[i],
            ],
    ];

int _bitCount(int mask) {
  var count = 0;
  for (var rest = mask; rest != 0; rest &= rest - 1) {
    count++;
  }
  return count;
}

final SmfHost _silentHost = SmfHost(
  prompter: const _NoPrompter(),
  processRunner: const _NoProcessRunner(),
  logger: const _SilentLogger(),
  fileSystem: MemoryFileSystem(),
  environmentVariables: const {},
  operatingSystem: HostOperatingSystem.other,
  hasTerminal: false,
);

final class _NoPrompter implements SmfPrompter {
  const _NoPrompter();

  Never _fail(String message) =>
      throw StateError('The contract harness cannot ask: $message');

  @override
  Future<bool> confirm(String message, {bool defaultValue = false}) =>
      _fail(message);

  @override
  Future<String> input(String message, {String? defaultValue}) =>
      _fail(message);

  @override
  Future<T> select<T extends Object>(
    String message,
    List<T> choices, {
    String Function(T choice)? display,
    T? defaultValue,
  }) =>
      _fail(message);

  @override
  Future<List<T>> multiSelect<T extends Object>(
    String message,
    List<T> choices, {
    String Function(T choice)? display,
    List<T> defaultValues = const [],
  }) =>
      _fail(message);
}

final class _NoProcessRunner implements SmfProcessRunner {
  const _NoProcessRunner();

  @override
  Future<SmfProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    bool runInShell = false,
    void Function(String line)? onOutput,
  }) =>
      throw StateError('The contract harness runs no commands: $executable');

  @override
  Future<int> runInteractive(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    bool runInShell = false,
  }) =>
      throw StateError('The contract harness runs no commands: $executable');
}

final class _SilentLogger implements SmfLogger {
  const _SilentLogger();

  @override
  void detail(String message) {}

  @override
  void error(String message) {}

  @override
  void info(String message) {}

  @override
  SmfProgress progress(String message) => const _SilentProgress();

  @override
  void success(String message) {}

  @override
  void warn(String message) {}
}

final class _SilentProgress implements SmfProgress {
  const _SilentProgress();

  @override
  void complete([String? message]) {}

  @override
  void fail([String? message]) {}

  @override
  void update(String message) {}
}
