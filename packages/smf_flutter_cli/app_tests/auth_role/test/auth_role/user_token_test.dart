// A test that continuous integration runs in the apps with the auth role,
// whichever module provides it, in each mode of the role: the token with
// which a server of the app tells who the user is. Nobody has no token, the
// user of an account and an anonymous user each have one, a forced refresh
// gives another one with the same user, and a read tells nobody of a change.
// Through the session of the app, a request reads the token of the user at
// each moment, and a token that a server refused is replaced once, however
// many requests it refused at the same time. The next start of the app still
// has a token for the user of the device.
//
// It knows only the role. The start-up of the app runs first, as on a device,
// with the mocks of the platform side of every module of the app, which the
// matrix sets up before the tests of each test file
// (flutter_test_config.dart). Each test signs out first, and uses email
// addresses of its own. Each expectation gives its reason, which a provider
// of the role with a known bug fails the test with (brokenProviders of the
// fixture registry).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/auth/app_session.dart';

import 'auth_role.dart';

/// What the tests of a user who is signed out expect of a read, with the
/// reason that a provider which keeps a token fails on.
const _noToken = 'With nobody signed in, the service has no token to give: a '
    'read answers null, also a read that forces a refresh, and no earlier '
    'token stays behind for it.';

/// What a forced refresh must do, with the reason that a provider which does
/// not refresh fails on.
const _newToken = 'A read with forceRefresh asks the server of the provider '
    'for a new token: it differs from the one before, the user stays, and the '
    'reads after it give the new one.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs fails
  // sooner.
  const timeout = Timeout(Duration(minutes: 2));

  testWidgets(
    'the service gives no token while nobody is signed in',
    (tester) async {
      await startUp(tester);
      String? read;
      String? forced;

      await inRealTime(tester, 'reading the token', () async {
        // A token that a user read before stays with that user.
        final service = createAuthService();
        await service.signUp(
          email: addressOf('token-nobody'),
          password: password,
        );
        await service.userToken();
        await service.signOut();
        read = await service.userToken();
        forced = await service.userToken(forceRefresh: true);
      });

      expect([read, forced], [null, null], reason: _noToken);
    },
    timeout: timeout,
  );

  testWidgets(
    'the user of an account has a token, which a forced refresh replaces',
    (tester) async {
      await startUp(tester);
      String? uid;
      String? first;
      String? again;
      String? refreshed;
      String? afterRefresh;
      String? uidAfterRefresh;

      await inRealTime(tester, 'reading the token', () async {
        final service = createAuthService();
        await service.signOut();
        await service.signUp(
          email: addressOf('token-account'),
          password: password,
        );
        uid = service.currentUser?.uid;
        first = await service.userToken();
        again = await service.userToken();
        refreshed = await service.userToken(forceRefresh: true);
        afterRefresh = await service.userToken();
        uidAfterRefresh = service.currentUser?.uid;
      });

      expect(
        first,
        isNotNull,
        reason: 'The user of an account has a token.',
      );
      expect(first, isNotEmpty, reason: 'A token is not empty.');
      expect(
        again,
        first,
        reason: 'A read comes from the device while the token is valid, so '
            'it gives the same token.',
      );
      expect(
        (refreshed == first, afterRefresh == refreshed, uidAfterRefresh == uid),
        (false, true, true),
        reason: _newToken,
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'an anonymous user has a token, and keeps the id with a refresh and with '
    'an account',
    (tester) async {
      await startUp(tester);
      String? uid;
      String? first;
      String? refreshed;
      String? uidAfterRefresh;
      String? linked;
      String? uidOfAccount;

      await inRealTime(tester, 'reading the token', () async {
        final service = createAuthService();
        await service.signOut();
        await service.signInAnonymously();
        uid = service.currentUser?.uid;
        first = await service.userToken();
        refreshed = await service.userToken(forceRefresh: true);
        uidAfterRefresh = service.currentUser?.uid;
        await service.linkPassword(
          email: addressOf('token-linked'),
          password: password,
        );
        linked = await service.userToken();
        uidOfAccount = service.currentUser?.uid;
      });

      expect(
        first,
        isNotNull,
        reason: 'An anonymous user has a token too, so a server tells one '
            'anonymous user from another.',
      );
      expect(first, isNotEmpty, reason: 'A token is not empty.');
      expect(
        (refreshed == first, uidAfterRefresh == uid),
        (false, true),
        reason: _newToken,
      );
      expect(
        [linked, uidOfAccount == uid],
        [isNotEmpty, true],
        reason: 'The account that linkPassword() gave an anonymous user has '
            'a token, with the id of that user.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'a read of the token tells nobody of a change',
    (tester) async {
      await startUp(tester);
      final heardOfService = <String>[];
      final heardOfSession = <String>[];
      void onSession() => heardOfSession.add(sessionNow());

      await inRealTime(tester, 'reading the token', () async {
        await appSession.signOut();
        await appSession.signUp(
          email: addressOf('token-silent'),
          password: password,
        );
        // What the sign-up tells has reached the listeners by then.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final service = createAuthService();
        final subscription = service.userChanges.listen(
          (user) => heardOfService.add(userOf(user)),
        );
        appSession.addListener(onSession);
        await service.userToken();
        await service.userToken(forceRefresh: true);
        await appSession.userToken();
        final token = await appSession.userToken();
        if (token != null) await appSession.userTokenAfter(token);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        appSession.removeListener(onSession);
        await subscription.cancel();
      });

      expect(
        [heardOfService, heardOfSession],
        [isEmpty, isEmpty],
        reason: 'A read leaves the user as that user was, so it tells no '
            'listener of the service or of the session: the session reads '
            'the token often.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'the session gives the token of its user, as the mode of the app says',
    (tester) async {
      await startUp(tester);
      String? uid;
      String? ofAccount;
      String? ofService;
      String? afterSignOut;
      String? uidAfterSignOut;

      await inRealTime(tester, 'reading the token', () async {
        await appSession.signOut();
        await appSession.signUp(
          email: addressOf('token-session'),
          password: password,
        );
        uid = appSession.value.uid;
        ofAccount = await appSession.userToken();
        ofService = await createAuthService().userToken();
        await appSession.signOut();
        afterSignOut = await appSession.userToken();
        uidAfterSignOut = appSession.value.uid;
      });

      expect(ofAccount, isNotNull, reason: 'The session has a token.');
      expect(
        ofAccount,
        ofService,
        reason: 'The session gives the token that the service has.',
      );
      expect(
        afterSignOut == null,
        authMode != AuthMode.anonymous,
        reason: 'After a sign-out the session has no token, and in the mode '
            'anonymous the token of the new anonymous user.',
      );
      expect(
        afterSignOut == ofAccount,
        isFalse,
        reason: 'After a sign-out the session does not give the token of the '
            'user who left.',
      );
      expect(
        uidAfterSignOut == null,
        authMode != AuthMode.anonymous,
        reason: 'The session has the user that the mode of the app says.',
      );
      expect(uidAfterSignOut == uid, isFalse);
    },
    timeout: timeout,
  );

  testWidgets(
    'the session refreshes a token that a server refused once, for all the '
    'reads at the same time and for those that come later',
    (tester) async {
      await startUp(tester);
      String? first;
      late List<String?> atOnce;
      String? afterThem;
      String? later;
      String? current;
      String? other;

      await inRealTime(tester, 'refreshing the token', () async {
        await appSession.signOut();
        await appSession.signUp(
          email: addressOf('token-refused'),
          password: password,
        );
        first = await appSession.userToken();
        atOnce = await Future.wait([
          for (var read = 0; read < 8; read++)
            appSession.userTokenAfter(first ?? ''),
        ]);
        afterThem = await appSession.userToken();
        later = await appSession.userTokenAfter(first ?? '');
        current = await appSession.userToken();
        other = await appSession.userTokenAfter('a token of nobody');
      });

      expect(
        atOnce.toSet().length,
        1,
        reason: 'Reads at the same time share one refresh, so they all get '
            'one token: $atOnce.',
      );
      expect(
        (atOnce.first == first, atOnce.first == afterThem),
        (false, true),
        reason: _newToken,
      );
      expect(
        (later == afterThem, current == afterThem, other == afterThem),
        (true, true, true),
        reason: 'A read with a token that the session has replaced takes the '
            'current token, and asks the server for no other.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'the next start of the app has a token for the user of the device',
    (tester) async {
      await startUp(tester);
      String? uid;
      String? afterStart;
      String? uidAfterStart;

      await inRealTime(tester, 'starting the session again', () async {
        await appSession.signOut();
        await appSession.signUp(
          email: addressOf('token-next-start'),
          password: password,
        );
        uid = appSession.value.uid;
        await initAuth();
        afterStart = await appSession.userToken();
        uidAfterStart = appSession.value.uid;
      });

      expect(
        afterStart,
        isNotNull,
        reason: 'The service that the next start created has the user of the '
            'device, and a token for that user.',
      );
      expect(afterStart, isNotEmpty, reason: 'A token is not empty.');
      expect(uidAfterStart, uid);
    },
    timeout: timeout,
  );
}
