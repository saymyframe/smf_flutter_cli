import 'dart:convert';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/src/preflight/commands.dart';
import 'package:smf_firebase_core/src/preflight/firebase_cli.dart';

/// Checks that the user has logged in to the Firebase CLI, and that Google
/// still accepts the login, which `flutterfire configure` needs to reach the
/// Firebase projects.
///
/// `firebase login:list --json` tells whether there is an account: it
/// prints `{"status": "success"}` with the accounts in `result`, and without
/// `result` when there is none, exiting with code 0 either way. Its output
/// holds the tokens of the accounts, so the check never shows it: when the
/// command fails, it shows the error that the Firebase CLI reported in its
/// JSON, and the end of the standard error. When `firebase --version` fails
/// too, the Firebase CLI does not run, such as on a Node.js that is too old
/// for it, which [FirebaseCliCheck] tells about, so the check says only that.
///
/// `login:list` only reads what the Firebase CLI keeps on the machine, so it
/// lists a login that has expired or was revoked too. With an account, the
/// check lists the Firebase projects with `firebase projects:list --debug`,
/// which asks Google and only reads: the login works when the command
/// succeeds, with any number of projects. When it fails, the Firebase CLI
/// reports the same error for a login that Google rejects and for a machine
/// without a network, so the check reads its debug output, which has the
/// HTTP status of each answer of Google; see [_rejectedIn]. A status that
/// rejects the login means that the login has expired or is no longer
/// valid; any other failure is a check that could not run, with the error
/// and the requests that failed, as the output names them. The output holds
/// the email of the account, so the check shows nothing else of it.
///
/// The check can log the user in with `firebase login`, which asks its own
/// questions in the terminal, or again with `firebase login --reauth` when
/// the Firebase CLI has an account, since `firebase login` keeps a login it
/// has.
///
/// `firebase login` waits for the browser to come back to a server on the
/// machine, which a browser on another machine cannot reach. So over SSH, as
/// [isOverSsh] tells, the check logs in with `--no-localhost`, which gives a
/// link to open on any device and asks for the authorization code shown
/// there, and the instructions give that command for any remote machine.
///
/// Like every command of the Firebase CLI, `login:list` and `projects:list`
/// keep records of their own while they only read: they update the time of
/// their last error in the configuration of the Firebase CLI and fetch its
/// message of the day once a day, `projects:list` keeps there the access
/// token that it refreshes, as every command that asks Google does, and
/// `--debug` leaves `firebase-debug.log` in the directory where the command
/// runs, which is among the temporary files of the run. The check turns off
/// the check for updates, which would run in the background after them.
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
    final SmfProcessResult result;
    try {
      result = await _listAccounts(firebase, environment);
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
      return _failedListing(firebase, environment, result, json);
    }
    if (_hasAccounts(json)) return _useLogin(firebase, environment);
    return switch (json) {
      {'status': 'success'} => const PreflightMissing(
          instructions: 'Log in $_howToLogIn.',
          installable: true,
        ),
      _ => const PreflightFailed(
          '"$_listing" did not report the accounts it knows.',
        ),
    };
  }

  /// Runs `firebase login` in the terminal: with `--reauth` when the
  /// Firebase CLI has an account, whose login Google no longer accepts, and
  /// with `--no-localhost` over SSH.
  @override
  Future<ToolInstall> install(SmfEnvironment environment) async {
    final firebase = await environment.findExecutable('firebase');
    if (firebase == null) {
      throw const PreflightSetupException('The Firebase CLI was not found.');
    }
    final accounts = await _listAccounts(firebase, environment);
    final arguments = [
      'login',
      if (accounts.succeeded && _hasAccounts(_jsonIn(accounts.stdout)))
        '--reauth',
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

/// The command that lists the accounts of the Firebase CLI.
const _listing = 'firebase login:list --json';

/// Runs `firebase login:list --json` with [firebase] in a directory of its
/// own, where the Firebase CLI may leave its `firebase-debug.log`, and
/// without its check for updates.
Future<SmfProcessResult> _listAccounts(
  String firebase,
  SmfEnvironment environment,
) async =>
    environment.processRunner.run(
      firebase,
      const ['login:list', '--json'],
      workingDirectory: await scratchDirectory(environment),
      environment: const {'NO_UPDATE_NOTIFIER': '1'},
    );

/// What the check finds when `firebase login:list --json` of [firebase]
/// failed with [result], whose output holds [json]: that the Firebase CLI
/// does not run, when `firebase --version` fails too, or else how the
/// command ended, with the error of its JSON and the end of its standard
/// error.
Future<PreflightStatus> _failedListing(
  String firebase,
  SmfEnvironment environment,
  SmfProcessResult result,
  Object? json,
) async {
  // A Firebase CLI that does not run fails every command, and the check of
  // the Firebase CLI tells why; the login is unknown until it runs.
  if (await whyFirebaseDoesNotRun(firebase, environment) != null) {
    return _cliDoesNotRun;
  }
  final reasons = [
    if (json case {'status': 'error', 'error': final String error}
        when error.trim().isNotEmpty)
      error.trim(),
    if (tailOf(result.stderr) case final tail when tail.isNotEmpty) tail,
  ];
  final end = endOf(_listing, result.exitCode, environment.operatingSystem);
  return PreflightFailed(
    reasons.isEmpty ? '$end.' : '$end:\n${reasons.join('\n')}',
  );
}

/// Whether [json], the output of `firebase login:list --json`, lists an
/// account.
bool _hasAccounts(Object? json) => switch (json) {
      {'status': 'success', 'result': final List<Object?> accounts} =>
        accounts.isNotEmpty,
      _ => false,
    };

/// Whether the Firebase CLI [firebase] can use its login, as
/// `firebase projects:list --debug` tells; see [FirebaseLoginCheck].
Future<PreflightStatus> _useLogin(
  String firebase,
  SmfEnvironment environment,
) async {
  const command = 'firebase projects:list --debug';
  final result = await environment.processRunner.run(
    firebase,
    const ['projects:list', '--debug'],
    workingDirectory: await scratchDirectory(environment),
    environment: const {'NO_UPDATE_NOTIFIER': '1'},
  );
  if (result.succeeded) return const PreflightPassed();
  final output = '${result.stdout}\n${result.stderr}';
  if (_rejectedIn(output)) return _expired;
  final reasons = {
    if (_errorIn(output) case final error?) error,
    for (final match in _failedRequest.allMatches(output))
      (match[1] ?? match[2]!).trim(),
  };
  final end = endOf(command, result.exitCode, environment.operatingSystem);
  return PreflightFailed(
    reasons.isEmpty ? '$end.' : '$end:\n${reasons.join('\n')}',
  );
}

/// A line of the debug output of the Firebase CLI with the HTTP status of
/// an answer: the URL without its query, and the status, such as
///
/// ```text
/// <<< [apiv2][status] GET https://firebase.googleapis.com/v1beta1/projects 401
/// ```
final _status = RegExp(r'<<< \[apiv2\]\[status\] [A-Z]+ (\S+) (\d{3})\b');

/// Whether [output], the debug output of a Firebase CLI command, has an
/// answer of Google that rejects the login: 401 from an API, or 400 from the
/// endpoint that refreshes the access token, which is how Google rejects a
/// refresh token that has expired or was revoked (`invalid_grant`), and a
/// login that needs to be renewed (`invalid_rapt`).
///
/// A machine without a network gets no answer at all, even when the Firebase
/// CLI says that the credentials are no longer valid, which it says for any
/// failure to refresh the token.
bool _rejectedIn(String output) => _status.allMatches(output).any(
      (match) => switch (match[2]) {
        '401' => true,
        '400' => match[1]!.endsWith('/token'),
        _ => false,
      },
    );

/// The line of the error with which a Firebase CLI command ended, such as
/// `Error: Failed to list Firebase projects. See firebase-debug.log for more
/// info.`, without the pointer to the log, which goes away with the
/// temporary files of the run.
final _error = RegExp(
  r'^Error: (.+?)(?: See firebase-debug\.log for more info\.)?\s*$',
  multiLine: true,
);

/// The error of the last line of [output] that [_error] matches, or `null`
/// if none does.
String? _errorIn(String output) => _error.allMatches(output).lastOrNull?[1];

/// A request that the Firebase CLI could not make, as its debug output names
/// it, such as `request to https://www.googleapis.com/oauth2/v3/token failed,
/// reason: getaddrinfo ENOTFOUND www.googleapis.com` or `Timeout reached
/// making request to https://firebase.googleapis.com/v1beta1/projects`.
final _failedRequest = RegExp(
  r'FetchError: (request to \S+ failed, reason: [^\r\n]+)|'
  r'(Timeout reached making request to \S+)',
);

/// What the check finds when Google rejects the login of the Firebase CLI.
const _expired = PreflightMissing(
  found: 'the login has expired or is no longer valid',
  instructions: 'Log in again with "firebase login --reauth", or on a remote '
      'machine, such as over SSH, with "firebase login --reauth '
      '--no-localhost".',
  installable: true,
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
