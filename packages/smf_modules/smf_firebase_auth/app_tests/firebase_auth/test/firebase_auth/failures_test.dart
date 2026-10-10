// A test that continuous integration runs in the apps with the
// firebase_auth module, on the real Firebase packages, whose platform side
// is a backend in memory (firebase_auth_mocks.dart): the sign-in service of
// the module, which createFirebaseAuthService() creates, gives each code
// with which Firebase Authentication answers a call the reason of the auth
// role. The platform side answers with each code in the form in which
// Android sends it, the code of Firebase as it is, and in the form of iOS,
// and the plugin makes one code of both. A way to sign in that is not
// enabled in the Firebase project is notConfigured, with a hint that has
// the link to the project, also where Firebase tells of it only in a
// message or, on iOS and macOS, in an internal error. The hint names what
// Firebase answered in a line, also where the message of iOS is the
// description of an error over many lines. A code that the service does
// not know is unknown, with the code and the message on one line. A
// password reset completes for an address without an account also when
// Firebase tells so. An empty address or password fails before Firebase is
// asked, with the same reason on every platform. A call that failed leaves
// the user. And a call for a user whose session has ended on the server
// signs that user out.
//
// It uses the service of the module and runs none of the start-up of the
// app but the start of Firebase (service.dart). The matrix sets up the
// mocks of the platform side of every module of the app before the tests,
// and the test takes a backend of its own, whose answers it scripts.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/auth/auth_service.dart';
import 'package:{{app_name}}/core/auth/firebase_auth_service.dart';

import '../firebase_auth_mocks.dart';
import 'service.dart';

/// The message with which Android answers for a project in which
/// Authentication was never set up, under a code of no error of Firebase
/// Authentication.
const _notFound = 'An internal error has occurred. [ CONFIGURATION_NOT_FOUND ]';

/// The message of an internal error of Firebase on iOS, which has nothing
/// of what the server answered.
const _internal = 'An internal error has occurred, print and inspect the '
    'error details for more information.';

/// The message with which iOS answers a sign-in, a sign-up and an anonymous
/// sign-in for a project in which Authentication was never set up, under
/// the code of an internal error: the description of the error, over
/// several lines, with addresses in memory and the answer of the server.
/// Its first line is as an iPhone simulator had it, and the others are
/// the answer of the server as such a description prints it.
const _notFoundOnIos = 'Error Domain=FIRAuthErrorDomain Code=17999 '
    '"$_internal" UserInfo={NSLocalizedDescription=$_internal, '
    'FIRAuthErrorUserInfoNameKey=ERROR_INTERNAL_ERROR, '
    'NSUnderlyingError=0x600000c5e910 {Error '
    'Domain=FIRAuthInternalErrorDomain Code=3 "(null)" '
    'UserInfo={NSUnderlyingError=0x600000c2ff90 {Error '
    'Domain=com.google.HTTPStatus Code=400 "(null)" '
    'UserInfo={data={length = 220, bytes = 0x7b0a2020 22657272 6f72223a '
    '207b0a20 ... 5d0a2020 7d0a7d0a }, '
    'data_content_type=application/json; charset=UTF-8}}, '
    'FIRAuthErrorUserInfoDeserializedResponseKey={\n'
    '    code = 400;\n'
    '    errors =     (\n'
    '                {\n'
    '            domain = global;\n'
    '            message = "CONFIGURATION_NOT_FOUND";\n'
    '            reason = invalid;\n'
    '        }\n'
    '    );\n'
    '    message = "CONFIGURATION_NOT_FOUND";\n'
    '}}}}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockFirebaseAuth firebase;
  late AuthService service;

  /// The calls of the service by the method of Firebase Authentication that
  /// each makes.
  late Map<String, Future<void> Function()> calls;

  setUpAll(() async {
    firebase = mockFirebaseAuth();
    await initializeFirebase();
    service = createFirebaseAuthService();
    final email = addressOf('failures');
    calls = {
      'signInWithEmailAndPassword': () =>
          service.signIn(email: email, password: password),
      'createUserWithEmailAndPassword': () =>
          service.signUp(email: email, password: password),
      'signInAnonymously': service.signInAnonymously,
      'sendPasswordResetEmail': () => service.sendPasswordReset(email),
      'linkWithCredential': () =>
          service.linkPassword(email: email, password: password),
      'delete': service.deleteAccount,
    };
  });

  /// How the call of [method] ends when Firebase answers it with [code] and
  /// [message], as a platform sends them.
  Future<String> outcome(String method, String code, [String? message]) async {
    firebase.failNext(method, code: code, message: message);
    return outcomeOf(await errorOf(calls[method]!));
  }

  /// How the call of [method] ends for each of [codes].
  Future<Map<String, String>> outcomes(
    String method,
    Iterable<String> codes,
  ) async =>
      {for (final code in codes) code: await outcome(method, code)};

  test(
      'the service gives each code of Firebase its reason, in the form of '
      'Android and in the form of iOS', () async {
    await service.signOut();
    await service.signInAnonymously();
    final before = userOf(service.currentUser);
    const reasons = {
      'signInWithEmailAndPassword': {
        'ERROR_INVALID_CREDENTIAL': AuthFailureReason.invalidCredentials,
        'invalid-credential': AuthFailureReason.invalidCredentials,
        'ERROR_WRONG_PASSWORD': AuthFailureReason.invalidCredentials,
        'wrong-password': AuthFailureReason.invalidCredentials,
        'ERROR_USER_NOT_FOUND': AuthFailureReason.invalidCredentials,
        'user-not-found': AuthFailureReason.invalidCredentials,
        'ERROR_INVALID_EMAIL': AuthFailureReason.invalidEmail,
        'invalid-email': AuthFailureReason.invalidEmail,
        'ERROR_MISSING_EMAIL': AuthFailureReason.invalidEmail,
        'missing-email': AuthFailureReason.invalidEmail,
        'ERROR_USER_DISABLED': AuthFailureReason.userDisabled,
        'user-disabled': AuthFailureReason.userDisabled,
        'ERROR_TOO_MANY_REQUESTS': AuthFailureReason.tooManyAttempts,
        'too-many-requests': AuthFailureReason.tooManyAttempts,
        'ERROR_NETWORK_REQUEST_FAILED': AuthFailureReason.network,
        'network-request-failed': AuthFailureReason.network,
      },
      'createUserWithEmailAndPassword': {
        'ERROR_EMAIL_ALREADY_IN_USE': AuthFailureReason.emailInUse,
        'email-already-in-use': AuthFailureReason.emailInUse,
        'ERROR_WEAK_PASSWORD': AuthFailureReason.weakPassword,
        'weak-password': AuthFailureReason.weakPassword,
        'ERROR_PASSWORD_DOES_NOT_MEET_REQUIREMENTS':
            AuthFailureReason.weakPassword,
        'password-does-not-meet-requirements': AuthFailureReason.weakPassword,
        'ERROR_INVALID_EMAIL': AuthFailureReason.invalidEmail,
        'network-request-failed': AuthFailureReason.network,
      },
      'linkWithCredential': {
        'ERROR_EMAIL_ALREADY_IN_USE': AuthFailureReason.emailInUse,
        'ERROR_CREDENTIAL_ALREADY_IN_USE': AuthFailureReason.emailInUse,
        'credential-already-in-use': AuthFailureReason.emailInUse,
        'ERROR_WEAK_PASSWORD': AuthFailureReason.weakPassword,
        'ERROR_REQUIRES_RECENT_LOGIN': AuthFailureReason.recentSignInRequired,
        'requires-recent-login': AuthFailureReason.recentSignInRequired,
      },
      'delete': {
        'ERROR_REQUIRES_RECENT_LOGIN': AuthFailureReason.recentSignInRequired,
        'requires-recent-login': AuthFailureReason.recentSignInRequired,
        'network-request-failed': AuthFailureReason.network,
      },
      'signInAnonymously': {
        'network-request-failed': AuthFailureReason.network,
        'too-many-requests': AuthFailureReason.tooManyAttempts,
      },
      'sendPasswordResetEmail': {
        'ERROR_INVALID_EMAIL': AuthFailureReason.invalidEmail,
        'missing-email': AuthFailureReason.invalidEmail,
        'too-many-requests': AuthFailureReason.tooManyAttempts,
        'network-request-failed': AuthFailureReason.network,
      },
    };

    final found = {
      for (final MapEntry(key: method, value: codes) in reasons.entries)
        method: await outcomes(method, codes.keys),
    };
    // Android sends this one in the message of an unknown error.
    final inMessage = await outcome(
      'signInWithEmailAndPassword',
      'UNKNOWN',
      'An internal error has occurred. [ INVALID_LOGIN_CREDENTIALS ]',
    );

    expect(
      found,
      {
        for (final MapEntry(key: method, value: codes) in reasons.entries)
          method: {
            for (final MapEntry(key: code, value: reason) in codes.entries)
              code: reason.name,
          },
      },
      reason: 'A call that Firebase answers with one of its codes fails '
          'with the reason of the auth role for that code, and with no '
          'hint: a wrong password and an address without an account are '
          'both invalidCredentials.',
    );
    expect(
      inMessage,
      AuthFailureReason.invalidCredentials.name,
      reason: 'A project that protects its email addresses from '
          'enumeration answers a wrong password, on Android, with an '
          'unknown error whose message has INVALID_LOGIN_CREDENTIALS.',
    );
    expect(
      userOf(service.currentUser),
      before,
      reason: 'A call that failed leaves the user who is signed in.',
    );
  });

  test(
      'a way to sign in that is not enabled in the Firebase project is '
      'notConfigured, with a hint that has the link to the project', () async {
    await service.signOut();
    final project = Firebase.app().options.projectId;
    final link = 'https://console.firebase.google.com/project/$project/'
        'authentication/providers';

    final found = {
      'Email/Password, on Android': await outcome(
        'signInWithEmailAndPassword',
        'ERROR_OPERATION_NOT_ALLOWED',
        'The given sign-in provider is disabled for this Firebase project.',
      ),
      'Email/Password, on iOS': await outcome(
        'createUserWithEmailAndPassword',
        'operation-not-allowed',
      ),
      'Anonymous, on Android': await outcome(
        'signInAnonymously',
        'ERROR_ADMIN_RESTRICTED_OPERATION',
        'This operation is restricted to administrators only.',
      ),
      'Anonymous, on iOS': await outcome(
        'signInAnonymously',
        'admin-restricted-operation',
      ),
      'no Authentication in the project, on Android': await outcome(
        'createUserWithEmailAndPassword',
        'UNKNOWN',
        _notFound,
      ),
      'no Authentication in the project, on iOS': await outcome(
        'signInWithEmailAndPassword',
        'internal-error',
        _notFoundOnIos,
      ),
    };

    String hint(String answered) =>
        'notConfigured (Sign-in is not enabled in the Firebase project '
        '$project (Firebase answered $answered). To fix it, enable '
        'Email/Password, and Anonymous for an app that signs in anonymous '
        'users, under Authentication > Sign-in method: $link)';
    expect(
      found,
      {
        'Email/Password, on Android': hint('operation-not-allowed'),
        'Email/Password, on iOS': hint('operation-not-allowed'),
        'Anonymous, on Android': hint('admin-restricted-operation'),
        'Anonymous, on iOS': hint('admin-restricted-operation'),
        'no Authentication in the project, on Android':
            hint('unknown, CONFIGURATION_NOT_FOUND'),
        'no Authentication in the project, on iOS':
            hint('internal-error, CONFIGURATION_NOT_FOUND'),
      },
      reason: 'When Firebase answers that a way to sign in is not allowed, '
          'or that it found no configuration, which it tells only in the '
          'message of an unknown error on Android and of an internal error '
          'on iOS, the call fails with notConfigured. Its hint for the '
          'developer names the project, the code of Firebase and what the '
          'service found in the message, and has the link to the sign-in '
          'methods of the project. It has none of the message of iOS, the '
          'description of an error over many lines.',
    );
  });

  test(
      'an internal error of Firebase is notConfigured on iOS and macOS, '
      'where a project without Authentication answers so, and unknown on '
      'Android', () async {
    await service.signOut();
    final found = <TargetPlatform, String>{};
    for (final platform in const [
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.android,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      try {
        found[platform] = await outcome(
          'signInWithEmailAndPassword',
          // As iOS sends it, and as the plugin makes it of the code of
          // Android.
          platform == TargetPlatform.android
              ? 'ERROR_INTERNAL_ERROR'
              : 'internal-error',
          _internal,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }

    final hedged = allOf(
      startsWith(
        'notConfigured (Firebase reported an internal error '
        '(internal-error: $_internal), which is also what it answers on iOS '
        'and macOS when sign-in is not enabled in the Firebase project ',
      ),
      contains('If that is the cause, enable Email/Password'),
      endsWith('/authentication/providers)'),
    );
    expect(
      found,
      {
        TargetPlatform.iOS: hedged,
        TargetPlatform.macOS: hedged,
        TargetPlatform.android: 'unknown (internal-error: $_internal)',
      },
      reason: 'On iOS and macOS, Firebase answers for a project in which '
          'Authentication was never set up with an internal error, which '
          'nothing tells from another one: the service takes it for '
          'notConfigured there, and its hint says that it may be another '
          'error. On Android, where Firebase names that case in its '
          'message, an internal error is unknown.',
    );
  });

  test(
      'a code that the service does not know is unknown, with the code and '
      'the whole message of Firebase on one line', () async {
    await service.signOut();

    final found = [
      await outcome(
        'signInWithEmailAndPassword',
        'ERROR_APP_NOT_AUTHORIZED',
        'This app is not authorized to use Firebase Authentication.',
      ),
      // A message over several lines, as iOS has some.
      await outcome(
        'signInWithEmailAndPassword',
        'keychain-error',
        'Error Domain=FIRAuthErrorDomain Code=17995 UserInfo={\n'
            '    NSLocalizedFailureReason = "SecItemAdd (-34018)";\n'
            '}',
      ),
      await outcome('signInWithEmailAndPassword', 'ERROR_QUOTA_EXCEEDED'),
    ];

    expect(
      found,
      [
        'unknown (app-not-authorized: This app is not authorized to use '
            'Firebase Authentication.)',
        'unknown (keychain-error: Error Domain=FIRAuthErrorDomain Code=17995 '
            'UserInfo={ NSLocalizedFailureReason = "SecItemAdd (-34018)"; })',
        'unknown (quota-exceeded)',
      ],
      reason: 'A call that Firebase answers with a code that has no reason '
          'of the auth role fails with unknown. Its hint for the developer '
          'has the code and the whole message, on one line, and the code '
          'alone when Firebase gives no message.',
    );
  });

  test(
      'an empty address or password fails before Firebase is asked, with '
      'the same reason on every platform', () async {
    await service.signOut();
    await service.signInAnonymously();
    final before = userOf(service.currentUser);
    final email = addressOf('empty');
    firebase.calls.clear();

    final found = {
      'signIn without an address': outcomeOf(
        await errorOf(() => service.signIn(email: '', password: password)),
      ),
      'signIn without a password': outcomeOf(
        await errorOf(() => service.signIn(email: email, password: '')),
      ),
      'signUp without an address': outcomeOf(
        await errorOf(() => service.signUp(email: '', password: password)),
      ),
      'signUp without a password': outcomeOf(
        await errorOf(() => service.signUp(email: email, password: '')),
      ),
      'linkPassword without an address': outcomeOf(
        await errorOf(
          () => service.linkPassword(email: '', password: password),
        ),
      ),
      'linkPassword without a password': outcomeOf(
        await errorOf(() => service.linkPassword(email: email, password: '')),
      ),
      'sendPasswordReset without an address': outcomeOf(
        await errorOf(() => service.sendPasswordReset('')),
      ),
    };

    expect(
      found,
      {
        'signIn without an address': AuthFailureReason.invalidEmail.name,
        'signIn without a password': AuthFailureReason.invalidCredentials.name,
        'signUp without an address': AuthFailureReason.invalidEmail.name,
        'signUp without a password': AuthFailureReason.weakPassword.name,
        'linkPassword without an address': AuthFailureReason.invalidEmail.name,
        'linkPassword without a password': AuthFailureReason.weakPassword.name,
        'sendPasswordReset without an address':
            AuthFailureReason.invalidEmail.name,
      },
      reason: 'Android refuses an empty text with a code that has no '
          'reason, and iOS answers an empty password as a wrong one. So '
          'the service decides itself: an empty address is invalidEmail, '
          'and an empty password is invalidCredentials for a sign-in and '
          'weakPassword where it would become the password of an account.',
    );
    expect(
      [firebase.calls, userOf(service.currentUser)],
      [isEmpty, before],
      reason: 'The service asks Firebase for nothing, not for the language '
          'of a message either, and whoever is signed in stays.',
    );
  });

  test(
      'a password reset completes when Firebase tells that the address has '
      'no account', () async {
    await service.signOut();

    final found = await outcomes(
      'sendPasswordResetEmail',
      const ['ERROR_USER_NOT_FOUND', 'user-not-found'],
    );

    expect(
      found.values,
      everyElement('completed'),
      reason: 'A project without the protection against the enumeration of '
          'email addresses answers a password reset for an address without '
          'an account with user-not-found. The service completes all the '
          'same, so that nobody learns from the app which addresses have an '
          'account.',
    );
  });

  test(
      'a call for a user whose session has ended on the server signs that '
      'user out and fails with recentSignInRequired', () async {
    // What each call for the user who is signed in ends with for each code
    // of a session that has ended, the user of the service then, the calls
    // that reached Firebase, and what a listener of the service heard.
    final found = <String, List<Object?>>{};
    final heard = <String>[];
    final subscription = service.userChanges.listen(
      (user) => heard.add(userOf(user)),
    );
    addTearDown(subscription.cancel);

    for (final method in const ['delete', 'linkWithCredential']) {
      for (final code in const [
        'ERROR_USER_TOKEN_EXPIRED',
        'user-token-expired',
        'ERROR_INVALID_USER_TOKEN',
        'ERROR_USER_NOT_FOUND',
        'user-not-found',
        // The plugin answers so itself when the platform has no user.
        'NO_CURRENT_USER',
        'no-current-user',
      ]) {
        await service.signOut();
        await service.signInAnonymously();
        await pumpEventQueue();
        firebase.calls.clear();
        heard.clear();
        final ended = await outcome(method, code);
        await pumpEventQueue();
        found['$method answered with $code'] = [
          ended,
          userOf(service.currentUser),
          [for (final call in firebase.calls) call.first],
          heard.toSet(),
        ];
      }
    }

    expect(
      found.values,
      everyElement([
        AuthFailureReason.recentSignInRequired.name,
        'nobody',
        anyOf(
          equals(['delete', 'signOut']),
          equals(['linkWithCredential', 'signOut']),
        ),
        {'nobody'},
      ]),
      reason: 'When Firebase answers a call for the user who is signed in '
          'that the session of that user has ended, as when the account '
          'was deleted on another device, the service signs the user out '
          'on this device, tells its listeners, and fails with '
          'recentSignInRequired: $found',
    );
    expect(found, hasLength(14));
  });

  test(
      'a call for the user who is signed in fails without a call of '
      'Firebase when nobody is signed in', () async {
    await service.signOut();
    firebase.calls.clear();

    final found = [
      outcomeOf(await errorOf(calls['delete']!)),
      outcomeOf(await errorOf(calls['linkWithCredential']!)),
    ];

    expect(
      [found, firebase.calls],
      [
        [
          AuthFailureReason.recentSignInRequired.name,
          AuthFailureReason.recentSignInRequired.name,
        ],
        isEmpty,
      ],
      reason: 'Without a user, the service fails a call for the user who '
          'is signed in itself, with recentSignInRequired.',
    );
  });
}
