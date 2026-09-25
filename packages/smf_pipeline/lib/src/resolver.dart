import 'package:smf_contracts/lego_core.dart';
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
  final selected = <ModuleId, ResolvedModule>{};
  // Keyed by message: the loop may find a problem more than once.
  final issues = <String, SmfIssue>{};
  void report(SmfIssue issue) => issues[issue.message] = issue;
  final picks = answers ?? {};

  void add(SmfModule module, SelectionReason reason) =>
      selected[module.descriptor.id] = ResolvedModule(module, reason);

  for (final id in requested) {
    final module = registry[id] ??
        (throw ArgumentError.value(id, 'requested', 'Not in the registry'));
    if (!excluded.contains(id)) add(module, const Requested());
  }

  var changed = true;
  while (changed) {
    changed = false;

    for (final module in selected.values.toList()) {
      for (final dependency in module.descriptor.dependsOn) {
        if (selected.containsKey(dependency)) continue;
        if (excluded.contains(dependency)) {
          report(
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
    if (changed) continue;

    final present = {
      for (final module in selected.values) ...module.descriptor.provides,
    };
    for (final MapEntry(key: role, value: need)
        in _requiredRoles(selected.values, registry).entries) {
      if (present.contains(role)) continue;
      if (declined.contains(role)) {
        report(
          SmfIssue(
            'No module provides the ${role.id}, as chosen, but '
            '${need.phrase}.',
            hint: 'Choose a provider of the ${role.id}, or leave out '
                '${need.module ?? 'what needs it'}.',
          ),
        );
        continue;
      }
      final candidates = [
        for (final module in registry.providersOf(role))
          if (!excluded.contains(module.descriptor.id)) module,
      ];
      if (candidates.isEmpty) {
        report(
          SmfIssue(
            'No module provides the ${role.id}, but ${need.phrase}.',
            origin: need.module == null ? null : ModuleOrigin(need.module!),
          ),
        );
        continue;
      }
      // A module added here may provide or require other roles, so every
      // addition starts a new pass.
      if (candidates.length == 1) {
        add(candidates.single, ProviderOf(role, need.phrase));
        changed = true;
        break;
      }
      final remembered = picks[role];
      final SmfModule module;
      var others = const <ModuleId>[];
      if (remembered != null &&
          candidates.any((c) => c.descriptor.id == remembered)) {
        module = registry[remembered]!;
      } else if (explain) {
        module = candidates.first;
        others = [for (final other in candidates.skip(1)) other.descriptor.id];
      } else if (environment.interactive) {
        module = await environment.prompter.select(
          '${role.description}: ${need.phrase}. Which module provides it?',
          candidates,
          display: (module) =>
              '${module.descriptor.id} — ${module.descriptor.description}',
        );
        picks[role] = module.descriptor.id;
      } else {
        throw SmfUsageException(
          'Several modules provide the ${role.id}, which ${need.phrase}: '
          '${candidates.map((m) => m.descriptor.id).join(', ')}. Add one '
          'of them to -m.',
        );
      }
      add(
        module,
        ProviderOf(role, need.phrase, chosen: true, alternatives: others),
      );
      changed = true;
      break;
    }
  }

  final modules = selected.values.toList();
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

  final resolved = <ResolvedModule>[];
  for (final module in modules) {
    final variants = module.descriptor.variants;
    if (variants == null) {
      resolved.add(module);
      continue;
    }
    final provider = byRole[variants.role]?.single;
    if (provider == null) {
      // The role is missing; its issue is already reported.
      resolved.add(module);
      continue;
    }
    if (!variants.byProvider.containsKey(provider.id)) {
      report(
        SmfIssue(
          '${module.id} has no variant for ${provider.id}, the provider of '
          'the ${variants.role.id}. It supports '
          '${variants.byProvider.keys.join(', ')}.',
          origin: module.origin,
        ),
      );
    }
    resolved.add(
      ResolvedModule(module.module, module.reason, variant: provider.id),
    );
  }

  final hasErrors = issues.values.any((issue) => issue.isError);
  return ResolverResult(
    resolution: hasErrors ? null : Resolution(List.unmodifiable(resolved)),
    issues: List.unmodifiable(issues.values),
  );
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
