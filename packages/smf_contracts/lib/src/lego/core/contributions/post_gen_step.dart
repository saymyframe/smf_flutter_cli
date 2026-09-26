part of '../contributions.dart';

/// A command the pipeline runs in the generated app after `flutter pub get`
/// and code generation, such as `flutterfire configure`.
///
/// Steps run in the order of the contributions of a socket (see
/// [SocketContribution]). The environment of a step includes, in its `PATH`,
/// the directories of the tools that [Preflight] checks installed.
///
/// A step runs unless:
/// - it is [external] and the run skips external setup
///   (`--skip-external-setup`);
/// - it is [interactive] and the run is not;
/// - a check that it [needs] has not passed.
///
/// Then the pipeline prints the command for the user to run later, or fails
/// generation if the step is not [skippable]. In an interactive run, the
/// user may also skip a [skippable] step. A [skippable] step whose tool is
/// missing, or that fails, is left for later too; any other step that fails
/// fails generation.
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
    this.description,
    this.interactive = false,
    this.skippable = false,
    this.external = false,
    this.needs = const [],
    super.when,
  });

  /// The tool to run.
  final ToolRef tool;

  /// The arguments, after the tool's [ToolRef.prefixArgs].
  final List<String> arguments;

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
}
