import 'package:smf_contracts/core.dart';
import 'package:smf_pipeline/src/collector.dart';

/// A post-generation step of the app with the steps that continue it (see
/// [PostGenStep.followUpOf]).
final class BoundStep {
  /// Creates the step of [collected], which [followUps] continue.
  const BoundStep(this.collected, this.followUps);

  /// The step and who contributed it.
  final Collected collected;

  /// The steps that continue it, in the order they run.
  final List<BoundStep> followUps;

  /// The step.
  PostGenStep get step => collected.contribution as PostGenStep;

  /// Who contributed the step.
  ContributionOrigin get origin => collected.origin;

  /// The step and the steps that continue it, each before those that
  /// continue it in turn, in the order they run.
  Iterable<Collected> get all sync* {
    yield collected;
    for (final next in followUps) {
      yield* next.all;
    }
  }
}

/// The post-generation steps among [steps] that continue no other step, in
/// the order of [steps], each with the steps among [steps] that continue it,
/// in that order too.
///
/// A step continues the first step among [steps] with the id that it
/// follows. A step that continues none of them, such as a step whose step
/// does not apply to the app, is left out, with the steps that continue it,
/// and so are steps that continue each other in a cycle; validation reports
/// what the app does not have and the cycles.
List<BoundStep> bindSteps(List<Collected> steps) {
  final byId = <PostGenStepId, Collected>{};
  for (final collected in steps) {
    if ((collected.contribution as PostGenStep).id case final id?) {
      byId.putIfAbsent(id, () => collected);
    }
  }
  final roots = <Collected>[];
  // By the step they continue, which the steps only compare by identity.
  final followUps = <Collected, List<Collected>>{};
  for (final collected in steps) {
    final followed = (collected.contribution as PostGenStep).followUpOf;
    if (followed == null) {
      roots.add(collected);
    } else if (byId[followed] case final step?) {
      followUps.putIfAbsent(step, () => []).add(collected);
    }
  }
  // Each step continues one step, so a step whose chain of steps reaches a
  // root is reached once, and a cycle is never reached.
  BoundStep bound(Collected collected) => BoundStep(collected, [
        for (final next in followUps[collected] ?? const <Collected>[])
          bound(next),
      ]);
  return [for (final root in roots) bound(root)];
}
