part of '../contributions.dart';

/// A command the pipeline runs in the generated app after `flutter pub get`
/// and code generation, such as `flutterfire configure`.
///
/// Steps run in the order of fragments in a socket (see [SocketRef]): after
/// the steps of the modules their module depends on, then by module id. The
/// environment of a step includes, in its `PATH`, the directories of the
/// tools that [Preflight] checks installed.
final class PostGenStep extends Contribution {
  /// Creates a step that runs [tool] with [arguments].
  const PostGenStep(
    this.tool,
    this.arguments, {
    this.description,
    this.interactive = false,
    this.skippable = false,
    this.external = false,
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

  /// Whether the user may skip the step; the pipeline then prints the
  /// command to run later.
  final bool skippable;

  /// Whether the step needs something outside the app, such as a network
  /// account.
  ///
  /// With `--skip-external-setup`, or in a non-interactive run of an
  /// [interactive] step, the pipeline prints the command instead of running
  /// it.
  final bool external;
}
