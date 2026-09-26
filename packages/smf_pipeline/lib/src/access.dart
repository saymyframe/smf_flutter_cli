import 'package:smf_contracts/lego_core.dart';
import 'package:smf_pipeline/src/registry.dart';
import 'package:smf_pipeline/src/resolver.dart';

/// The roles whose sockets, symbols, data and presence flags [origin] may
/// use (`access`), and those it may list in a [Contribution.when] (`when`):
/// - a module: the roles it provides, requires or uses;
/// - the template of a role: the role and the roles it requires or uses;
/// - the pipeline: none of its own.
///
/// `access` also has the roles open to all modules, such as the app entry.
({Set<Role> access, Set<Role> when}) rolesOf(
  ContributionOrigin origin,
  ModuleRegistry registry,
  Resolution resolution,
) {
  final open = registry.openRoles;
  switch (origin) {
    case ModuleOrigin(:final module):
      final roles =
          resolution.module(module)?.descriptor.roles ?? const <Role>{};
      return (access: {...roles, ...open}, when: roles);
    case RoleTemplateOrigin(:final role):
      final roles = {role, ...role.visibleRoles};
      return (access: {...roles, ...open}, when: roles);
    case PipelineOrigin():
      return (access: open, when: const {});
  }
}

/// [origin] as the owner of files and brick variables: a module's variant
/// is its module.
ContributionOrigin ownerOf(ContributionOrigin origin) => switch (origin) {
      ModuleOrigin(:final module) => ModuleOrigin(module),
      _ => origin,
    };
