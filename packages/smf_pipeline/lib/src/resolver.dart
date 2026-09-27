import 'package:smf_contracts/core.dart';
import 'package:smf_pipeline/src/environment.dart';
import 'package:smf_pipeline/src/registry.dart';

/// Why a module is in the app.
sealed class SelectionReason {
  const SelectionReason();
}

/// The user asked for the module.
final class Requested extends SelectionReason {
  /// Creates the reason.
  const Requested();

  @override
  String toString() => 'requested';
}

/// Another module depends on the module.
final class DependencyOf extends SelectionReason {
  /// Creates the reason: [dependent] depends on the module.
  const DependencyOf(this.dependent);

  /// The module that depends on it.
  final ModuleId dependent;

  @override
  String toString() => 'a dependency of $dependent';
}

/// The module provides a role the app needs.
final class ProviderOf extends SelectionReason {
  /// Creates the reason: the module provides [role], which [requiredBy]
  /// needs.
  const ProviderOf(
    this.role,
    this.requiredBy, {
    this.chosen = false,
    this.alternatives = const [],
  });

  /// The role the module provides.
  final Role role;

  /// Who needs the role, as a phrase such as `home requires the router`.
  final String requiredBy;

  /// Whether the user chose the module among several providers.
  final bool chosen;

  /// The other providers a run would offer, if `--explain` took the first
  /// one instead of asking.
  final List<ModuleId> alternatives;

  @override
  String toString() {
    if (alternatives.isNotEmpty) {
      return 'the first provider of the ${role.id} ($requiredBy); a run '
          'asks which one, also offering ${alternatives.join(', ')}';
    }
    return chosen
        ? 'chosen to provide the ${role.id} ($requiredBy)'
        : 'the only provider of the ${role.id} ($requiredBy)';
  }
}

/// A module of the app, with why it is there and which of its variants
/// applies.
final class ResolvedModule {
  /// Creates the module.
  const ResolvedModule(this.module, this.reason, {this.variant});

  /// The module.
  final SmfModule module;

  /// Why the module is in the app.
  final SelectionReason reason;

  /// The provider whose variant of the module applies, if the module has
  /// variants.
  final ModuleId? variant;

  /// The descriptor of the module.
  ModuleDescriptor get descriptor => module.descriptor;

  /// The id of the module.
  ModuleId get id => module.descriptor.id;

  /// The origin of the module's own contributions.
  ModuleOrigin get origin => ModuleOrigin(id);
}

/// Stage 3 of the pipeline: the modules of the app and the roles they
/// provide.
final class Resolution {
  /// Creates the resolution.
  Resolution(this.modules)
      : presentRoles = {
          for (final module in modules) ...module.descriptor.provides,
        };

  /// The modules of the app, in the order they were selected: the requested
  /// ones in the order given, then those added for them.
  final List<ResolvedModule> modules;

  /// The roles present in the app: those its modules provide, in the order
  /// of their first provider.
  final Set<Role> presentRoles;

  /// The module [id], if it is in the app.
  ResolvedModule? module(ModuleId id) {
    for (final module in modules) {
      if (module.id == id) return module;
    }
    return null;
  }

  /// The modules of the app that provide [role].
  List<ResolvedModule> providersOf(Role role) => [
        for (final module in modules)
          if (module.descriptor.provides.contains(role)) module,
      ];

  /// The provider object of [role] of the module [module].
  static RoleProvider providerObject(ResolvedModule module, Role role) =>
      module.descriptor.providers
          .firstWhere((provider) => identical(provider.role, role));

  /// The modules [id] depends on, directly or not.
  Set<ModuleId> dependencyClosure(ModuleId id) {
    final closure = <ModuleId>{};
    void visit(ModuleId current) {
      final module = this.module(current);
      if (module == null) return;
      for (final dependency in module.descriptor.dependsOn) {
        if (closure.add(dependency)) visit(dependency);
      }
    }

    visit(id);
    return closure;
  }
}

/// The result of stage 3: a [resolution] or the [issues] that prevent one.
final class ResolverResult {
  /// Creates the result.
  const ResolverResult({this.resolution, this.issues = const []});

  /// The modules of the app, or `null` if [issues] has errors.
  final Resolution? resolution;

  /// The problems found; those with a module origin can be left out in
  /// lenient mode.
  final List<SmfIssue> issues;
}

/// Stage 3 of the pipeline: adds what the [requested] modules need until
/// nothing changes, and picks their variants.
///
/// - The modules each module depends on are added.
/// - A role that the modules or other present roles require, and every role
///   that each app has exactly one of, gets a provider: the only one in the
///   registry, or the one the user picks. In a run that is not interactive,
///   several providers are a usage error.
/// - A role can have one provider unless it allows many.
/// - A module with variants gets the variant of the selected provider of
///   their role.
///
/// With [explain], a role with several providers takes the first one and
/// records the others, since `--explain` asks nothing.
///
/// Modules in [excluded], which lenient mode left out, are never added.
/// Problems caused by a module carry its origin, so lenient mode can leave
/// it out too. [answers] keeps the user's picks between runs of the stage.
Future<ResolverResult> resolve({
  required List<ModuleId> requested,
  required ModuleRegistry registry,
  required PipelineEnvironment environment,
  Set<Role> declined = const {},
  Set<ModuleId> excluded = const {},
  Map<Role, ModuleId>? answers,
  bool explain = false,
}) async {
  final resolver = _Resolver(
    registry: registry,
    environment: environment,
    declined: declined,
    excluded: excluded,
    picks: answers ?? {},
    explain: explain,
  );
  for (final id in requested) {
    final module = registry[id] ??
        (throw ArgumentError.value(id, 'requested', 'Not in the registry'));
    if (!excluded.contains(id)) resolver.add(module, const Requested());
  }

  var changed = true;
  while (changed) {
    changed = resolver.addDependencies() || await resolver.addProvider();
  }

  final modules = resolver.selected.values.toList();
  final byRole = _providersByRole(modules);
  final resolved = [
    for (final module in modules) resolver.withVariant(module, byRole),
  ];

  final issues = resolver.issues.values;
  final hasErrors = issues.any((issue) => issue.isError);
  return ResolverResult(
    resolution: hasErrors ? null : Resolution(List.unmodifiable(resolved)),
    issues: List.unmodifiable(issues),
  );
}

/// The modules that [resolve] selects so far, and the problems it found.
final class _Resolver {
  _Resolver({
    required this.registry,
    required this.environment,
    required this.declined,
    required this.excluded,
    required this.picks,
    required this.explain,
  });

  final ModuleRegistry registry;
  final PipelineEnvironment environment;
  final Set<Role> declined;
  final Set<ModuleId> excluded;

  /// The user's picks of providers, kept between runs of the stage.
  final Map<Role, ModuleId> picks;

  final bool explain;

  /// The selected modules by id.
  final Map<ModuleId, ResolvedModule> selected = {};

  /// The problems found, keyed by message: the loop of [resolve] may find
  /// a problem more than once.
  final Map<String, SmfIssue> issues = {};

  void _report(SmfIssue issue) => issues[issue.message] = issue;

  /// Selects [module] for [reason].
  void add(SmfModule module, SelectionReason reason) =>
      selected[module.descriptor.id] = ResolvedModule(module, reason);

  /// Adds the modules that the selected modules depend on and returns
  /// whether it added one.
  bool addDependencies() {
    var changed = false;
    for (final module in selected.values.toList()) {
      for (final dependency in module.descriptor.dependsOn) {
        if (selected.containsKey(dependency)) continue;
        if (excluded.contains(dependency)) {
          _report(
            SmfIssue(
              '${module.id} depends on $dependency, which was left out.',
              origin: module.origin,
            ),
          );
          continue;
        }
        add(registry[dependency]!, DependencyOf(module.id));
        changed = true;
      }
    }
    return changed;
  }

  /// Adds a provider of the first role that the selected modules need and
  /// no selected module provides, and returns whether it added one. A
  /// module added here may provide or require other roles, so every
  /// addition starts a new pass.
  Future<bool> addProvider() async {
    final present = {
      for (final module in selected.values) ...module.descriptor.provides,
    };
    for (final MapEntry(key: role, value: need)
        in _requiredRoles(selected.values, registry).entries) {
      if (present.contains(role)) continue;
      if (declined.contains(role)) {
        _report(
          SmfIssue(
            'No module provides the ${role.id}, as chosen, but '
            '${need.phrase}.',
            hint: 'Choose a provider of the ${role.id}, or leave out '
                '${need.module ?? 'what needs it'}.',
          ),
        );
        continue;
      }
      final candidates = _candidatesFor(role);
      if (candidates.isEmpty) {
        _report(_noProviderIssue(role, need));
        continue;
      }
      if (candidates.length == 1) {
        add(candidates.single, ProviderOf(role, need.phrase));
        return true;
      }
      final (module, others) = await _pick(role, need, candidates);
      add(
        module,
        ProviderOf(role, need.phrase, chosen: true, alternatives: others),
      );
      return true;
    }
    return false;
  }

  /// The providers of [role] in the registry that are not excluded.
  List<SmfModule> _candidatesFor(Role role) => [
        for (final module in registry.providersOf(role))
          if (!excluded.contains(module.descriptor.id)) module,
      ];

  SmfIssue _noProviderIssue(Role role, _Need need) => SmfIssue(
        'No module provides the ${role.id}, but ${need.phrase}.',
        origin: need.module == null ? null : ModuleOrigin(need.module!),
      );

  /// The provider of [role] among [candidates] for [need], with the others
  /// that `--explain` did not take: the user's earlier pick, the first one
  /// with `--explain`, or the one the user picks now.
  ///
  /// Throws an [SmfUsageException] if the run cannot ask the user.
  Future<(SmfModule, List<ModuleId>)> _pick(
    Role role,
    _Need need,
    List<SmfModule> candidates,
  ) async {
    final remembered = picks[role];
    if (remembered != null &&
        candidates.any((c) => c.descriptor.id == remembered)) {
      return (registry[remembered]!, const <ModuleId>[]);
    }
    if (explain) {
      return (
        candidates.first,
        [for (final other in candidates.skip(1)) other.descriptor.id],
      );
    }
    if (environment.interactive) {
      final module = await environment.prompter.select(
        '${role.description}: ${need.phrase}. Which module provides it?',
        candidates,
        display: (module) =>
            '${module.descriptor.id} — ${module.descriptor.description}',
      );
      picks[role] = module.descriptor.id;
      return (module, const <ModuleId>[]);
    }
    throw SmfUsageException(
      'Several modules provide the ${role.id}, which ${need.phrase}: '
      '${candidates.map((m) => m.descriptor.id).join(', ')}. Add one '
      'of them to -m.',
    );
  }

  /// [module] with the variant of the provider of the role of its
  /// variants, among the providers of each role, [byRole].
  ResolvedModule withVariant(
    ResolvedModule module,
    Map<Role, List<ResolvedModule>> byRole,
  ) {
    final variants = module.descriptor.variants;
    if (variants == null) return module;
    final provider = byRole[variants.role]?.single;
    // The role is missing; its issue is already reported.
    if (provider == null) return module;
    if (!variants.byProvider.containsKey(provider.id)) {
      _report(
        SmfIssue(
          '${module.id} has no variant for ${provider.id}, the provider of '
          'the ${variants.role.id}. It supports '
          '${variants.byProvider.keys.join(', ')}.',
          origin: module.origin,
        ),
      );
    }
    return ResolvedModule(module.module, module.reason, variant: provider.id);
  }
}

/// The providers of each role among [modules].
///
/// Throws an [SmfUsageException] if a role that allows one provider has
/// more.
Map<Role, List<ResolvedModule>> _providersByRole(
  List<ResolvedModule> modules,
) {
  final byRole = <Role, List<ResolvedModule>>{};
  for (final module in modules) {
    for (final role in module.descriptor.provides) {
      byRole.putIfAbsent(role, () => []).add(module);
    }
  }
  for (final MapEntry(key: role, value: providers) in byRole.entries) {
    if (providers.length > 1 && !role.cardinality.allowsMany) {
      throw SmfUsageException(
        'An app can have one provider of the ${role.id}, but it has '
        '${providers.map((m) => '${m.id} (${m.reason})').join(' and ')}. '
        'Keep one of them.',
      );
    }
  }
  return byRole;
}

/// Who needs a role.
final class _Need {
  const _Need(this.phrase, [this.module]);

  /// Who needs the role, as a phrase.
  final String phrase;

  /// The module that needs it, if a module does.
  final ModuleId? module;
}

/// The roles [modules] need, with who needs each: every role that each app
/// has exactly one of, and the roles each module requires, including those
/// the roles it provides require.
Map<Role, _Need> _requiredRoles(
  Iterable<ResolvedModule> modules,
  ModuleRegistry registry,
) {
  final needs = <Role, _Need>{};
  for (final role in registry.roles) {
    if (role.cardinality == RoleCardinality.exactlyOne) {
      needs[role] = _Need('every app needs the ${role.id}');
    }
  }
  for (final module in modules) {
    for (final role in module.descriptor.effectiveRequires) {
      needs.putIfAbsent(
        role,
        () => _Need('${module.id} requires the ${role.id}', module.id),
      );
    }
  }
  return needs;
}
