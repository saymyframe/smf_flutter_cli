// A test that continuous integration runs in the apps with the sign-in
// module, in each mode of the auth role: the three screens of the sign-in
// on a phone of 320 by 480 with insets and the text at three times its
// size, in each language of the app, and what they say to a screen reader
// and do for a user who asks for less motion.
//
// Nothing overflows there. Each page scrolls to its fields and its buttons,
// which keep to the screen and out of the insets. The message of a failure
// wraps what the provider says to the developer of the app, a long line
// with an address, so it pushes no button off the screen, and that text
// and the title of a page grow only by half, while the symbol in the cell
// of a page keeps its size, since the cell is a picture. A screen reader
// announces the title of a page as a header, each field with its label,
// and the message of a failure when it appears. The parts of a page come
// in one after another and then nothing moves. In an app that asks for
// less motion, the first frame of a page has them all in their places,
// the message of a failure takes its place at once, and the button of a
// form does not spin while its call is on its way.
//
// The session of the app gets a service of the test, which says what each
// call does (ScriptedAuthService). The phone is that small only while the
// sign-in is shown: whether the other screens of the app fit it is a
// matter for the tests of their own modules. The matrix writes of_app.dart
// next to this file, with the texts of the module in each language of the
// app. The test starts the app once, since the start-up of an app may not
// run twice, and each expectation gives its reason.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/auth/app_session.dart';
import 'package:{{app_name}}/features/sign_in/sign_in_widgets.dart';

import 'app.dart';
import 'of_app.dart';

/// The small phone of the test, and its inset at the top and at the bottom,
/// such as a notch and the bar of the home gesture.
const Size _phone = Size(320, 480);
const double _inset = 40;

const _email = 'small-phone@sign-in-tests.example.com';
const _password = 'Small-phone-2468';

/// What the provider of sign-in says to the developer of the app about a
/// failure, in the test: one long line, with an address that has no space
/// to wrap at.
const _hint = 'CONFIGURATION_NOT_FOUND: the way to sign in is not enabled '
    'for this project, enable it at '
    'https://console.provider.example.com/project/sign-in-tests/'
    'authentication/providers and start the app again';

/// The text of [finder], a text that the user sees, as it is laid out.
RenderParagraph _paragraphOf(WidgetTester tester, Finder finder) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(
        of: finder,
        matching: find.byType(RichText),
        matchRoot: true,
      ),
    );

/// Checks that the page that the user sees scrolls to [target], which
/// [what] names, on the small phone: to its top and to its bottom, each of
/// which is then on the screen, out of its insets. A text at three times
/// its size may make a button taller than the screen has room for at once.
Future<void> _expectReached(
  WidgetTester tester,
  Finder target,
  String what,
) async {
  final element = tester.element(target);
  await Scrollable.ensureVisible(element);
  await tester.pumpAndSettle();
  final atTop = tester.getRect(target);
  await Scrollable.ensureVisible(element, alignment: 1);
  await tester.pumpAndSettle();
  final atBottom = tester.getRect(target);
  expect(
    (atTop.left >= 0, atTop.right <= _phone.width),
    (true, true),
    reason: 'On a small phone with a large text size, $what keeps to the '
        'width of the screen: it is at $atTop.',
  );
  expect(
    (atTop.top >= _inset, atBottom.bottom <= _phone.height - _inset),
    (true, true),
    reason: 'On a small phone with a large text size, the page scrolls to '
        'the top of $what and to its bottom, each of which is then on the '
        'screen, out of its insets: it is at $atTop and then at $atBottom.',
  );
}

/// Taps [target] once the page that the user sees has scrolled to it, and
/// waits for the screen, on which no call is on its way.
Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// How far each part of the page of [screen] has come in, from 0 for a
/// part that is not shown yet to 1 for one that is there.
List<double> _entrance(WidgetTester tester, Finder screen) => [
      for (final part in tester.widgetList<Opacity>(
        find.descendant(of: screen, matching: find.byType(Opacity)),
      ))
        part.opacity,
    ];

/// The action at the field of the password of the sign-in, by its text in
/// the language that the device asks for.
Finder _forgotPassword() =>
    find.widgetWithText(TextButton, texts['forgotPassword']!);

/// The texts in the cell of the page that the user sees, as they are laid
/// out: the symbol of the app and its number. The cell is the box with a
/// border in the picture of the page.
List<RenderParagraph> _cellTexts(WidgetTester tester) {
  final cell = find.byWidgetPredicate(
    (widget) =>
        widget is Container &&
        switch (widget.decoration) {
          BoxDecoration(border: Border()) => true,
          _ => false,
        },
    description: 'the cell of the page',
  );
  return [
    for (final text in find
        .descendant(of: cell, matching: find.byType(RichText))
        .evaluate())
      text.renderObject! as RenderParagraph,
  ];
}

/// Checks the title of the page that the user sees, the text [title]: a
/// screen reader announces it as a header, and it grows only by half with
/// the text size of the device.
void _expectTitle(WidgetTester tester, String title, String language) {
  // The title comes first on its page, before a button with the same text.
  final shown = find.text(title).first;
  expect(
    tester.getSemantics(shown),
    isSemantics(label: title, isHeader: true),
    reason: 'A screen reader announces the title of a page of the sign-in '
        'as a header: "$title", in $language.',
  );
  expect(
    _paragraphOf(tester, shown).textScaler.scale(10),
    15,
    reason: 'The title of a page of the sign-in is large already, so it '
        'grows only by half with the text size of the device.',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // A tap that reaches no widget fails the test where it misses.
  WidgetController.hitTestWarningShouldBeFatal = true;

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the screens of the sign-in fit a small phone with a large text size in '
    'each language of the app, tell a screen reader of their titles, their '
    'fields and a failure, and keep still for a user who asks for less '
    'motion',
    (tester) async {
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final languages = signInTexts.keys.toList();
      await useLanguage(tester, languages.first);
      await startApp(tester);
      final service = ScriptedAuthService();
      await showSignInWith(tester, service);

      // The entrance of a page, before the phone gets small: the screen
      // that creates an account comes in over the sign-in.
      await tester.ensureVisible(otherScreenAction);
      await tester.pumpAndSettle();
      await tester.tap(otherScreenAction);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final entering = _entrance(tester, signUpScreen);
      await tester.pumpAndSettle();
      expect(
        (entering.first, entering.any((part) => part < 1)),
        (1, true),
        reason: 'The parts of a page of the sign-in come in one after '
            'another: half a second after its first frame, the first is '
            'there and another is not.',
      );
      expect(
        _entrance(tester, signUpScreen),
        allOf(hasLength(entering.length), everyElement(1.0)),
        reason: 'Once a page of the sign-in has come in, its parts are all '
            'there.',
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // The small phone, with the sign-in on it.
      const insets = FakeViewPadding(top: _inset, bottom: _inset);
      tester.view
        ..physicalSize = _phone
        ..devicePixelRatio = 1
        ..padding = insets
        ..viewPadding = insets;
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      await tester.pumpAndSettle();
      service.failure = const AuthFailure(
        AuthFailureReason.notConfigured,
        developerHint: _hint,
      );
      await fill(tester, email: _email, password: _password);
      await _tap(tester, submitButton);

      for (final language in languages) {
        await useLanguage(tester, language);

        // The sign-in, with the message of a failure.
        _expectTitle(tester, texts['title']!, language);
        for (final (field, label) in [
          (emailField, texts['email']!),
          (passwordField, texts['password']!),
        ]) {
          await _expectReached(tester, field, 'the field "$label"');
          expect(
            tester.getSemantics(
              find.descendant(of: field, matching: find.byType(TextField)),
            ),
            isSemantics(label: label, isTextField: true),
            reason: 'A screen reader announces a field of the sign-in with '
                'its label: "$label", in $language.',
          );
        }
        await _expectReached(
          tester,
          _forgotPassword(),
          'the action "${texts['forgotPassword']}"',
        );
        await _expectReached(
          tester,
          submitButton,
          'the button "${texts['submit']}", below the message of a failure',
        );
        await _expectReached(
          tester,
          otherScreenAction,
          'the action "${texts['createAccount']}"',
        );
        final message = failureMessage(AuthFailureReason.notConfigured);
        final hint = find.descendant(
          of: find.byType(FailureMessage),
          matching: find.text(_hint),
        );
        await tester.ensureVisible(message);
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(
            find.descendant(
              of: find.byType(FailureMessage),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics &&
                    (widget.properties.liveRegion ?? false),
                description: 'the live region of the message',
              ),
            ),
          ),
          isSemantics(isLiveRegion: true),
          reason: 'A screen reader announces the message of a failure when '
              'it appears.',
        );
        final hintBox = tester.getRect(hint);
        final hintText = _paragraphOf(tester, hint);
        expect(
          (hintBox.left >= 0, hintBox.right <= _phone.width),
          (true, true),
          reason: 'What the provider says to the developer of the app wraps '
              'in the message of a failure, also an address without a '
              'space: it is at $hintBox on a screen ${_phone.width} wide.',
        );
        expect(
          (
            hintText.textScaler.scale(10),
            hintBox.height > 3 * hintText.textScaler.scale(12),
          ),
          (15, true),
          reason: 'What the provider says to the developer of the app grows '
              'only by half with the text size of the device, and takes the '
              'lines that it needs.',
        );
        expect(
          [for (final text in _cellTexts(tester)) text.textScaler],
          [TextScaler.noScaling, TextScaler.noScaling],
          reason: 'The number and the symbol in the cell of a page keep '
              'their size: the cell is a picture, which does not grow with '
              'the text.',
        );

        // The screen that creates an account.
        await _tap(tester, otherScreenAction);
        expect(
          signUpScreen,
          findsOneWidget,
          reason: 'On the small phone, the action below the button of the '
              'sign-in shows the screen that creates an account.',
        );
        _expectTitle(tester, texts['signUpTitle']!, language);
        await _expectReached(tester, emailField, 'the field of the address');
        await _expectReached(
            tester, passwordField, 'the field of the password');
        await _expectReached(
          tester,
          submitButton,
          'the button "${texts['signUpSubmit']}"',
        );
        await _expectReached(
          tester,
          otherScreenAction,
          'the action "${texts['haveAccount']}"',
        );
        await _tap(tester, otherScreenAction);

        // The screen that resets a password, and what it says once the
        // message is sent.
        await _tap(tester, _forgotPassword());
        expect(
          resetScreen,
          findsOneWidget,
          reason: 'On the small phone, the action at the field of the '
              'password shows the screen that resets a password.',
        );
        _expectTitle(tester, texts['resetTitle']!, language);
        await _expectReached(tester, emailField, 'the field of the address');
        await _expectReached(
          tester,
          submitButton,
          'the button "${texts['sendLink']}"',
        );
        service.failure = null;
        await fill(tester, email: _email);
        await _tap(tester, submitButton);
        _expectTitle(tester, texts['resetSentTitle']!, language);
        await _expectReached(
          tester,
          find.byType(EmailAddress),
          'the address that the message went to',
        );
        final back = find.widgetWithText(FilledButton, texts['backToSignIn']!);
        await _expectReached(
          tester,
          back,
          'the button "${texts['backToSignIn']}"',
        );
        await _tap(tester, back);
        expect(
          signInScreen,
          findsOneWidget,
          reason: 'On the small phone, the button below the address leads '
              'back to the sign-in.',
        );
      }
      await useLanguage(tester, languages.first);

      // Less motion: a page is there at once, a failure takes its place at
      // once, and nothing spins.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      await tester.pumpAndSettle();
      await tester.ensureVisible(otherScreenAction);
      await tester.pumpAndSettle();
      await tester.tap(otherScreenAction);
      await tester.pump();
      await tester.pump();
      expect(
        _entrance(tester, signUpScreen),
        allOf(isNotEmpty, everyElement(1.0)),
        reason: 'In an app that asks for less motion, the first frame of a '
            'page of the sign-in has its parts in their places.',
      );
      await tester.pumpAndSettle();
      final hold = service.hold = Completer<void>();
      service.failure = const AuthFailure(AuthFailureReason.emailInUse);
      await fill(tester, email: _email, password: _password);
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final button = find.descendant(
        of: submitButton,
        matching: find.byType(FilledButton),
      );
      expect(
        (
          service.calls.last,
          tester.widget<FilledButton>(button).onPressed,
          find.byType(CircularProgressIndicator).evaluate().length,
        ),
        (
          '${authMode == AuthMode.anonymous ? 'linkPassword' : 'signUp'} '
              '$_email',
          null,
          0,
        ),
        reason: 'In an app that asks for less motion, the button of a form '
            'whose call is on its way takes no tap and does not spin.',
      );
      hold.complete();
      service.hold = null;
      await tester.pump();
      await tester.pump();
      expect(
        (
          failureMessage(AuthFailureReason.emailInUse).evaluate().length,
          find
              .descendant(
                of: signUpScreen,
                matching: find.byType(AnimatedSize),
              )
              .evaluate()
              .length,
        ),
        (1, 0),
        reason: 'In an app that asks for less motion, the message of a '
            'failure takes its place at once: nothing lets it grow.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
