import 'dart:convert';

import 'package:smf_contracts/lego.dart';
import 'package:smf_firebase_core/src/preflight/commands.dart';

/// Checks that the user has logged in to the Firebase CLI, which
/// `flutterfire configure` needs to reach the Firebase projects.
///
/// `firebase login:list --json` tells: it prints `{"status": "success"}`
/// with the accounts in `result`, and without `result` when there is none,
/// exiting with code 0 either way. Its output holds the tokens of the
/// accounts, so the check never shows it: when the command fails, it shows
/// the error that the Firebase CLI reported in its JSON, and the end of the
/// standard error, such as that the Node.js version is too old. The check
/// can log the user in with `firebase login`, which asks its own questions
/// in the terminal.
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
        instructions: 'Install the Firebase CLI, then log in with '
            '"firebase login".',
      );
    }
    const command = 'firebase login:list --json';
    final result = await environment.processRunner.run(
      firebase,
      const ['login:list', '--json'],
      // The Firebase CLI writes firebase-debug.log where it runs.
      workingDirectory: await scratchDirectory(environment),
      environment: const {'NO_UPDATE_NOTIFIER': '1'},
    );
    final json = _jsonIn(result.stdout);
    if (!result.succeeded) {
      final reasons = [
        if (json case {'status': 'error', 'error': final String error}
            when error.trim().isNotEmpty)
          error.trim(),
        if (tailOf(result.stderr) case final tail when tail.isNotEmpty) tail,
      ];
      final end = endOf(command, result.exitCode);
      return PreflightFailed(
        reasons.isEmpty ? '$end.' : '$end:\n${reasons.join('\n')}',
      );
    }
    return switch (json) {
      {'status': 'success', 'result': final List<Object?> accounts}
          when accounts.isNotEmpty =>
        const PreflightPassed(),
      {'status': 'success'} => const PreflightMissing(
          instructions: 'Log in with "firebase login".',
          installable: true,
        ),
      _ => const PreflightFailed(
          '"$command" did not report the accounts it knows.',
        ),
    };
  }

  /// Runs `firebase login` in the terminal.
  @override
  Future<ToolInstall> install(SmfEnvironment environment) async {
    final firebase = await environment.findExecutable('firebase');
    if (firebase == null) {
      throw const PreflightSetupException('The Firebase CLI was not found.');
    }
    final code = await environment.processRunner.runInteractive(
      firebase,
      const ['login'],
      workingDirectory: await scratchDirectory(environment),
    );
    if (code != 0) {
      throw PreflightSetupException('${endOf('firebase login', code)}.');
    }
    return const ToolInstall();
  }
}

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
