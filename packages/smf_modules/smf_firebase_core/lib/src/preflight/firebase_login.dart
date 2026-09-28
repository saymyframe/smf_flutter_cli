import 'dart:convert';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/src/preflight/commands.dart';
import 'package:smf_firebase_core/src/preflight/firebase_cli.dart';

/// Checks that the user has logged in to the Firebase CLI, which
/// `flutterfire configure` needs to reach the Firebase projects.
///
/// `firebase login:list --json` tells: it prints `{"status": "success"}`
/// with the accounts in `result`, and without `result` when there is none,
/// exiting with code 0 either way. Its output holds the tokens of the
/// accounts, so the check never shows it: when the command fails, it shows
/// the error that the Firebase CLI reported in its JSON, and the end of the
/// standard error. When `firebase --version` fails too, the Firebase CLI
/// does not run, such as on a Node.js that is too old for it, which
/// [FirebaseCliCheck] tells about, so the check says only that. The check
/// can log the user in with `firebase login`, which asks its own questions
/// in the terminal.
///
/// `firebase login` waits for the browser to come back to a server on the
/// machine, which a browser on another machine cannot reach. So over SSH, as
/// [isOverSsh] tells, the check logs in with `firebase login --no-localhost`,
/// which gives a link to open on any device and asks for the authorization
/// code shown there, and the instructions give that command for any remote
/// machine.
///
/// Like every command of the Firebase CLI, `login:list` keeps records of its
/// own while it only reads the accounts: it notes the time of its last
/// error in its configuration and fetches its message of the day once a
/// day. The check turns off the check for updates, which would run in the
/// background after it.
final class FirebaseLoginCheck extends PreflightCheck {
  /// Creates the check.
  const FirebaseLoginCheck();

  @override
  String get id => 'firebase_login';

  @override
  String get description => 'Firebase login';

  @override
  Future<PreflightStatus> check(SmfEnvironment environment) async {
    final firebase = await environment.findExecutable('firebase');
    if (firebase == null) {
      return const PreflightMissing(
        instructions: 'Install the Firebase CLI, then log in $_howToLogIn.',
      );
    }
    const command = 'firebase login:list --json';
    final SmfProcessResult result;
    try {
      result = await environment.processRunner.run(
        firebase,
        const ['login:list', '--json'],
        // The Firebase CLI writes firebase-debug.log where it runs.
        workingDirectory: await scratchDirectory(environment),
        environment: const {'NO_UPDATE_NOTIFIER': '1'},
      );
    } on SmfCancelledException {
      rethrow;
    } on Exception {
      if (await whyFirebaseDoesNotRun(firebase, environment) != null) {
        return _cliDoesNotRun;
      }
      rethrow;
    }
    final json = _jsonIn(result.stdout);
    if (!result.succeeded) {
      // A Firebase CLI that does not run fails every command, and the check
      // of the Firebase CLI tells why; the login is unknown until it runs.
      if (await whyFirebaseDoesNotRun(firebase, environment) != null) {
        return _cliDoesNotRun;
      }
      final reasons = [
        if (json case {'status': 'error', 'error': final String error}
            when error.trim().isNotEmpty)
          error.trim(),
        if (tailOf(result.stderr) case final tail when tail.isNotEmpty) tail,
      ];
      final end = endOf(
        command,
        result.exitCode,
        environment.operatingSystem,
      );
      return PreflightFailed(
        reasons.isEmpty ? '$end.' : '$end:\n${reasons.join('\n')}',
      );
    }
    return switch (json) {
      {'status': 'success', 'result': final List<Object?> accounts}
          when accounts.isNotEmpty =>
        const PreflightPassed(),
      {'status': 'success'} => const PreflightMissing(
          instructions: 'Log in $_howToLogIn.',
          installable: true,
        ),
      _ => const PreflightFailed(
          '"$command" did not report the accounts it knows.',
        ),
    };
  }

  /// Runs `firebase login` in the terminal, with `--no-localhost` over SSH.
  @override
  Future<ToolInstall> install(SmfEnvironment environment) async {
    final firebase = await environment.findExecutable('firebase');
    if (firebase == null) {
      throw const PreflightSetupException('The Firebase CLI was not found.');
    }
    final arguments = [
      'login',
      if (isOverSsh(environment)) '--no-localhost',
    ];
    final code = await environment.processRunner.runInteractive(
      firebase,
      arguments,
      workingDirectory: await scratchDirectory(environment),
    );
    if (code != 0) {
      final command = ['firebase', ...arguments].join(' ');
      throw PreflightSetupException(
        '${endOf(command, code, environment.operatingSystem)}.',
      );
    }
    return const ToolInstall();
  }
}

/// Whether the user reached the machine over SSH, whose server sets
/// `SSH_CONNECTION`, `SSH_CLIENT` or `SSH_TTY` for the session: then the
/// browser of the user runs on another machine.
bool isOverSsh(SmfEnvironment environment) =>
    const ['SSH_CONNECTION', 'SSH_CLIENT', 'SSH_TTY'].any(
      (name) => environment.environmentVariable(name)?.isNotEmpty ?? false,
    );

/// What the check finds when the Firebase CLI does not run.
const _cliDoesNotRun = PreflightMissing(
  found: 'the Firebase CLI does not run',
  instructions: 'Install the Firebase CLI, then log in $_howToLogIn.',
);

/// How to log in with the Firebase CLI, in the terminal of the machine or of
/// a remote one.
const _howToLogIn = 'with "firebase login", or on a remote machine, such as '
    'over SSH, with "firebase login --no-localhost"';

/// The JSON that the Firebase CLI printed in [output], from its first `{`
/// to its last `}`, after any warning; `null` if there is none.
Object? _jsonIn(String output) {
  final start = output.indexOf('{');
  final end = output.lastIndexOf('}');
  if (start < 0 || end < start) return null;
  try {
    return jsonDecode(output.substring(start, end + 1));
  } on FormatException {
    // Its text could hold the tokens of the accounts, so it goes unseen.
    return null;
  }
}
