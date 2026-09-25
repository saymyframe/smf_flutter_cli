import 'package:smf_contracts/lego_core.dart';
import 'package:smf_pipeline/src/collector.dart';
import 'package:smf_pipeline/src/environment.dart';
import 'package:smf_pipeline/src/errors.dart';
import 'package:smf_pipeline/src/shell.dart';

/// A post-generation step that did not run or did not succeed, with the
/// command to run later.
final class SkippedStep {
  /// Creates the record of the step [description], which is not done
  /// because of [reason].
  const SkippedStep(this.description, this.command, this.reason);

  /// What the step does.
  final String description;

  /// The command, as the user runs it in the directory of the app.
  final String command;

  /// Why it is not done, as a phrase such as `the run skips external setup`
  /// or `it exited with code 1`.
  final String reason;

  @override
  String toString() => '$description: $command ($reason)';
}

/// The codes of the diagnostics that the import cleanup fixes.
///
/// A template may import a library that only some of its branches use, and
/// a fragment may import a library that its file imports anyway. `dart fix`
/// cleans the imports of a file only when it makes no other fix in the file
/// in the same run, so the cleanup runs alone, before the full `dart fix`.
const importCleanupCodes = [
  'duplicate_import',
  'unnecessary_import',
  'unused_import',
];

/// Stage 9 of the pipeline: runs the commands that finish the app in
/// [directory], the temporary directory it was rendered into:
/// 1. `flutter pub get`;
/// 2. `dart run build_runner build`, once, if [codegen] has requests, and
///    checks that it generated the outputs they name;
/// 3. the post-generation [steps] of the modules, in their order;
/// 4. `dart fix --apply` for the imports only; see [importCleanupCodes];
/// 5. `dart fix --apply` for everything, unless [fullDartFix] is `false`;
/// 6. `dart format .`.
///
/// A step that needs a terminal in a run that cannot ask the user, or
/// external setup in a run that skips it, does not run; the pipeline checked
/// before that such a step is skippable. In an interactive run the user may
/// also leave a skippable step for later. A skippable step whose tool is
/// missing, or that fails, is left for later too; a failure is reported with
/// the output of the command. Returns the steps that are not done, with
/// their commands for later.
///
/// Throws a [GenerationFailedException] when `pub get`, code generation or
/// a step that is not skippable fails, and an [SmfCancelledException] when
/// the user cancels the run. `dart fix` and `dart format` only warn when
/// they fail, since the app is complete without them.
Future<List<SkippedStep>> runPostGen({
  required String directory,
  required PipelineEnvironment environment,
  required List<Collected> steps,
  List<Collected> codegen = const [],
  bool fullDartFix = true,
}) async {
  final commands = _Commands(environment, directory);
  final logger = environment.logger;

  await commands.require(
    'Getting the packages of the app',
    const ToolRef('flutter'),
    const ['pub', 'get'],
  );
  if (codegen.isNotEmpty) {
    await commands.require(
      'Generating code with build_runner',
      const ToolRef('dart'),
      const ['run', 'build_runner', 'build'],
    );
    final fileSystem = environment.fileSystem;
    for (final collected in codegen) {
      final request = collected.contribution as CodegenRequest;
      for (final output in request.outputs) {
        final path = fileSystem.path.joinAll([directory, ...output.split('/')]);
        if (!fileSystem.file(path).existsSync()) {
          throw GenerationFailedException(
            'build_runner did not generate $output, which '
            '${collected.origin} named as an output of its code generation.',
          );
        }
      }
    }
  }

  final skipped = <SkippedStep>[];
  for (final collected in steps) {
    final step = collected.contribution as PostGenStep;
    final resolved = await commands.resolve(step.tool, step.arguments);
    final command = commands.display(step.tool, step.arguments, resolved);
    final description = step.description ?? command;
    String? reason;
    if (step.external && environment.skipExternalSetup) {
      reason = 'the run skips external setup';
    } else if (step.interactive && !environment.interactive) {
      reason = 'the run cannot ask the user';
    } else if (resolved == null) {
      if (!step.skippable) {
        throw GenerationFailedException(
          'The step "$description" of ${collected.origin} cannot run, '
          'because ${step.tool.executable} was not found.',
        );
      }
      reason = '${step.tool.executable} was not found';
    } else if (step.skippable &&
        environment.interactive &&
        !await environment.prompter.confirm(
          '${step.description == null ? command : '$description ($command)'}'
          ', for ${collected.origin}. Run it now?',
          defaultValue: true,
        )) {
      reason = 'you chose to run it later';
    }
    if (reason == null) {
      final failure = await commands.runResolved(
        description,
        resolved!,
        interactive: step.interactive,
      );
      if (failure == null) continue;
      if (!step.skippable) {
        throw GenerationFailedException(
          'The step "$description" of ${collected.origin} failed: '
          '${failure.detail}',
        );
      }
      logger.warn('The step "$description" failed: ${failure.detail}');
      reason = failure.reason;
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
/// Flutter writes its files with the right paths; see `flutterToolFiles`.
///
/// It only warns if the command fails or the user interrupts it, since the
/// app is complete and the next `flutter` command in it runs it again.
Future<void> getPackagesInPlace(
  PipelineEnvironment environment,
  String directory,
) async {
  try {
    await _Commands(environment, directory).tryRun(
      'Getting the packages of the app in its directory',
      const ToolRef('flutter'),
      const ['pub', 'get'],
    );
  } on SmfCancelledException {
    environment.logger.warn(
      'The app is complete, but getting its packages was interrupted; run '
      '"flutter pub get" in it.',
    );
  }
}

/// What `flutter` writes while it waits for another `flutter` command, such
/// as one of an IDE, which may take long.
const _startupLock =
    'Waiting for another flutter command to release the startup lock';

/// Why a command failed: the [reason] for a summary, such as `it exited
/// with code 1`, and the [detail] with the end of its output.
final class _Failure {
  const _Failure(this.reason, [String? detail]) : detail = detail ?? reason;

  final String reason;
  final String detail;
}

/// Runs commands of the Flutter SDK and of the modules in the directory of
/// the app, with progress.
final class _Commands {
  _Commands(this._environment, this._directory);

  final PipelineEnvironment _environment;
  final String _directory;

  /// [tool] with [arguments] ready to run, or `null` if its executable is
  /// missing.
  Future<ResolvedTool?> resolve(ToolRef tool, List<String> arguments) async {
    try {
      return await _environment.resolveTool(tool, arguments);
    } on ToolNotFoundException {
      return null;
    }
  }

  /// [tool] with [arguments] as the user types it in the app: the
  /// executable by its name, or by its path when the tool names it by path
  /// or was installed during the run, so it may be missing from the user's
  /// `PATH`; then the arguments, quoted for the user's shell.
  String display(
    ToolRef tool,
    List<String> arguments, [
    ResolvedTool? resolved,
  ]) {
    final context = _environment.fileSystem.path;
    final executable = switch (resolved?.executable) {
      final path? when _environment.binDirs.contains(context.dirname(path)) =>
        path,
      _ when context.isAbsolute(tool.executable) => tool.executable,
      _ => context.basename(tool.executable),
    };
    final system = _environment.operatingSystem;
    return [executable, ...tool.argumentsFor(arguments)]
        .map((argument) => shellQuoted(argument, system))
        .join(' ');
  }

  /// Runs [resolved], the command of [description], and returns `null` if it
  /// succeeded, or why it failed.
  ///
  /// With [interactive], the command gets the terminal. The runner of the
  /// host decides how to start a batch file on Windows.
  Future<_Failure?> runResolved(
    String description,
    ResolvedTool resolved, {
    bool interactive = false,
  }) async {
    final logger = _environment.logger;
    final runner = _environment.processRunner;
    logger.detail(
      'Running ${[resolved.executable, ...resolved.arguments].join(' ')} in '
      '$_directory',
    );
    if (interactive) {
      logger.info('$description…');
      final int code;
      try {
        code = await runner.runInteractive(
          resolved.executable,
          resolved.arguments,
          workingDirectory: _directory,
          environment: resolved.environment,
        );
      } on SmfCancelledException {
        rethrow;
      } on Object catch (error) {
        return _Failure('it could not start', 'it could not start: $error');
      }
      return code == 0 ? null : _Failure('it exited with code $code');
    }
    final progress = logger.progress(description);
    var waiting = false;
    final SmfProcessResult result;
    try {
      result = await runner.run(
        resolved.executable,
        resolved.arguments,
        workingDirectory: _directory,
        environment: resolved.environment,
        onOutput: (line) {
          if (waiting || !line.contains(_startupLock)) return;
          waiting = true;
          progress.update(
            '$description: waiting for another flutter command to finish, '
            'such as one of an IDE',
          );
        },
      );
    } on SmfCancelledException {
      progress.fail(description);
      rethrow;
    } on Object catch (error) {
      progress.fail(description);
      return _Failure('it could not start', 'it could not start: $error');
    }
    final streams = [result.stderr.trim(), result.stdout.trim()]
      ..removeWhere((text) => text.isEmpty);
    if (streams.isNotEmpty) logger.detail(streams.join('\n'));
    if (result.succeeded) {
      progress.complete(description);
      return null;
    }
    progress.fail(description);
    final reason = 'it exited with code ${result.exitCode}';
    return streams.isEmpty
        ? _Failure(reason)
        : _Failure(reason, '$reason:\n${streams.map(_tail).join('\n')}');
  }

  /// Runs [tool] with [arguments], the command of [description], and
  /// returns `null` if it succeeded, or why it failed.
  Future<_Failure?> run(
    String description,
    ToolRef tool,
    List<String> arguments,
  ) async {
    final resolved = await resolve(tool, arguments);
    if (resolved == null) return _Failure('${tool.executable} was not found');
    return runResolved(description, resolved);
  }

  /// Runs [tool] and throws a [GenerationFailedException] if it fails.
  Future<void> require(
    String description,
    ToolRef tool,
    List<String> arguments,
  ) async {
    final failure = await run(description, tool, arguments);
    if (failure == null) return;
    throw GenerationFailedException(
      '${display(tool, arguments)} failed: ${failure.detail}',
    );
  }

  /// Runs [tool] and warns if it fails.
  Future<void> tryRun(
    String description,
    ToolRef tool,
    List<String> arguments,
  ) async {
    final failure = await run(description, tool, arguments);
    if (failure == null) return;
    _environment.logger.warn(
      '${display(tool, arguments)} failed, so run it in the app yourself: '
      '${failure.detail}',
    );
  }
}

/// The last lines of [output], which say what went wrong. Both streams of a
/// command count: tools such as `build_runner` report their errors on the
/// standard output.
String _tail(String output) {
  final lines = output.split('\n');
  return lines.length <= 20
      ? output
      : ['…', ...lines.sublist(lines.length - 20)].join('\n');
}
