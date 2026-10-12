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

/// What the script of an app printed in a run of CI whose service account
/// lacked `serviceusage.services.enable` in [_project]: its own lines and,
/// between them, those of firebase-tools 15.14.0. It is as the log of the
/// run has it, in which `***` stands where GitHub hid a part of a line,
/// but for the number of the project, which is another one here.
const _refusedToEnableApis = '''
Enabling Email/Password in the Firebase project saymyframe-app-cli (the mode of the app is required).

\x1B[1m\x1B[37m===\x1B[39m Deploying to 'saymyframe-app-cli'...\x1B[22m

\x1B[36m\x1B[1mi \x1B[22m\x1B[39m deploying \x1B[1mauth\x1B[22m
Enabling auth providers: email/password...

\x1B[1m\x1B[31mError:\x1B[39m\x1B[22m Failed to provision Firebase app: ENABLE_FIREBASE_API_TASK: com.google.apps.framework.auth.IamPermissionDeniedException: Permission denied to enable service [cloudapis.googleapis.com]
Permission denied to enable service [cloudresourcemanager.googleapis.com]
Permission denied to enable service [firebase.googleapis.com]
Permission denied to enable service [firebasehosting.googleapis.com]
Permission denied to enable service [identitytoolkit.googleapis.com] ***
  Details: [
    IAM***policy: 'serviceusage_services-/resourcemanager_projectnumbers/\\/00000000499602d2/services/cloudapis.googleapis.com' resource: 'projectnumbers/1234567890/services/cloudapis.googleapis.com' \tpermission: 'serviceusage.services.enable'*** denied ***auditlog: false, cloudaudit: true***
      Permission denied to enable service [cloudapis.googleapis.com] ***
        IAM***policy: 'serviceusage_services-/resourcemanager_projectnumbers/\\/00000000499602d2/services/cloudapis.googleapis.com' resource: 'projectnumbers/1234567890/services/cloudapis.googleapis.com' \tpermission: 'serviceusage.services.enable'*** denied ***auditlog: false, cloudaudit: true***
      ***
    IAM***policy: 'serviceusage_services-/resourcemanager_projectnumbers/\\/00000000499602d2/services/cloudresourcemanager.googleapis.com' resource: 'projectnumbers/1234567890/services/cloudresourcemanager.googleapis.com' \tpermission: 'serviceusage.services.enable'*** denied ***auditlog: false, cloudaudit: true***
      Permission denied to enable service [cloudresourcemanager.googleapis.com] ***
        IAM***policy: 'serviceusage_services-/resourcemanager_projectnumbers/\\/00000000499602d2/services/cloudresourcemanager.googleapis.com' resource: 'projectnumbers/1234567890/services/cloudresourcemanager.googleapis.com' \tpermission: 'serviceusage.services.enable'*** denied ***auditlog: false, cloudaudit: true***
      ***
    IAM***policy: 'serviceusage_services-/resourcemanager_projectnumbers/\\/00000000499602d2/services/firebase.googleapis.com' resource: 'projectnumbers/1234567890/services/firebase.googleapis.com' \tpermission: 'serviceusage.services.enable'*** denied ***auditlog: false, cloudaudit: true***
      Permission denied to enable service [firebase.googleapis.com] ***
        IAM***policy: 'serviceusage_services-/resourcemanager_projectnumbers/\\/00000000499602d2/services/firebase.googleapis.com' resource: 'projectnumbers/1234567890/services/firebase.googleapis.com' \tpermission: 'serviceusage.services.enable'*** denied ***auditlog: false, cloudaudit: true***
      ***
    IAM***policy: 'serviceusage_services-/resourcemanager_projectnumbers/\\/00000000499602d2/services/firebasehosting.googleapis.com' resource: 'projectnumbers/1234567890/services/firebasehosting.googleapis.com' \tpermission: 'serviceusage.services.enable'*** denied ***auditlog: false, cloudaudit: true***
      Permission denied to enable service [firebasehosting.googleapis.com] ***
        IAM***policy: 'serviceusage_services-/resourcemanager_projectnumbers/\\/00000000499602d2/services/firebasehosting.googleapis.com' resource: 'projectnumbers/1234567890/services/firebasehosting.googleapis.com' \tpermission: 'serviceusage.services.enable'*** denied ***auditlog: false, cloudaudit: true***
      ***
    IAM***policy: 'serviceusage_services-/resourcemanager_projectnumbers/\\/00000000499602d2/services/identitytoolkit.googleapis.com' resource: 'projectnumbers/1234567890/services/identitytoolkit.googleapis.com' \tpermission: 'serviceusage.services.enable'*** denied ***auditlog: false, cloudaudit: true***
      Permission denied to enable service [identitytoolkit.googleapis.com] ***
        IAM***policy: 'serviceusage_services-/resourcemanager_projectnumbers/\\/00000000499602d2/services/identitytoolkit.googleapis.com' resource: 'projectnumbers/1234567890/services/identitytoolkit.googleapis.com' \tpermission: 'serviceusage.services.enable'*** denied ***auditlog: false, cloudaudit: true***
      ***
  ]
*** (Neither system permission tenantmanagement.write granted nor fine-grained check com.google.api.tenant.auth.PublicAnnotations\$DefaultTenantManagerAuthChecker passed): securityContext=ValidatedSecurityContext***gaiauser/0x1***
The Firebase CLI did not enable the sign-in methods (exit code 2).
- If it ran as the wrong account: this script runs the Firebase CLI in a temporary directory, where an account that "firebase login:use" chose for the directory of the app does not apply. To name the account, run: dart tool/enable_firebase_sign_in.dart --account <email>
- Its log, firebase-debug.log, was in that temporary directory, which this script removes. To see what the Firebase CLI did, run: dart tool/enable_firebase_sign_in.dart --debug
- The Firebase console enables the methods too, under Authentication > Sign-in method: https://console.firebase.google.com/project/saymyframe-app-cli/authentication/providers
''';

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

    /// As firebase-tools 15.14.0 notes with `--debug` the permissions that
    /// its check finds missing, and goes on.
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

    /// A line that names [permission] as denied, in the form of those of
    /// [_refusedToEnableApis].
    String denied(String permission) =>
        "    IAM***policy: 'p' resource: 'r' \tpermission: '$permission'*** "
        'denied ***auditlog: false, cloudaudit: true***\n';

    test(
        'is a lack of a permission when the project refuses the Firebase '
        'CLI, but not when an API is not enabled, which has the same error',
        () {
      expect(
        {
          for (final (name, output) in [
            ('refused', refused),
            ('refused to enable the APIs', _refusedToEnableApis),
            ('a denied permission alone', denied('firebase.clients.create')),
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
          'refused to enable the APIs': (true, false),
          'a denied permission alone': (true, false),
          'unauthorized': (true, false),
          'disabled': (false, true),
          'no credentials': (false, false),
          'other': (false, false),
          'nothing': (false, false),
        },
      );
    });

    test(
        'has the permission that Google denied the Firebase CLI in a run of '
        'CI, once, although what the Firebase CLI printed names it for each '
        'API', () {
      expect(
        "permission: 'serviceusage.services.enable'"
            .allMatches(_refusedToEnableApis),
        hasLength(10),
        reason: 'The output of the run names the permission for five APIs, '
            'twice each.',
      );

      expect(
        missingPermissionsIn(_refusedToEnableApis),
        ['serviceusage.services.enable'],
        reason: 'It is neither one of the permissions that the Firebase CLI '
            'checks itself nor tenantmanagement.write, which the last line '
            'of the error has and no role grants.',
      );
      expect(
        debugMayNamePermission(_refusedToEnableApis),
        isFalse,
        reason: 'The output names the permission, so a second run with '
            '--debug has nothing to add.',
      );
    });

    test(
        'has the permissions that the Firebase CLI printed as denied, each '
        'once and in their order, before those that it lists as missing', () {
      expect(
        missingPermissionsIn(
          '${denied('firebase.clients.create')}'
          '${denied('serviceusage.services.enable')}'
          '${denied('firebase.clients.create')}',
        ),
        ['firebase.clients.create', 'serviceusage.services.enable'],
      );
      expect(
        missingPermissionsIn(
          '$debug${denied('firebaseauth.configs.update')}'
          '${denied('serviceusage.services.enable')}',
        ),
        [
          'firebaseauth.configs.update',
          'serviceusage.services.enable',
          'firebase.projects.update',
        ],
      );
      // Not what only looks like it: another key, or no name of a
      // permission between the quotes.
      expect(
        missingPermissionsIn(
          "resource: 'projectnumbers/1234567890'\n"
          "permission: ''\n"
          "permission: '[cloudapis.googleapis.com]'\n"
          'system permission tenantmanagement.write\n',
        ),
        isEmpty,
      );
    });

    test(
        'has the permissions that the Firebase CLI says its account lacks, '
        'in its debug output or where it stops at them', () {
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
    });

    test(
        'is run again with --debug only for a lack of a permission that '
        'the Firebase CLI did not name', () {
      expect(
        {
          for (final (name, output) in [
            ('refused', refused),
            ('refused to enable the APIs', _refusedToEnableApis),
            ('unauthorized', unauthorized),
            ('disabled', disabled),
            ('no credentials', noCredentials),
            ('other', other),
            ('nothing', ''),
          ])
            name: debugMayNamePermission(output),
        },
        {
          'refused': isTrue,
          'refused to enable the APIs': isFalse,
          'unauthorized': isFalse,
          'disabled': isFalse,
          'no credentials': isFalse,
          'other': isFalse,
          'nothing': isFalse,
        },
      );
    });

    test(
        'names a role only for the permissions that the reference of the '
        'IAM roles lists for it, and for a failure that names no permission '
        'those that the command is known to ask for', () {
      expect(rolesWith, {
        'serviceusage.services.':
            'Service Usage Admin (roles/serviceusage.serviceUsageAdmin)',
        'firebase.': 'Firebase Admin (roles/firebase.admin)',
        'firebaseauth.': 'Firebase Admin (roles/firebase.admin)',
        'firebasehosting.': 'Firebase Admin (roles/firebase.admin)',
      });
      expect(deployPermissions, [
        'serviceusage.services.enable',
        'firebase.projects.get',
        'firebase.projects.update',
        'firebaseauth.configs.update',
      ]);
    });

    group('is told', () {
      const failed = 'The script of the app did not enable the sign-in '
          'methods in the Firebase project $_project (exit code 2).';
      const refusedFor = '$failed The project refused the Firebase CLI for '
          'lack of a permission';
      const lacks = 'The Firebase CLI printed what the service account of '
          'CI lacks:';
      const serviceUsageAdmin =
          'Service Usage Admin (roles/serviceusage.serviceUsageAdmin)';
      const firebaseAdmin = 'Firebase Admin (roles/firebase.admin)';
      const at = 'at https://console.cloud.google.com/iam-admin/iam?project='
          '$_project';
      String told(String output, {String debugOutput = ''}) => enablingFailure(
            project: _project,
            code: 2,
            output: output,
            debugOutput: debugOutput,
          );

      test(
          'with the permission that Google denied in the run of CI and a '
          'role that has it, whatever a run with --debug adds', () {
        const text = '$refusedFor. $lacks serviceusage.services.enable. '
            'Grant the service account a role that has it, such as '
            '$serviceUsageAdmin, $at\n\n$_refusedToEnableApis';

        expect(told(_refusedToEnableApis), text);
        expect(told(_refusedToEnableApis, debugOutput: debug), text);
      });

      test(
          'with the permissions of a run with --debug where the first run '
          'named none, and one role when it has them all', () {
        expect(
          told(refused, debugOutput: debug),
          '$refusedFor. $lacks firebase.projects.update, '
          'firebaseauth.configs.update. Grant the service account a role '
          'that has them, such as $firebaseAdmin, $at\n\n$refused',
        );
      });

      test(
          'with each role next to the permissions that it has, and no role '
          'for a permission that the test knows none for', () {
        expect(
          told(
            '${denied('serviceusage.services.enable')}'
            '${denied('resourcemanager.projects.get')}'
            '${denied('firebase.clients.create')}'
            '${denied('firebasehosting.sites.update')}',
          ),
          startsWith(
            '$refusedFor. $lacks serviceusage.services.enable, '
            'resourcemanager.projects.get, firebase.clients.create, '
            'firebasehosting.sites.update. Grant the service account roles '
            'that have them, such as $serviceUsageAdmin for '
            'serviceusage.services.enable and $firebaseAdmin for '
            'firebase.clients.create, firebasehosting.sites.update, $at\n\n',
          ),
        );
        expect(
          told(
            '${denied('serviceusage.services.enable')}'
            '${denied('resourcemanager.projects.get')}',
          ),
          startsWith(
            '$refusedFor. $lacks serviceusage.services.enable, '
            'resourcemanager.projects.get. Grant the service account roles '
            'that have them, such as $serviceUsageAdmin for '
            'serviceusage.services.enable, $at\n\n',
          ),
        );
        expect(
          told(denied('resourcemanager.projects.get')),
          startsWith(
            '$refusedFor. $lacks resourcemanager.projects.get. Grant the '
            'service account a role that has it $at\n\n',
          ),
        );
        expect(
          told(
            '${denied('resourcemanager.projects.get')}'
            '${denied('iam.serviceAccounts.actAs')}',
          ),
          startsWith(
            '$refusedFor. $lacks resourcemanager.projects.get, '
            'iam.serviceAccounts.actAs. Grant the service account roles '
            'that have them $at\n\n',
          ),
        );
      });

      test(
          'with the permissions that the command is known to ask for when '
          'the Firebase CLI names none, with or without --debug', () {
        const text = '$refusedFor, and the Firebase CLI did not print which '
            'one. firebase deploy --only auth is known to ask for '
            'serviceusage.services.enable, firebase.projects.get, '
            'firebase.projects.update, firebaseauth.configs.update. Grant '
            'the service account of CI a role for each of them that it '
            'lacks, such as $serviceUsageAdmin for '
            'serviceusage.services.enable and $firebaseAdmin for '
            'firebase.projects.get, firebase.projects.update, '
            'firebaseauth.configs.update, $at\n\n$refused';

        expect(told(refused), text);
        expect(told(refused, debugOutput: refused), text);
      });

      test('with what to do for each other failure that the test knows', () {
        expect(
          told(disabled, debugOutput: debug),
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
          '$failed It is none of the failures that the test knows: a lack '
          'of a permission, an API that is not enabled, or credentials that '
          'the Firebase CLI did not take.\n\n$other',
        );
      });
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
