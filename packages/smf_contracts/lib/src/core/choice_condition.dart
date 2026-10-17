import 'package:meta/meta.dart';
import 'package:smf_contracts/core.dart';

/// A condition on what a role chose, such as that no route starts the app,
/// which the router decides.
///
/// A brick and role data can depend on such conditions (see
/// [Contribution.whenChosen]), and so can a symbol of the interface of a
/// role (see [RequiredSymbol.whenChosen]). [Contribution.when] tells by the
/// roles of the app whether a contribution applies, which the pipeline knows
/// once it has resolved the modules. A role chooses later, in
/// [RoleTemplate.choose] after the checks of the machine, so a condition on
/// a choice decides only what the pipeline renders:
/// - validation and `--explain` treat a contribution under such a condition
///   as one that applies, so its problems are reported in every app that
///   may have it;
/// - the `choose` hook of a role whose data depends on what another role
///   chose runs after the hook of that role, and gets only the data whose
///   conditions hold;
/// - once every role has chosen, the contributions whose conditions do not
///   hold leave the app: the render hooks, the templates and the checks of
///   the rendered app do not see them.
///
/// A role publishes the conditions on its choice as constants, so that
/// modules and the providers of other roles name them without knowing the
/// type of its choice:
///
/// ```dart
/// static const twelveHours = ChoiceCondition(
///   clockRole,
///   'the clock shows 12 hours',
///   holdsFor: _showsTwelveHours,
///   withoutRole: false,
/// );
///
/// bool _showsTwelveHours(Object? choice) => choice == '12';
/// ```
///
/// A module that uses the clock then contributes the files of a dial with
/// 12 hours only to the apps that need them:
/// `BrickContribution(dialBundle, whenChosen: {ClockRole.twelveHours})`.
///
/// Conditions compare by identity, like roles, so each condition is one
/// constant.
@immutable
final class ChoiceCondition {
  /// Creates the condition [name] on the choice of [role]: [holdsFor] tells
  /// from a result of the role's [RoleTemplate.choose] whether it holds, and
  /// [withoutRole] whether it holds in an app without the role.
  const ChoiceCondition(
    this.role,
    this.name, {
    required bool Function(Object? choice) holdsFor,
    required this.withoutRole,
  }) : _holdsFor = holdsFor;

  /// The role whose choice decides.
  final Role role;

  /// What holds when the condition does, as messages name it, such as
  /// `no route starts the app`.
  final String name;

  /// Whether the condition holds in an app without [role], which makes no
  /// choice.
  final bool withoutRole;

  final bool Function(Object? choice) _holdsFor;

  /// Whether the condition holds in an app with the [presentRoles], whose
  /// roles made the [choices].
  ///
  /// [role] chose `null` when it is not among the [choices]: when it has no
  /// template, or when its template made no choice.
  bool holds({
    required Set<Role> presentRoles,
    required Map<Role, Object?> choices,
  }) =>
      presentRoles.contains(role) ? _holdsFor(choices[role]) : withoutRole;

  /// Whether the condition holds in the app of [request], with the choices
  /// of its roles; see [holds].
  bool holdsIn(RoleHookRequest request) =>
      holds(presentRoles: request.presentRoles, choices: request.choices);

  @override
  String toString() => name;
}
