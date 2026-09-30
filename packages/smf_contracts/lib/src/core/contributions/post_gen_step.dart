part of '../contributions.dart';

/// A command the pipeline runs in the generated app after `flutter pub get`
/// and code generation, such as `flutterfire configure`.
///
/// Steps run in the order of the contributions of a socket (see
/// [SocketContribution]). The environment of a step includes, in its `PATH`,
/// the directories of the tools that [Preflight] checks installed.
///
/// A step may continue another step, such as with a fix of a file that the
/// tool of that step writes: it names that step by its [id] in
/// [followUpOf], and runs right after it rather than in its own place. A
/// module continues its own steps and those that the modules it depends on
/// publish the ids of, so a module knows nothing of the modules that
/// continue its steps.
///
/// A step whose [hosts] leave out the operating system of the run does not
/// apply to it. A step that applies runs unless:
/// - it is [external] and the run skips external setup
///   (`--skip-external-setup`);
/// - it is [interactive] and the run is not;
/// - a check that it [needs] has not passed;
/// - it continues a step that is not done.
///
/// Then the pipeline prints the command for the user to run later, or fails
/// generation if the step is not [skippable]; a step that continues a step
/// that is not done is left for later with it either way. In an interactive
/// run, the user may also skip a [skippable] step that continues no other
/// step. A [skippable] step whose tool is missing, or that fails, is left
/// for later too; any other step that fails fails generation.
///
/// The app is generated in a temporary directory and moved to its place
/// afterwards, so a step must not write the absolute path of its working
/// directory into the app. The files where Flutter records such paths, like
/// `ios/Flutter/Generated.xcconfig`, are written again in the app's place.
final class PostGenStep extends Contribution {
  /// Creates a step that runs [tool] with [arguments].
  const PostGenStep(
    this.tool,
    this.arguments, {
    this.id,
    this.followUpOf,
    this.description,
    this.interactive = false,
    this.skippable = false,
    this.external = false,
    this.needs = const [],
    this.hosts = const {},
    super.when,
  });

  /// The tool to run.
  final ToolRef tool;

  /// The arguments, after the tool's [ToolRef.prefixArgs].
  final List<String> arguments;

  /// The id by which other steps continue this one (see [followUpOf]), or
  /// `null` if none does.
  ///
  /// It names the module that contributes the step, which publishes it as
  /// a constant of its module class, such as
  /// `FirebaseCoreModule.configureStep`, and no other step of the app has
  /// it. The pipeline reports an id of another module, and an id of two
  /// steps, as a problem of the contributor.
  final PostGenStepId? id;

  /// The step that this one continues, by its [id], such as a step whose
  /// tool writes a file that this one fixes, or `null` if it continues
  /// none.
  ///
  /// A module continues its own steps and those of the modules it depends
  /// on directly ([ModuleDescriptor.dependsOn]). The step runs right after
  /// the step it continues, once that one succeeded, and after the steps
  /// that continue that one and come before it in the order of the steps;
  /// the steps that continue it run right after it in turn.
  ///
  /// It is part of the step it continues, so the user is not asked about
  /// it. When that step does not run or fails, it does not run either, and
  /// it is left for later after that step, with that step as the reason,
  /// whether it is [skippable] or not. Otherwise it runs as any step of its
  /// contributor: by its own [needs], [interactive], [external] and
  /// [skippable].
  ///
  /// It applies to the app whenever the step it continues does, so it has
  /// no [when] of its own. The pipeline reports as problems of its
  /// contributor a step that it may not continue, a step that the app does
  /// not have, a [when], and steps that continue each other in a cycle.
  final PostGenStepId? followUpOf;

  /// What the step does, for progress output and instructions.
  final String? description;

  /// Whether the step talks to the user, so the pipeline runs it with the
  /// terminal attached (see [SmfProcessRunner.runInteractive]).
  final bool interactive;

  /// Whether the app is complete without the step, so the pipeline may
  /// print its command for later instead of running it.
  final bool skippable;

  /// Whether the step needs something outside the app, such as a network
  /// account.
  final bool external;

  /// The ids of the checks of the [Preflight] of the same contributor that
  /// the step needs, such as the check that its tool is installed.
  ///
  /// When one of them has not passed once the checks are done, because the
  /// user declined to install what it found missing, the installation
  /// failed, or the run could not install it, the step would fail: it does
  /// not run, and the user is not asked about it. It is left for later with
  /// the check as the reason, as a step whose tool is missing is. A check of
  /// a [Preflight] that does not apply to the app holds no step back. The
  /// pipeline reports an id that names no check of the contributor as a
  /// problem of the contributor.
  final List<String> needs;

  /// The operating systems on which the step runs, or none for every one,
  /// such as macOS for a step that changes the Xcode project of the app.
  ///
  /// On any other system the step does not apply to the run, as a
  /// contribution whose [when] does not hold: it neither runs nor is left
  /// for later, and neither are the steps that continue it. `--explain`
  /// names the systems of such a step.
  final Set<HostOperatingSystem> hosts;
}

/// Identifies a post-generation step of a module, so that another step may
/// continue it (see [PostGenStep.followUpOf]).
///
/// A module that lets the modules which depend on it continue a step
/// publishes the id of the step as a constant of its module class, next to
/// its [ModuleId]:
///
/// ```dart
/// final class FirebaseCoreModule extends SmfModule {
///   static const id = ModuleId('firebase_core');
///   static const configureStep = PostGenStepId(id, 'configure');
///   // ...
/// }
/// ```
///
/// Ids of different modules differ, so modules that do not know each other
/// cannot give two steps one id.
@immutable
final class PostGenStepId {
  /// Identifies the step [name] of the module [module].
  const PostGenStepId(this.module, this.name);

  /// The module whose step it is, which contributes the step.
  final ModuleId module;

  /// The name of the step, which no other step of [module] has.
  final String name;

  @override
  bool operator ==(Object other) =>
      other is PostGenStepId && other.module == module && other.name == name;

  @override
  int get hashCode => Object.hash(module, name);

  @override
  String toString() => '$module.$name';
}
