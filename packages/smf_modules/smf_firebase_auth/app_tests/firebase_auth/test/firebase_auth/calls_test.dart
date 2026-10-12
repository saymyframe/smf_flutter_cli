// A test that continuous integration runs in the apps with the
// firebase_auth module, on the real Firebase packages, whose platform side
// is a backend in memory (firebase_auth_mocks.dart): what the sign-in
// service of the module, which createFirebaseAuthService() creates, sends
// to Firebase Authentication. Each call reaches Firebase with what it got.
// The deletion of a user signs out too, since the plugin keeps a deleted
// user as its current one until the platform tells it of the sign-out. A
// password reset asks for the message in the language that the app is in,
// and for none in an app without languages of its own. And the service
// tells of a sign-out that Firebase makes without a call of the app.
//
// It uses the service of the module and runs none of the start-up of the
// app but the start of Firebase (service.dart). The matrix sets up the
// mocks of the platform side of every module of the app before the tests,
// and the test takes a backend of its own, which records what reaches it.
// The matrix writes the languages of the app for it, from the localization
// role of the app (languages.dart).
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/auth/auth_service.dart';
import 'package:{{app_name}}/core/auth/firebase_auth_service.dart';

import '../firebase_auth_mocks.dart';
import 'languages.dart';
import 'service.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late MockFirebaseAuth firebase;
  late AuthService service;

  setUpAll(() async {
    firebase = mockFirebaseAuth();
    await initializeFirebase();
    service = createFirebaseAuthService();
  });

  setUp(() async {
    await service.signOut();
    firebase.calls.clear();
  });

  test('each call of the service reaches Firebase with what it got', () async {
    final email = addressOf('calls');
    final linked = addressOf('calls-linked');

    await service.signUp(email: email, password: password);
    await service.signOut();
    await service.signIn(email: email, password: password);
    await service.sendPasswordReset(email);
    await service.signOut();
    await service.signInAnonymously();
    await service.linkPassword(email: linked, password: password);

    expect(
      [
        // The language of a message has a test of its own below.
        for (final call in firebase.calls)
          if (call.first != 'setLanguageCode') call,
      ],
      [
        ['createUserWithEmailAndPassword', email, password],
        ['signOut'],
        ['signInWithEmailAndPassword', email, password],
        ['sendPasswordResetEmail', email, null],
        ['signOut'],
        ['signInAnonymously'],
        [
          'linkWithCredential',
          {
            'providerId': 'password',
            'signInMethod': 'password',
            'email': linked,
            'emailLink': null,
            'secret': password,
          },
        ],
      ],
      reason: 'The service signs up, in and out, asks for the message of a '
          'password reset and signs in anonymously with the calls of '
          'Firebase Authentication for them, and gives an anonymous user an '
          'account by linking the credential of the email address and the '
          'password to that user.',
    );
  });

  test(
      'the deletion of a user signs out on Firebase too, so that nobody is '
      'signed in when it is over', () async {
    await service.signUp(email: addressOf('deleted'), password: password);
    firebase.calls.clear();

    await service.deleteAccount();

    expect(
      firebase.calls,
      [
        ['delete'],
        ['signOut'],
      ],
      reason: 'The plugin keeps a user who was deleted as its current one '
          'until the platform tells it of the sign-out, which may come '
          'after the call is over. So the service signs out once Firebase '
          'deleted the user.',
    );
    expect(
      (userOf(service.currentUser), firebase.signedInUid),
      ('nobody', null),
      reason: 'When deleteAccount() completes, the service has nobody, and '
          'nobody is signed in on the platform side.',
    );
  });

  test(
      'a password reset asks Firebase for the message in the language that '
      'the app is in', () async {
    addTearDown(binding.platformDispatcher.clearLocalesTestValue);
    addTearDown(() => chooseLanguage(null));
    // The languages that the service asked for before each message, and
    // the message, by what the app was in.
    final asked = <String, List<Object?>>{};
    Future<void> reset(String name) async {
      firebase.calls.clear();
      await service.sendPasswordReset(addressOf('reset'));
      asked[name] = [
        for (final call in firebase.calls)
          call.first == 'setLanguageCode' ? call[1] : call.first,
      ];
    }

    for (final language in messageLanguages) {
      await chooseLanguage(language);
      await reset('the language $language, which the user chose');
    }
    await chooseLanguage(null);
    if (messageLanguages.isEmpty) {
      await reset('no language of its own');
    } else {
      binding.platformDispatcher.localesTestValue = [
        Locale(messageLanguages.last, 'ZZ'),
      ];
      await reset('the language that the device prefers');
      binding.platformDispatcher.localesTestValue = const [Locale('zz')];
      await reset('its first language, on a device that asks for another');
    }

    const message = 'sendPasswordResetEmail';
    expect(
      asked,
      {
        for (final language in messageLanguages)
          'the language $language, which the user chose': [language, message],
        if (messageLanguages.isEmpty)
          'no language of its own': [message]
        else ...{
          'the language that the device prefers': [
            messageLanguages.last,
            message,
          ],
          'its first language, on a device that asks for another': [
            messageLanguages.first,
            message,
          ],
        },
      },
      reason: 'In an app with languages of its own, the service sets the '
          'language of Firebase Authentication before it asks for the '
          'message: the language that the user chose for the app, or, '
          'while the app follows the device, the one that the device '
          'prefers among those of the app, and the first of them when it '
          'prefers none. An app without languages of its own sets none, '
          'and Firebase sends the message in the language of its template.',
    );
  });

  test(
      'the service tells of a sign-out that Firebase makes without a call '
      'of the app, and has nobody then', () async {
    final email = addressOf('signed-out-by-firebase');
    final heard = <String>[];
    final subscription = service.userChanges.listen(
      (user) => heard.add(userOf(user)),
    );
    addTearDown(subscription.cancel);
    await service.signUp(email: email, password: password);
    await pumpEventQueue();
    final signedUp = heard.toSet();
    final uid = service.currentUser?.uid;
    heard.clear();

    // As when the Firebase SDK finds that the session of the user has
    // ended on the server.
    firebase.signOutOnPlatform();
    await pumpEventQueue();

    expect(
      signedUp,
      {'the account $uid of $email'},
      reason: 'The service tells its listeners of the user of a sign-up.',
    );
    expect(
      [heard, userOf(service.currentUser)],
      [
        ['nobody'],
        'nobody',
      ],
      reason: 'The service follows the user of Firebase Authentication: '
          'when the Firebase SDK signs the user out on its own, the service '
          'has nobody, and tells its listeners so, once.',
    );
  });
}
