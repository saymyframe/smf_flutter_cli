part of '../contributions.dart';

/// A step of the setup of the app that its developer does by hand, since no
/// command can do it, such as giving a Firebase project the push key of
/// Apple.
///
/// A step is an [id] and a short [title], and nothing else: what the
/// developer does, click by click, is in the guide of the step, which its
/// id names (see [ManualStepId.wire]).
///
/// A module or the template of a role contributes a step that every app of
/// it needs, with [when] for the roles that it only uses. A step that
/// depends on the data of a role comes from the `manualSteps` hook of the
/// template of the role or of a provider of it instead (see
/// [RoleTemplate.manualSteps] and [RoleProvider.manualSteps]), and has no
/// [when]: the hook asks for the presence of the roles itself.
///
/// A step whose id is of a role applies only in an app with that role, as
/// code for a socket of a role does. The pipeline plans the steps of the
/// app once, when it validates the app, before the roles choose, so the
/// steps take no condition on what a role chose ([whenChosen]), as the
/// steps after generation take none: a run that stops before the choices,
/// as `--explain` does, has the steps of the app too. It lists each step
/// once: steps with one id are one step,
/// whoever lists them, so contributors that do not know each other share a
/// step of a role (see [ManualStepId.role]). It orders the steps by the
/// edges between their contributors, as it orders the steps after
/// generation (see [SocketContribution]), but puts the steps of roles
/// first: a role publishes a step that contributors which do not know each
/// other share, so it comes before their own. The order only tells the
/// developer which step to do first, so a cycle of the edges is no error
/// here, and the contributors on it are ordered by name.
///
/// The pipeline reports as problems of the contributor:
/// - a name of the id that is not lower snake_case;
/// - an id of a module other than its own, the variant of a module counting
///   as the module, an id of a module from the template of a role, and an
///   id of a role that it does not provide, require or use, and that is not
///   open to all modules (see [Role.openToAllModules]);
/// - a [title] that is blank, has a line break or a space at its start or
///   end, is longer than [maxTitleLength], starts with neither an
///   upper-case letter nor `iOS`, ends with a period, or has a backslash;
/// - a title that differs from the title of the step with the same id that
///   comes first in the order of the steps, as a problem of the later of
///   the two contributors;
/// - a step that a hook returned with [when].
final class ManualStep extends Contribution {
  /// Creates the step [id] with its [title].
  const ManualStep(this.id, this.title, {super.when});

  /// The longest [title], in characters.
  static const maxTitleLength = 80;

  /// The id of the step, which names it in the link to its guide.
  final ManualStepId id;

  /// What the developer does, as one short line that starts with an
  /// upper-case letter, or with `iOS`, and ends without a period, such as
  /// `Give Firebase your Apple push key (APNs key)`.
  ///
  /// The instructions are in the guide of the step, not here.
  final String title;
}

/// Identifies a step by hand (see [ManualStep]): its owner, a module or a
/// role, and its name.
///
/// The owner publishes the id as a constant:
/// - a module, of a step of its own, next to its [ModuleId], such as
///   `FirebaseMessagingModule.apnsKeyStep`;
/// - a role, of a step that contributors which do not know each other
///   share, such as one that every module which signs the iOS app with an
///   entitlement needs, as a constant of its class. Each contributor lists
///   the step, and the app has it once.
///
/// Ids compare by owner and name. The registry refuses a role with the id
/// of a module, so two steps of different owners never have one [wire].
@immutable
final class ManualStepId {
  /// Identifies the step [name] of the module [module].
  const ManualStepId(ModuleId this.module, this.name) : role = null;

  /// Identifies the step [name] of the role [role], which modules and
  /// templates that do not know each other may list.
  const ManualStepId.role(Role this.role, this.name) : module = null;

  /// The module whose step it is, or `null` for a step of a [role].
  final ModuleId? module;

  /// The role whose step it is, or `null` for a step of a [module].
  final Role? role;

  /// The name of the step in lower snake_case, which no other step of its
  /// owner has, such as `apns_key`.
  final String name;

  /// The id of the owner of the step: that of its [module] or [role].
  String get owner => module?.value ?? role!.id;

  /// The id as the link to the guide of the step carries it,
  /// `<owner>.<name>`, such as `firebase_messaging.apns_key`.
  ///
  /// It names the step for good: a link that a run once printed still
  /// leads to the guide of the step, so the owner never renames the step.
  /// Of a step that the apps no longer have, the guide stays.
  String get wire => '$owner.$name';

  @override
  bool operator ==(Object other) =>
      other is ManualStepId &&
      other.module == module &&
      identical(other.role, role) &&
      other.name == name;

  @override
  int get hashCode => Object.hash(module, identityHashCode(role), name);

  @override
  String toString() => wire;
}

/// The steps by hand of an app (see [ManualStep]), in order and each once,
/// with the link to their guide, as the pipeline planned them when it
/// validated the app.
///
/// The render hooks and the structural rules of a role that is open to all
/// modules get them (see [RoleHookInput.manualSetup]), such as the app
/// entry, which tells of every step of the app; every other hook gets
/// [none].
@immutable
final class ManualSetup {
  /// Creates the setup of [steps], guided by [link].
  const ManualSetup({this.steps = const [], this.link});

  /// No steps and no link.
  static const none = ManualSetup();

  /// The steps of the app, those of roles first, each once.
  final List<ManualStep> steps;

  /// The page that guides the developer through [steps], or `null` when
  /// the front end of the pipeline names none.
  final Uri? link;
}
