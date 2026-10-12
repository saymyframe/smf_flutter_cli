// A test that continuous integration runs in the apps with the auth role,
// whichever module provides it, in each mode of the role: a call of the
// session that is made before the app starts waits for the start, and the
// start-up of the app is over only after the call. So an account that is
// signed up before the start-up is signed in when the start-up is over,
// before the first frame.
//
// The mocks of the tests of an app use this: a module whose guard of the
// routes asks for an account signs a user up there, so that the tests of
// the other modules see the screens that they expect. The matrix sets
// those mocks up before the tests of each test file
// (flutter_test_config.dart), so in an app with such a module, its account
// is signed up before the one of this test, whose user replaces it.
//
// It knows only the role. The call is made in a setUpAll, outside the body
// of a test, as the role asks: made in the body of a widget test, it would
// wait in the fake time of that body, and the start-up, which runs in real
// time, would never be over. It has a file of its own, since the start-up
// of an app runs once in a test file.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/auth/app_session.dart';

import 'auth_role.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final email = addressOf('before-start');
  // How the sign-up ended: `null` while it waits, and then what it failed
  // with, or that it completed.
  Object? signUp;

  setUpAll(() {
    // Nothing awaits the call: it completes during the start-up of the app,
    // which the test runs.
    unawaited(
      appSession.signUp(email: email, password: password).then(
            (_) => signUp = 'completed',
            onError: (Object error) => signUp = error,
          ),
    );
  });

  testWidgets(
    'an account that is signed up before the app starts is signed in when '
    'the start-up of the app is over',
    (tester) async {
      final before = (signUp, appSession.value);

      await startUp(tester);
      final after = (signUp, sessionNow());

      expect(
        before,
        (null, const SignedOutSession()),
        reason: 'A call of the session that is made before the app starts '
            'waits for the start: until then, the session has nobody.',
      );
      expect(
        after,
        ('completed', sessionOfAccount(email)),
        reason: 'The start-up of the app is over only after the calls of '
            'the session that were made before it: the app starts with the '
            'account that was signed up, before its first frame.',
      );
    },
    // A widget test fails after ten minutes by default; a test that hangs
    // fails sooner.
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
