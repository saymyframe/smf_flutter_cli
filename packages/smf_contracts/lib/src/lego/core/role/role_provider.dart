part of '../role.dart';

/// The implementation of a role by a module, such as the go_router module
/// providing the router role.
///
/// A module has one provider object per role it provides, listed in
/// [ModuleDescriptor.providers]. A provider requires and uses what its role
/// requires and uses, and must generate the symbols of the role's
/// [RoleInterface]. Its hooks receive the same input as the role's
/// template.
abstract base class RoleProvider<D extends Object> {
  /// Allows subclasses to have constant constructors.
  const RoleProvider();

  /// Creates a provider of [role] without hooks, for a module whose bricks
  /// alone implement the role.
  const factory RoleProvider.plain(Role<D> role) = _PlainRoleProvider<D>;

  /// The role this object provides.
  Role<D> get role;

  /// Checks the data of the role against what this provider supports, such
  /// as the number of destinations a layout can show, and returns the
  /// problems found.
  List<SmfIssue> validate(RoleHookInput<D> input) => const [];

  /// Returns the fragments and brick variables of the module's bricks that
  /// depend on the data, such as the routes of a router.
  RoleOutput render(RoleHookInput<D> input) => const RoleOutput();
}

final class _PlainRoleProvider<D extends Object> extends RoleProvider<D> {
  const _PlainRoleProvider(this.role);

  @override
  final Role<D> role;
}
