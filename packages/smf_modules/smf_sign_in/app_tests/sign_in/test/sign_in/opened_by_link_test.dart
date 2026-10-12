// A test that continuous integration runs in the apps with the sign-in
// module, in each mode of the auth role: the platform opens the app on the
// route of the sign-in, as a link to it does for an app that is not
// running, with nobody signed in on the device.
//
// An app that asks for an account shows the sign-in in place of the screen
// that it starts on, as on any first launch: the flow is that of its gate.
// An app that everyone may use shows the sign-in too, since the flow of
// the guard of the account is not over for a user without one. The
// location of the platform would leave the sign-in alone there, with no
// way back into the app, so the router shows it over the screen that the
// app starts on, and the back button of the system leads into the app.
//
// The router of the app shows the screens, whichever module provides it, as
// the router role says of a location from the platform. A router may take
// no such location, and then the app starts on the screen that it starts
// on: the test tells such a router by another page of the app, which it
// does not show for the platform either. The matrix writes of_app.dart
// next to this file. The test starts the app once, since the start-up of
// an app may not run twice, which is why it has a file of its own, and
// each expectation gives its reason.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/auth/app_session.dart';
import 'package:{{app_name}}/core/router/navigation.dart';

import '../sign_in_mocks.dart';
import 'app.dart';
import 'of_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // A tap that reaches no widget fails the test where it misses.
  WidgetController.hitTestWarningShouldBeFatal = true;
  // The app starts as its first launch finds it: the mocks of the module
  // sign no account up for the test of this file.
  signInIsUnderTest = true;

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'an app that the platform opens on the route of the sign-in, with '
    'nobody signed in, shows the sign-in: in place of its screens when it '
    'asks for an account, and over the screen that it starts on, with a '
    'way back into the app, when everyone may use it',
    (tester) async {
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      useTallPhone(tester);
      await useLanguage(tester, signInTexts.keys.first);
      tester.platformDispatcher.defaultRouteNameTestValue =
          const SignInSignInLocation().path;
      await startApp(tester);

      if (authMode == AuthMode.required) {
        expect(
          (
            sessionNow(),
            signInScreen.evaluate().length,
            builtStartScreen.evaluate().length,
            find.byType(BackButton).evaluate().length,
            rootCanPop(tester),
          ),
          ('nobody', 1, 0, 0, false),
          reason: 'An app that asks for an account and that the platform '
              'opens on the sign-in shows the sign-in in place of the '
              'screen that it starts on, which it does not build, as on any '
              'first launch.',
        );
        return;
      }

      final withoutAccount =
          authMode == AuthMode.anonymous ? 'an anonymous user' : 'nobody';
      final guest = appSession.value.uid;
      if (signInScreen.evaluate().isEmpty) {
        await expectRouterTakesNoLinks(
          tester,
          'For an app that the platform opens on the sign-in',
        );
        return;
      }
      expect(
        (
          sessionNow(),
          signInScreen.evaluate().length,
          builtStartScreen.evaluate().length,
          rootCanPop(tester),
        ),
        (withoutAccount, 1, 1, true),
        reason: 'An app that everyone may use and that the platform opens '
            'on the sign-in shows the sign-in over the screen that it '
            'starts on, which is built below it, with a way back into the '
            'app.',
      );
      expect(
        await pressSystemBack(tester),
        isTrue,
        reason: 'The app handles the back button of the system on the '
            'sign-in that it was opened on: it does not close the app.',
      );
      expect(
        (
          find.byType(startScreen).evaluate().length,
          anySignInScreen.evaluate().length,
          sessionNow(),
          appSession.value.uid,
        ),
        (1, 0, withoutAccount, guest),
        reason: 'After the back button of the system, the user is on the '
            'screen that the app starts on, no screen of the sign-in is '
            'built, and the session is as it was.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
