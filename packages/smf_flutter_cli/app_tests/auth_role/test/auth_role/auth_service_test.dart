// A test that continuous integration runs in the apps with the auth role,
// whichever module provides it: the service of the provider keeps the
// contract of AuthService, which is the same in every mode of the app.
// When a call completes, the user of the service is its result. Signing up
// creates an account and signs in to it, and the user of an account has
// the same id each time. A wrong password and an address without an
// account fail alike. The user of a call replaces the user who was signed
// in. An anonymous user keeps the id with an account. Deleting removes the
// account. A call for the user who is signed in fails when nobody is. And
// the stream of the changes tells of each change, once the user changed.
//
// It knows only the role, and calls the service itself, which only a test
// of the contract of the role does: the code of an app signs in through
// appSession. The start-up of the app runs first, as on a device, since it
// creates the service, with the mocks of the platform side of every module
// of the app, which the matrix sets up before the tests of each test file
// (flutter_test_config.dart). Each test signs out first, and uses email
// addresses of its own. Each expectation gives its reason, which a
// provider of the role with a known bug fails the test with
// (brokenProviders of the fixture registry).
//
// What a provider does with a text that is no email address, or with a
// weak password, is up to the provider, and no test can make a server
// stop answering or end the session of a user, so the test does not look
// at the reasons invalidEmail, weakPassword, network, tooManyAttempts,
// userDisabled and notConfigured.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/auth/app_session.dart';
import 'package:{{app_name}}/core/auth/auth_service.dart';

import 'auth_role.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  const timeout = Timeout(Duration(minutes: 2));

  testWidgets(
    'signing up creates an account and signs in to it, and signing in again '
    'finds the user with the same id',
    (tester) async {
      await startUp(tester);
      final email = addressOf('sign-up');
      AuthUser? created;
      AuthUser? signedOut;
      Object? secondSignOut;
      AuthUser? again;

      await inRealTime(tester, 'signing up, out and in', () async {
        final service = createAuthService();
        await service.signOut();
        await service.signUp(email: email, password: password);
        created = service.currentUser;
        await service.signOut();
        signedOut = service.currentUser;
        secondSignOut = await errorOf(service.signOut);
        await service.signIn(email: email, password: password);
        again = service.currentUser;
      });

      expect(
        userOf(created),
        'the account of $email',
        reason: 'When signUp() completes, the user of the service is the '
            'user of the new account, who is not anonymous and has its '
            'email address.',
      );
      expect(
        created?.uid,
        isNotEmpty,
        reason: 'The user of an account has an id.',
      );
      expect(
        (userOf(signedOut), secondSignOut),
        ('nobody', null),
        reason: 'When signOut() completes, nobody is signed in, and it '
            'completes when nobody is signed in too.',
      );
      expect(
        (userOf(again), again?.uid),
        ('the account of $email', created?.uid),
        reason: 'signIn() signs in to the account, whose user has the id '
            'that the sign-up gave.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'a wrong password and an address without an account fail alike, and '
    'sign nobody in',
    (tester) async {
      await startUp(tester);
      final email = addressOf('wrong-password');
      Object? wrong;
      Object? unknown;
      AuthUser? after;

      await inRealTime(tester, 'signing in with what matches no account',
          () async {
        final service = createAuthService();
        await service.signOut();
        await service.signUp(email: email, password: password);
        await service.signOut();
        wrong = await errorOf(
          () => service.signIn(email: email, password: wrongPassword),
        );
        unknown = await errorOf(
          () => service.signIn(
            email: addressOf('no-account'),
            password: password,
          ),
        );
        after = service.currentUser;
      });

      expect(
        wrong,
        failsWith(AuthFailureReason.invalidCredentials),
        reason: 'signIn() with a wrong password fails with '
            'invalidCredentials.',
      );
      expect(
        unknown,
        failsWith(AuthFailureReason.invalidCredentials),
        reason: 'signIn() with an address without an account fails with '
            'invalidCredentials, as a wrong password does, so that nobody '
            'learns from the app which addresses have an account.',
      );
      expect(
        userOf(after),
        'nobody',
        reason: 'A sign-in that failed signs nobody in.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'signing up with an address that has an account fails with emailInUse, '
    'and leaves the account as it was',
    (tester) async {
      await startUp(tester);
      final email = addressOf('in-use');
      Object? second;
      AuthUser? after;
      Object? signIn;

      await inRealTime(tester, 'signing up twice', () async {
        final service = createAuthService();
        await service.signOut();
        await service.signUp(email: email, password: password);
        await service.signOut();
        second = await errorOf(
          () => service.signUp(email: email, password: wrongPassword),
        );
        after = service.currentUser;
        signIn = await errorOf(
          () => service.signIn(email: email, password: password),
        );
      });

      expect(
        second,
        failsWith(AuthFailureReason.emailInUse),
        reason: 'signUp() with an address that has an account fails with '
            'emailInUse.',
      );
      expect(
        (userOf(after), signIn),
        ('nobody', null),
        reason: 'A sign-up that failed signs nobody in, and the account of '
            'the address keeps its password.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'a password reset completes for an address with an account and for one '
    'without',
    (tester) async {
      await startUp(tester);
      final email = addressOf('reset');
      Object? known;
      Object? unknown;

      await inRealTime(tester, 'resetting passwords', () async {
        final service = createAuthService();
        await service.signOut();
        await service.signUp(email: email, password: password);
        await service.signOut();
        known = await errorOf(() => service.sendPasswordReset(email));
        unknown = await errorOf(
          () => service.sendPasswordReset(addressOf('no-reset')),
        );
      });

      expect(
        (known, unknown),
        (null, null),
        reason: 'sendPasswordReset() completes whether the address has an '
            'account or not, so that nobody learns from the app which '
            'addresses have one.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'the user of a call replaces the user who was signed in',
    (tester) async {
      await startUp(tester);
      final first = addressOf('first');
      final second = addressOf('second');
      String? firstUid;
      AuthUser? afterSignUp;
      AuthUser? afterSignIn;
      AuthUser? anonymous;
      AuthUser? afterAnonymous;

      await inRealTime(tester, 'signing up and in while signed in', () async {
        final service = createAuthService();
        await service.signOut();
        await service.signUp(email: first, password: password);
        firstUid = service.currentUser?.uid;
        await service.signUp(email: second, password: password);
        afterSignUp = service.currentUser;
        await service.signIn(email: first, password: password);
        afterSignIn = service.currentUser;
        await service.signOut();
        await service.signInAnonymously();
        anonymous = service.currentUser;
        await service.signIn(email: first, password: password);
        afterAnonymous = service.currentUser;
      });

      expect(
        (userOf(afterSignUp), afterSignUp?.uid == firstUid),
        ('the account of $second', false),
        reason: 'signUp() while the user of another account is signed in '
            'creates the account and signs in to it, in place of that user.',
      );
      expect(
        (userOf(afterSignIn), afterSignIn?.uid),
        ('the account of $first', firstUid),
        reason: 'signIn() while the user of another account is signed in '
            'signs in to the account of the call, in place of that user.',
      );
      expect(
        userOf(anonymous),
        'an anonymous user',
        reason: 'signInAnonymously() signs in as an anonymous user.',
      );
      expect(
        (userOf(afterAnonymous), afterAnonymous?.uid),
        ('the account of $first', firstUid),
        reason: 'signIn() while an anonymous user is signed in signs in to '
            'the account of the call, in place of that user.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'an anonymous user has an id and no email address, and keeps the id '
    'with an account',
    (tester) async {
      await startUp(tester);
      final email = addressOf('linked');
      AuthUser? anonymous;
      AuthUser? linked;
      AuthUser? again;
      AuthUser? other;
      Object? taken;
      AuthUser? afterTaken;

      await inRealTime(tester, 'giving an anonymous user an account', () async {
        final service = createAuthService();
        await service.signOut();
        await service.signInAnonymously();
        anonymous = service.currentUser;
        await service.linkPassword(email: email, password: password);
        linked = service.currentUser;
        await service.signOut();
        await service.signIn(email: email, password: password);
        again = service.currentUser;
        await service.signOut();
        await service.signInAnonymously();
        other = service.currentUser;
        taken = await errorOf(
          () => service.linkPassword(email: email, password: password),
        );
        afterTaken = service.currentUser;
      });

      expect(
        userOf(anonymous),
        'an anonymous user',
        reason: 'When signInAnonymously() completes, the user of the service '
            'is anonymous and has no email address.',
      );
      expect(
        anonymous?.uid,
        isNotEmpty,
        reason: 'An anonymous user has an id.',
      );
      expect(
        (userOf(linked), linked?.uid),
        ('the account of $email', anonymous?.uid),
        reason: 'linkPassword() gives the anonymous user who is signed in '
            'an account: the user keeps the id, is no longer anonymous and '
            'has the email address.',
      );
      expect(
        (userOf(again), again?.uid),
        ('the account of $email', anonymous?.uid),
        reason: 'The account that an anonymous user got is the account of '
            'that user: signing in to it again finds the same id.',
      );
      expect(
        taken,
        failsWith(AuthFailureReason.emailInUse),
        reason: 'linkPassword() with an address that has an account fails '
            'with emailInUse.',
      );
      expect(
        (userOf(afterTaken), afterTaken?.uid),
        ('an anonymous user', other?.uid),
        reason: 'An anonymous user who did not get the account stays signed '
            'in, with the same id.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'deleting the user who has just signed in removes the account and signs '
    'out, an anonymous user too',
    (tester) async {
      await startUp(tester);
      final email = addressOf('deleted');
      Object? deletion;
      AuthUser? after;
      Object? signIn;
      Object? anonymousDeletion;
      AuthUser? afterAnonymous;

      await inRealTime(tester, 'deleting users', () async {
        final service = createAuthService();
        await service.signOut();
        await service.signUp(email: email, password: password);
        await service.signOut();
        await service.signIn(email: email, password: password);
        deletion = await errorOf(service.deleteAccount);
        after = service.currentUser;
        signIn = await errorOf(
          () => service.signIn(email: email, password: password),
        );
        await service.signOut();
        await service.signInAnonymously();
        anonymousDeletion = await errorOf(service.deleteAccount);
        afterAnonymous = service.currentUser;
      });

      expect(
        (deletion, userOf(after)),
        (null, 'nobody'),
        reason: 'deleteAccount() succeeds for a user who has just signed in, '
            'and nobody is signed in when it completes.',
      );
      expect(
        signIn,
        failsWith(AuthFailureReason.invalidCredentials),
        reason: 'The account of a user who was deleted is gone: signing in '
            'to it fails with invalidCredentials.',
      );
      expect(
        (anonymousDeletion, userOf(afterAnonymous)),
        (null, 'nobody'),
        reason: 'deleteAccount() deletes an anonymous user who has just '
            'signed in too, and nobody is signed in when it completes.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'a call for the user who is signed in fails with recentSignInRequired '
    'when nobody is signed in',
    (tester) async {
      await startUp(tester);
      Object? link;
      Object? deletion;
      AuthUser? after;

      await inRealTime(tester, 'calling without a user', () async {
        final service = createAuthService();
        await service.signOut();
        link = await errorOf(
          () => service.linkPassword(
            email: addressOf('nobody'),
            password: password,
          ),
        );
        deletion = await errorOf(service.deleteAccount);
        after = service.currentUser;
      });

      expect(
        link,
        failsWith(AuthFailureReason.recentSignInRequired),
        reason: 'linkPassword() fails with recentSignInRequired when nobody '
            'is signed in.',
      );
      expect(
        deletion,
        failsWith(AuthFailureReason.recentSignInRequired),
        reason: 'deleteAccount() fails with recentSignInRequired when nobody '
            'is signed in.',
      );
      expect(
        userOf(after),
        'nobody',
        reason: 'A call for the user who is signed in that failed signs '
            'nobody in.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'the stream of the changes tells every listener of each change of the '
    'user, once the user of the service has changed',
    (tester) async {
      await startUp(tester);
      final email = addressOf('changes');
      final service = createAuthService();
      // The user that each of two listeners heard of last.
      final heard = <String?>[null, null];
      // Each event that came while the service had another user.
      final early = <String>[];
      final subscriptions = <StreamSubscription<AuthUser?>>[];
      // After each step, the user of the service, and then the user that
      // each listener heard of last.
      final steps = <String, List<String?>>{};

      Future<void> step(String name, Future<void> Function() call) async {
        heard.fillRange(0, heard.length);
        await inRealTime(tester, name, call);
        final user = userOf(service.currentUser);
        await waitUntil(tester, () => heard.every((last) => last == user));
        steps[name] = [user, ...heard];
      }

      await inRealTime(tester, 'signing out and listening', () async {
        await service.signOut();
        for (var listener = 0; listener < heard.length; listener++) {
          subscriptions.add(
            service.userChanges.listen((user) {
              final told = userOf(user);
              final current = userOf(service.currentUser);
              heard[listener] = told;
              if (told != current) {
                early.add('told of $told while the service had $current');
              }
            }),
          );
        }
      });
      addTearDown(() async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      });

      await step('signInAnonymously()', service.signInAnonymously);
      await step(
        'linkPassword()',
        () => service.linkPassword(email: email, password: password),
      );
      await step('signOut()', service.signOut);
      await step(
        'signIn()',
        () => service.signIn(email: email, password: password),
      );
      await step('deleteAccount()', service.deleteAccount);
      await step(
        'signUp()',
        () => service.signUp(email: email, password: password),
      );

      const anonymous = 'an anonymous user';
      final account = 'the account of $email';
      expect(
        steps,
        {
          'signInAnonymously()': [anonymous, anonymous, anonymous],
          'linkPassword()': [account, account, account],
          'signOut()': ['nobody', 'nobody', 'nobody'],
          'signIn()': [account, account, account],
          'deleteAccount()': ['nobody', 'nobody', 'nobody'],
          'signUp()': [account, account, account],
        },
        reason: 'userChanges is a broadcast stream that tells each of its '
            'listeners of every change of the user of the service: after '
            'each call, the user that a listener heard of last is the user '
            'of the service.',
      );
      expect(
        early,
        isEmpty,
        reason: 'userChanges tells of a change once the user of the service '
            'has changed: when a listener hears of a user, currentUser is '
            'that user.',
      );
    },
    timeout: timeout,
  );
}
