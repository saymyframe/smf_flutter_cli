import 'package:smf_contracts/lego_core.dart';
import 'package:smf_pipeline/src/collector.dart';
import 'package:smf_pipeline/src/environment.dart';
import 'package:smf_pipeline/src/errors.dart';

/// A post-generation step that did not run, with the command to run later.
final class SkippedStep {
  /// Creates the record of the step [description], which did not run
  /// because of [reason].
  const SkippedStep(this.description, this.command, this.reason);

  /// What the step does.
  final String description;

  /// The command, as the user runs it in the directory of the app.
  final String command;

  /// Why it did not run, as a phrase such as `the run skips external
  /// setup`.
  final String reason;

  @override
  String toString() => '$description: $command ($reason)';
}

/// The codes of the diagnostics that the import cleanup fixes, which runs
/// before any other fix: `dart fix` cleans the imports of a file only when
/// it makes no other fix in the file in the same run.
const importCleanupCodes = [
  'duplicate_import',
  'unnecessary_import',
  'unused_import',
];

/// Stage 9 of the pipeline: runs the commands that finish the app in
/// [directory], the temporary directory it was rendered into:
/// 1. `flutter pub get`;
/// 2. `dart run build_runner build`, once, if [codegen];
/// 3. the post-generation [steps] of the modules, in their order;
/// 4. `dart fix --apply` for the imports only (see [importCleanupCodes]),
///    since fragments of several modules can import the same library;
/// 5. `dart fix --apply` for everything, unless [fullDartFix] is `false`;
/// 6. `dart format .`.
///
/// A step that needs a terminal in a run without one, or external setup in
/// a run that skips it, does not run; the pipeline checked before that such
/// a step is skippable. In an interactive run the user may also skip a
/// skippable step. A skippable step that fails, or whose tool is missing,
/// is skipped too, with a warning. Returns the steps that did not run, with
/// their commands for later.
///
/// Throws a [GenerationFailedException] when `pub get`, code generation or
/// a step that is not skippable fails. `dart fix` and `dart format` only
/// warn when they fail, since the app is complete without them.
Future<List<SkippedStep>> runPostGen({
  required String directory,
  required PipelineEnvironment environment,
  required List<Collected> steps,
  bool codegen = false,
  bool fullDartFix = true,
}) async {
  final commands = _Commands(environment, directory);
  final logger = environment.logger;

  await commands.require(
    'Getting the packages of the app',
    const ToolRef('flutter'),
    const ['pub', 'get'],
  );
  if (codegen) {
    await commands.require(
      'Generating code with build_runner',
      const ToolRef('dart'),
      const ['run', 'build_runner', 'build'],
    );
  }

  final skipped = <SkippedStep>[];
  for (final collected in steps) {
    final step = collected.contribution as PostGenStep;
    final command = _display(step.tool, step.arguments);
    final description = step.description ?? command;
    String? reason;
    if (step.external && environment.skipExternalSetup) {
      reason = 'the run skips external setup';
    } else if (step.interactive && !environment.interactive) {
      reason = 'it needs a terminal';
    } else if (step.skippable &&
        environment.interactive &&
        !await environment.prompter.confirm(
          '$description ($command), for ${collected.origin}. Run it now?',
          defaultValue: true,
        )) {
      reason = 'you chose to run it later';
    }
    if (reason == null) {
      final problem = await commands.run(
        description,
        step.tool,
        step.arguments,
        interactive: step.interactive,
      );
      if (problem == null) continue;
      if (!step.skippable) {
        throw GenerationFailedException(
          'The step "$description" of ${collected.origin} failed: $problem',
        );
      }
      reason = 'it failed: $problem';
      logger.warn('The step "$description" failed; run it later: $command');
    }
    skipped.add(SkippedStep(description, command, reason));
  }

  await commands.tryRun(
    'Cleaning up the imports',
    const ToolRef('dart'),
    ['fix', '--apply', '--code=${importCleanupCodes.join(',')}'],
  );
  if (fullDartFix) {
    await commands.tryRun(
      'Applying dart fix',
      const ToolRef('dart'),
      const ['fix', '--apply'],
    );
  }
  await commands.tryRun(
    'Formatting the code',
    const ToolRef('dart'),
    const ['format', '.'],
  );
  return skipped;
}

/// Runs `flutter pub get` in [directory], the app in its final place, so
/// Flutter writes its files with the right paths; see [flutterToolFiles].
///
/// It only warns if the command fails, since the next `flutter` command in
/// the app runs it again.
Future<void> getPackagesInPlace(
  PipelineEnvironment environment,
  String directory,
) =>
    _Commands(environment, directory).tryRun(
      'Getting the packages of the app in its directory',
      const ToolRef('flutter'),
      const ['pub', 'get'],
    );

/// The files and directories that Flutter and pub write into an app with
/// the absolute path of the app or of the machine's tools, relative to the
/// root of the app. They are not moved with the app from its temporary
/// directory; `flutter pub get` writes them again in the app's final place.
const flutterToolFiles = [
  '.dart_tool',
  'build',
  '.flutter-plugins',
  '.flutter-plugins-dependencies',
  'ios/Flutter/Generated.xcconfig',
  'ios/Flutter/flutter_export_environment.sh',
  'ios/Flutter/ephemeral',
  'macos/Flutter/ephemeral',
  'linux/flutter/ephemeral',
  'windows/flutter/ephemeral',
];

/// Runs commands of the Flutter SDK and of the modules in the directory of
/// the app, with progress.
final class _Commands {
  _Commands(this._environment, this._directory);

  final PipelineEnvironment _environment;
  final String _directory;

  /// Runs [tool] with [arguments] and returns `null` if it succeeded, or
  /// what went wrong.
  Future<String?> run(
    String description,
    ToolRef tool,
    List<String> arguments, {
    bool interactive = false,
  }) async {
    final ResolvedTool resolved;
    try {
      resolved = await _environment.resolveTool(tool, arguments);
    } on ToolNotFoundException catch (error) {
      return '$error';
    }
    final logger = _environment.logger;
    final runner = _environment.processRunner;
    final shell = _environment.operatingSystem == HostOperatingSystem.windows &&
        RegExp(r'\.(bat|cmd)$', caseSensitive: false)
            .hasMatch(resolved.executable);
    if (interactive) {
      logger.info('$description…');
      final code = await runner.runInteractive(
        resolved.executable,
        resolved.arguments,
        workingDirectory: _directory,
        environment: resolved.environment,
        runInShell: shell,
      );
      return code == 0 ? null : 'it exited with code $code';
    }
    final progress = logger.progress(description);
    final SmfProcessResult result;
    try {
      result = await runner.run(
        resolved.executable,
        resolved.arguments,
        workingDirectory: _directory,
        environment: resolved.environment,
        runInShell: shell,
      );
    } on Object catch (error) {
      progress.fail();
      return 'it could not start: $error';
    }
    if (result.succeeded) {
      progress.complete();
      return null;
    }
    progress.fail();
    final output = [result.stderr.trim(), result.stdout.trim()]
        .firstWhere((text) => text.isNotEmpty, orElse: () => '');
    return 'it exited with code ${result.exitCode}'
        '${output.isEmpty ? '' : ':\n${_tail(output)}'}';
  }

  /// Runs [tool] and throws a [GenerationFailedException] if it fails.
  Future<void> require(
    String description,
    ToolRef tool,
    List<String> arguments,
  ) async {
    final problem = await run(description, tool, arguments);
    if (problem == null) return;
    throw GenerationFailedException(
      '${_display(tool, arguments)} failed: $problem',
    );
  }

  /// Runs [tool] and warns if it fails.
  Future<void> tryRun(
    String description,
    ToolRef tool,
    List<String> arguments,
  ) async {
    final problem = await run(description, tool, arguments);
    if (problem == null) return;
    _environment.logger.warn(
      '${_display(tool, arguments)} failed, so run it in the app yourself: '
      '$problem',
    );
  }
}

/// The last lines of [output], which say what went wrong.
String _tail(String output) {
  final lines = output.split('\n');
  return lines.length <= 20
      ? output
      : ['…', ...lines.sublist(lines.length - 20)].join('\n');
}

/// [tool] with [arguments] as the user types it: the name of the
/// executable, then the arguments, quoted where a shell needs it.
String _display(ToolRef tool, List<String> arguments) {
  String quoted(String argument) =>
      RegExp(r'^[A-Za-z0-9_./:=,@%+-]+$').hasMatch(argument)
          ? argument
          : "'${argument.replaceAll("'", r"'\''")}'";
  final name = tool.executable.split(RegExp(r'[/\\]')).last;
  return [name, ...tool.argumentsFor(arguments)].map(quoted).join(' ');
}
