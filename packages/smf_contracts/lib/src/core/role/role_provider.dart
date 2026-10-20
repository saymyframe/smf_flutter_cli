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
  ///
  /// It runs before [RoleTemplate.choose], so [RoleHookInput.choice] is
  /// `null`. A warning among the problems is about what the app is made of,
  /// with a code of the role (see [SmfIssue.code]).
  List<SmfIssue> validate(RoleHookInput<D> input) => const [];

  /// Returns the steps of the app that its developer does by hand and that
  /// depend on the data of the role, or of the roles that it requires or
  /// uses, such as a step in the backend of the provider for a way to sign
  /// in that a module gives the role (see [ManualStep]).
  ///
  /// It runs once, with [validate], before [RoleTemplate.choose], so
  /// [RoleHookInput.choice] is `null`. A step that every app with the
  /// provider has is a contribution of its module instead. A step that the
  /// hook returns has no [Contribution.when], since the hook asks for the
  /// presence of the roles itself (see [RoleHookInput.has]), and has an id
  /// of the module of the provider, or of a role that the module provides,
  /// requires or uses, or that is open to all modules. A step of a role
  /// that the app lacks does not apply.
  List<ManualStep> manualSteps(RoleHookInput<D> input) => const [];

  /// Returns the fragments, the variables of the module's bricks and the
  /// files that depend on the data, such as the routes of a router.
  RoleOutput render(RoleHookInput<D> input) => const RoleOutput();
}

final class _PlainRoleProvider<D extends Object> extends RoleProvider<D> {
  const _PlainRoleProvider(this.role);

  @override
  final Role<D> role;
}
