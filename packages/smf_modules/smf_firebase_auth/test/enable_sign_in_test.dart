// The sign-in methods of an app with firebase_auth in its Firebase project,
// as CI checks them once flutterfire configured the app and before it
// starts the app on a device. The test needs a Firebase project, so it runs
// only with an app that flutterfire configured in SMF_CONFIGURED_APP and
// the id of its project in SMF_FIREBASE_PROJECT, as CI gives them. CI gives
// it the app with every module of each provider of the app entry, one in
// each job, and it skips an app that does not depend on firebase_auth,
// which signs nobody in.
//
// Every run asks the project as a client, with the API key of the app: a
// sign-in with a password, for an address that has no account, which
// creates nothing. A project with Email/Password answers that the address
// or the password is wrong, and any other answer fails the test with what
// it means (see emailPasswordProblem). The apps of CI are in the mode
// required, so the test asks for Email/Password alone: asking for Anonymous
// would sign an anonymous user up.
//
// One run enables the methods first, the one with
// SMF_FIREBASE_ENABLE_SIGN_IN=1, which CI gives one job of the workflow
// Build, so that two runs never write to the project at once. It runs the
// command of the README of the app, the script of the app, with the key of
// a service account of the project, whose path is in
// SMF_FIREBASE_SERVICE_ACCOUNT, as GOOGLE_APPLICATION_CREDENTIALS, and
// names no project: the script reads it from firebase.json. The Firebase
// CLI adds a web app to a project that has none, which registers an app in
// the project, so the test fails before the command for such a project
// unless the run may register apps, with SMF_FIREBASE_REGISTER=1, as the
// test of firebase_core that configures the app does for the Android and
// iOS apps (see webAppProblem). When the script fails, the test tells a
// lack of a permission of the service account from the other failures,
// with the permissions that the Firebase CLI printed as denied or missing
// and a role to grant for them (see enablingFailure).
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_auth/src/enable_sign_in.dart';
import 'package:test/test.dart';

import 'support/app_pubspec.dart';
import 'support/sign_in_methods.dart';

/// Runs [executable] with [arguments] in [directory], with [environment]
/// added to that of the test.
Future<ProcessResult> _run(
  String executable,
  List<String> arguments, {
  String? directory,
  Map<String, String>? environment,
}) =>
    Process.run(
      executable,
      arguments,
      workingDirectory: directory,
      environment: environment,
      runInShell: Platform.isWindows,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );

/// The names of the files and directories right in the directory [app].
Set<String> _entriesOf(String app) => {
      for (final entity in Directory(app).listSync())
        entity.uri.pathSegments.lastWhere((segment) => segment.isNotEmpty),
    };

/// What the Firebase project of the app with the API key [apiKey] answers
/// a sign-in with a password for an address that has no account: an
/// address of this run in a domain that nobody has. The key goes in a
/// header, so that no log of a request has it in an address. A request
/// that does not reach the project is made again, three times at most.
Future<({int status, String body})> _signInWithoutAccount(String apiKey) async {
  for (var attempt = 1;; attempt++) {
    try {
      return await _ask(apiKey);
    } on IOException {
      if (attempt == 3) rethrow;
      await Future<void>.delayed(Duration(seconds: 2 * attempt));
    }
  }
}

/// Makes the request of [_signInWithoutAccount] once.
Future<({int status, String body})> _ask(String apiKey) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  try {
    final request = await client.postUrl(signInWithPassword);
    request.headers
      ..set('X-Goog-Api-Key', apiKey)
      ..contentType = ContentType.json;
    request.write(
      jsonEncode({
        'email': 'no-account-${DateTime.now().microsecondsSinceEpoch}'
            '@smf-ci.example',
        'password': 'no password of an account',
        'returnSecureToken': true,
      }),
    );
    final response = await request.close();
    return (
      status: response.statusCode,
      body: await response.transform(utf8.decoder).join(),
    );
  } finally {
    client.close();
  }
}

void main() {
  final environment = Platform.environment;
  final app = environment['SMF_CONFIGURED_APP'];
  final project = environment['SMF_FIREBASE_PROJECT'];
  final serviceAccount = environment['SMF_FIREBASE_SERVICE_ACCOUNT'];
  final enables = environment['SMF_FIREBASE_ENABLE_SIGN_IN'] == '1';
  final register = environment['SMF_FIREBASE_REGISTER'] == '1';

  test(
    'the Firebase project of the app has Email/Password enabled, which the '
    'script of the app enables with the command of its README in the run '
    'that may write to the project',
    () async {
      final options = File('$app/lib/firebase_options.dart').readAsStringSync();
      expect(
        options,
        contains("projectId: '$project'"),
        reason: 'flutterfire did not configure the app in SMF_CONFIGURED_APP '
            'for the project $project.',
      );
      final mode = authRole.modeWrittenIn(
        File('$app/${AuthRole.sessionFile}').readAsStringSync(),
      );
      expect(
        mode,
        isNotNull,
        reason: '${AuthRole.sessionFile} of the app does not tell its mode.',
      );

      if (enables) {
        expect(
          serviceAccount,
          isNotNull,
          reason: 'A run that enables the sign-in methods needs the key of a '
              'service account of the project in '
              'SMF_FIREBASE_SERVICE_ACCOUNT.',
        );
        final credentials = {'GOOGLE_APPLICATION_CREDENTIALS': serviceAccount!};

        // Before the script, whose Firebase CLI adds a web app to a project
        // that has none. The Firebase CLI keeps its log in the directory
        // that it runs in, which is none of the repository.
        final listed = await _run(
          'firebase',
          ['apps:list', 'WEB', '--project=$project', '--json'],
          directory: Directory.systemTemp.path,
          environment: credentials,
        );
        expect(
          listed.exitCode,
          0,
          reason: 'firebase apps:list: ${listed.stdout}${listed.stderr}',
        );
        if (webAppProblem(
          webApps: webAppIdsOf('${listed.stdout}'),
          project: project!,
          register: register,
        )
            case final problem?) {
          fail(problem);
        }

        expect(
          File('$app/README.md').readAsStringSync(),
          contains('```bash\n$enableSignInCommand\n```'),
          reason: 'The README of the app gives no command for the script.',
        );
        final config = File('$app/firebase.json');
        final configured = config.readAsBytesSync();
        final entries = _entriesOf(app!);

        final [executable, ...arguments] = enableSignInCommand.split(' ');
        final enabled = await _run(
          executable,
          arguments,
          directory: app,
          environment: credentials,
        );
        final output = '${enabled.stdout}${enabled.stderr}';
        if (enabled.exitCode != 0) {
          // What Google denied is in what the Firebase CLI printed. Only
          // when that names no permission does the test run the script
          // again, for the debug output of the Firebase CLI, which lists
          // the permissions that its own check found missing. Of that
          // output the test takes those alone and prints nothing else.
          final withDebug = debugMayNamePermission(output)
              ? await _run(
                  executable,
                  [...arguments, '--debug'],
                  directory: app,
                  environment: credentials,
                )
              : null;
          fail(
            enablingFailure(
              project: project,
              code: enabled.exitCode,
              output: output,
              debugOutput: withDebug == null
                  ? ''
                  : '${withDebug.stdout}${withDebug.stderr}',
            ),
          );
        }
        // In the log of the run, which has no secret: what the script and
        // the Firebase CLI said of the project.
        // ignore: avoid_print
        print(output);

        // The script named the project of firebase.json and the methods of
        // the mode of the app, and the Firebase CLI enabled those.
        expect(
          '${enabled.stdout}',
          allOf(
            contains(
              'in the Firebase project $project (the mode of the app is '
              '${mode!.name}).',
            ),
            contains(enabledLineOf(mode)),
          ),
        );
        // It left the app as flutterfire configured it.
        expect(
          config.readAsBytesSync(),
          configured,
          reason: 'The script changed firebase.json of the app.',
        );
        expect(
          _entriesOf(app).difference(entries),
          isEmpty,
          reason: 'The script, or the Firebase CLI, left a file in the app, '
              'such as .firebaserc or firebase-debug.log.',
        );
      }

      final keys = apiKeysOf(options);
      expect(
        keys,
        isNotEmpty,
        reason: 'lib/firebase_options.dart of the app has no API key.',
      );
      final answer = await _signInWithoutAccount(keys.first);
      if (emailPasswordProblem(
        project: project!,
        status: answer.status,
        body: answer.body,
      )
          case final problem?) {
        fail(problem);
      }
    },
    skip: app == null || project == null
        ? 'Needs an app with firebase_auth that flutterfire configured in '
            'SMF_CONFIGURED_APP, and the id of its Firebase project in '
            'SMF_FIREBASE_PROJECT.'
        : !dependsOn(app, 'firebase_auth')
            ? 'The app in SMF_CONFIGURED_APP does not depend on '
                'firebase_auth, so it signs nobody in.'
            : null,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
