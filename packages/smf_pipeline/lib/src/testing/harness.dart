import 'package:file/memory.dart';
import 'package:smf_contracts/lego_core.dart';
import 'package:smf_pipeline/src/collector.dart';
import 'package:smf_pipeline/src/environment.dart';
import 'package:smf_pipeline/src/host.dart';
import 'package:smf_pipeline/src/registry.dart';
import 'package:smf_pipeline/src/resolver.dart';
import 'package:smf_pipeline/src/templates.dart';
import 'package:smf_pipeline/src/testing/file_indexer.dart';
import 'package:smf_pipeline/src/validation.dart';

/// One app the harness builds to check a module or a role: the modules
/// asked for and the provider picked for each role.
final class ContractCase {
  /// Creates the case [name].
  const ContractCase(
    this.name, {
    required this.requested,
    this.picks = const {},
  });

  /// What the case checks, such as `home (bloc) with analytics`.
  final String name;

  /// The modules asked for.
  final List<ModuleId> requested;

  /// The provider of each role that has several in the registry.
  final Map<Role, ModuleId> picks;

  @override
  String toString() => name;
}

/// The problems the harness found in one [ContractCase].
final class ContractResult {
  /// Creates the result.
  const ContractResult(this.contractCase, this.issues, {this.resolution});

  /// The case.
  final ContractCase contractCase;

  /// The errors and warnings found.
  final List<SmfIssue> issues;

  /// The modules of the app, if the case resolved.
  final Resolution? resolution;

  /// The errors among [issues].
  List<SmfIssue> get errors => [
        for (final issue in issues)
          if (issue.isError) issue,
      ];
}

/// The contract test harness: checks that the modules and roles of a
/// registry follow the rules of the lego model, the way the pipeline would
/// generate them in every combination that matters.
///
/// For a module it builds an app for each of its variants and each subset
/// of the roles it only uses, adding a provider for every role the app
/// needs; for a role, the same for each of its providers and each subset of
/// the roles the role uses. Each app goes through the stages 3 to 5 of the
/// pipeline, then [checkTemplateTags]. The checks of rendered code, such as
/// the structural rules of the roles, run on files with [checkStructure].
///
/// It depends on no test framework, so the tests of any package can use it.
final class ContractHarness {
  /// Creates the harness for [registry], generating apps described by
  /// [context].
  ContractHarness(this.registry, {this.context = defaultContext});

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

  /// The cases of the module [id]: each variant of the module, and each
  /// subset of the roles it only uses, with the first registered provider
  /// of every role the case needs unless a variant decides.
  ///
  /// A role left out of a subset is still present when another module of
  /// the case requires it.
  List<ContractCase> casesOfModule(ModuleId id) {
    final module = registry[id];
    if (module == null) throw ArgumentError.value(id, 'id', 'Not registered');
    final descriptor = module.descriptor;
    final variants = descriptor.variants;
    final variantPicks = variants == null
        ? const <Map<Role, ModuleId>>[{}]
        : [
            for (final provider in variants.byProvider.keys)
              {variants.role: provider},
          ];
    final used = [
      for (final role in descriptor.effectiveUses)
        if (registry.providersOf(role).isNotEmpty) role,
    ];
    return [
      for (final picks in variantPicks)
        for (final subset in _subsets(used))
          _case(
            [
              id.value,
              for (final provider in picks.values) '($provider)',
              if (subset.isNotEmpty)
                'with ${subset.map((role) => role.id).join(', ')}',
            ].join(' '),
            [id],
            picks: picks,
            present: subset,
          ),
    ];
  }

  /// The cases of [role]: each of its providers with each subset of the
  /// roles it uses.
  List<ContractCase> casesOfRole(Role role) {
    final used = [
      for (final other in role.uses)
        if (registry.providersOf(other).isNotEmpty) other,
    ];
    return [
      for (final provider in registry.providersOf(role))
        for (final subset in _subsets(used))
          _case(
            [
              '${role.id} by ${provider.descriptor.id}',
              if (subset.isNotEmpty)
                'with ${subset.map((role) => role.id).join(', ')}',
            ].join(' '),
            [provider.descriptor.id],
            picks: {role: provider.descriptor.id},
            present: subset,
          ),
    ];
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

  /// Runs the stages 3 to 5 of the pipeline and [checkTemplateTags] for
  /// [contractCase].
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
    );
    return ContractResult(
      contractCase,
      [
        ...resolved.issues,
        ...validation.issues,
        ...checkTemplateTags(
          registry: registry,
          resolution: resolution,
          collection: collection,
        ),
      ],
      resolution: resolution,
    );
  }

  /// Checks every case of every module and every role of the registry.
  Future<List<ContractResult>> checkAll() async => [
        for (final module in registry.modules)
          for (final contractCase in casesOfModule(module.descriptor.id))
            await check(contractCase),
        for (final role in registry.roles)
          for (final contractCase in casesOfRole(role))
            await check(contractCase),
      ];

  /// Indexes the Dart files among [files], rendered text by path, and runs
  /// the structural rules of the present roles of [resolution] and checks
  /// the symbols of their interfaces.
  ///
  /// [owners] names who generated each file; [data] is the data of the
  /// roles, as the pipeline collected it.
  List<SmfIssue> checkStructure({
    required Resolution resolution,
    required Map<String, String> files,
    Map<String, ContributionOrigin> owners = const {},
    List<RoleData<Object>> data = const [],
  }) {
    final indexes = {
      for (final MapEntry(key: path, value: text) in files.entries)
        if (path.endsWith('.dart')) path: DartFileIndexer.index(path, text),
    };
    final issues = <SmfIssue>[
      for (final MapEntry(key: path, value: text) in files.entries)
        if (path.endsWith('.dart'))
          for (final error in DartFileIndexer.errorsOf(text))
            SmfIssue(
              '$path does not parse: $error',
              path: path,
              origin: owners[path],
            ),
    ];
    final request = StructuralRuleRequest(
      hook: RoleHookRequest(
        data: data,
        presentRoles: resolution.presentRoles,
        context: context,
      ),
      files: indexes,
      owners: owners,
      modules: [for (final module in resolution.modules) module.descriptor],
    );
    for (final role in resolution.presentRoles) {
      issues
        ..addAll(role.checkStructure(request))
        ..addAll(role.interface.checkSymbols(indexes));
    }
    return issues;
  }
}

/// Every subset of [roles], the empty one first, in a stable order.
List<List<Role>> _subsets(List<Role> roles) => [
      for (var mask = 0; mask < 1 << roles.length; mask++)
        [
          for (var i = 0; i < roles.length; i++)
            if (mask & (1 << i) != 0) roles[i],
        ],
    ];

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
