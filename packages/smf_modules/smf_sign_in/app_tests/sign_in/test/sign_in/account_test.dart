// A test that continuous integration runs in the apps with the sign-in
// module, in each mode of the auth role: the screen of the account, its
// entry on the settings screen, and the ways between them. The session of
// the app gets a service of the test, which says what each call does
// (ScriptedAuthService).
//
// The entry shows the email address of the account, or that nobody is
// signed in, and follows a change of the session that no screen made, also
// while it is on the screen: another account that is signed in with no
// sign-out in between. A tap on it shows the screen of the account over
// the settings screen. For
// a user without an account, in an app that everyone may use, the router
// shows the sign-in over the settings screen first: back from there drops
// the request, and once the user has an account the router closes the
// sign-in and shows the screen of the account.
//
// The screen signs out and deletes the account through the session, and
// closes nothing itself. In an app that everyone may use, the router then
// closes its page, and the user is on the settings screen; in an app that
// signs an anonymous user in, a new one is signed in. In an app that asks
// for an account, the sign-in takes the place of every screen. The
// deletion asks first, in a sheet that is closed before the call. The way
// out of the sheet, the back button of the system and a tap outside the
// sheet close it and delete nothing. While a
// call is on its way, its action shows it and neither action takes a tap.
// A deletion that failed leaves the screen with the text of the failure.
// And when the session ends while the sheet is open, as on the server, the
// sheet goes with the page under it. No call of the app ended that
// session, so the session has nobody then, in every mode: an app that
// signs an anonymous user in does so again when the user comes back to it.
//
// The sign-in that the entry opens for a user without an account is a page
// over the settings screen, and once the user has signed in there, the
// screen of the account is. A screen of the sign-in that closed a page a
// frame after the sign-in would close that screen instead, so this is
// where the test shows that the screens of the sign-in close nothing once
// the router has shown what the user asked for. A screen that closed a
// page in the turn of the sign-in would close only the sign-in, which the
// router closes then anyway, as the router role says: no test tells that
// from a screen that closes nothing.
//
// Where the settings screen is no destination of the main navigation, the
// test opens it over the screen that the app starts on, as a screen of an
// app without a main navigation does. In an app that everyone may use, the
// user is then on the settings screen after a sign-out and a deletion, with
// the screen that the app starts on below it: a screen of the account that
// closed a page itself, after the router closed its own, would leave the
// user on the screen that the app starts on.
//
// The matrix writes of_app.dart next to this file, with the settings
// screen of the app, whether it is a destination of the main navigation,
// and the entry of the module, from the settings screen role and the layout
// role, whichever modules provide them. The test starts the app once, since
// the start-up of an app may not run twice, and each expectation gives its
// reason.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/auth/app_session.dart';
import 'package:{{app_name}}/features/sign_in/sign_in_widgets.dart';

import 'app.dart';
import 'of_app.dart';

const _email = 'account@sign-in-tests.example.com';
const _password = 'Account-2468';

/// The email address of another account, which the test signs in to while
/// the entry of the first one is on the screen.
const _otherEmail = 'other-account@sign-in-tests.example.com';

/// Whether everyone may use the app, which then asks for an account only
/// where a screen needs one.
bool get _open => authMode != AuthMode.required;

/// What the session says of a user without an account in the mode of the
/// app.
String get _withoutAccount =>
    authMode == AuthMode.anonymous ? 'an anonymous user' : 'nobody';

/// Signs in to the account of the test through the session, as a screen of
/// the sign-in does, and waits for the screen.
Future<void> _signIn(WidgetTester tester) async {
  await appSession.signIn(email: _email, password: _password);
  await tester.pumpAndSettle();
}

/// Opens the screen of the account from its entry on the settings screen.
Future<void> _openAccount(WidgetTester tester) async {
  await openSettings(tester);
  await tester.tap(accountRow);
  await tester.pumpAndSettle();
}

/// Taps [target] and shows the frames of the next half a second, without
/// waiting for a call that is on its way.
Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.tap(target);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// Checks what the entry of the account on the settings screen, which the
/// user sees, shows below its title: [value].
void _expectRow(String value, String when) {
  expect(
    shownSettingsScreen,
    findsOneWidget,
    reason: '$when, the user is on the settings screen.',
  );
  expect(
    [
      for (final shown in [text('accountTitle'), find.text(value)])
        find.descendant(of: accountRow, matching: shown).evaluate().length,
    ],
    [1, 1],
    reason: '$when, the entry of the account on the settings screen shows '
        'its title and "$value".',
  );
}

/// Whether the button of [action], an action of the screen of the account,
/// takes a tap.
bool _takesTap<T extends ButtonStyleButton>(
  WidgetTester tester,
  Finder action,
) =>
    tester
        .widget<T>(find.descendant(of: action, matching: find.byType(T)))
        .onPressed !=
    null;

/// Whether [action], an action of the screen of the account, shows that its
/// call is on its way.
bool _spins(Finder action) => find
    .descendant(of: action, matching: find.byType(CircularProgressIndicator))
    .evaluate()
    .isNotEmpty;

/// Checks that the user has no account and is where the mode of the app
/// says, once [what] took the account: on the settings screen in an app
/// that everyone may use, and on the sign-in, in place of every screen, in
/// an app that asks for an account. No page of the account is left, and
/// no sheet, and in an app that everyone may use the pages below the
/// settings screen are as before the screen of the account was opened: the
/// root navigator can pop if it [couldPop] then. The session has [session],
/// which is what the mode of the app says of a user without an account
/// unless it is given.
void _expectWithoutAccount(
  WidgetTester tester,
  String what, {
  required bool couldPop,
  String? session,
}) {
  expect(
    sessionNow(),
    session ?? _withoutAccount,
    reason: 'Once $what, the session has ${session ?? _withoutAccount}, in '
        'the mode ${authMode.name}.',
  );
  expect(
    (builtAccountScreen.evaluate().length, deleteSheet.evaluate().length),
    (0, 0),
    reason: 'Once $what, the router has closed the page of the account, '
        'with what was open over it: the screen closes nothing itself.',
  );
  if (_open) {
    _expectRow(texts['notSignedIn']!, 'Once $what');
    expect(
      anySignInScreen,
      findsNothing,
      reason: 'Once $what, an app that everyone may use shows no sign-in.',
    );
    expect(
      rootCanPop(tester),
      couldPop,
      reason: 'Once $what, the pages below the settings screen are as '
          'they were before the screen of the account was opened: the '
          'router closed the page of the account, and the screen closed no '
          'page itself.',
    );
  } else {
    expect(
      (signInScreen.evaluate().length, builtSettingsScreen.evaluate().length),
      (1, 0),
      reason: 'Once $what, an app that asks for an account shows the '
          'sign-in in place of every screen.',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // A tap that reaches no widget fails the test where it misses.
  WidgetController.hitTestWarningShouldBeFatal = true;

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the entry of the settings screen leads to the screen of the account, '
    'through the sign-in for a user without one; a sign-out and a deletion, '
    'which asks first, go through the session, and the router closes the '
    'screen, also under an open sheet when the session ends elsewhere',
    (tester) async {
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      useTallPhone(tester);
      final languages = signInTexts.keys.toList();
      await useLanguage(tester, languages.first);
      await startApp(tester);
      final service = ScriptedAuthService();
      await appSession.start(service);
      await tester.pumpAndSettle();
      await _signIn(tester);
      final uid = appSession.value.uid;

      // The entry and the screen, in each language of the app.
      await openSettings(tester);
      final couldPop = rootCanPop(tester);
      if (!settingsInMainNavigation) {
        expect(
          (couldPop, builtStartScreen.evaluate().length),
          (true, 1),
          reason: 'Where the settings screen is no destination of the main '
              'navigation, the test opens it over the screen that the app '
              'starts on.',
        );
      }
      for (final language in languages) {
        await useLanguage(tester, language);
        _expectRow(_email, 'With an account, in $language');
      }

      // The entry follows the session while it is on the screen: another
      // account, with no sign-out in between, and the first one again.
      await useLanguage(tester, languages.first);
      await appSession.signUp(email: _otherEmail, password: _password);
      await tester.pumpAndSettle();
      _expectRow(
        _otherEmail,
        'Once another account is signed in, with the entry on the screen',
      );
      await appSession.signIn(email: _email, password: _password);
      await tester.pumpAndSettle();
      _expectRow(_email, 'Once the first account is signed in again');
      await tester.tap(accountRow);
      await tester.pumpAndSettle();
      expect(
        (
          accountScreen.evaluate().length,
          builtSettingsScreen.evaluate().length
        ),
        (1, 1),
        reason: 'A tap on the entry shows the screen of the account over '
            'the settings screen.',
      );
      for (final language in languages) {
        await useLanguage(tester, language);
        expect(
          [
            text('signedInAs').evaluate().length,
            find.widgetWithText(EmailAddress, _email).evaluate().length,
            find
                .widgetWithText(SubmitButton, texts['signOut']!)
                .evaluate()
                .length,
            find
                .widgetWithText(DestructiveAction, texts['deleteAccount']!)
                .evaluate()
                .length,
          ],
          [1, 1, 1, 1],
          reason: 'The screen of the account shows the address of the '
              'account, the button that signs out and the action that '
              'deletes the account, in $language.',
        );
      }
      await useLanguage(tester, languages.first);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      _expectRow(_email, 'Back from the screen of the account');
      expect(
        (builtAccountScreen.evaluate().length, rootCanPop(tester)),
        (0, couldPop),
        reason: 'The button of the app bar of the screen of the account '
            'leads back to the settings screen, with the pages that were '
            'below it.',
      );

      // A sign-out: the button shows the call, and neither action takes a
      // tap while it is on its way.
      await tester.tap(accountRow);
      await tester.pumpAndSettle();
      var hold = service.hold = Completer<void>();
      var calls = service.calls.length;
      await _tap(tester, submitButton);
      expect(
        (
          service.calls.sublist(calls).join(', '),
          _spins(submitButton),
          _takesTap<TextButton>(tester, deleteAction),
        ),
        ('signOut', true, false),
        reason: 'While the sign-out is on its way, its button spins and '
            'the action that deletes the account takes no tap.',
      );
      await _tap(tester, submitButton);
      expect(
        service.calls.length - calls,
        1,
        reason: 'A tap on the button while the sign-out is on its way '
            'makes no second call.',
      );
      hold.complete();
      service.hold = null;
      await tester.pumpAndSettle();
      expect(
        service.calls.length - calls,
        authMode == AuthMode.anonymous ? 2 : 1,
        reason: 'The screen signs out through the session, once; in an '
            'app that signs an anonymous user in, the session then does.',
      );
      _expectWithoutAccount(
        tester,
        'the user has signed out',
        couldPop: couldPop,
      );

      // Back to an account.
      if (_open) {
        // The entry asks for the route of the account: the router shows
        // the sign-in over the settings screen first.
        final guest = appSession.value.uid;
        await tester.tap(accountRow);
        await tester.pumpAndSettle();
        expect(
          (
            signInScreen.evaluate().length,
            builtSettingsScreen.evaluate().length
          ),
          (1, 1),
          reason: 'For a user without an account, a tap on the entry shows '
              'the sign-in over the settings screen.',
        );
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        _expectRow(texts['notSignedIn']!, 'Back from that sign-in');
        expect(
          (
            anySignInScreen.evaluate().length,
            builtAccountScreen.evaluate().length,
            rootCanPop(tester),
          ),
          (0, 0, couldPop),
          reason: 'Back from the sign-in returns to the settings screen, '
              'and the screen of the account does not show.',
        );
        await tester.tap(accountRow);
        await tester.pumpAndSettle();
        if (authMode == AuthMode.anonymous) {
          // The anonymous user gets the account, on the screen that creates
          // one.
          await tester.tap(otherScreenAction);
          await tester.pumpAndSettle();
        }
        await fill(tester, email: _email, password: _password);
        await _tap(tester, submitButton);
        await tester.pumpAndSettle();
        expect(
          sessionNow(),
          'the account of $_email',
          reason: 'The screens of the sign-in give the user the account.',
        );
        if (authMode == AuthMode.anonymous) {
          expect(
            appSession.value.uid,
            guest,
            reason: 'An anonymous user who signs up from the settings '
                'screen keeps the id.',
          );
        }
        expect(
          [
            accountScreen.evaluate().length,
            builtSettingsScreen.evaluate().length,
            anySignInScreen.evaluate().length,
          ],
          [1, 1, 0],
          reason: 'Once the user has an account, the router closes the '
              'sign-in and shows the screen of the account, which the '
              'entry asked for, over the settings screen.',
        );
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        _expectRow(_email, 'Back from the screen of the account');
        expect(
          rootCanPop(tester),
          couldPop,
          reason: 'No page of the sign-in is left below the settings '
              'screen.',
        );
        await tester.tap(accountRow);
        await tester.pumpAndSettle();
      } else {
        await fill(tester, email: _email, password: _password);
        await _tap(tester, submitButton);
        await tester.pumpAndSettle();
        await _openAccount(tester);
      }
      expect(
        accountScreen,
        findsOneWidget,
        reason: 'With an account again, the entry shows the screen of the '
            'account.',
      );

      // Code of the app signs the user in again as soon as the session has
      // no account, as an app does that keeps its user signed in. The
      // router has closed the page of the account by then, and the screen
      // that the user opens next is not busy.
      var signedInAgain = false;
      void signInAgain() {
        if (appSession.hasAccount.value) return;
        appSession.removeListener(signInAgain);
        unawaited(
          appSession
              .signIn(email: _email, password: _password)
              .whenComplete(() => signedInAgain = true),
        );
      }

      appSession.addListener(signInAgain);
      addTearDown(() => appSession.removeListener(signInAgain));
      await _tap(tester, submitButton);
      await tester.pumpAndSettle();
      expect(
        (signedInAgain, sessionNow()),
        (true, 'the account of $_email'),
        reason: 'Code of the app has signed the user in again in the turn '
            'of the sign-out.',
      );
      expect(
        (
          builtAccountScreen.evaluate().length,
          anySignInScreen.evaluate().length,
          find.byType(CircularProgressIndicator).evaluate().length,
        ),
        (0, 0, 0),
        reason: 'The router closed the page of the account when the session '
            'had no account, and nothing of the sign-out is left: no page '
            'of the account, no sign-in, and nothing that spins.',
      );
      if (_open) {
        _expectRow(_email, 'Once that user is signed in again');
      } else {
        expect(
          builtStartScreen,
          findsOneWidget,
          reason: 'In an app that asks for an account, a user who is signed '
              'in again is on the screen that the app starts on: the gate '
              'brings nobody back to a page.',
        );
      }
      await _openAccount(tester);
      expect(
        (
          accountScreen.evaluate().length,
          _spins(submitButton),
          _takesTap<FilledButton>(tester, submitButton),
          _takesTap<TextButton>(tester, deleteAction),
        ),
        (1, false, true, true),
        reason: 'The screen of the account that the user opens then is not '
            'busy: both of its actions take a tap.',
      );

      // The deletion asks first, in each language, and the way out of the
      // sheet deletes nothing.
      calls = service.calls.length;
      await tester.tap(deleteAction);
      await tester.pumpAndSettle();
      for (final language in languages) {
        await useLanguage(tester, language);
        expect(
          [
            inDeleteSheet(text('deleteTitle')).evaluate().length,
            inDeleteSheet(text('deleteText')).evaluate().length,
            inDeleteSheet(find.widgetWithText(FilledButton, texts['delete']!))
                .evaluate()
                .length,
            inDeleteSheet(find.widgetWithText(TextButton, texts['cancel']!))
                .evaluate()
                .length,
          ],
          [1, 1, 1, 1],
          reason: 'The sheet asks whether to delete the account, with the '
              'button that deletes and the way out, in $language.',
        );
      }
      await useLanguage(tester, languages.first);
      await tester.tap(inDeleteSheet(find.byType(TextButton)));
      await tester.pumpAndSettle();
      expect(
        [
          deleteSheet.evaluate().length,
          accountScreen.evaluate().length,
          service.calls.length - calls,
        ],
        [0, 1, 0],
        reason: 'The way out of the sheet closes it and deletes nothing.',
      );

      // The back button of the system and a tap outside the sheet close it
      // too, and delete nothing.
      for (final (dismiss, how) in <(Future<bool> Function(), String)>[
        (() => pressSystemBack(tester), 'The back button of the system'),
        (
          () async {
            // Above the sheet, which leaves room there on the phone of the
            // test.
            final sheet = tester.getRect(deleteSheet);
            await tester.tapAt(Offset(sheet.center.dx, sheet.top / 2));
            await tester.pumpAndSettle();
            return sheet.top > 0;
          },
          'A tap outside the sheet',
        ),
      ]) {
        await tester.tap(deleteAction);
        await tester.pumpAndSettle();
        expect(
          deleteSheet,
          findsOneWidget,
          reason: 'The action that deletes the account opens the sheet.',
        );
        expect(
          (
            await dismiss(),
            deleteSheet.evaluate().length,
            accountScreen.evaluate().length,
            service.calls.length - calls,
            sessionNow(),
          ),
          (true, 0, 1, 0, 'the account of $_email'),
          reason: '$how closes the sheet that asks before a deletion: the '
              'app handles it, deletes nothing, and the user is on the '
              'screen of the account.',
        );
      }

      // A deletion that fails leaves the screen, with the text of the
      // failure.
      service.failure = const AuthFailure(
        AuthFailureReason.recentSignInRequired,
      );
      await tester.tap(deleteAction);
      await tester.pumpAndSettle();
      await tester.tap(inDeleteSheet(find.byType(FilledButton)));
      await tester.pumpAndSettle();
      expect(
        (
          service.calls.last,
          failureMessage(AuthFailureReason.recentSignInRequired)
              .evaluate()
              .length,
          deleteSheet.evaluate().length,
          accountScreen.evaluate().length,
          sessionNow(),
        ),
        ('deleteAccount', 1, 0, 1, 'the account of $_email'),
        reason: 'A deletion that needs a recent sign-in leaves the user on '
            'the screen of the account, which tells to sign out and sign '
            'in again.',
      );
      service.failure = null;

      // A deletion: the sheet is closed before the call, and the action
      // shows the call.
      hold = service.hold = Completer<void>();
      calls = service.calls.length;
      await tester.tap(deleteAction);
      await tester.pumpAndSettle();
      await _tap(tester, inDeleteSheet(find.byType(FilledButton)));
      expect(
        (
          service.calls.sublist(calls).join(', '),
          deleteSheet.evaluate().length,
          _spins(deleteAction),
          _takesTap<FilledButton>(tester, submitButton),
        ),
        ('deleteAccount', 0, true, false),
        reason: 'The sheet is closed before the account is deleted. While '
            'the deletion is on its way, its action spins and the button '
            'that signs out takes no tap.',
      );
      hold.complete();
      service.hold = null;
      await tester.pumpAndSettle();
      _expectWithoutAccount(
        tester,
        'the account is deleted',
        couldPop: couldPop,
      );
      if (authMode == AuthMode.anonymous) {
        expect(
          appSession.value.uid,
          isNot(uid),
          reason: 'After the deletion, an app that signs an anonymous user '
              'in has a new one.',
        );
      }

      // The session ends elsewhere while the sheet is open: the sheet goes
      // with the page under it.
      if (!_open) {
        await fill(tester, email: _email, password: _password);
        await _tap(tester, submitButton);
        await tester.pumpAndSettle();
      } else {
        await _signIn(tester);
      }
      await _openAccount(tester);
      await tester.tap(deleteAction);
      await tester.pumpAndSettle();
      expect(
        deleteSheet,
        findsOneWidget,
        reason: 'The sheet is open over the screen of the account.',
      );
      calls = service.calls.length;
      service.endSession();
      await tester.pumpAndSettle();
      // No call of the app left the user signed out, so no anonymous
      // sign-in follows, in any mode.
      _expectWithoutAccount(
        tester,
        'the session has ended elsewhere while the sheet was open',
        couldPop: couldPop,
        session: 'nobody',
      );
      expect(
        (_open ? rootCanPop(tester) : couldPop, service.calls.length - calls),
        (couldPop, 0),
        reason: 'No page and no sheet is left over the settings screen, and '
            'the session called nothing: it only followed its service.',
      );

      // The user comes back to the app: one that signs an anonymous user in
      // does so again, and the user stays where the router left them.
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      _expectWithoutAccount(
        tester,
        'the user has come back to the app after that',
        couldPop: couldPop,
        session: _withoutAccount,
      );
      expect(
        (
          _open ? rootCanPop(tester) : couldPop,
          service.calls.sublist(calls).join(', '),
        ),
        (couldPop, authMode == AuthMode.anonymous ? 'signInAnonymously' : ''),
        reason: 'Once the user has come back, an app that signs an '
            'anonymous user in has done so, and no other app has called '
            'its service; no page was opened or closed for it.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
