import 'dart:convert';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'support/sign_in_methods.dart';

/// The Firebase project of the tests.
const _project = 'saymyframe-app-cli';

/// The page of the Firebase console with the sign-in methods of
/// [_project].
const _console = 'https://console.firebase.google.com/project/$_project/'
    'authentication/providers';

/// What a run that finds the sign-in methods not enabled is told to do.
const _whoEnables = 'Only one job of the workflow Build enables the sign-in '
    'methods in the project, with SMF_FIREBASE_ENABLE_SIGN_IN=1, so that '
    'two runs never write to it at once. Run Build first, such as by hand '
    'on this branch, or enable Email/Password at $_console';

/// What the Identity Toolkit API answers a request that it refuses with
/// [message], as JSON.
String _refused(String message, {int code = 400, String? status}) =>
    jsonEncode({
      'error': {
        'code': code,
        'message': message,
        if (status != null) 'status': status,
        'errors': [
          {'message': message, 'domain': 'global', 'reason': 'invalid'},
        ],
      },
    });

void main() {
  group('apiKeysOf', () {
    test(
        'finds the API key of each platform that flutterfire configured in '
        'the options of the app, and none in the placeholder', () {
      const configured = '''
class DefaultFirebaseOptions {
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'key-of-android',
    appId: '1:1234567890:android:0a1b2c3d4e5f6789',
    messagingSenderId: '1234567890',
    projectId: 'saymyframe-app-cli',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'key-of-ios',
    appId: '1:1234567890:ios:0a1b2c3d4e5f6789',
    iosBundleId: 'com.saymyframe.ci.firebase-start-app',
  );
}
''';
      const placeholder = '''
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError('DefaultFirebaseOptions are not configured.');
  }
}
''';

      expect(apiKeysOf(configured), ['key-of-android', 'key-of-ios']);
      expect(apiKeysOf(placeholder), isEmpty);
    });
  });

  group('emailPasswordProblem', () {
    String? problem(int status, String body) =>
        emailPasswordProblem(project: _project, status: status, body: body);

    test(
        'takes the answer that the address or the password is wrong for a '
        'project with Email/Password, with the protection against the '
        'enumeration of addresses and without it', () {
      expect(problem(400, _refused('INVALID_LOGIN_CREDENTIALS')), isNull);
      expect(problem(400, _refused('EMAIL_NOT_FOUND')), isNull);
      expect(enabledAnswers, {'INVALID_LOGIN_CREDENTIALS', 'EMAIL_NOT_FOUND'});
    });

    test(
        'tells a project in which Authentication is set up without '
        'Email/Password, and who enables it', () {
      for (final code in ['PASSWORD_LOGIN_DISABLED', 'OPERATION_NOT_ALLOWED']) {
        expect(
          problem(400, _refused(code)),
          'The Firebase project $_project answers a sign-in with a password '
          'with $code: Authentication is set up there, but Email/Password is '
          'not enabled, so nobody can sign in to the app. $_whoEnables',
        );
      }
      // As the API tells the reason after the code.
      expect(
        problem(
          400,
          _refused(
            'OPERATION_NOT_ALLOWED : Password sign-in is disabled for this '
            'project.',
          ),
        ),
        startsWith(
          'The Firebase project $_project answers a sign-in with a password '
          'with OPERATION_NOT_ALLOWED: Authentication is set up there,',
        ),
      );
    });

    test(
        'tells a project in which Authentication was never set up, and who '
        'enables the methods', () {
      expect(
        problem(400, _refused('CONFIGURATION_NOT_FOUND')),
        'The Firebase project $_project answers a sign-in with a password '
        'with CONFIGURATION_NOT_FOUND: Authentication was never set up '
        'there, so no way to sign in is enabled. $_whoEnables',
      );
    });

    test(
        'tells an answer that says nothing of the sign-in methods, with '
        'what each answer of a project means', () {
      const meaning = ', which does not tell whether Email/Password is '
          'enabled there. A project with it answers '
          'INVALID_LOGIN_CREDENTIALS or EMAIL_NOT_FOUND, one without it '
          'PASSWORD_LOGIN_DISABLED, and one in which Authentication was '
          'never set up CONFIGURATION_NOT_FOUND. An answer about the API key '
          'means that the app is not configured for this project, or that '
          'the key is restricted to its app.';
      const asked = 'The Firebase project $_project answers a sign-in with '
          'a password, for an address without an account, with HTTP';

      expect(
        problem(
          400,
          _refused(
            'API key not valid. Please pass a valid API key.',
            status: 'INVALID_ARGUMENT',
          ),
        ),
        '$asked 400 (API key not valid. Please pass a valid API key.)$meaning',
      );
      expect(
        problem(
          403,
          _refused(
            'Requests from this Android client application <empty> are '
            'blocked.',
            code: 403,
            status: 'PERMISSION_DENIED',
          ),
        ),
        '$asked 403 (Requests from this Android client application <empty> '
        'are blocked.)$meaning',
      );
      // A code that only an address with an account can get, and one of
      // too many requests.
      for (final code in ['INVALID_PASSWORD', 'TOO_MANY_ATTEMPTS_TRY_LATER']) {
        expect(problem(400, _refused(code)), '$asked 400 ($code)$meaning');
      }
      // A code of a project with Email/Password, under another status.
      expect(
        problem(500, _refused('INVALID_LOGIN_CREDENTIALS', code: 500)),
        '$asked 500 (INVALID_LOGIN_CREDENTIALS)$meaning',
      );
      expect(
        problem(403, _refused('CONFIGURATION_NOT_FOUND', code: 403)),
        '$asked 403 (CONFIGURATION_NOT_FOUND)$meaning',
      );
      // No error of the API at all: a sign-in that succeeded, a page of a
      // proxy, an empty answer.
      expect(problem(200, '{"idToken": "token"}'), '$asked 200$meaning');
      expect(problem(502, '<html>Bad Gateway</html>'), '$asked 502$meaning');
      expect(problem(400, ''), '$asked 400$meaning');
      expect(problem(400, '{"error": "refused"}'), '$asked 400$meaning');
    });
  });

  group('webAppIdsOf', () {
    test('finds the web apps that the Firebase CLI lists, after its own line',
        () {
      String listed(List<Map<String, String>> apps) =>
          'i  Preparing the list of your Firebase WEB apps\n'
          '${jsonEncode({'status': 'success', 'result': apps})}\n';

      expect(
        webAppIdsOf(
          listed([
            {
              'appId': '1:1234567890:web:0a1b2c3d4e5f6789',
              'displayName': 'Default Web App',
              'platform': 'WEB',
            },
            {'appId': '1:1234567890:web:9876f5e4d3c2b1a0', 'platform': 'WEB'},
          ]),
        ),
        [
          '1:1234567890:web:0a1b2c3d4e5f6789',
          '1:1234567890:web:9876f5e4d3c2b1a0',
        ],
      );
      expect(webAppIdsOf(listed([])), isEmpty);
    });
  });

  group('webAppProblem', () {
    String? problem(List<String> webApps, {required bool register}) =>
        webAppProblem(webApps: webApps, project: _project, register: register);

    test('lets every run enable the methods in a project with a web app', () {
      for (final register in [true, false]) {
        expect(problem(['1:1:web:a'], register: register), isNull);
        expect(problem(['1:1:web:a', '1:1:web:b'], register: register), isNull);
      }
    });

    test(
        'lets only a run that may register apps enable them in a project '
        'without a web app, to which the Firebase CLI would add one', () {
      expect(problem([], register: true), isNull);
      expect(
        problem([], register: false),
        'The Firebase project $_project has no web app, and the Firebase CLI '
        'would add one, named "Default Web App", to enable the sign-in '
        'methods through it. Only the runs of the workflow Build register an '
        'app in the project, with SMF_FIREBASE_REGISTER=1. Run Build first, '
        'such as by hand on this branch.',
      );
    });
  });

  group('enabledLineOf', () {
    test(
        'is the line of the Firebase CLI for the methods of the mode of the '
        'app, with Anonymous first', () {
      expect({
        for (final mode in AuthMode.values) mode: enabledLineOf(mode),
      }, {
        AuthMode.required: 'Auth providers enabled: email/password',
        AuthMode.guest: 'Auth providers enabled: email/password',
        AuthMode.anonymous: 'Auth providers enabled: anonymous, email/password',
      });
    });
  });

  group('a run of the script that failed', () {
    /// What the script prints after the Firebase CLI failed.
    const footer = 'The Firebase CLI did not enable the sign-in methods '
        '(exit code 2).\n'
        '- If it ran as the wrong account: this script runs the Firebase '
        'CLI in a temporary directory.\n';

    /// As firebase-tools 15.14.0 fails when the project refuses the
    /// request that enables the methods (`enhanceProvisioningError`).
    const refused = "=== Deploying to '$_project'...\n"
        '\n'
        'i  deploying auth\n'
        'Enabling auth providers: email/password...\n'
        '\n'
        'Error: Failed to provision Firebase app: HTTP Error: 403, The '
        'caller does not have permission\n'
        '$footer';

    /// As a version that stops at its check of the permissions prints.
    const unauthorized = 'Error: Authorization failed. This account is '
        'missing the following required permissions on project $_project:\n'
        '\n'
        '  firebase.projects.update\n'
        '  firebaseauth.configs.update\n'
        '$footer';

    /// As Google answers for an API that is not enabled in the project.
    const disabled = 'Error: Failed to provision Firebase app: HTTP Error: '
        '403, Firebase Management API has not been used in project '
        '1234567890 before or it is disabled. Enable it by visiting '
        'https://console.developers.google.com/apis/api/'
        'firebase.googleapis.com/overview?project=1234567890 then retry.\n'
        '\n'
        'Error details:\n'
        '  Reason: SERVICE_DISABLED\n'
        '  Domain: googleapis.com\n'
        '$footer';

    const noCredentials = 'Error: Failed to authenticate, have you run '
        'firebase login?\n'
        '$footer';

    const other = 'Error: Failed to provision Firebase app: HTTP Error: 500, '
        'Internal error encountered.\n'
        '$footer';

    test(
        'is a lack of a permission when the project refuses the Firebase '
        'CLI, but not when an API is not enabled, which has the same error',
        () {
      expect(
        {
          for (final (name, output) in [
            ('refused', refused),
            ('unauthorized', unauthorized),
            ('disabled', disabled),
            ('no credentials', noCredentials),
            ('other', other),
            ('nothing', ''),
          ])
            name: (lacksPermission(output), apiIsDisabled(output)),
        },
        {
          'refused': (true, false),
          'unauthorized': (true, false),
          'disabled': (false, true),
          'no credentials': (false, false),
          'other': (false, false),
          'nothing': (false, false),
        },
      );
    });

    test(
        'has the permissions that the Firebase CLI says its account lacks, '
        'in its debug output or where it stops at them', () {
      // As firebase-tools 15.14.0 notes them, and goes on.
      const debug = '[iam] checking project $_project for permissions '
          '["firebase.projects.get","firebase.projects.update",'
          '"firebaseauth.configs.update"]\n'
          '[iam] error while checking permissions, command may fail: '
          'Authorization failed. This account is missing the following '
          'required permissions on project $_project:\n'
          '\n'
          '  firebase.projects.update\n'
          '  firebaseauth.configs.update\n'
          '\n'
          "=== Deploying to '$_project'...\n"
          // A line of the same form after the list is none of it.
          '  not.of.the.list\n';

      expect(
        missingPermissionsIn(debug),
        ['firebase.projects.update', 'firebaseauth.configs.update'],
      );
      expect(
        missingPermissionsIn(unauthorized),
        ['firebase.projects.update', 'firebaseauth.configs.update'],
      );
      expect(missingPermissionsIn(debug.replaceAll('\n', '\r\n')), [
        'firebase.projects.update',
        'firebaseauth.configs.update',
      ]);
      expect(missingPermissionsIn(refused), isEmpty);
      expect(missingPermissionsIn(''), isEmpty);
      expect(deployPermissions, [
        'firebase.projects.get',
        'firebase.projects.update',
        'firebaseauth.configs.update',
      ]);
    });

    test(
        'is told with what to do for each failure that the test knows, '
        'before what the script printed', () {
      const failed = 'The script of the app did not enable the sign-in '
          'methods in the Firebase project $_project (exit code 2).';
      const grant = 'Grant the service account a role that has them, such '
          'as Firebase Admin (roles/firebase.admin), at '
          'https://console.cloud.google.com/iam-admin/iam?project=$_project';
      String told(String output, {List<String> missing = const []}) =>
          enablingFailure(
            project: _project,
            code: 2,
            output: output,
            missing: missing,
          );

      // The permissions that the account lacks, where the Firebase CLI
      // told of them, and those that the command asks for otherwise.
      expect(
        told(refused, missing: ['firebaseauth.configs.update']),
        '$failed The project refused the Firebase CLI for lack of a '
        'permission. The service account of CI lacks '
        'firebaseauth.configs.update. $grant\n\n$refused',
      );
      expect(
        told(refused),
        '$failed The project refused the Firebase CLI for lack of a '
        'permission. firebase deploy --only auth asks for '
        'firebase.projects.get, firebase.projects.update, '
        'firebaseauth.configs.update. $grant\n\n$refused',
      );
      expect(
        told(disabled),
        '$failed An API that the Firebase CLI calls is not enabled in the '
        'project. What it printed has the address at which the API is '
        'enabled.\n\n$disabled',
      );
      expect(
        told(noCredentials),
        '$failed The Firebase CLI did not take the key of the service '
        'account of CI, which the test gives it as '
        'GOOGLE_APPLICATION_CREDENTIALS.\n\n$noCredentials',
      );
      expect(
        told(other),
        '$failed It is none of the failures that the test knows: a lack of '
        'a permission, an API that is not enabled, or credentials that the '
        'Firebase CLI did not take.\n\n$other',
      );
    });
  });

  test('the page of the sign-in methods of a project is that of the console',
      () {
    expect(signInMethodsOf(_project), _console);
    expect(
      '$signInWithPassword',
      'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword',
    );
  });
}
