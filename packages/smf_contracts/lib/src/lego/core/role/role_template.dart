part of '../role.dart';

/// The code a role contributes itself, whichever module provides it, such as
/// the interface a router's providers implement.
///
/// The pipeline treats the template as a pseudo-module named `role:<id>`
/// (see [RoleTemplateOrigin]). It may put code into the sockets of its own
/// role, of the roles its role requires or uses, and of the roles open to
/// all modules (see [Role.openToAllModules]). Its hooks run at these stages
/// of generation:
/// 1. [contribute], while contributions are collected;
/// 2. [validate], during validation;
/// 3. [choose], after preflight checks, to ask the user what only the user
///    can decide;
/// 4. [render], before the templates are rendered.
///
/// All data is collected before [validate], so the hooks of different roles
/// never depend on each other's results.
abstract base class RoleTemplate<D extends Object> {
  /// Allows subclasses to have constant constructors.
  const RoleTemplate();

  /// Returns the template's own contributions, such as the bricks of the
  /// role's interface files.
  ///
  /// Like a module, the template does not branch on other roles; it uses
  /// [Contribution.when] instead.
  List<Contribution> contribute(ModuleContext context) => const [];

  /// Checks the data of the role and returns the problems found.
  ///
  /// It runs before [choose], so [RoleHookInput.choice] is `null`.
  List<SmfIssue> validate(RoleHookInput<D> input) => const [];

  /// Asks the user, or reads the role's options, for a decision that the
  /// data leaves open, such as the start screen of the app.
  ///
  /// The result reaches [render] and the providers' render hooks as
  /// [RoleHookInput.choice]. The hook checks the decision itself: it throws
  /// an [SmfUsageException] for an option value that does not fit the data,
  /// or if the run is not interactive and no option decides.
  Future<Object?> choose(RoleChoiceContext<D> context) async => null;

  /// Returns the fragments and brick variables that depend on the data,
  /// such as a composite of all analytics services.
  RoleOutput render(RoleHookInput<D> input) => const RoleOutput();
}
