import 'package:file/file.dart';
import 'package:smf_contracts/lego_core.dart';
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
      var index = 1;
      var copy = '$path copy';
      while (fileSystem.typeSync(copy) != FileSystemEntityType.notFound) {
        index++;
        copy = '$path copy $index';
      }
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
  final prompter = environment.prompter;
  final chosen = <SmfModule>[];
  // Providers the answers need that the user was not asked about: the
  // resolver adds them with the reason, so they are not requested.
  final implied = <SmfModule>[];
  final declined = <Role>{};
  final asked = <Role>{};

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

  // Asks until the answers need no more roles: a later answer can need a
  // role that was declined before, which is then asked again without
  // "None".
  var changed = true;
  while (changed) {
    changed = false;
    for (final role in _promptOrder(registry)) {
      final providers = registry.providersOf(role);
      if (providers.isEmpty) continue;
      final app = _withDependencies([...chosen, ...implied], registry);
      if (app.any((module) => module.descriptor.provides.contains(role))) {
        continue;
      }
      final requiredBy = _requirer(role, app);
      if (asked.contains(role) && requiredBy == null) continue;
      asked.add(role);
      declined.remove(role);
      if (requiredBy != null && providers.length == 1) {
        implied.add(providers.single);
        changed = true;
        continue;
      }
      final question = requiredBy == null
          ? '${role.description}: which module provides it?'
          : '${role.description}: $requiredBy. Which module provides it?';
      if (role.cardinality.allowsMany) {
        final picked = await prompter.multiSelect<SmfModule>(
          question,
          providers,
          display: _display,
          defaultValues: requiredBy == null ? const [] : [providers.first],
        );
        if (picked.isEmpty && requiredBy != null) {
          throw SmfUsageException(
            'The app needs a module that provides the ${role.id}: '
            '$requiredBy.',
          );
        }
        if (picked.isEmpty) declined.add(role);
        chosen.addAll(picked);
        changed |= picked.isNotEmpty;
        continue;
      }
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
      } else {
        chosen.add(module);
        changed = true;
      }
    }
  }
  return ([for (final module in chosen) module.descriptor.id], declined);
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

/// Why the modules in [chosen] need [role], or `null` if they do not.
String? _requirer(Role role, List<SmfModule> chosen) {
  if (role.cardinality == RoleCardinality.exactlyOne) {
    return 'every app needs the ${role.id}';
  }
  for (final module in chosen) {
    // Includes the roles that the roles the module provides require.
    final descriptor = module.descriptor;
    if (descriptor.effectiveRequires.contains(role)) {
      return '${descriptor.id} requires the ${role.id}';
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
