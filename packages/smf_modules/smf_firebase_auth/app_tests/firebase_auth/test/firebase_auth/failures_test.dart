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
// the user. A call for a user whose session has ended on the server signs
// that user out. And a read of the token of the user gets the reason of the
// code of Firebase and leaves the user, but for such a session.
//
// A call with a credential of Google or Apple gets the reason of its own
// call: a link that Firebase refuses because the identity, or its email
// address, belongs to another user is credentialInUse or
// accountExistsWithOtherMethod, where a link of a password is emailInUse; a
// sign-in again for a deletion with a credential of another user, or of an
// identity without a user, is invalidCredentials and leaves the user signed
// in, but for an account that the server deleted, which is signed out; and
// the hint of a way to sign in that is not enabled names it. A revocation
// of the tokens of Apple that Firebase refuses is notConfigured, with a hint
// that names what the Apple sign-in method of the project needs, but for an
// answer that is no matter of the setup, and deletes nothing.
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

/// The message with which iOS answers an anonymous sign-in for a project
/// in which Authentication was never set up, under the code of an internal
/// error: the description of the error, as an iPhone simulator had it, with
/// the addresses in memory replaced by one value. A sign-in and a sign-up
/// get such a message too. What the server answered is under one of the
/// keys of the description, which come in another order from call to call,
/// so the service only looks for `CONFIGURATION_NOT_FOUND` in the message.
const _notFoundOnIos = 'Error Domain=FIRAuthErrorDomain Code=17999 '
    '"$_internal" UserInfo={NSUnderlyingError=0x600000c00000 {Error '
    'Domain=FIRAuthInternalErrorDomain Code=3 "(null)" '
    'UserInfo={FIRAuthErrorUserInfoDeserializedResponseKey={\n'
    '    code = 400;\n'
    '    errors =     (\n'
    '                {\n'
    '            domain = global;\n'
    '            message = "CONFIGURATION_NOT_FOUND";\n'
    '            reason = invalid;\n'
    '        }\n'
    '    );\n'
    '    message = "CONFIGURATION_NOT_FOUND";\n'
    '}, NSUnderlyingError=0x600000c00000 {Error Domain=com.google.HTTPStatus '
    'Code=400 "(null)" UserInfo={data={length = 220, bytes = 0x7b0a2020 '
    '22657272 6f72223a 207b0a20 ... 5d0a2020 7d0a7d0a }, '
    'data_content_type=application/json; charset=UTF-8}}}}, '
    'NSLocalizedDescription=$_internal, '
    'FIRAuthErrorUserInfoNameKey=ERROR_INTERNAL_ERROR}';

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

  /// How the call of [method], or [call], ends when Firebase answers it
  /// with [code] and [message], as a platform sends them.
  Future<String> outcome(
    String method,
    String code, [
    String? message,
    Future<void> Function()? call,
  ]) async {
    firebase.failNext(method, code: code, message: message);
    return outcomeOf(await errorOf(call ?? calls[method]!));
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
      'a call with a credential gets the reason of its own call for each code '
      'of Firebase, in the form of Android and in the form of iOS, and leaves '
      'the user', () async {
    // Each call with a credential, by the method of Firebase that it makes,
    // with what makes the user whom it is for, and the call itself, with a
    // new credential each time.
    final ofCalls =
        <String, (Future<void> Function(), Future<void> Function())>{
      'signInWithCredential': (
        service.signOut,
        () => service.signInWith(credentialOf(google, 'failures-sign-in')),
      ),
      'linkWithCredential': (
        () async {
          await service.signOut();
          await service.signInAnonymously();
        },
        () => service.linkWith(credentialOf(apple, 'failures-link')),
      ),
      'reauthenticateWithCredential': (
        () async {
          await service.signOut();
          await service.signInWith(credentialOf(apple, 'failures-deleted'));
        },
        () => service.deleteAccount(
              fresh: credentialOf(apple, 'failures-deleted'),
            ),
      ),
    };
    const reasons = {
      'signInWithCredential': {
        'ERROR_ACCOUNT_EXISTS_WITH_DIFFERENT_CREDENTIAL':
            AuthFailureReason.accountExistsWithOtherMethod,
        'account-exists-with-different-credential':
            AuthFailureReason.accountExistsWithOtherMethod,
        'ERROR_INVALID_CREDENTIAL': AuthFailureReason.invalidCredentials,
        'invalid-credential': AuthFailureReason.invalidCredentials,
        'ERROR_MISSING_OR_INVALID_NONCE': AuthFailureReason.invalidCredentials,
        'missing-or-invalid-nonce': AuthFailureReason.invalidCredentials,
        'ERROR_USER_DISABLED': AuthFailureReason.userDisabled,
        'network-request-failed': AuthFailureReason.network,
      },
      // A link of a password answers credential-already-in-use and
      // email-already-in-use with emailInUse (see above).
      'linkWithCredential': {
        'ERROR_CREDENTIAL_ALREADY_IN_USE': AuthFailureReason.credentialInUse,
        'credential-already-in-use': AuthFailureReason.credentialInUse,
        'ERROR_EMAIL_ALREADY_IN_USE':
            AuthFailureReason.accountExistsWithOtherMethod,
        'email-already-in-use': AuthFailureReason.accountExistsWithOtherMethod,
        'ERROR_ACCOUNT_EXISTS_WITH_DIFFERENT_CREDENTIAL':
            AuthFailureReason.accountExistsWithOtherMethod,
        'ERROR_INVALID_CREDENTIAL': AuthFailureReason.invalidCredentials,
        'ERROR_MISSING_OR_INVALID_NONCE': AuthFailureReason.invalidCredentials,
      },
      // A credential of another user, and of an identity without a user,
      // which Firebase answers with user-not-found, as for a user whose
      // session has ended: the user still exists on the server.
      'reauthenticateWithCredential': {
        'ERROR_USER_MISMATCH': AuthFailureReason.invalidCredentials,
        'user-mismatch': AuthFailureReason.invalidCredentials,
        'ERROR_USER_NOT_FOUND': AuthFailureReason.invalidCredentials,
        'user-not-found': AuthFailureReason.invalidCredentials,
        'ERROR_INVALID_CREDENTIAL': AuthFailureReason.invalidCredentials,
        'ERROR_MISSING_OR_INVALID_NONCE': AuthFailureReason.invalidCredentials,
        'network-request-failed': AuthFailureReason.network,
      },
    };

    final found = <String, Map<String, String>>{};
    final moved = <String>[];
    for (final MapEntry(key: method, value: codes) in reasons.entries) {
      final (prepare, call) = ofCalls[method]!;
      found[method] = {};
      for (final code in codes.keys) {
        await prepare();
        final before = userOf(service.currentUser);
        firebase.failNext(method, code: code);
        found[method]![code] = outcomeOf(await errorOf(call));
        if (userOf(service.currentUser) != before) {
          moved.add('$method answered with $code');
        }
      }
    }

    expect(
      found,
      {
        for (final MapEntry(key: method, value: codes) in reasons.entries)
          method: {
            for (final MapEntry(key: code, value: reason) in codes.entries)
              code: reason.name,
          },
      },
      reason: 'A call with a credential that Firebase answers with one of '
          'its codes fails with the reason of the auth role for that code '
          'and that call: a link that Firebase refuses for an identity of '
          'another user is credentialInUse, and for an email address of '
          'another account accountExistsWithOtherMethod. A sign-in again '
          'for a deletion with a credential of another user, or of an '
          'identity without a user, is invalidCredentials, and a token whose '
          'nonce Firebase took before is invalidCredentials too.',
    );
    expect(
      moved,
      isEmpty,
      reason: 'A call with a credential that failed leaves the user who is '
          'signed in, also a sign-in again that Firebase answers with '
          'user-not-found, which is no sign that the session of the user has '
          'ended.',
    );
  });

  test(
      'a link of a way to sign in that the user has already is unknown, with '
      'the code and the message of Firebase', () async {
    await service.signOut();
    await service.signInAnonymously();

    final found = await outcome(
      'linkWithCredential',
      'ERROR_PROVIDER_ALREADY_LINKED',
      'User has already been linked to the given provider.',
      () => service.linkWith(credentialOf(google, 'failures-linked')),
    );

    expect(
      found,
      'unknown (provider-already-linked: User has already been linked to the '
      'given provider.)',
      reason: 'The session links a way to sign in only to an anonymous user, '
          'so Firebase answers no link of the app so. The service leaves it '
          'unknown, with what Firebase answered as the hint.',
    );
  });

  test(
      'a call with a credential of a way to sign in that is not enabled is '
      'notConfigured, with a hint that names the way to sign in and the link '
      'to the project', () async {
    await service.signOut();
    final project = Firebase.app().options.projectId;
    final link = 'https://console.firebase.google.com/project/$project/'
        'authentication/providers';

    final found = {
      'Google, in the form of Android': await outcome(
        'signInWithCredential',
        'ERROR_OPERATION_NOT_ALLOWED',
        'The identity provider configuration is disabled.',
        () => service.signInWith(credentialOf(google, 'failures-disabled')),
      ),
      'Apple, in the form of iOS': await outcome(
        'signInWithCredential',
        'operation-not-allowed',
        null,
        () => service.signInWith(credentialOf(apple, 'failures-disabled')),
      ),
    };

    // The script of the app enables Google, and only the Firebase console
    // Apple.
    const script = 'run `dart tool/enable_firebase_sign_in.dart` in the '
        'directory of the app, or ';
    String hint(String method) =>
        'notConfigured (Sign-in with $method is not enabled in the Firebase '
        'project $project (Firebase answered operation-not-allowed). To fix '
        "it, ${method == 'Google' ? script : ''}enable $method in the "
        'Firebase console under Authentication > Sign-in method: $link)';
    expect(
      found,
      {
        'Google, in the form of Android': hint('Google'),
        'Apple, in the form of iOS': hint('Apple'),
      },
      reason: 'When Firebase answers that the sign-in method of a credential '
          'is not enabled, the call fails with notConfigured, and its hint '
          'names that sign-in method and the page of the project where it '
          'is enabled.',
    );
  });

  test(
      'a deletion with a fresh credential of the user of an account that the '
      'server deleted signs the user out and fails with recentSignInRequired',
      () async {
    await service.signOut();
    await service.signInWith(credentialOf(apple, 'failures-gone'));
    // As when the user deleted the account on another device.
    firebase
      ..deleteUserOnServer()
      ..calls.clear();

    final found = outcomeOf(
      await errorOf(
        () => service.deleteAccount(
          fresh: credentialOf(apple, 'failures-gone'),
        ),
      ),
    );

    expect(
      [
        found,
        userOf(service.currentUser),
        [for (final call in firebase.calls) call.first],
      ],
      [
        AuthFailureReason.recentSignInRequired.name,
        'nobody',
        ['reauthenticateWithCredential', 'reload', 'signOut'],
      ],
      reason: 'Firebase answers the sign-in again with the credential of the '
          'user of an account that the server deleted with user-not-found, '
          'as for a credential of an identity without a user. The reload of '
          'the user tells the two apart: for a deleted user it fails with a '
          'code of a session that has ended, and the service signs the user '
          'out and fails with recentSignInRequired, as for any call for such '
          'a user.',
    );
  });

  test(
      'a revocation of the tokens of Apple that Firebase refuses is '
      'notConfigured, with a hint that names what the Apple sign-in method '
      'of the project needs, one that does not reach Firebase is network, '
      'and neither deletes anything', () async {
    final project = Firebase.app().options.projectId;
    final found = <String, List<Object?>>{};
    for (final (code, message) in const [
      ('invalid-credential', 'Code flow is not enabled for Apple.'),
      ('invalid-credential', 'Error getting access token from Apple.'),
      ('internal-error', _internal),
      ('network-request-failed', 'A network error has occurred.'),
      ('too-many-requests', 'Too many requests.'),
      ('user-disabled', 'The user account has been disabled.'),
    ]) {
      await service.signOut();
      await service.signInWith(credentialOf(apple, 'failures-revoked'));
      final before = userOf(service.currentUser);
      firebase.calls.clear();
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        found['$code: $message'] = [
          await outcome(
            'revokeTokenWithAuthorizationCode',
            code,
            message,
            () => service.deleteAccount(
              fresh: credentialOf(apple, 'failures-revoked'),
            ),
          ),
          userOf(service.currentUser) == before,
          [for (final call in firebase.calls) call.first],
        ];
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }

    String notRevoked(String answer) =>
        'notConfigured (Firebase did not revoke the tokens that Apple gave '
        'the app ($answer), so the account was not deleted. The revocation '
        'needs the Services ID and the OAuth code flow configuration, with '
        'the Apple team ID, the Key ID and the private key, of the Apple '
        'sign-in method of the Firebase project $project, in the Firebase '
        'console under Authentication > Sign-in method: '
        'https://console.firebase.google.com/project/$project/authentication/'
        'providers. When they are set, the authorization code of Apple was '
        'older than five minutes or used before, and the next deletion asks '
        'Apple for a new one.)';
    const calls = [
      'reauthenticateWithCredential',
      'revokeTokenWithAuthorizationCode',
    ];
    expect(
      found,
      {
        for (final message in [
          'Code flow is not enabled for Apple.',
          'Error getting access token from Apple.',
        ])
          'invalid-credential: $message': [
            notRevoked('invalid-credential: $message'),
            true,
            calls,
          ],
        'internal-error: $_internal': [
          notRevoked('internal-error: $_internal'),
          true,
          calls,
        ],
        'network-request-failed: A network error has occurred.': [
          AuthFailureReason.network.name,
          true,
          calls,
        ],
        'too-many-requests: Too many requests.': [
          AuthFailureReason.tooManyAttempts.name,
          true,
          calls,
        ],
        'user-disabled: The user account has been disabled.': [
          AuthFailureReason.userDisabled.name,
          true,
          calls,
        ],
      },
      reason: 'Firebase answers a revocation without the Services ID and the '
          'OAuth code flow configuration of the Apple sign-in method, or '
          'with a wrong one, with invalid-credential: the deletion fails '
          'with notConfigured, whose hint has what Firebase answered and '
          'what the project needs, and so does an internal error, which on '
          'iOS says no more. An answer that is no matter of the setup, a '
          'request that did not reach Firebase, too many attempts or a '
          'disabled account, gets its own reason. Either way the account is '
          'not deleted, and the user stays signed in.',
    );
  });

  test(
      'a way to sign in that is not enabled in the Firebase project is '
      'notConfigured, with a hint that has the command of the script which '
      'enables it and the link to the project', () async {
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
        '$project (Firebase answered $answered). To fix it, run `dart '
        'tool/enable_firebase_sign_in.dart` in the directory of the app, or '
        'enable Email/Password, and Anonymous for an app that signs in '
        'anonymous users, in the Firebase console under Authentication > '
        'Sign-in method: $link)';
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
          'service found in the message, and has the command of the script '
          'of the app that enables the methods and the link to the sign-in '
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
      contains(
        'If that is the cause, run `dart tool/enable_firebase_sign_in.dart` '
        'in the directory of the app, or enable Email/Password',
      ),
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
      'a read of the token that Firebase refuses for a session that has ended '
      'signs the user out and fails with recentSignInRequired', () async {
    // What a read that Firebase answers with each code ends with, with a
    // forced read and with one that the device could answer, the user of the
    // service then, the calls that reached Firebase, and what a listener of
    // the service heard.
    final found = <String, List<Object?>>{};
    final heard = <String>[];
    final subscription = service.userChanges.listen(
      (user) => heard.add(userOf(user)),
    );
    addTearDown(subscription.cancel);
    for (final forceRefresh in const [true, false]) {
      for (final code in const [
        'ERROR_USER_TOKEN_EXPIRED',
        'user-token-expired',
        'ERROR_INVALID_USER_TOKEN',
        'ERROR_USER_NOT_FOUND',
        'user-not-found',
        'NO_CURRENT_USER',
        'no-current-user',
      ]) {
        await service.signOut();
        await service.signInAnonymously();
        await pumpEventQueue();
        firebase
          ..calls.clear()
          ..failNext('getIdToken', code: code);
        heard.clear();
        final ended = await errorOf(
          () => service.userToken(forceRefresh: forceRefresh),
        );
        await pumpEventQueue();
        found['$code, forced $forceRefresh'] = [
          outcomeOf(ended),
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
        ['getIdToken', 'signOut'],
        {'nobody'},
      ]),
      reason: 'When Firebase answers a read of the token that the session of '
          'the user has ended, the service signs the user out on this device, '
          'tells its listeners, and fails with recentSignInRequired: $found',
    );
    expect(found, hasLength(14));
  });

  test(
      'a read of the token of a user whom the server deleted signs that user '
      'out when it forces a refresh', () async {
    await service.signOut();
    await service.signUp(email: addressOf('token-gone'), password: password);
    firebase.deleteUserOnServer();

    final read = await service.userToken();
    final forced = await errorOf(() => service.userToken(forceRefresh: true));

    expect(
      read,
      isNotEmpty,
      reason: 'The Firebase SDK answers from the device while the token is '
          'valid, whatever happened on the server.',
    );
    expect(
      (outcomeOf(forced), userOf(service.currentUser)),
      (AuthFailureReason.recentSignInRequired.name, 'nobody'),
      reason: 'A forced read asks the server, whose answer ends the session '
          'of the user on this device.',
    );
  });

  test(
      'a read of the token that Firebase refuses gets the reason of the code, '
      'and leaves the user', () async {
    await service.signOut();
    await service.signUp(email: addressOf('token-refused'), password: password);
    final before = userOf(service.currentUser);
    final heard = <String>[];
    final subscription = service.userChanges.listen(
      (user) => heard.add(userOf(user)),
    );
    addTearDown(subscription.cancel);
    await pumpEventQueue();
    heard.clear();
    final found = <String, String>{};

    for (final code in const [
      'ERROR_NETWORK_REQUEST_FAILED',
      'network-request-failed',
      'ERROR_USER_DISABLED',
      'user-disabled',
      'ERROR_TOO_MANY_REQUESTS',
      'too-many-requests',
    ]) {
      firebase.failNext('getIdToken', code: code);
      found[code] = outcomeOf(
        await errorOf(() => service.userToken(forceRefresh: true)),
      );
    }
    firebase.failNext(
      'getIdToken',
      code: 'some-other-code',
      message: 'Firebase says so.',
    );
    final other = outcomeOf(await errorOf(service.userToken));
    await pumpEventQueue();

    expect(
      found,
      {
        'ERROR_NETWORK_REQUEST_FAILED': AuthFailureReason.network.name,
        'network-request-failed': AuthFailureReason.network.name,
        'ERROR_USER_DISABLED': AuthFailureReason.userDisabled.name,
        'user-disabled': AuthFailureReason.userDisabled.name,
        'ERROR_TOO_MANY_REQUESTS': AuthFailureReason.tooManyAttempts.name,
        'too-many-requests': AuthFailureReason.tooManyAttempts.name,
      },
      reason: 'A read that Firebase refuses gets the reason of the code, as '
          'any other call of the service.',
    );
    expect(
      other,
      '${AuthFailureReason.unknown.name} (some-other-code: Firebase says so.)',
      reason: 'A code that the service does not know is unknown, with what '
          'Firebase answered as the hint.',
    );
    expect(
      [userOf(service.currentUser), heard],
      [before, isEmpty],
      reason: 'A read that failed leaves the user, and tells nobody.',
    );
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
