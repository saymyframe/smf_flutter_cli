import 'package:file/file.dart';
import 'package:smf_contracts/core.dart';
import 'package:smf_pipeline/src/environment.dart';
import 'package:smf_pipeline/src/errors.dart';
import 'package:smf_pipeline/src/identity.dart';
import 'package:smf_pipeline/src/registry.dart';
import 'package:smf_pipeline/src/request.dart';

/// Where the app will be generated.
final class TargetDecision {
  /// Creates the decision.
  const TargetDecision({
    required this.path,
    this.replaceExisting = false,
    this.conflict = false,
  });

  /// The absolute path of the app's directory.
  final String path;

  /// Whether the existing directory at [path] is replaced once the app has
  /// been generated.
  final bool replaceExisting;

  /// Whether a non-empty directory exists where the app would go and no
  /// decision was made, as in `--explain`.
  final bool conflict;
}

/// Stage 1 of the pipeline: what the user asked for.
final class Selection {
  /// Creates the selection.
  const Selection({
    required this.appName,
    required this.org,
    required this.target,
    required this.requested,
    this.declined = const {},
  });

  /// The name of the app as given.
  final String appName;

  /// The organization as given.
  final String org;

  /// Where the app will be generated.
  final TargetDecision target;

  /// The modules the user asked for, in order.
  final List<ModuleId> requested;

  /// The roles for which the user explicitly chose no provider.
  final Set<Role> declined;
}

/// Stage 1 of the pipeline: reads the app name, the organization, the
/// target directory and the modules from [request], and asks the user for
/// what is missing if the run is interactive.
///
/// The conflict with an existing directory is decided here, before any
/// external action.
Future<Selection> select(
  CreateRequest request,
  ModuleRegistry registry,
  PipelineEnvironment environment,
) async {
  final interactive = environment.interactive;
  final given = request.modules;
  if (given != null) _checkRegistered(given, registry);

  final String appName;
  if (request.appName case final name?) {
    appName = name;
    AppNames.packageName(name);
  } else if (interactive) {
    appName = await _askValid(
      environment,
      'App name',
      'my_app',
      AppNames.packageName,
    );
  } else {
    throw const SmfUsageException(
      'Give the name of the app, as in "smf create my_app".',
    );
  }
  final package = AppNames.packageName(appName);

  final target = await _decideTarget(request, package, environment);

  final String org;
  if (request.org case final given?) {
    org = given;
    AppNames.orgSegments(org);
  } else if (interactive) {
    org = await _askValid(
      environment,
      'Organization (reverse domain)',
      AppNames.defaultOrg,
      AppNames.orgSegments,
    );
  } else {
    org = AppNames.defaultOrg;
  }

  if (given != null) {
    return Selection(
      appName: appName,
      org: org,
      target: target,
      requested: given,
    );
  }
  if (!interactive) {
    environment.logger.info(
      request.explain
          ? 'No modules were given with -m, so this explains an app with only '
              'what every app needs; a run in a terminal would ask for them.'
          : 'No modules were given with -m, so the app has only what every '
              'app needs.',
    );
    return Selection(
      appName: appName,
      org: org,
      target: target,
      requested: const [],
    );
  }
  final (requested, declined) = await _askModules(registry, environment);
  return Selection(
    appName: appName,
    org: org,
    target: target,
    requested: requested,
    declined: declined,
  );
}

/// Asks for text until [check] accepts it, reporting why it did not.
Future<String> _askValid(
  PipelineEnvironment environment,
  String message,
  String defaultValue,
  Object Function(String text) check,
) async {
  while (true) {
    final text = await environment.prompter.input(
      message,
      defaultValue: defaultValue,
    );
    try {
      check(text);
      return text;
    } on SmfUsageException catch (error) {
      environment.logger.warn(error.message);
    }
  }
}

void _checkRegistered(List<ModuleId> ids, ModuleRegistry registry) {
  for (final id in ids) {
    if (registry[id] != null) continue;
    final known = registry.ids.map((id) => id.value).toList();
    final close = known.where((name) => _distance(name, id.value) <= 2).toList()
      ..sort(
        (a, b) => _distance(a, id.value).compareTo(_distance(b, id.value)),
      );
    throw SmfUsageException(
      [
        'There is no module $id.',
        if (close.isNotEmpty) 'Did you mean ${close.first}?',
        'Modules: ${known.join(', ')}.',
      ].join(' '),
    );
  }
}

/// The Levenshtein distance of [a] and [b].
int _distance(String a, String b) {
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 0; i < a.length; i++) {
    final current = [i + 1];
    for (var j = 0; j < b.length; j++) {
      final cost = a[i] == b[j] ? 0 : 1;
      current.add(
        [current[j] + 1, previous[j + 1] + 1, previous[j] + cost]
            .reduce((x, y) => x < y ? x : y),
      );
    }
    previous = current;
  }
  return previous.last;
}

Future<TargetDecision> _decideTarget(
  CreateRequest request,
  String package,
  PipelineEnvironment environment,
) async {
  final fileSystem = environment.fileSystem;
  final context = fileSystem.path;
  final path = context.normalize(
    context.absolute(context.join(request.outputDirectory, package)),
  );
  await _checkNoFileAt(path, environment);
  final directory = fileSystem.directory(path);
  if (!directory.existsSync() || directory.listSync().isEmpty) {
    return TargetDecision(path: path);
  }
  if (request.explain) return TargetDecision(path: path, conflict: true);

  var decision = request.onConflict;
  final asked = decision == OnConflict.prompt;
  if (asked) {
    if (!environment.interactive) {
      throw SmfUsageException(
        '$path already exists. Choose what to do with --on-conflict: '
        'replace, copy or cancel.',
      );
    }
    decision = await environment.prompter.select(
      '$path already exists. What should happen to it?',
      const [OnConflict.copy, OnConflict.replace, OnConflict.cancel],
      display: (choice) => switch (choice) {
        OnConflict.replace => 'Replace it with the new app',
        OnConflict.copy => 'Keep it and create the app next to it',
        _ => 'Cancel',
      },
      defaultValue: OnConflict.copy,
    );
  }
  switch (decision) {
    case OnConflict.replace:
      environment.logger.warn(
        '$path will be replaced once the app has been generated.',
      );
      return TargetDecision(path: path, replaceExisting: true);
    case OnConflict.copy:
      final copy = _copyPath(path, fileSystem);
      environment.logger.info('The app will be created at $copy.');
      return TargetDecision(path: copy);
    case OnConflict.prompt:
    case OnConflict.cancel:
      // The user's answer cancels the run as Ctrl-C does; the option makes
      // a script fail.
      if (asked) throw const SmfCancelledException();
      throw GenerationFailedException(
        '$path already exists, and the run was cancelled.',
      );
  }
}

/// Throws an [SmfUsageException] if a file is at [path], the directory of
/// the app, or at a directory above it.
Future<void> _checkNoFileAt(
  String path,
  PipelineEnvironment environment,
) async {
  final fileSystem = environment.fileSystem;
  final context = fileSystem.path;
  if (await fileSystem.isFile(path)) {
    throw SmfUsageException(
      'Cannot create the app at $path, because a file is there.',
    );
  }
  for (var parent = context.dirname(path);
      parent != context.dirname(parent);
      parent = context.dirname(parent)) {
    if (await fileSystem.isFile(parent)) {
      throw SmfUsageException(
        'Cannot create the app at $path, because $parent is a file.',
      );
    }
  }
}

/// The first of `<path> copy`, `<path> copy 2` and so on that is free.
String _copyPath(String path, FileSystem fileSystem) {
  var index = 1;
  var copy = '$path copy';
  while (fileSystem.typeSync(copy) != FileSystemEntityType.notFound) {
    index++;
    copy = '$path copy $index';
  }
  return copy;
}

/// Asks the user for the modules: first those without a role, grouped by
/// kind, then a provider of each role.
///
/// A role that the modules chosen so far require offers no "none"; with a
/// single provider, that provider is taken without asking. Roles that other
/// roles require are asked last, so their question knows whether they are
/// required.
Future<(List<ModuleId>, Set<Role>)> _askModules(
  ModuleRegistry registry,
  PipelineEnvironment environment,
) async {
  final questions = _ModuleQuestions(registry, environment.prompter);
  await questions.askModulesWithoutRoles();

  // Asks until the answers need no more roles: a later answer can need a
  // role that was declined before, which is then asked again without
  // "None".
  var changed = true;
  while (changed) {
    changed = false;
    for (final role in _promptOrder(registry)) {
      changed |= await questions.askRole(role);
    }
  }
  return (
    [for (final module in questions.chosen) module.descriptor.id],
    questions.declined,
  );
}

/// The questions of [_askModules] and the answers so far.
final class _ModuleQuestions {
  _ModuleQuestions(this.registry, this.prompter);

  final ModuleRegistry registry;
  final SmfPrompter prompter;

  /// The modules the user chose.
  final List<SmfModule> chosen = [];

  /// Providers the answers need that the user was not asked about: the
  /// resolver adds them with the reason, so they are not requested.
  final List<SmfModule> implied = [];

  /// The roles the user chose no provider of.
  final Set<Role> declined = {};

  final Set<Role> _asked = {};

  /// Asks for the modules without a role, grouped by kind.
  Future<void> askModulesWithoutRoles() async {
    final byKind = <String, List<SmfModule>>{};
    for (final module in registry.modules) {
      if (module.descriptor.providers.isEmpty) {
        byKind.putIfAbsent(module.descriptor.kind.id, () => []).add(module);
      }
    }
    for (final modules in byKind.values) {
      chosen.addAll(
        await prompter.multiSelect(
          '${modules.first.descriptor.kind.label}: which do you want?',
          modules,
          display: _display,
        ),
      );
    }
  }

  /// Asks for a provider of [role], unless no module provides it, the
  /// answers so far have one, or it was asked before and the answers do
  /// not require it; a single provider that the answers require is taken
  /// without asking. Returns whether it added a module to the answers.
  Future<bool> askRole(Role role) async {
    final providers = registry.providersOf(role);
    if (providers.isEmpty) return false;
    final app = _withDependencies([...chosen, ...implied], registry);
    if (app.any((module) => module.descriptor.provides.contains(role))) {
      return false;
    }
    final requiredBy = _requirer(role, app);
    if (_asked.contains(role) && requiredBy == null) return false;
    _asked.add(role);
    declined.remove(role);
    if (requiredBy != null && providers.length == 1) {
      implied.add(providers.single);
      return true;
    }
    final question = requiredBy == null
        ? '${role.description}: which module provides it?'
        : '${role.description}: $requiredBy the $role. Which module provides '
            'it?';
    if (role.cardinality.allowsMany) {
      return _askMany(role, providers, question, requiredBy: requiredBy);
    }
    return _askOne(role, providers, question, requiredBy: requiredBy);
  }

  /// Asks for the [providers] of [role] with [question], and requires one
  /// if the answers need the role for [requiredBy].
  Future<bool> _askMany(
    Role role,
    List<SmfModule> providers,
    String question, {
    required String? requiredBy,
  }) async {
    final picked = await prompter.multiSelect<SmfModule>(
      question,
      providers,
      display: _display,
      defaultValues: requiredBy == null ? const [] : [providers.first],
    );
    if (picked.isEmpty && requiredBy != null) {
      throw SmfUsageException(
        'The app needs a module that provides the $role, which '
        '$requiredBy.',
      );
    }
    if (picked.isEmpty) declined.add(role);
    chosen.addAll(picked);
    return picked.isNotEmpty;
  }

  /// Asks for one of the [providers] of [role] with [question], or none
  /// unless the answers need the role for [requiredBy].
  Future<bool> _askOne(
    Role role,
    List<SmfModule> providers,
    String question, {
    required String? requiredBy,
  }) async {
    final picked = await prompter.select<_Choice>(
      question,
      [
        for (final provider in providers) _Choice(provider),
        if (requiredBy == null) const _Choice(null),
      ],
      display: (choice) =>
          choice.module == null ? 'None' : _display(choice.module!),
    );
    final module = picked.module;
    if (module == null) {
      declined.add(role);
      return false;
    }
    chosen.add(module);
    return true;
  }
}

/// [chosen] and the modules they depend on, directly or not.
List<SmfModule> _withDependencies(
  List<SmfModule> chosen,
  ModuleRegistry registry,
) {
  final all = <ModuleId, SmfModule>{};
  void add(SmfModule module) {
    if (all.containsKey(module.descriptor.id)) return;
    all[module.descriptor.id] = module;
    for (final dependency in module.descriptor.dependsOn) {
      if (registry[dependency] case final dependency?) add(dependency);
    }
  }

  chosen.forEach(add);
  return all.values.toList();
}

final class _Choice {
  const _Choice(this.module);

  final SmfModule? module;
}

String _display(SmfModule module) =>
    '${module.descriptor.id} — ${module.descriptor.description}';

/// Who among the modules in [chosen] needs [role], and how, as the start
/// of a phrase such as `home requires`, or `null` if they do not need it.
String? _requirer(Role role, List<SmfModule> chosen) {
  if (role.cardinality == RoleCardinality.exactlyOne) {
    return 'every app needs';
  }
  for (final module in chosen) {
    // Includes the roles that the roles the module provides require.
    final descriptor = module.descriptor;
    if (descriptor.effectiveRequires.contains(role)) {
      return '${descriptor.id} requires';
    }
  }
  return null;
}

/// The roles in the order they are asked: a role comes after the roles
/// that require it, or whose providers do, so its question knows whether
/// the answers so far need it; otherwise the order of the registry.
List<Role> _promptOrder(ModuleRegistry registry) {
  final ordered = <Role>[];
  final visiting = <Role>{};
  bool needs(Role other, Role role) =>
      other.requires.contains(role) ||
      registry.providersOf(other).any(
            (module) => module.descriptor.effectiveRequires.contains(role),
          );
  void visit(Role role) {
    if (ordered.contains(role) || !visiting.add(role)) return;
    for (final other in registry.roles) {
      if (!identical(other, role) && needs(other, role)) visit(other);
    }
    ordered.add(role);
  }

  registry.roles.forEach(visit);
  return ordered;
}
