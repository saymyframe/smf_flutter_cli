// A test that continuous integration runs in the apps with the
// firebase_auth module, on the real Firebase packages, whose platform side
// is a backend in memory (firebase_auth_mocks.dart): what the sign-in
// service of the module, which createFirebaseAuthService() creates, sends
// to Firebase Authentication. Each call reaches Firebase with what it got:
// a credential of Google with its ID token, and one of Apple with its ID
// token, its raw nonce and the name of the user. The user lists the
// identity providers that the user signs in with. A sign-in after a link
// that Firebase refused takes the credential that Firebase gave with its
// answer, since the refused link has taken the token of the credential.
// The deletion of a user signs out too, since the plugin keeps a deleted
// user as its current one until the platform tells it of the sign-out. A
// deletion with a fresh credential signs the user in again first, and with
// one of Apple on iOS it revokes the tokens of Apple with the authorization
// code of that credential before it deletes the account, and deletes
// nothing when the revocation fails. A password reset asks for the message
// in the language that the app is in, and for none in an app without
// languages of its own. The service tells of a sign-out that Firebase makes
// without a call of the app. A credential of another identity provider
// reaches nothing of Firebase. And a read of the token of the user asks
// Firebase for a new token only when it forces a refresh, and tells nobody of
// a change.
//
// It uses the service of the module and runs none of the start-up of the
// app but the start of Firebase (service.dart). The matrix sets up the
// mocks of the platform side of every module of the app before the tests,
// and the test takes a backend of its own, which records what reaches it.
// The matrix writes the languages of the app for it, from the localization
// role of the app (languages.dart).
import 'dart:ui';

import 'package:flutter/foundation.dart';
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
      'a credential of Google reaches Firebase with its ID token, and one of '
      'Apple with its ID token, its raw nonce and the name of the user, and '
      'the user lists the identity providers that the user signs in with',
      () async {
    final ofGoogle = credentialOf(google, 'calls-google');
    final ofApple = credentialOf(apple, 'calls-apple');

    await service.signInWith(ofGoogle);
    final signedIn = (userOf(service.currentUser), service.currentUser?.uid);
    final issuersOfSignIn = issuersOf(service.currentUser);
    await service.signOut();
    await service.signInAnonymously();
    final guest = service.currentUser?.uid;
    await service.linkWith(ofApple);
    final linked = service.currentUser;

    /// A credential as the plugin sends it.
    Map<String, Object?> sent(
      String provider,
      IdTokenCredential credential, {
      String? rawNonce,
      String? givenName,
      String? familyName,
    }) =>
        {
          'providerId': provider,
          'signInMethod': provider,
          'idToken': credential.idToken,
          'accessToken': null,
          'secret': null,
          'rawNonce': rawNonce,
          'serverAuthCode': null,
          'familyName': familyName,
          'givenName': givenName,
          'middleName': null,
          'nickname': null,
          'namePrefix': null,
          'nameSuffix': null,
        };
    expect(
      [
        for (final call in firebase.calls)
          if (call.first != 'setLanguageCode') call,
      ],
      [
        ['signInWithCredential', sent('google.com', ofGoogle)],
        ['signOut'],
        ['signInAnonymously'],
        [
          'linkWithCredential',
          sent(
            'apple.com',
            ofApple,
            rawNonce: ofApple.rawNonce,
            givenName: 'Ada',
            familyName: 'Lovelace',
          ),
        ],
      ],
      reason: 'The service signs in and links with the credential of Google '
          'by its ID token, since GoogleAuthProvider takes no nonce and '
          'Firebase does not check the nonce of a token of Google, and with '
          'the credential of Apple by its ID token, the '
          'raw nonce that Firebase checks the token against, and the name '
          'of the user, which Apple gives only at the first sign-in.',
    );
    expect(
      [signedIn.$1, issuersOfSignIn],
      [
        'the account ${signedIn.$2}',
        [google],
      ],
      reason: 'signInWith() of a new identity of Google signs in to a new '
          'user of that identity, who lists Google.',
    );
    expect(
      [linked?.uid, linked?.isAnonymous, issuersOf(linked)],
      [
        guest,
        false,
        [apple],
      ],
      reason: 'linkWith() gives the anonymous user the identity of Apple: '
          'the user keeps the id, is no longer anonymous and lists Apple.',
    );
  });

  test(
      'a sign-in after a link that Firebase refused takes the credential that '
      'Firebase gave with its answer, since the link has taken the token',
      () async {
    final email = addressOf('calls-refused');
    await service.signInWith(credentialOf(apple, 'calls-refused'));
    final owner = service.currentUser?.uid;
    await service.signOut();
    await service.signUp(email: email, password: password);
    final account = service.currentUser?.uid;
    // For each refusal: what the link failed with, what the sign-in with
    // the identical credential after it ended with, the call of that
    // sign-in, and whether the plugin sent a credential by its number and
    // an ID token.
    final found = <String, List<Object?>>{};
    for (final (name, credential, of) in [
      (
        'an identity of another user',
        credentialOf(apple, 'calls-refused'),
        owner,
      ),
      (
        'an email address of another account',
        credentialOf(apple, 'calls-refused-email', email: email),
        account,
      ),
    ]) {
      await service.signOut();
      await service.signInAnonymously();
      firebase.calls.clear();
      final link = outcomeOf(await errorOf(() => service.linkWith(credential)));
      final signIn = await errorOf(() => service.signInWith(credential));
      final [method, ..., sent as Map<Object?, Object?>] = firebase.calls.last;
      found[name] = [
        link,
        switch (signIn) {
          null => 'signed in to ${service.currentUser?.uid == of}',
          _ => outcomeOf(signIn),
        },
        method,
        sent['token'] is int,
        sent.containsKey('idToken'),
      ];
    }

    expect(
      found,
      {
        'an identity of another user': [
          AuthFailureReason.credentialInUse.name,
          'signed in to true',
          'signInWithCredential',
          true,
          false,
        ],
        'an email address of another account': [
          AuthFailureReason.accountExistsWithOtherMethod.name,
          AuthFailureReason.accountExistsWithOtherMethod.name,
          'signInWithCredential',
          true,
          false,
        ],
      },
      reason: 'Firebase refuses a link of an identity of another user with '
          'credential-already-in-use, and one whose email address has an '
          'account of another user with email-already-in-use, and gives a '
          'credential of the identity with its answer. The refused link has '
          'taken the token, as Apple takes a token once, so signInWith() of '
          'the identical credential object signs in with the credential '
          'that Firebase gave, which the plugin sends by its number, and '
          'not with the token again, which Firebase would refuse.',
    );
  });

  test(
      'a sign-in with another credential after a refused link sends its own '
      'token, and the identical credential still gets the credential that '
      'Firebase gave', () async {
    await service.signInWith(credentialOf(apple, 'calls-kept'));
    final owner = service.currentUser?.uid;
    await service.signOut();
    await service.signInAnonymously();
    final refused = credentialOf(apple, 'calls-kept');
    final link = outcomeOf(await errorOf(() => service.linkWith(refused)));
    // As when the session could not move the data of the guest, and the
    // user signs out and in with Google.
    await service.signOut();
    final other = credentialOf(google, 'calls-kept-other');
    firebase.calls.clear();
    await service.signInWith(other);
    final ofOther = firebase.calls.single;
    final otherUser = service.currentUser;
    await service.signOut();
    firebase.calls.clear();
    await service.signInWith(refused);
    final [_, ofRefused as Map<Object?, Object?>] = firebase.calls.single;

    expect(
      [
        link,
        (ofOther.last! as Map<Object?, Object?>)['idToken'] == other.idToken,
        issuersOf(otherUser),
        otherUser?.uid == owner,
      ],
      [
        AuthFailureReason.credentialInUse.name,
        true,
        [google],
        false,
      ],
      reason: 'What Firebase gave with a refused link belongs to the '
          'credential object of the link: a sign-in with another credential '
          'sends its own token and signs in to its own identity.',
    );
    expect(
      [ofRefused['token'] is int, service.currentUser?.uid == owner],
      [true, true],
      reason: 'The identical credential object still gets the credential that '
          'Firebase gave, and signs in to the user of its identity.',
    );
  });

  test(
      'a deletion with a fresh credential of Apple on iOS signs the user in '
      'again, revokes the tokens of Apple with the authorization code of '
      'that credential, deletes the account and signs out, and on Android, '
      'and for a credential of Google, it revokes nothing', () async {
    final found = <String, List<Object?>>{};
    for (final (issuer, platform) in [
      (apple, TargetPlatform.iOS),
      (apple, TargetPlatform.android),
      (google, TargetPlatform.iOS),
    ]) {
      await service.signInWith(credentialOf(issuer, 'calls-deleted'));
      final fresh = credentialOf(issuer, 'calls-deleted');
      firebase.calls.clear();
      debugDefaultTargetPlatformOverride = platform;
      try {
        await service.deleteAccount(fresh: fresh);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      found['${issuer == apple ? 'Apple' : 'Google'} on ${platform.name}'] = [
        for (final call in firebase.calls)
          switch (call) {
            ['reauthenticateWithCredential', final Map<Object?, Object?> sent]
                when sent['idToken'] == fresh.idToken =>
              'signs in again with the fresh credential',
            ['revokeTokenWithAuthorizationCode', final code]
                when code == fresh.authorizationCode =>
              'revokes with the code of the fresh credential',
            _ => call.first,
          },
        userOf(service.currentUser),
      ];
    }

    expect(
      found,
      {
        'Apple on iOS': [
          'signs in again with the fresh credential',
          'revokes with the code of the fresh credential',
          'delete',
          'signOut',
          'nobody',
        ],
        for (final name in ['Apple on android', 'Google on iOS'])
          name: [
            'signs in again with the fresh credential',
            'delete',
            'signOut',
            'nobody',
          ],
      },
      reason: 'With a fresh credential, the service signs the user in again '
          'first, so that Firebase deletes the account without asking for a '
          'recent sign-in. For a credential of Apple, it then revokes the '
          'tokens that Apple gave the app with the authorization code of '
          'that credential, as the App Store asks, before it deletes the '
          'account. Firebase revokes on iOS and macOS only, and only the '
          'tokens of Apple.',
    );
  });

  test(
      'a revocation that fails deletes nothing, and the deletion fails with '
      'notConfigured, with a hint that tells what the Apple sign-in method '
      'of the project needs', () async {
    await service.signInWith(credentialOf(apple, 'calls-not-revoked'));
    final user = userOf(service.currentUser);
    firebase
      ..calls.clear()
      ..failNext(
        'revokeTokenWithAuthorizationCode',
        code: 'invalid-credential',
        message: 'Code flow is not enabled for Apple.',
      );

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final Object? failure;
    try {
      failure = await errorOf(
        () => service.deleteAccount(
          fresh: credentialOf(apple, 'calls-not-revoked'),
        ),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }

    expect(
      failure,
      isA<AuthFailure>()
          .having(
            (failure) => failure.reason,
            'reason',
            AuthFailureReason.notConfigured,
          )
          .having(
            (failure) => failure.developerHint,
            'developerHint',
            allOf(
              contains('(invalid-credential: Code flow is not enabled for '
                  'Apple.), so the account was not deleted'),
              contains('the Services ID and the OAuth code flow '
                  'configuration, with the Apple team ID, the Key ID and the '
                  'private key, of the Apple sign-in method'),
              contains('/authentication/providers'),
              isNot(contains('firebase-auth-tests-')),
            ),
          ),
      reason: 'A revocation that Firebase refuses fails the deletion with '
          'notConfigured: the hint has what Firebase answered and what the '
          'Apple sign-in method of the project needs, and neither the token '
          'nor the authorization code.',
    );
    expect(
      [
        [for (final call in firebase.calls) call.first],
        userOf(service.currentUser),
      ],
      [
        ['reauthenticateWithCredential', 'revokeTokenWithAuthorizationCode'],
        user,
      ],
      reason: 'Nothing is deleted when the revocation fails: the user stays '
          'signed in.',
    );
  });

  test(
      'a credential of another identity provider fails with notConfigured '
      'before it reaches Firebase, and a deletion with one deletes nothing',
      () async {
    const credential = IdTokenCredential(
      issuer: 'https://accounts.example.com',
      idToken: 'secret-token',
    );
    await service.signUp(email: addressOf('credential'), password: password);
    final uid = service.currentUser!.uid;
    firebase.calls.clear();
    final failures = <String, String>{};
    for (final (name, call) in [
      ('signInWith', () => service.signInWith(credential)),
      ('linkWith', () => service.linkWith(credential)),
      ('deleteAccount', () => service.deleteAccount(fresh: credential)),
    ]) {
      try {
        await call();
        failures[name] = 'none';
      } on AuthFailure catch (failure) {
        final hint = failure.developerHint ?? '';
        failures[name] = [
          failure.reason.name,
          if (hint.contains('https://accounts.example.com')) 'the issuer',
          if (hint.contains('secret-token')) 'the token',
        ].join(', ');
      }
    }

    expect(
      failures,
      {
        for (final name in ['signInWith', 'linkWith', 'deleteAccount'])
          name: 'notConfigured, the issuer',
      },
      reason: 'The service takes the credentials of Google and Apple only, '
          'and its hint names the identity provider and no token.',
    );
    expect(
      [
        for (final call in firebase.calls)
          if (call.first != 'setLanguageCode') call,
      ],
      isEmpty,
      reason: 'Nothing reaches Firebase.',
    );
    expect(
      userOf(service.currentUser),
      'the account $uid of ${addressOf('credential')}',
      reason: 'The user of the account is still signed in, and not deleted.',
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
      'a read of the token reaches Firebase with what it asks for, and tells '
      'the listeners of the service nothing', () async {
    final heard = <String>[];
    final subscription = service.userChanges.listen(
      (user) => heard.add(userOf(user)),
    );
    addTearDown(subscription.cancel);
    final nobody = await service.userToken();
    final nobodyForced = await service.userToken(forceRefresh: true);
    final callsOfNobody = [...firebase.calls];
    await service.signUp(email: addressOf('token'), password: password);
    await pumpEventQueue();
    heard.clear();
    firebase.calls.clear();

    final read = await service.userToken();
    final again = await service.userToken();
    final forced = await service.userToken(forceRefresh: true);
    await pumpEventQueue();

    expect(
      [nobody, nobodyForced, callsOfNobody],
      [null, null, isEmpty],
      reason: 'With nobody signed in, the service answers null without a '
          'call of Firebase.',
    );
    expect(
      firebase.calls,
      [
        ['getIdToken', false],
        ['getIdToken', false],
        ['getIdToken', true],
      ],
      reason: 'A read leaves the token to the Firebase SDK, which keeps it on '
          'the device, and only a forced read asks for a new one.',
    );
    expect(
      [read, again == read, forced == read],
      [isNotEmpty, true, false],
      reason: 'The token is what Firebase answers.',
    );
    expect(
      heard,
      isEmpty,
      reason: 'A read of the token changes nobody, and an app may read it '
          'for each of its requests, so the service tells its listeners '
          'nothing.',
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
