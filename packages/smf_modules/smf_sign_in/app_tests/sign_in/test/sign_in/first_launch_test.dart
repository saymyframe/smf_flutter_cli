// A test that continuous integration runs in the apps with the sign-in
// module, in each mode of the auth role: what the app does on its first
// launch, with nobody signed in on the device, and from there on, with the
// module that provides the sign-in, whose mocks keep the accounts in
// memory.
//
// An app that asks for an account shows the sign-in in place of the screen
// that it starts on, which it does not build. The sign-in leads to the
// screen that creates an account and to the one that resets a password, and
// each leads back. A sign-up and a sign-in show the screen that the app
// starts on, the next launch has the account, and a sign-out shows the
// sign-in again. For a user with an account, a link to a route of the
// sign-in shows the screen that the app starts on.
//
// An app that everyone may use shows the screen that it starts on, and the
// sign-in once code asks for it, over that screen, with a button that leads
// back. A sign-up closes the sign-in, and the user is back on the screen
// below. In an app that signs an anonymous user in, that user keeps the id
// with the account. A sign-out leaves the app open. After a sign-in over a
// screen, the user is on that same page, with the pages that were below
// it: the router closed the sign-in, and its screen closed nothing.
//
// The screens only change the session of the app: the router of the app,
// whichever module provides it, shows them and leaves them, as the router
// role says of the guards of the routes. The matrix writes of_app.dart next
// to this file, with the screen that the app starts on. The test starts the
// app once, since the start-up of an app may not run twice, and each
// expectation gives its reason.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/auth/app_session.dart';
import 'package:{{app_name}}/features/sign_in/sign_in_widgets.dart';

import '../sign_in_mocks.dart';
import 'app.dart';
import 'of_app.dart';

/// The email address and the password of the account that the test creates.
const _email = 'first-launch@sign-in-tests.example.com';
const _password = 'First-launch-2468';

/// Starts the session of the app again, as the next launch of the app does,
/// with the user who is signed in on the device.
Future<void> _nextLaunch(WidgetTester tester) async {
  await inRealTime(tester, 'initAuth()', initAuth);
  await tester.pumpAndSettle();
}

/// Signs the user out, as the code of the app does.
Future<void> _signOut(WidgetTester tester) async {
  await inRealTime(tester, 'signing out', appSession.signOut);
  await tester.pumpAndSettle();
}

/// Checks that the app shows the screen that it starts on and has built no
/// screen of the sign-in, [when].
void _expectApp(String when) {
  expect(
    find.byType(startScreen),
    findsOneWidget,
    reason: '$when, the app shows the screen that it starts on.',
  );
  expect(
    anySignInScreen,
    findsNothing,
    reason: '$when, the router has left the screens of the sign-in.',
  );
}

/// Checks that the app shows the sign-in in place of its screens, [when].
void _expectSignInAlone(String when) {
  expect(
    signInScreen,
    findsOneWidget,
    reason: '$when, an app that asks for an account shows the sign-in.',
  );
  expect(
    builtStartScreen,
    findsNothing,
    reason: '$when, an app that asks for an account does not build the '
        'screen that it starts on.',
  );
  expect(
    find.byType(BackButton),
    findsNothing,
    reason: '$when, the sign-in is the only page of the app, so it has no '
        'button that leads back.',
  );
}

/// Creates the account of the test on the screen that creates an account,
/// which the user sees.
Future<void> _signUp(WidgetTester tester) async {
  await fill(tester, email: _email, password: _password);
  await tapInRealTime(
    tester,
    submitButton,
    until: () => appSession.hasAccount.value,
  );
}

/// The app asks for an account: the sign-in comes first.
Future<void> _asksForAccount(WidgetTester tester) async {
  expect(
    sessionNow(),
    'nobody',
    reason: 'On its first launch, the app has nobody signed in.',
  );
  _expectSignInAlone('On its first launch');

  // The sign-in leads to its two other screens, and each leads back.
  await tester.tap(otherScreenAction);
  await tester.pumpAndSettle();
  expect(
    signUpScreen,
    findsOneWidget,
    reason: 'The action below the button of the sign-in shows the screen '
        'that creates an account.',
  );
  expect(
    find.byType(BackButton),
    findsOneWidget,
    reason: 'The screen that creates an account is over the sign-in, so it '
        'has a button that leads back.',
  );
  await tester.tap(otherScreenAction);
  await tester.pumpAndSettle();
  expect(
    (signInScreen.evaluate().length, signUpScreen.evaluate().length),
    (1, 0),
    reason: 'The action below the button of the screen that creates an '
        'account leads back to the sign-in.',
  );
  await tester.tap(find.widgetWithText(TextButton, texts['forgotPassword']!));
  await tester.pumpAndSettle();
  expect(
    resetScreen,
    findsOneWidget,
    reason: 'The action at the field of the password shows the screen that '
        'resets a password.',
  );
  await fill(tester, email: _email);
  await tapInRealTime(
    tester,
    submitButton,
    until: () => find.byType(EmailAddress).evaluate().isNotEmpty,
  );
  expect(
    (
      text('resetSentTitle').evaluate().length,
      find.widgetWithText(EmailAddress, _email).evaluate().length,
    ),
    (1, 1),
    reason: 'Once the message of a password reset is sent, the screen says '
        'so and shows the address that it went to, whether the address has '
        'an account or not.',
  );
  expect(
    sessionNow(),
    'nobody',
    reason: 'A password reset signs nobody in.',
  );
  await tester.tap(find.widgetWithText(FilledButton, texts['backToSignIn']!));
  await tester.pumpAndSettle();
  expect(
    (signInScreen.evaluate().length, resetScreen.evaluate().length),
    (1, 0),
    reason: 'The button of the screen that tells of the message leads back '
        'to the sign-in.',
  );

  // A sign-up opens the app.
  await tester.tap(otherScreenAction);
  await tester.pumpAndSettle();
  await _signUp(tester);
  expect(
    sessionNow(),
    'the account of $_email',
    reason: 'The screen that creates an account signs the user up through '
        'the session of the app.',
  );
  _expectApp('Once the user has an account');
  final uid = appSession.value.uid;

  await _nextLaunch(tester);
  expect(
    (sessionNow(), appSession.value.uid),
    ('the account of $_email', uid),
    reason: 'The next launch of the app has the account that was signed in.',
  );
  _expectApp('On the next launch, with the account on the device');

  // A sign-out closes the app again.
  await _signOut(tester);
  _expectSignInAlone('Once the user has signed out');
  await _nextLaunch(tester);
  _expectSignInAlone('On a launch after a sign-out');

  // A sign-in with a wrong password says so, and one with the right
  // password opens the app.
  await fill(tester, email: _email, password: '$_password-wrong');
  await tapInRealTime(
    tester,
    submitButton,
    until: () => failureMessage(AuthFailureReason.invalidCredentials)
        .evaluate()
        .isNotEmpty,
  );
  expect(
    failureMessage(AuthFailureReason.invalidCredentials),
    findsOneWidget,
    reason: 'A sign-in with a wrong password says that the email or the '
        'password is wrong.',
  );
  _expectSignInAlone('After a sign-in that failed');
  await fill(tester, password: _password);
  await tapInRealTime(
    tester,
    submitButton,
    until: () => appSession.hasAccount.value,
  );
  expect(
    (sessionNow(), appSession.value.uid),
    ('the account of $_email', uid),
    reason: 'The sign-in signs the user in to the account, through the '
        'session of the app.',
  );
  _expectApp('Once the user has signed in');

  // The flow of the sign-in is over: a link to one of its routes shows the
  // app, and the screens need no code for that.
  await followLinksToSignIn(tester);
  _expectApp('After a link to each route of the sign-in, for a user with an '
      'account');
}

/// Everyone may use the app: the sign-in comes when code asks for it.
Future<void> _opensForEveryone(WidgetTester tester) async {
  final withoutAccount = switch (authMode) {
    AuthMode.anonymous => 'an anonymous user',
    _ => 'nobody',
  };
  expect(
    sessionNow(),
    withoutAccount,
    reason: 'On its first launch, an app in the mode ${authMode.name} has '
        '$withoutAccount signed in.',
  );
  _expectApp('On its first launch, in an app that everyone may use');
  final guest = appSession.value.uid;

  // The sign-in over the screen, and back.
  await pushSignIn(tester);
  expect(
    signInScreen,
    findsOneWidget,
    reason: 'For a user without an account, a navigation to the sign-in '
        'shows it.',
  );
  expect(
    builtStartScreen,
    findsOneWidget,
    reason: 'The sign-in is over the screen that the user was on.',
  );
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
  _expectApp('Once the user went back from the sign-in');
  expect(
    (sessionNow(), appSession.value.uid),
    (withoutAccount, guest),
    reason: 'Going back from the sign-in changes nothing of the session.',
  );

  // A sign-up closes the sign-in.
  await pushSignIn(tester);
  await tester.tap(otherScreenAction);
  await tester.pumpAndSettle();
  expect(
    signUpScreen,
    findsOneWidget,
    reason: 'The action below the button of the sign-in shows the screen '
        'that creates an account.',
  );
  await _signUp(tester);
  expect(
    sessionNow(),
    'the account of $_email',
    reason: 'The screen that creates an account signs the user up through '
        'the session of the app.',
  );
  final uid = appSession.value.uid;
  if (authMode == AuthMode.anonymous) {
    expect(
      uid,
      guest,
      reason: 'An anonymous user who signs up keeps the id: the session of '
          'the app gives the account to that user.',
    );
  }
  _expectApp('Once the user has an account');

  await pushSignIn(tester);
  _expectApp('After a navigation to the sign-in by a user with an account');
  await followLinksToSignIn(tester);
  _expectApp('After a link to each route of the sign-in, for a user with an '
      'account');

  await _nextLaunch(tester);
  expect(
    (sessionNow(), appSession.value.uid),
    ('the account of $_email', uid),
    reason: 'The next launch of the app has the account that was signed in.',
  );
  _expectApp('On the next launch, with the account on the device');

  // A sign-out leaves the app open, and the sign-in signs in again.
  await _signOut(tester);
  expect(
    sessionNow(),
    withoutAccount,
    reason: 'After a sign-out, an app in the mode ${authMode.name} has '
        '$withoutAccount signed in.',
  );
  _expectApp('After a sign-out, in an app that everyone may use');
  final page = tester.element(find.byType(startScreen));
  final couldPop = rootCanPop(tester);
  await pushSignIn(tester);
  expect(
    signInScreen,
    findsOneWidget,
    reason: 'After a sign-out, a navigation to the sign-in shows it again.',
  );
  await fill(tester, email: _email, password: _password);
  await tapInRealTime(
    tester,
    submitButton,
    until: () => appSession.hasAccount.value,
  );
  expect(
    (sessionNow(), appSession.value.uid),
    ('the account of $_email', uid),
    reason: 'The sign-in signs the user in to the account, through the '
        'session of the app.',
  );
  _expectApp('Once the user has signed in');
  expect(
    (
      identical(tester.element(find.byType(startScreen)), page),
      rootCanPop(tester)
    ),
    (true, couldPop),
    reason: 'Once the user has signed in, the router has closed the page of '
        'the sign-in, and the user is on the page that it was opened over, '
        'with the pages that were below it: the screen of the sign-in '
        'closes nothing itself, which would close that page.',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // A tap that reaches no widget fails the test where it misses.
  WidgetController.hitTestWarningShouldBeFatal = true;
  // The app starts as its first launch finds it: the mocks of the module
  // sign no account up for the tests of this file.
  signInIsUnderTest = true;

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'on its first launch, an app that asks for an account shows the sign-in '
    'in place of the screen that it starts on, and an app that everyone may '
    'use shows it once code asks for it; a sign-up and a sign-in show the '
    'app, the next launch has the account, and a sign-out does what the '
    'mode of the app says',
    (tester) async {
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      useTallPhone(tester);
      await useLanguage(tester, signInTexts.keys.first);
      await startApp(tester);

      switch (authMode) {
        case AuthMode.required:
          await _asksForAccount(tester);
        case AuthMode.guest || AuthMode.anonymous:
          await _opensForEveryone(tester);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
