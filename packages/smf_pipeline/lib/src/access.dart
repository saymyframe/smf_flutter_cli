import 'package:smf_contracts/core.dart';
import 'package:smf_pipeline/src/registry.dart';
import 'package:smf_pipeline/src/resolver.dart';

/// The roles of a contributor that [rolesOf] returns.
typedef ContributorRoles = ({
  Set<Role> access,
  Set<Role> when,
  Set<Role> feeds
});

/// The roles whose sockets, symbols, data and presence flags [origin] may
/// use (`access`), those it may list in a [Contribution.when] (`when`), and
/// those it may give data alone (`feeds`):
/// - a module: the roles it provides, requires or uses, and the roles it
///   feeds (see [ModuleDescriptor.feeds]);
/// - the template of a role: the role and the roles it requires or uses,
///   and the roles it feeds (see [Role.feeds]);
/// - the pipeline: none of its own.
///
/// `access` also has the roles open to all modules, such as the app entry.
/// Only data may go to a role in `feeds`, so every other check reports a
/// contribution of [origin] that names a role it only feeds as it reports
/// one that names a role it does not know.
ContributorRoles rolesOf(
  ContributionOrigin origin,
  ModuleRegistry registry,
  Resolution resolution,
) {
  final open = registry.openRoles;
  switch (origin) {
    case ModuleOrigin(:final module):
      final descriptor = resolution.module(module)?.descriptor;
      final roles = descriptor?.roles ?? const <Role>{};
      return (
        access: {...roles, ...open},
        when: roles,
        feeds: descriptor?.feeds ?? const {},
      );
    case RoleTemplateOrigin(:final role):
      final roles = {role, ...role.visibleRoles};
      return (access: {...roles, ...open}, when: roles, feeds: role.feeds);
    // coverage:ignore-start
    // No check of access meets the contributions of the pipeline: the
    // build_runner dependency goes to the merge of the pubspec only, and
    // the check of the Flutter SDK to the preflight checks.
    case PipelineOrigin():
      return (access: open, when: const {}, feeds: const {});
    // coverage:ignore-end
  }
}

/// [origin] as the owner of files and brick variables: a module's variant
/// is its module.
ContributionOrigin ownerOf(ContributionOrigin origin) => switch (origin) {
      ModuleOrigin(:final module) => ModuleOrigin(module),
      _ => origin,
    };
