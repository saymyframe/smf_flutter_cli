// A test that continuous integration runs in the apps with the auth role,
// whichever module provides it, in each mode of the role: the session of
// the app does what the mode of the app says, with the service of the
// provider. The app is in the mode that the role chose for it. The session
// follows its user through a sign-up, a sign-out, a sign-in and the
// deletion of the account: nobody uses an app without an account in the
// modes required and guest, of which only guest lets the user see the app,
// and an anonymous user does in the mode anonymous, who keeps the id with
// an account. The session follows a change of the user that none of its
// calls made. And when the user comes back to the app, only an app in the
// mode anonymous signs a user in.
//
// It knows only the role. The matrix fills in the mode that the role chose
// for the app, which the app has as the constant authMode, and the test
// expects what that mode says, so it holds in an app of every mode. The
// start-up of the app runs first, as on a device, since it starts the
// session, with the mocks of the platform side of every module of the
// app, which the matrix sets up before the tests of each test file
// (flutter_test_config.dart). Each test signs out first, and uses email
// addresses of its own. Each expectation gives its reason, which a
// provider of the role with a known bug fails the test with
// (brokenProviders of the fixture registry).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/auth/app_session.dart';

import 'auth_role.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  const timeout = Timeout(Duration(minutes: 2));

  test('the app is in the mode that the auth role chose for it', () {
    expect(
      authMode.name,
      chosenMode,
      reason: 'The constant authMode of the app is the mode that the role '
          'chose: the first one, required, for an app that was generated '
          'without the option --auth-mode, and the value of the option '
          'otherwise.',
    );
    expect(
      appSession.mode,
      authMode,
      reason: 'The session of the app works by the mode of the app.',
    );
  });

  testWidgets(
    'the session of the app follows its user through a sign-up, a sign-out, '
    'a sign-in and the deletion of the account, as the mode of the app says',
    (tester) async {
      await startUp(tester);
      final email = addressOf('session');
      // How often the listeners of the session and of its two flags were
      // called since a step began.
      final calls = [0, 0, 0];
      final listeners = [
        for (var index = 0; index < calls.length; index++) () => calls[index]++,
      ];
      final listened = <Listenable>[
        appSession,
        appSession.allowsApp,
        appSession.hasAccount,
      ];
      for (final (index, listenable) in listened.indexed) {
        listenable.addListener(listeners[index]);
      }
      addTearDown(() {
        for (final (index, listenable) in listened.indexed) {
          listenable.removeListener(listeners[index]);
        }
      });
      // After each step, what the session says, the id of its user, and
      // whether each listener heard of the step.
      final sessions = <String, String>{};
      final uids = <String, String?>{};
      final heard = <String, List<bool>>{};

      Future<Object?> step(String name, Future<void> Function() call) async {
        calls.fillRange(0, calls.length, 0);
        Object? error;
        await inRealTime(tester, name, () async {
          error = await errorOf(call);
        });
        sessions[name] = sessionNow();
        uids[name] = appSession.value.uid;
        heard[name] = [for (final count in calls) count > 0];
        return error;
      }

      await step('a sign-out', appSession.signOut);
      final signUp = await step(
        'a sign-up',
        () => appSession.signUp(email: email, password: password),
      );
      await step('the next sign-out', appSession.signOut);
      final wrong = await step(
        'a sign-in with a wrong password',
        () => appSession.signIn(email: email, password: wrongPassword),
      );
      final signIn = await step(
        'a sign-in',
        () => appSession.signIn(email: email, password: password),
      );
      final deletion = await step('the deletion', appSession.deleteAccount);
      final gone = await step(
        'a sign-in to the deleted account',
        () => appSession.signIn(email: email, password: password),
      );

      expect(
        (signUp, signIn, deletion),
        (null, null, null),
        reason: 'A sign-up, a sign-in to the account and the deletion of '
            'the account of a user who has just signed in succeed.',
      );
      expect(
        sessions,
        {
          'a sign-out': sessionWithoutAccount,
          'a sign-up': sessionOfAccount(email),
          'the next sign-out': sessionWithoutAccount,
          'a sign-in with a wrong password': sessionWithoutAccount,
          'a sign-in': sessionOfAccount(email),
          'the deletion': sessionWithoutAccount,
          'a sign-in to the deleted account': sessionWithoutAccount,
        },
        reason: 'With an account, its user uses the app, in every mode. '
            'Without one, nobody does in the modes required and guest, of '
            'which only guest lets the user see the app, and an anonymous '
            'user does in the mode anonymous, whom the session signs in '
            'once a sign-out or a deletion left nobody.',
      );
      expect(
        [wrong, gone],
        [
          failsWith(AuthFailureReason.invalidCredentials),
          failsWith(AuthFailureReason.invalidCredentials),
        ],
        reason: 'A call of the session fails with the AuthFailure of the '
            'provider: a wrong password, and an account that was deleted, '
            'are invalidCredentials.',
      );
      expect(
        uids['a sign-in'],
        uids['a sign-up'],
        reason: 'The user of an account has the same id each time.',
      );
      expect(
        heard['a sign-up'],
        [true, true, true],
        reason: 'The listeners of the session, of allowsApp and of '
            'hasAccount are called when the session changes.',
      );
      if (authMode == AuthMode.anonymous) {
        expect(
          uids['a sign-up'],
          uids['a sign-out'],
          reason: 'In the mode anonymous, a sign-up gives the anonymous '
              'user the account: the user keeps the id.',
        );
        expect(
          {uids['the next sign-out'], uids['the deletion']}
              .intersection({uids['a sign-up']}),
          isEmpty,
          reason: 'In the mode anonymous, the anonymous user after a '
              'sign-out or a deletion is a new one, not the user of the '
              'account.',
        );
      } else {
        expect(
          (uids['a sign-out'], uids['the next sign-out'], uids['the deletion']),
          (null, null, null),
          reason: 'In the modes required and guest, the session has no id '
              'of a user while nobody is signed in.',
        );
      }
    },
    timeout: timeout,
  );

  testWidgets(
    'the session follows a change of the user that none of its calls made, '
    'and only an app in the mode anonymous signs a user in when the user '
    'comes back to it',
    (tester) async {
      await startUp(tester);
      final email = addressOf('followed');
      late String signedUp;
      late String followed;
      late String back;

      await inRealTime(tester, 'signing up', () async {
        await appSession.signOut();
        await appSession.signUp(email: email, password: password);
        signedUp = sessionNow();
        // The provider signs the user out, as it does when the session of
        // the user ends: no call of the session of the app made the change.
        await createAuthService().signOut();
      });
      await waitUntil(tester, () => appSession.value is SignedOutSession);
      followed = sessionNow();
      await inRealTime(tester, 'coming back to the app', () async {
        tester.binding
          ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
          ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        // An app in the mode anonymous signs in now, and an app in another
        // mode does nothing: a moment shows both.
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await waitUntil(tester, () => sessionNow() == sessionWithoutAccount);
      back = sessionNow();

      expect(
        signedUp,
        sessionOfAccount(email),
        reason: 'A sign-up signs in to the new account.',
      );
      expect(
        followed,
        sessionOfNobody,
        reason: 'The session follows a change of the user that the provider '
            'tells of, also one that no call of the session made: nobody '
            'uses the app, in every mode.',
      );
      expect(
        back,
        sessionWithoutAccount,
        reason: 'When the user comes back to the app, an app in the mode '
            'anonymous without a user signs in anonymously, and an app in '
            'another mode stays without a user.',
      );
    },
    timeout: timeout,
  );
}
