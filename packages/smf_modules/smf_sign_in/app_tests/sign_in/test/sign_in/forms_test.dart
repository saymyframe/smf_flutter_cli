// A test that continuous integration runs in the apps with the sign-in
// module, in each mode of the auth role: what the forms of the three
// screens of the sign-in do with what the user types and with what a call
// answers. The session of the app gets a service of the test, which says
// what each call does (ScriptedAuthService), so the test sees every failure
// that a call can have, and a call that is on its way.
//
// A form tells of an email address and a password that are missing, and of an
// address that is none, without a call. A call gets the address without the
// spaces around it. While it is on its way, the button of the form spins, and
// neither the form nor an action of the screen takes input, a tap or the
// keyboard, so a second tap makes no second call. A field that has the focus
// keeps it, and takes typing again once the call has failed. A call that fails
// leaves the form as it was, with the text of the app for the reason of the
// failure, in each language of the app, and with what the provider says to the
// developer of the app, which a debug build shows. The screen that creates an
// account calls the session, which gives an anonymous user the account. The
// screen that resets a password tells where the message went. And the button
// of the field of a password shows and hides it.
//
// Above the form, the sign-in and the sign-up show a button for each way to
// sign in of the app that works on the platform that the app runs on, in the
// order of appSignInMethods, as wide as the button of the form and at least
// as tall, with "or" between them and the form, and a line of text that asks
// how to sign in. A screen reader reads each as one button with its label. A
// tap calls the way to sign in, whose module answers with its mocks, and
// gives the credential to the session: the router leaves the sign-in, and
// an anonymous user keeps the id. While the call is on its way, its button
// spins, and neither another button nor the form takes a tap; in an app that
// asks for less motion the button is disabled with its label instead. A
// call that failed shows its failure below the buttons, not above the button
// of the form. An app without ways to sign in shows no button and no "or".
// When the user closes the sheet of a way to sign in, the screen is as it
// was before the tap: the mocks of a way to sign in always give a
// credential, so the tests of the package of the module check that, with a
// way to sign in of their own.
//
// The matrix writes of_app.dart next to this file, with the texts of the
// module in each language of the app. The test starts the app once, since
// the start-up of an app may not run twice, and each expectation gives its
// reason.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/auth/app_session.dart';
import 'package:{{app_name}}/core/auth/sign_in_methods.dart';
import 'package:{{app_name}}/features/sign_in/sign_in_widgets.dart';

import 'app.dart';
import 'of_app.dart';

const _email = 'forms@sign-in-tests.example.com';
const _password = 'Forms-2468';

/// What the provider of sign-in says to the developer of the app about a
/// failure, in the tests.
const _hint = 'The provider says: enable this way to sign in.';

/// The texts of the mistakes that the fields of the form that the user sees
/// show below them.
List<String> _mistakes(WidgetTester tester) => tester
    .stateList<FormFieldState<String>>(find.byType(TextFormField))
    .map((field) => field.errorText)
    .nonNulls
    .toList();

/// What the form that the user sees has in its fields.
List<String> _typed(WidgetTester tester) => [
      for (final field in tester.widgetList<EditableText>(
        find.byType(EditableText),
      ))
        field.controller.text,
    ];

/// Taps the button of the form that the user sees and shows the frames
/// until what the tap started has settled, but for a call that is on its
/// way, whose button spins for as long as it takes.
Future<void> _submit(WidgetTester tester) async {
  await tester.tap(submitButton);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Whether the button of the form that the user sees shows that a call is
/// on its way.
bool _spins(WidgetTester tester) => submitSpins();

/// The field of the email address of the form that the user sees, as the
/// keyboard has it.
EditableText _emailInput(WidgetTester tester) => tester.widget<EditableText>(
      find.descendant(of: emailField, matching: find.byType(EditableText)),
    );

/// Checks the form that the user sees, which [screen] names, with a call
/// that [service] holds back: it shows that the call is on its way and
/// takes no input, and a second tap on its button makes no second call.
/// Then the call fails, and the form is as it was, with the message.
Future<void> _expectBusyUntilTheCallEnds(
  WidgetTester tester,
  ScriptedAuthService service,
  String screen,
) async {
  final hold = service.hold = Completer<void>();
  service.failure = const AuthFailure(AuthFailureReason.network);
  final calls = service.calls.length;
  final typed = _typed(tester);
  // The field of the address has the focus, as for a user who submits
  // with the keyboard open.
  await tester.showKeyboard(emailField);
  await tester.pump();
  await _submit(tester);
  expect(
    (
      _emailInput(tester).focusNode.hasFocus,
      _emailInput(tester).readOnly,
      tester.testTextInput.hasAnyClients,
    ),
    (true, true, false),
    reason: 'While a call of $screen is on its way, a field that has the '
        'focus keeps it and takes no typing: the keyboard has no field to '
        'type into.',
  );

  expect(
    (service.calls.length - calls, _spins(tester)),
    (1, true),
    reason: 'While a call of $screen is on its way, its button spins.',
  );
  expect(
    [
      for (final form in tester.widgetList<AbsorbPointer>(
        find.ancestor(
          of: find.byType(TextFormField),
          matching: find.byType(AbsorbPointer),
        ),
      ))
        form.absorbing,
    ],
    contains(true),
    reason: 'While a call of $screen is on its way, its form takes no '
        'input.',
  );
  final forgot = find.widgetWithText(TextButton, texts['forgotPassword']!);
  if (forgot.evaluate().isNotEmpty) {
    expect(
      tester.widget<TextButton>(forgot).onPressed,
      isNull,
      reason: 'While a call of $screen is on its way, the action at the '
          'field of the password takes neither a tap nor a key.',
    );
  }
  if (otherScreenAction.evaluate().isNotEmpty) {
    expect(
      tester
          .widget<TextButton>(
            find.descendant(
              of: otherScreenAction,
              matching: find.byType(TextButton),
            ),
          )
          .onPressed,
      isNull,
      reason: 'While a call of $screen is on its way, the action that leads '
          'to the other screen takes no tap.',
    );
  }
  await _submit(tester);
  expect(
    service.calls.length - calls,
    1,
    reason: 'A tap on the button of $screen while its call is on its way '
        'makes no second call.',
  );

  hold.complete();
  service.hold = null;
  await tester.pumpAndSettle();
  expect(
    (
      _emailInput(tester).focusNode.hasFocus,
      _emailInput(tester).readOnly,
      tester.testTextInput.hasAnyClients,
    ),
    (true, false, true),
    reason: 'Once a call of $screen has failed, the field that had the '
        'focus still has it and takes typing again.',
  );
  expect(
    service.calls.length - calls,
    1,
    reason: 'A tap on the button of $screen while its call is on its way '
        'makes no call that waits for the first one either: the session '
        'would make it once that one has ended.',
  );
  expect(
    _spins(tester),
    isFalse,
    reason: 'Once a call of $screen has failed, its button spins no more.',
  );
  expect(
    _typed(tester),
    typed,
    reason: 'A call of $screen that failed leaves the form with what the '
        'user typed.',
  );
  expect(
    failureMessage(AuthFailureReason.network),
    findsOneWidget,
    reason: 'A call of $screen that failed tells why.',
  );
  service.failure = null;
}

/// Checks the buttons of the ways to sign in of the screen that the user
/// sees, which [screen] names, on [platform]: one for each way to sign in
/// that works there, in their order, above the form, with "or" between them
/// and the form, and the line of text [methodsIntro] in place of [intro]. A
/// screen reader reads each as one button with its label. Without such ways
/// to sign in, the screen shows no button, no "or" and the text [intro].
void _expectMethods(
  WidgetTester tester,
  String screen,
  TargetPlatform platform, {
  required String intro,
  required String methodsIntro,
}) {
  final methods = methodsHere();
  final buttons = find.byType(SignInMethodButton);
  final where = '$screen on ${platform.name}';
  if (methods.isEmpty) {
    expect(
      (
        buttons.evaluate().length,
        text('or').evaluate().length,
        text(intro).evaluate().length,
      ),
      (0, 0, 1),
      reason: 'In an app without a way to sign in that works on '
          '${platform.name}, $screen shows no button of a way to sign in, no '
          '"or", and the line of text "${texts[intro]}".',
    );
    return;
  }
  expect(
    [
      for (final button in tester.widgetList<SignInMethodButton>(buttons))
        button.method.issuer,
    ],
    [for (final method in methods) method.issuer],
    reason: '$where shows a button for each way to sign in that works there, '
        'in the order of appSignInMethods.',
  );
  expect(
    (text(methodsIntro).evaluate().length, text(intro).evaluate().length),
    (1, 0),
    reason: 'With buttons of ways to sign in, $screen asks how to sign in: '
        '"${texts[methodsIntro]}".',
  );
  final submit = tester.getRect(buttonIn(submitButton));
  final or = tester.getRect(text('or'));
  final email = tester.getRect(emailField);
  var above = tester.getRect(text(methodsIntro)).bottom;
  for (final method in methods) {
    final rect = tester.getRect(buttonIn(methodButton(method)));
    final label = method.label(tester.element(methodButton(method)));
    expect(
      (
        rect.top >= above,
        rect.bottom < or.top,
        rect.left,
        rect.width,
        rect.height >= submit.height,
      ),
      (true, true, submit.left, submit.width, true),
      reason: 'On $where, the button "$label" is below the one before it, '
          'above "or" and the form, as wide as the button of the form and at '
          'least as tall: it is at $rect, and the button of the form at '
          '$submit.',
    );
    expect(
      tester.getSemantics(buttonIn(methodButton(method))),
      isSemantics(
        label: label,
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        isFocusable: true,
      ),
      reason: 'A screen reader reads the button of a way to sign in as one '
          'button with its label, "$label", on $where: its icon adds nothing.',
    );
    above = rect.bottom;
  }
  expect(
    or.bottom < email.top,
    isTrue,
    reason: 'On $where, "or" is between the buttons of the ways to sign in '
        'and the form.',
  );
}

/// Checks the button of [method] on the screen that the user sees, which
/// [screen] names, with a call that [service] holds back and then fails:
/// while the call is on its way, the button spins, or in an app that asks
/// for less motion is disabled with its label, and no other button and no
/// form takes a tap. Then the failure shows below the buttons of the ways
/// to sign in, and the screen stays as it was.
Future<void> _expectBusyMethod(
  WidgetTester tester,
  ScriptedAuthService service,
  SignInMethod method,
  String screen, {
  required bool lessMotion,
}) async {
  final hold = service.hold = Completer<void>();
  service.failure = const AuthFailure(AuthFailureReason.network);
  final calls = service.calls.length;
  final session = sessionNow();
  final button = methodButton(method);
  final label = method.label(tester.element(button));
  // An anonymous user gets the identity of the credential with the same id.
  final call = authMode == AuthMode.anonymous ? 'linkWith' : 'signInWith';
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  final spins = find
      .descendant(of: button, matching: find.byType(CircularProgressIndicator))
      .evaluate()
      .isNotEmpty;
  expect(
    (
      service.calls.sublist(calls).join(', '),
      spins,
      tester.widget<FilledButton>(buttonIn(button)).onPressed != null,
      find.descendant(of: button, matching: find.text(label)).evaluate().length,
    ),
    (
      '$call ${method.issuer}',
      !lessMotion,
      !lessMotion,
      1,
    ),
    reason: lessMotion
        ? 'In an app that asks for less motion, the button "$label" of '
            '$screen whose call is on its way takes no tap and keeps its '
            'label, and does not spin.'
        : 'While the call of the button "$label" of $screen is on its way, '
            'the button spins and keeps its colours: it does nothing on a '
            'tap. The call gives the credential of the way to sign in to '
            'the session.',
  );
  expect(
    [
      for (final other in tester.widgetList<SignInMethodButton>(
        find.byType(SignInMethodButton),
      ))
        if (other.method != method)
          tester
              .widget<FilledButton>(buttonIn(methodButton(other.method)))
              .onPressed,
      tester.widget<FilledButton>(buttonIn(submitButton)).onPressed,
    ],
    everyElement(isNull),
    reason: 'While the call of the button "$label" of $screen is on its way, '
        'no other button of a way to sign in and not the button of the form '
        'takes a tap.',
  );
  expect(
    tester
        .widgetList<AbsorbPointer>(
          find.ancestor(
            of: find.byType(TextFormField),
            matching: find.byType(AbsorbPointer),
          ),
        )
        .map((form) => form.absorbing),
    contains(true),
    reason: 'While the call of a way to sign in of $screen is on its way, '
        'the form takes no input.',
  );
  await tester.tap(button, warnIfMissed: false);
  await tester.pump();
  expect(
    service.calls.length - calls,
    1,
    reason: 'A second tap on the button "$label" of $screen while its call '
        'is on its way makes no second call.',
  );
  hold.complete();
  service.hold = null;
  await tester.pumpAndSettle();
  final message = text(failureTextOf(AuthFailureReason.network));
  expect(
    (
      find
          .descendant(of: find.byType(SignInMethods), matching: message)
          .evaluate()
          .length,
      failureMessage(AuthFailureReason.network).evaluate().length,
      sessionNow(),
    ),
    (1, 1, session),
    reason: 'A call of the button "$label" of $screen that failed shows its '
        'failure below the buttons of the ways to sign in, and not above '
        'the button of the form, and leaves the session as it was.',
  );
  service.failure = null;
}

/// Checks the buttons of the ways to sign in of the sign-in and of the
/// sign-up, on Android and on iOS, with the calls that [service] answers:
/// where they are, what a screen reader reads, a call that is on its way
/// and one that fails, also in an app that asks for less motion, and a
/// sign-in with each way to sign in, which the router leaves, and which
/// gives an anonymous user the identity with the same id.
Future<void> _expectWaysToSignIn(
  WidgetTester tester,
  ScriptedAuthService service,
) async {
  // The sign-in, for a user without an account.
  await appSession.signOut();
  await tester.pumpAndSettle();
  if (authMode != AuthMode.required) await pushSignIn(tester);

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    await usePlatform(tester, platform);
    _expectMethods(
      tester,
      'the sign-in',
      platform,
      intro: 'intro',
      methodsIntro: 'methodsIntro',
    );
    for (final method in methodsHere()) {
      await _expectBusyMethod(
        tester,
        service,
        method,
        'the sign-in',
        lessMotion: false,
      );
    }
    await tester.tap(otherScreenAction);
    await tester.pumpAndSettle();
    _expectMethods(
      tester,
      'the screen that creates an account',
      platform,
      intro: 'signUpIntro',
      methodsIntro: 'signUpMethodsIntro',
    );
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    for (final method in methodsHere()) {
      await _expectBusyMethod(
        tester,
        service,
        method,
        'the screen that creates an account',
        lessMotion: true,
      );
    }
    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // A sign-in with each way to sign in: the router leaves the
    // sign-in, and an anonymous user keeps the id.
    for (final method in methodsHere()) {
      final before = appSession.value;
      await tester.tap(methodButton(method));
      await tester.pumpAndSettle();
      final after = appSession.value;
      expect(
        (
          after is AccountSession && after.issuers.contains(method.issuer),
          after.uid == before.uid,
        ),
        (true, before is AnonymousSession),
        reason: 'A tap on the button of the way to sign in of '
            '${method.issuer} gives the session the account of its '
            'identity, and an anonymous user keeps the id.',
      );
      expect(
        (
          anySignInScreen.evaluate().length,
          find.byType(startScreen).evaluate().length,
        ),
        (0, 1),
        reason: 'Once the user has an account through a way to sign in, '
            'the router leaves the sign-in, and the app shows the screen '
            'that it starts on: no screen closes itself.',
      );
      await appSession.signOut();
      await tester.pumpAndSettle();
      if (authMode != AuthMode.required) await pushSignIn(tester);
    }
  }
  await usePlatform(tester, null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // A tap that reaches no widget fails the test where it misses.
  WidgetController.hitTestWarningShouldBeFatal = true;

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the forms of the sign-in tell of what is missing without a call, show '
    'that a call is on its way and take no input then, show the text of the '
    'app for each failure of a call in each language of the app, and tell '
    'where the message of a password reset went; the buttons of the ways to '
    'sign in of the platform are above the form, a tap gives the credential '
    'of a way to sign in to the session, a call that is on its way spins in '
    'its button and takes no other tap, and its failure shows below the '
    'buttons',
    (tester) async {
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      useTallPhone(tester);
      final languages = signInTexts.keys.toList();
      await useLanguage(tester, languages.first);
      await startApp(tester);
      final service = ScriptedAuthService();
      await showSignInWith(tester, service);
      expect(
        signInScreen,
        findsOneWidget,
        reason: 'With nobody signed in to an account, the app shows the '
            'sign-in: in place of its screens when it asks for an account, '
            'and otherwise once code asks for it.',
      );
      // The call that gives the user an account from the screen that
      // creates one: in an app that signs an anonymous user in, the session
      // gives that user the account.
      final signUpCall =
          authMode == AuthMode.anonymous ? 'linkPassword' : 'signUp';
      final calls = service.calls.length;

      // What is missing, and an address that is none, in each language.
      for (final language in languages) {
        await useLanguage(tester, language);
        await fill(tester, email: '', password: '');
        await _submit(tester);
        expect(
          _mistakes(tester),
          [texts['emailRequired'], texts['passwordRequired']],
          reason: 'A form without an email address and a password tells of '
              'both below their fields, in $language.',
        );
        await fill(tester, email: 'no address');
        await tester.pump();
        expect(
          _mistakes(tester),
          [texts['emailInvalid'], texts['passwordRequired']],
          reason: 'Once it was submitted, the form tells of an address '
              'without an @ as the user types, in $language.',
        );
        await fill(tester, email: _email, password: _password);
        await tester.pump();
        expect(
          _mistakes(tester),
          isEmpty,
          reason: 'A form with an address and a password has no mistake.',
        );
      }
      expect(
        service.calls.length,
        calls,
        reason: 'A form with a mistake makes no call.',
      );

      // The password, shown and hidden again.
      final password = find.descendant(
        of: passwordField,
        matching: find.byType(EditableText),
      );
      for (final (hidden, tooltip) in const [
        (false, 'showPassword'),
        (true, 'hidePassword'),
      ]) {
        await tester.tap(find.byTooltip(texts[tooltip]!));
        await tester.pump();
        expect(
          tester.widget<EditableText>(password).obscureText,
          hidden,
          reason: 'The button of the field of the password, which says '
              '"${texts[tooltip]}", ${hidden ? 'hides' : 'shows'} the '
              'password.',
        );
      }

      // Each failure of a call, in each language.
      for (final reason in AuthFailureReason.values) {
        // The provider explains only some failures to the developer.
        final hinted = reason == AuthFailureReason.notConfigured ||
            reason == AuthFailureReason.unknown;
        service.failure = AuthFailure(
          reason,
          developerHint: hinted ? '$_hint (${reason.name})' : null,
        );
        await fill(tester, email: '  $_email ', password: _password);
        await _submit(tester);
        await tester.pumpAndSettle();
        expect(
          service.calls.last,
          'signIn $_email',
          reason: 'The sign-in calls the session with the address that the '
              'user typed, without the spaces around it.',
        );
        for (final language in languages) {
          await useLanguage(tester, language);
          expect(
            failureMessage(reason),
            findsOneWidget,
            reason: 'A sign-in that failed with the reason ${reason.name} '
                'shows the text of the app for it, in $language: '
                '"${texts[failureTextOf(reason)]}".',
          );
        }
        expect(
          find.descendant(
            of: find.byType(FailureMessage),
            matching: find.textContaining(_hint),
          ),
          hinted ? findsOneWidget : findsNothing,
          reason: 'In a debug build, the message of a failure shows what '
              'the provider says to the developer of the app, if it says '
              'anything: here for the reason ${reason.name}.',
        );
        expect(
          (signInScreen.evaluate().length, sessionNow()),
          (1, authMode == AuthMode.anonymous ? 'an anonymous user' : 'nobody'),
          reason: 'A sign-in that failed leaves the user on the sign-in, '
              'and the session as it was.',
        );
      }
      await useLanguage(tester, languages.first);
      // The state of a screen outlives a rebuild of the screen: the last
      // failure is still shown.
      tester.element(signInScreen).markNeedsBuild();
      await tester.pump();
      expect(
        failureMessage(AuthFailureReason.values.last),
        findsOneWidget,
        reason: 'A screen of the sign-in keeps its state when it is built '
            'again: it creates what holds the state once.',
      );
      await _expectBusyUntilTheCallEnds(tester, service, 'the sign-in');

      // The screen that creates an account.
      final typedOnSignIn = _typed(tester);
      await tester.tap(otherScreenAction);
      await tester.pumpAndSettle();
      expect(
        signUpScreen,
        findsOneWidget,
        reason: 'The action below the button of the sign-in shows the '
            'screen that creates an account.',
      );
      expect(
        _typed(tester),
        ['', ''],
        reason: 'The screen that creates an account starts with an empty '
            'form.',
      );
      await _submit(tester);
      expect(
        _mistakes(tester),
        [texts['emailRequired'], texts['passwordRequired']],
        reason: 'The form that creates an account tells of what is missing '
            'too.',
      );
      for (final reason in const [
        AuthFailureReason.emailInUse,
        AuthFailureReason.weakPassword,
      ]) {
        service.failure = AuthFailure(reason);
        await fill(tester, email: ' $_email', password: _password);
        await _submit(tester);
        await tester.pumpAndSettle();
        expect(
          service.calls.last,
          '$signUpCall $_email',
          reason: 'The screen that creates an account calls signUp() of the '
              'session, in every mode of the app: for an anonymous user, '
              'the session gives the account to that user.',
        );
        expect(
          failureMessage(reason),
          findsOneWidget,
          reason: 'A sign-up that failed with the reason ${reason.name} '
              'shows the text of the app for it.',
        );
      }
      await _expectBusyUntilTheCallEnds(
        tester,
        service,
        'the screen that creates an account',
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(
        signInScreen,
        findsOneWidget,
        reason: 'The button of the app bar of the screen that creates an '
            'account leads back to the sign-in.',
      );
      expect(
        _typed(tester),
        typedOnSignIn,
        reason: 'The sign-in below the screen that creates an account keeps '
            'what the user typed.',
      );

      // The screen that resets a password.
      await tester.tap(
        find.widgetWithText(TextButton, texts['forgotPassword']!),
      );
      await tester.pumpAndSettle();
      await _submit(tester);
      expect(
        _mistakes(tester),
        [texts['emailRequired']],
        reason: 'The form that resets a password tells of an address that '
            'is missing.',
      );
      await fill(tester, email: ' $_email ');
      await _expectBusyUntilTheCallEnds(
        tester,
        service,
        'the screen that resets a password',
      );
      expect(
        (
          resetScreen.evaluate().length,
          find.byType(EmailAddress).evaluate().length,
        ),
        (1, 0),
        reason: 'A message that was not sent leaves the form of the password '
            'reset.',
      );
      await _submit(tester);
      await tester.pumpAndSettle();
      expect(
        service.calls.last,
        'sendPasswordReset $_email',
        reason: 'The screen that resets a password asks the session for the '
            'message, with the address without the spaces around it.',
      );
      for (final language in languages) {
        await useLanguage(tester, language);
        expect(
          (
            text('resetSentTitle').evaluate().length,
            text('resetSent').evaluate().length,
            find.widgetWithText(EmailAddress, _email).evaluate().length,
            find.byType(TextFormField).evaluate().length,
          ),
          (1, 1, 1, 0),
          reason: 'Once the message is sent, the screen says so in place of '
              'its form, with the address that the message went to, in '
              '$language.',
        );
      }
      await useLanguage(tester, languages.first);
      await tester.tap(
        find.widgetWithText(FilledButton, texts['backToSignIn']!),
      );
      await tester.pumpAndSettle();
      expect(
        (signInScreen.evaluate().length, resetScreen.evaluate().length),
        (1, 0),
        reason: 'The button below the address leads back to the sign-in.',
      );

      // A sign-in that succeeds: the router leaves the sign-in.
      await _submit(tester);
      await tester.pumpAndSettle();
      expect(
        (service.calls.last, sessionNow()),
        ('signIn $_email', 'the account of $_email'),
        reason: 'A sign-in that succeeds gives the session its account.',
      );
      expect(
        anySignInScreen,
        findsNothing,
        reason: 'Once the user has an account, the router leaves the '
            'screens of the sign-in: no screen closes itself.',
      );
      expect(
        find.byType(startScreen),
        findsOneWidget,
        reason: 'Once the user has an account, the app shows the screen '
            'that it starts on.',
      );

      await _expectWaysToSignIn(tester, service);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
