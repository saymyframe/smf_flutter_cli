import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/src/preflight/commands.dart';
import 'package:smf_firebase_core/src/preflight/install_scripts.dart';

/// How to install the Firebase CLI by hand.
const howToInstallFirebaseCli = 'Install it with "npm install -g '
    'firebase-tools", or see https://firebase.google.com/docs/cli.';

/// What `firebase --version` of the Firebase CLI [firebase] tells.
///
/// When the command succeeds, `output` is what it wrote on its standard
/// output, which is its version, and `why` is `null`. Otherwise the
/// Firebase CLI does not run: `output` is empty, and `why` tells how the
/// command ended and the last lines of what it wrote, or that it could not
/// start, such as a file that may not be executed, on one line and without
/// a final period.
///
/// The command runs in a directory of its own, where the Firebase CLI may
/// leave its `firebase-debug.log`, and without its check for updates, which
/// would run in the background after it.
Future<({String output, String? why})> askFirebaseVersion(
  String firebase,
  SmfEnvironment environment,
) async {
  const command = 'firebase --version';
  final SmfProcessResult result;
  try {
    result = await environment.processRunner.run(
      firebase,
      const ['--version'],
      workingDirectory: await scratchDirectory(environment),
      environment: const {'NO_UPDATE_NOTIFIER': '1'},
    );
  } on SmfCancelledException {
    rethrow;
  } on Exception catch (error) {
    return (
      output: '',
      why: _withoutPeriod('"$command" could not start: ${oneLine('$error')}'),
    );
  }
  if (result.succeeded) return (output: result.stdout, why: null);
  final end = endOf(command, result.exitCode, environment.operatingSystem);
  final errors = oneLine(outputTail(result, lines: 5));
  return (
    output: '',
    why: _withoutPeriod(errors.isEmpty ? end : '$end: $errors'),
  );
}

/// Why the Firebase CLI [firebase] does not run, or `null` if it runs, as
/// `firebase --version` tells; see [askFirebaseVersion].
Future<String?> whyFirebaseDoesNotRun(
  String firebase,
  SmfEnvironment environment,
) async =>
    (await askFirebaseVersion(firebase, environment)).why;

/// [text] without its final period, which the sentence around it ends with.
String _withoutPeriod(String text) =>
    text.endsWith('.') ? text.substring(0, text.length - 1) : text;

/// Checks that the Firebase CLI is installed and runs, which
/// `flutterfire configure` runs to reach the Firebase projects of the user.
///
/// A `firebase` command on the `PATH` may not run, such as one that needs
/// another Node.js than the one of the terminal, so the check runs
/// `firebase --version`; see [whyFirebaseDoesNotRun]. When the command fails
/// or cannot start, the check tells that the command does not run and why,
/// and offers the installation, as for a missing CLI.
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

  @override
  Future<PreflightStatus> check(SmfEnvironment environment) async {
    final installable = InstallScript.of(environment.operatingSystem) != null;
    final firebase = await environment.findExecutable('firebase');
    if (firebase == null) {
      return PreflightMissing(
        instructions: howToInstallFirebaseCli,
        installable: installable,
      );
    }
    final why = await whyFirebaseDoesNotRun(firebase, environment);
    if (why == null) return const PreflightPassed();
    // On one line, since a question shows the instructions.
    return PreflightMissing(
      found: '$firebase does not run',
      instructions: '$why. $howToInstallFirebaseCli',
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
