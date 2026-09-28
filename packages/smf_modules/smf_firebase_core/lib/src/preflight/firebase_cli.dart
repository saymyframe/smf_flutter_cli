import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/src/preflight/commands.dart';
import 'package:smf_firebase_core/src/preflight/install_scripts.dart';

/// Checks that the Firebase CLI is installed and runs, which
/// `flutterfire configure` runs to reach the Firebase projects of the user.
///
/// A `firebase` command on the `PATH` may not run, such as one that needs
/// another Node.js than the one of the terminal, so the check runs
/// `firebase --version`, without the check for updates, which would run in
/// the background after it. When the command fails, the check tells that
/// the command does not run and how it ended, with the last lines of its
/// errors, and offers the installation, as for a missing CLI.
///
/// It can install it with npm, and Node.js first when it is missing or too
/// old: the pipeline asks the user before. The progress shows what the
/// installation is doing, which may take minutes, and the changes to the
/// machine that outlive the run, such as a line in the profile of the shell,
/// are listed after it. On macOS and Linux, when the installation fails, it
/// offers the standalone binary of the Firebase CLI instead.
final class FirebaseCliCheck extends PreflightCheck {
  /// Creates the check.
  const FirebaseCliCheck();

  @override
  String get id => 'firebase_cli';

  @override
  String get description => 'Firebase CLI';

  static const _install = 'Install it with "npm install -g firebase-tools", '
      'or see https://firebase.google.com/docs/cli.';

  @override
  Future<PreflightStatus> check(SmfEnvironment environment) async {
    final installable = InstallScript.of(environment.operatingSystem) != null;
    final firebase = await environment.findExecutable('firebase');
    if (firebase == null) {
      return PreflightMissing(instructions: _install, installable: installable);
    }
    final result = await environment.processRunner.run(
      firebase,
      const ['--version'],
      // The Firebase CLI writes firebase-debug.log where it runs.
      workingDirectory: await scratchDirectory(environment),
      environment: const {'NO_UPDATE_NOTIFIER': '1'},
    );
    if (result.succeeded) return const PreflightPassed();
    final end = endOf(
      'firebase --version',
      result.exitCode,
      environment.operatingSystem,
    );
    // On one line, since a question shows the instructions.
    final errors = outputTail(result, lines: 5).split('\n').join(' ');
    var why = errors.isEmpty ? end : '$end: $errors';
    if (why.endsWith('.')) why = why.substring(0, why.length - 1);
    return PreflightMissing(
      found: '$firebase does not run',
      instructions: '$why. $_install',
      installable: installable,
    );
  }

  /// Runs the install script of the operating system and returns the
  /// directories it printed; see [InstallScript].
  @override
  Future<ToolInstall> install(SmfEnvironment environment) async {
    final script = InstallScript.of(environment.operatingSystem);
    if (script == null) {
      throw const PreflightSetupException(
        'SMF cannot install the Firebase CLI on this operating system.',
      );
    }
    final shell = await environment.findExecutable(script.shell);
    if (shell == null) {
      throw PreflightSetupException(
        '${script.shell}, which runs the installation, was not found.',
      );
    }
    final path = await environment.writeTempFile(script.fileName, script.text);
    final logger = environment.logger;
    const installing = 'Installing the Firebase CLI';
    final progress = logger.progress(installing);
    final SmfProcessResult result;
    try {
      result = await environment.processRunner.run(
        shell,
        [...script.arguments, path],
        workingDirectory: directoryOf(path),
        onOutput: (line) {
          final text = line.trim();
          if (text.isEmpty ||
              text.startsWith(binDirPrefix) ||
              text.startsWith(notePrefix)) {
            return;
          }
          progress.update('$installing: $text');
        },
      );
    } on Object {
      progress.fail(installing);
      rethrow;
    }
    final output = [result.stdout.trim(), result.stderr.trim()]
      ..removeWhere((text) => text.isEmpty);
    final notes = notesIn(result.stdout);
    if (result.succeeded) {
      progress.complete('Installed the Firebase CLI');
      notes.forEach(logger.info);
      if (output.isNotEmpty) logger.detail(output.join('\n'));
      return ToolInstall(binDirs: binDirsIn(result.stdout));
    }
    progress.fail(installing);
    notes.forEach(logger.info);
    final failure = failureOf(
      script.fileName,
      SmfProcessResult(
        exitCode: result.exitCode,
        stdout: withoutReports(result.stdout),
        stderr: result.stderr,
      ),
      environment.operatingSystem,
    );
    if (!script.standaloneFallback) throw PreflightSetupException(failure);

    logger.warn('Installing the Firebase CLI with npm failed: $failure');
    final standalone = await environment.prompter.confirm(
      'Install the standalone binary of the Firebase CLI with '
      '"$standaloneInstallCommand" instead? It asks for your password when '
      'it needs sudo to write to $standaloneBinDir.',
    );
    if (!standalone) throw PreflightSetupException(failure);
    final code = await environment.processRunner.runInteractive(
      shell,
      ['-lc', standaloneInstallCommand],
      workingDirectory: directoryOf(path),
    );
    if (code != 0) {
      final end = endOf(
        standaloneInstallCommand,
        code,
        environment.operatingSystem,
      );
      throw PreflightSetupException('$end.');
    }
    return const ToolInstall(binDirs: [standaloneBinDir]);
  }
}
