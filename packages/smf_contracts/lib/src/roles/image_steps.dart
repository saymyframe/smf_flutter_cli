import 'package:smf_contracts/core.dart';

/// The problem of a module that provides a role of images in the native
/// projects of the app, such as its icon, without a step that makes them in
/// every run: the module rule of such a role.
///
/// The native projects are files of the provider of the app entry, and two
/// bricks cannot generate one file, so only a [PostGenStep] can change them.
/// A step that a run without a terminal leaves out leaves the images of
/// `flutter create` in the apps of such runs, with nothing to tell of it:
/// one that is [PostGenStep.external], [PostGenStep.interactive] or has a
/// [PostGenStep.notice], one that runs only on some [PostGenStep.hosts], and
/// one that continues another step ([PostGenStep.followUpOf]), which may not
/// run itself. So at least one step of the provider has to be none of them.
///
/// The tool of the step is up to the provider, also one that the machine may
/// lack ([PostGenStep.needs]): that is a matter of the machine, of which the
/// run tells, and not of what the module is made of.
List<SmfIssue> imageStepProblems(ModuleRuleInput<NoDsl> input) {
  final module = input.module;
  final role = input.roleInput.role;
  if (!module.provides.contains(role)) return const [];
  final steps = input.contributions.whereType<PostGenStep>();
  final reasons = [for (final step in steps) _whyLeftOut(step)];
  if (reasons.contains(null)) return const [];
  final found = reasons.isEmpty ? 'it has no step' : reasons.join(', and ');
  return [
    SmfIssue(
      'The module ${module.id} provides the $role, which needs a step after '
      'generation that runs in every run of smf create, but $found.',
      hint: 'The native projects belong to the provider of the app entry, so '
          'a brick cannot write these images there. Add a PostGenStep that '
          'needs nothing outside the app, does not talk to the user, has no '
          'notice and no hosts, and continues no other step.',
      origin: ModuleOrigin(module.id),
    ),
  ];
}

/// Why a run without a terminal may leave [step] out, or `null` if nothing
/// in the step makes it do so.
String? _whyLeftOut(PostGenStep step) {
  final command = [step.tool.executable, ...step.arguments].join(' ');
  if (step.external) return '"$command" needs something outside the app';
  if (step.interactive) return '"$command" talks to the user';
  if (step.notice != null) return '"$command" has a notice';
  if (step.hosts.isNotEmpty) return '"$command" runs only on some systems';
  if (step.followUpOf != null) return '"$command" continues another step';
  return null;
}
