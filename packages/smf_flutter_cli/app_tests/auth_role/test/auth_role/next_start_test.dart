// A test that continuous integration runs in the apps with the auth role,
// whichever module provides it, in each mode of the role: who uses the app
// is known before the first frame. The next start of the app has the user
// who was signed in on the device when it is over, the user of an account
// and an anonymous one. A start that finds nobody on the device has
// nobody, and in the mode anonymous it signs in anonymously and waits for
// that. And the account of a user whom a start found on the device can be
// deleted, at the latest once the user has signed in again.
//
// It knows only the role. The start-up of the app runs first, as on a
// device, with the mocks of the platform side of every module of the app,
// which the matrix sets up before the tests of each test file
// (flutter_test_config.dart). The next start is initAuth() of the role
// again, which creates the service of the provider anew, with the user of
// the device, and starts the session with it. A test reads the session as
// soon as that start is over, without a wait, as the first frame of an app
// comes right after its start-up. The session of the app has that user
// before such a start already, which a launch of the app does not: so a
// session of the test, which never had a user, starts with the service
// too. Each test signs out first, and uses email addresses of its own. Each expectation gives its reason, which a
// provider of the role with a known bug fails the test with
// (brokenProviders of the fixture registry).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/auth/app_session.dart';
import 'package:{{app_name}}/core/auth/guest_data.dart';

import 'auth_role.dart';

/// Why a test expects the user of the device right after the next start.
const _knownAtStart = 'When the next start of the session is over, the '
    'session has the user who was signed in on the device: who uses the app '
    'is known before the first frame.';

/// Starts the session again, as the next launch of the app does, and
/// returns what the session says, and the id of its user, as soon as that
/// start is over.
Future<(String, String?)> _nextStart(WidgetTester tester) async {
  late (String, String?) found;
  await inRealTime(tester, 'initAuth()', () async {
    await initAuth();
    found = (sessionNow(), appSession.value.uid);
  });
  return found;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  const timeout = Timeout(Duration(minutes: 2));

  testWidgets(
    'the next start of the app has the account that was signed in, as soon '
    'as it is over',
    (tester) async {
      await startUp(tester);
      final email = addressOf('next-start');
      String? uid;
      late AppSession launched;

      await inRealTime(tester, 'signing up', () async {
        await appSession.signOut();
        await appSession.signUp(email: email, password: password);
        uid = appSession.value.uid;
      });
      final found = await _nextStart(tester);
      await inRealTime(tester, 'starting a session of the test', () async {
        // A session that never had a user, as that of an app is when the
        // app is launched: it disposes of it once it started.
        final session = AppSessionController(
          mode: authMode,
          takeGuestData: takeGuestData,
        );
        await session.start(createAuthService());
        launched = session.value;
        session.dispose();
      });

      expect(found, (sessionOfAccount(email), uid), reason: _knownAtStart);
      expect(
        (userOf(createAuthService().currentUser), sessionNow()),
        ('the account of $email', sessionOfAccount(email)),
        reason: 'The service that the next start created has the user of '
            'the device, and the session keeps that user.',
      );
      expect(
        launched,
        AccountSession(uid ?? '', email: email),
        reason: 'A session that never had a user takes the user of the '
            'service when it starts, as the session of an app does when the '
            'app is launched with a user on the device.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'the next start of the app has the anonymous user who was signed in, in '
    'every mode',
    (tester) async {
      await startUp(tester);
      String? uid;

      await inRealTime(tester, 'signing in anonymously', () async {
        // Through the service, since only the session of an app in the
        // mode anonymous signs in anonymously.
        final service = createAuthService();
        await service.signOut();
        await service.signInAnonymously();
        uid = service.currentUser?.uid;
      });
      final found = await _nextStart(tester);

      expect(
        found,
        (
          'an anonymous user, allowsApp ${authMode != AuthMode.required}, '
              'hasAccount false',
          uid
        ),
        reason: _knownAtStart,
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'a start that finds nobody on the device has nobody, and in the mode '
    'anonymous a new anonymous user, whom it waits for',
    (tester) async {
      await startUp(tester);
      final email = addressOf('first-launch');
      String? uid;

      await inRealTime(tester, 'signing up and out', () async {
        await appSession.signOut();
        await appSession.signUp(email: email, password: password);
        uid = appSession.value.uid;
        // Through the service, which leaves nobody on the device in every
        // mode: as on a first launch.
        await createAuthService().signOut();
      });
      final (session, found) = await _nextStart(tester);

      expect(
        session,
        sessionWithoutAccount,
        reason: 'A start that finds nobody on the device has nobody in the '
            'modes required and guest. In the mode anonymous it signs in '
            'anonymously and is over only once that user is signed in.',
      );
      expect(
        found,
        isNot(uid),
        reason: 'The user of an account that was signed out is not signed '
            'in at the next start.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'the account of a user whom a start found on the device can be deleted, '
    'at the latest once the user has signed in again',
    (tester) async {
      await startUp(tester);
      final email = addressOf('deleted-later');
      Object? first;
      Object? second;
      Object? gone;
      late String after;

      await inRealTime(tester, 'signing up', () async {
        await appSession.signOut();
        await appSession.signUp(email: email, password: password);
      });
      final (found, _) = await _nextStart(tester);
      expect(found, sessionOfAccount(email), reason: _knownAtStart);

      await inRealTime(tester, 'deleting the account', () async {
        first = await errorOf(appSession.deleteAccount);
        if (first != null) {
          await appSession.signOut();
          await appSession.signIn(email: email, password: password);
          second = await errorOf(appSession.deleteAccount);
        }
        after = sessionNow();
        gone = await errorOf(
          () => appSession.signIn(email: email, password: password),
        );
      });

      expect(
        first,
        anyOf(isNull, failsWith(AuthFailureReason.recentSignInRequired)),
        reason: 'The deletion of the account of a user who signed in before '
            'the app started succeeds, or fails with recentSignInRequired.',
      );
      expect(
        second,
        isNull,
        reason: 'Once the user has signed in again, the deletion of the '
            'account succeeds.',
      );
      expect(
        after,
        sessionWithoutAccount,
        reason: 'Once the account is deleted, the session has no account.',
      );
      expect(
        gone,
        failsWith(AuthFailureReason.invalidCredentials),
        reason: 'The account of a user who was deleted is gone: signing in '
            'to it fails with invalidCredentials.',
      );
    },
    timeout: timeout,
  );
}
