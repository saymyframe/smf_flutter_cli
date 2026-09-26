import 'dart:convert';

import 'package:smf_contracts/lego.dart';
import 'package:smf_firebase_core/src/preflight/commands.dart';

/// Checks that the user has logged in to the Firebase CLI, which
/// `flutterfire configure` needs to reach the Firebase projects.
///
/// `firebase login:list --json` tells: it prints `{"status": "success"}`
/// with the accounts in `result`, and without `result` when there is none,
/// exiting with code 0 either way. Its output holds the tokens of the
/// accounts, so the check never shows it. The check can log the user in
/// with `firebase login`, which asks its own questions in the terminal.
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
    );
    if (!result.succeeded) {
      return PreflightFailed('"$command" exited with code ${result.exitCode}.');
    }
    final output = result.stdout;
    final start = output.indexOf('{');
    final end = output.lastIndexOf('}');
    Object? json;
    if (start >= 0 && end > start) {
      try {
        json = jsonDecode(output.substring(start, end + 1));
      } on FormatException {
        json = null;
      }
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
      throw PreflightSetupException('"firebase login" exited with code $code.');
    }
    return const ToolInstall();
  }
}
