// A test that continuous integration runs in the apps with the paywall
// module and an onboarding, whichever module provides the onboarding: the
// step of the module that offers premium access, with the purchases of the
// provider of the purchases role and its mocks, which start as on a first
// launch, with nothing bought, and let a purchase succeed.
//
// The list of the steps of the onboarding has the step once, and a new
// onboarding screen shows it while the user has no premium access, with
// its texts in each language of the app, also in full on a small phone
// with a large text size. Its button shows the paywall over the
// onboarding, as a route of its own on the navigator at the root of the
// app, and its action completes only once the paywall closes. The close
// button and back close the paywall, and once the user has premium access,
// the step closes the paywall itself, since the router does not know its
// route, also from below a dialog over the paywall, which stays. Each time
// the onboarding goes on to its next page, and the page of the router
// below it stays: the router leaves the routes without a page over its
// pages as they are while the guard of premium access notifies. Then a new
// onboarding screen leaves the step out, and its action shows nothing.
//
// The test knows the module, and of the rest of the app only its roles. It
// pushes a new onboarding screen over the app, as the test of the
// onboarding screen role does, rather than go to the route of the screen,
// which a guard of its provider may keep the user from once the onboarding
// is over, and finds the step by its title, whichever module draws it. The
// matrix writes onboarding.dart next to this file, from the data of the
// onboarding screen role, and the texts of the step among those of the
// test of the paywall, whose helpers this test uses. The test starts the
// app once, since the start-up of an app may not run twice, and each
// expectation gives its reason.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/onboarding/onboarding_steps.dart';
import 'package:{{app_name}}/core/purchases/app_purchases.dart';
import 'package:{{app_name}}/features/paywall/paywall_step.dart';

import '../paywall/paywall.dart';
import '../paywall/of_app.dart';
import '../paywall_mocks.dart';
import 'onboarding.dart';

/// The onboarding screen that the user sees, and every one that the app
/// has built, also below another screen.
final Finder _onboarding = find.byType(onboardingScreen);
final Finder _builtOnboarding = find.byType(
  onboardingScreen,
  skipOffstage: false,
);

/// What the onboarding screen shows of [matching].
Finder _shown(Finder matching) =>
    find.descendant(of: _onboarding, matching: matching);

/// The most pages that an onboarding may show besides its steps and before
/// the step of the module, such as a first page of its own and the steps of
/// other modules.
const int _pagesBefore = 12;

/// The navigator at the root of the app, which shows its screens.
NavigatorState _rootNavigator(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator).first);

/// Whether the centre of a widget that [finder] finds is on the onboarding
/// screen: on the page that the user sees, rather than on a page that is
/// built beside it.
bool _isOnScreen(WidgetTester tester, Finder finder) {
  final screen = tester.getRect(_onboarding);
  return finder.evaluate().any((element) => _isWithin(screen, element));
}

/// Whether the centre of [element] is within [screen].
bool _isWithin(Rect screen, Element element) => switch (element.renderObject) {
      final RenderBox box when box.hasSize => screen.contains(
          box.localToGlobal(box.size.center(Offset.zero)),
        ),
      _ => false,
    };

/// Whether the page that the user sees is the page of the step: whether it
/// shows the title of the step.
bool _stepShown(WidgetTester tester) =>
    _isOnScreen(tester, _shown(text('stepTitle')));

/// Shows a new onboarding screen over the app, on top of the navigator at
/// the root of the app, and waits for its first page. A new screen asks
/// the steps again whether it shows them.
Future<void> _showNewOnboarding(WidgetTester tester) async {
  unawaited(
    _rootNavigator(tester).push<void>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            newOnboardingScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(
    _onboarding,
    findsOneWidget,
    reason: 'A new onboarding screen shows over the app.',
  );
}

/// Closes the onboarding screen that [_showNewOnboarding] showed.
Future<void> _closeOnboarding(WidgetTester tester) async {
  _rootNavigator(tester).pop();
  await tester.pumpAndSettle();
  expect(_builtOnboarding, findsNothing);
}

/// Turns the page of the onboarding screen to the next one with a swipe,
/// as the user does, and returns whether it turned: the next page shows
/// other texts, which are other elements, also where they say the same,
/// while a swipe on the last page leaves the same ones.
Future<bool> _swipe(WidgetTester tester) async {
  final before = _textsOnScreen(tester);
  final width = tester.getSize(_onboarding).width;
  await tester.drag(_onboarding, Offset(-width * 0.7, 0));
  await tester.pumpAndSettle();
  final after = _textsOnScreen(tester);
  return before.length != after.length || !before.containsAll(after);
}

/// The elements of the texts that the onboarding screen shows on the page
/// that the user sees, and around it, such as a button below the pages.
Set<Element> _textsOnScreen(WidgetTester tester) {
  final screen = tester.getRect(_onboarding);
  return {
    for (final element in _shown(find.byType(Text)).evaluate())
      if (_isWithin(screen, element)) element,
  };
}

/// Swipes from the page that the user sees to the page of the step; fails
/// if no swipe gets there.
Future<void> _swipeToStep(WidgetTester tester) async {
  for (var swipes = 0; swipes <= _pagesBefore; swipes++) {
    if (_stepShown(tester)) return;
    if (!await _swipe(tester)) break;
  }
  fail(
    'No swipe shows the onboarding step of the paywall: the screen does not '
    'show its title, "${texts['stepTitle']}".',
  );
}

/// Shows a new onboarding screen, swipes to the page of the step and taps
/// its button, which shows the paywall over the onboarding, and waits for
/// the plans of the paywall.
Future<void> _openPaywallFromStep(WidgetTester tester) async {
  await _showNewOnboarding(tester);
  await _swipeToStep(tester);
  await tester.tap(_shown(text('stepAction')));
  await waitInRealTime(
    tester,
    'the plans',
    until: () => planCards.evaluate().isNotEmpty,
  );
}

/// What the dialog that a test shows over the paywall says.
const String _dialogText = 'A dialog over the paywall';

/// The inset at the top and at the bottom of the small phone of the test,
/// such as a notch and the bar of the home gesture.
const double _inset = 40;

/// Gives the app a small phone of 320 by 480 with insets, and the text at
/// three times its size, about the largest that the settings of a device
/// have, as the test of the onboarding module checks its pages on.
Future<void> _useSmallPhone(WidgetTester tester) async {
  const insets = FakeViewPadding(top: _inset, bottom: _inset);
  tester.view
    ..physicalSize = const Size(320, 480)
    ..devicePixelRatio = 1
    ..padding = insets
    ..viewPadding = insets;
  tester.platformDispatcher.textScaleFactorTestValue = 3;
  await tester.pumpAndSettle();
}

/// Checks that the page of the step that the user sees shows the text
/// [name] of the module in full, in [language]: no ancestor fades it, no
/// line of it is cut off, and a scroll of the page brings it into view.
Future<void> _expectInFull(
  WidgetTester tester,
  String name,
  String language,
) async {
  final finder = _shown(text(name));
  expect(
    finder,
    findsOneWidget,
    reason: 'The page of the step shows its text $name on a small phone '
        'with a large text size, in $language.',
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  expect(
    (
      tester.renderObject<RenderParagraph>(finder).didExceedMaxLines,
      [
        for (final fade in tester.widgetList<Opacity>(
          find.ancestor(of: finder, matching: _shown(find.byType(Opacity))),
        ))
          fade.opacity,
      ].every((opacity) => opacity == 1),
      tester.getRect(finder).overlaps(tester.getRect(_onboarding)),
    ),
    (false, true, true),
    reason: 'The page of the step shows its text $name in full on a small '
        'phone with a large text size, in $language: no line of it is cut '
        'off, nothing fades it, and a scroll of the page brings it into '
        'view.',
  );
}

/// Shows the frames of [duration], one every 50 milliseconds, as a device
/// does: an animation that ends, such as one that closes a screen, runs to
/// its end, and one that does not, such as a button that spins, does not
/// keep the test waiting as pumpAndSettle would.
Future<void> _framesFor(WidgetTester tester, Duration duration) async {
  const frame = Duration(milliseconds: 50);
  for (var shown = Duration.zero; shown < duration; shown += frame) {
    await tester.pump(frame);
  }
}

/// Checks that the paywall is closed, that the onboarding went on to the
/// page after the step and that the page of the router below the
/// onboarding stays, after the paywall closed in the way that [how] names.
void _expectOnboardingGoesOn(WidgetTester tester, String how) {
  expect(
    builtPaywall,
    findsNothing,
    reason: 'The paywall that the step showed closes $how.',
  );
  expect(
    (_onboarding.evaluate().length, _stepShown(tester)),
    (1, false),
    reason: 'Once the paywall that the step showed closed $how, the '
        'onboarding goes on to the page after the step.',
  );
  expect(
    builtStartScreen,
    findsOneWidget,
    reason: 'The page of the router below the onboarding stays once the '
        'paywall that the step showed closed $how.',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // A tap that reaches no widget fails the test where it misses.
  WidgetController.hitTestWarningShouldBeFatal = true;
  // The app starts as on its first launch, with nothing bought.
  paywallIsUnderTest = true;

  testWidgets(
    'the onboarding shows the step while the user has no premium access, '
    'and its button shows the paywall over the onboarding, which goes on '
    'once the paywall closes with its close button, with back, or after a '
    'purchase',
    (tester) async {
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      useTallPhone(tester);
      await startApp(tester);
      expect(
        appPurchases.hasPremium.value,
        isFalse,
        reason: 'On a first launch, the user has bought nothing.',
      );

      // The list of the steps of the app has the step once.
      final steps = [
        for (final step in appOnboardingSteps)
          if (step.run == showPaywall) step,
      ];
      expect(
        steps,
        hasLength(1),
        reason: 'The list of the steps of the onboarding has the step of '
            'the paywall once.',
      );
      final step = steps.single;
      expect(
        (step.showIf == paywallStepShows, paywallStepShows()),
        (true, true),
        reason: 'The step shows while the user has no premium access.',
      );

      // A new onboarding shows the step, in each language of the app.
      for (final language in paywallTexts.keys) {
        await useLanguage(tester, language);
        final context = tester.element(find.byType(Navigator).first);
        expect(
          (
            step.title(context),
            step.text(context),
            step.action(context),
            step.later?.call(context),
          ),
          (
            texts['stepTitle'],
            texts['stepText'],
            texts['stepAction'],
            texts['stepLater'],
          ),
          reason: 'The labels of the step are its texts in $language, with '
              'a button that goes on without the paywall.',
        );
        await _showNewOnboarding(tester);
        await _swipeToStep(tester);
        for (final name in ['stepTitle', 'stepText', 'stepAction']) {
          expect(
            _isOnScreen(tester, _shown(text(name))),
            isTrue,
            reason: 'The page of the step shows its text $name in '
                '$language.',
          );
        }
        // The same page on a small phone with a large text size.
        await _useSmallPhone(tester);
        expect(
          tester.takeException(),
          isNull,
          reason: 'The page of the step fits a small phone with a large '
              'text size, in $language.',
        );
        for (final name in ['stepTitle', 'stepText', 'stepAction']) {
          await _expectInFull(tester, name, language);
        }
        for (final name in ['stepAction', 'stepLater']) {
          expect(
            _shown(text(name)).hitTestable(),
            findsOneWidget,
            reason: 'The buttons of the step are on the screen of a small '
                'phone with a large text size, where a tap reaches them, '
                'in $language: $name.',
          );
        }
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        tester.view
          ..resetPadding()
          ..resetViewPadding();
        useTallPhone(tester);
        await tester.pumpAndSettle();
        await _closeOnboarding(tester);
      }
      await useLanguage(tester, paywallTexts.keys.first);

      // The action of the step completes only once the paywall closes.
      await _showNewOnboarding(tester);
      await _swipeToStep(tester);
      final opened = showPaywall(tester.element(_onboarding)).then<Object?>(
        (_) => null,
      );
      await waitInRealTime(
        tester,
        'the plans',
        until: () => planCards.evaluate().isNotEmpty,
      );
      expect(
        (paywallScreen.evaluate().length, await outcomeOf(tester, opened)),
        (1, notCompleted),
        reason: 'While the paywall that the step showed is open, the action '
            'of the step has not completed, so the onboarding stays on the '
            'step.',
      );
      await tester.tap(find.byTooltip(texts['close']!));
      await tester.pumpAndSettle();
      expect(
        (builtPaywall.evaluate().length, await outcomeOf(tester, opened)),
        (0, null),
        reason: 'The action of the step completes once its paywall is '
            'closed.',
      );
      await _closeOnboarding(tester);

      // The close button of the paywall.
      await _openPaywallFromStep(tester);
      expect(
        (
          paywallScreen.evaluate().length,
          _builtOnboarding.evaluate().length,
          builtStartScreen.evaluate().length,
        ),
        (1, 1, 1),
        reason: 'The button of the step shows the paywall over the '
            'onboarding, which stays below it with the page of the router.',
      );
      final route = ModalRoute.of(tester.element(paywallScreen))!;
      expect(
        (route.settings is Page<Object?>, route.navigator),
        (false, _rootNavigator(tester)),
        reason: 'The step shows the paywall as a route without a page on '
            'the navigator at the root of the app: while the onboarding is '
            'on, a guard of the routes may keep the router from showing the '
            'route of the paywall.',
      );
      await tester.tap(find.byTooltip(texts['close']!));
      await tester.pumpAndSettle();
      _expectOnboardingGoesOn(tester, 'with its close button');
      await _closeOnboarding(tester);

      // Back.
      await _openPaywallFromStep(tester);
      expect(paywallScreen, findsOneWidget);
      expect(
        await pressSystemBack(tester),
        isTrue,
        reason: 'The app handles back on the paywall that the step showed.',
      );
      _expectOnboardingGoesOn(tester, 'with back');
      await _closeOnboarding(tester);

      // A dialog over the paywall when the user gets premium access: the
      // step closes the paywall below the dialog, which stays.
      await _openPaywallFromStep(tester);
      expect(paywallScreen, findsOneWidget);
      unawaited(
        showDialog<void>(
          context: tester.element(paywallScreen),
          builder: (context) => const AlertDialog(content: Text(_dialogText)),
        ),
      );
      await tester.pumpAndSettle();
      await inRealTime(tester, 'a purchase from code', () async {
        final plans = await appPurchases.plans();
        await appPurchases.purchase(plans.first);
      });
      expect(
        appPurchases.hasPremium.value,
        isTrue,
        reason: 'The purchase gives the user premium access.',
      );
      await _framesFor(tester, const Duration(seconds: 2));
      expect(
        (
          builtPaywall.evaluate().length,
          find.text(_dialogText).evaluate().length,
        ),
        (0, 1),
        reason: 'Once the user has premium access, the step closes its '
            'paywall also below a dialog over it, and the dialog stays.',
      );
      expect(
        (_onboarding.evaluate().length, _stepShown(tester)),
        (1, false),
        reason: 'Once the step closed its paywall below a dialog, the '
            'onboarding goes on to the page after the step.',
      );
      Navigator.of(tester.element(find.text(_dialogText))).pop();
      await tester.pumpAndSettle();
      await _closeOnboarding(tester);
      // A fresh user, who has bought nothing, for the purchase below.
      await startWithoutPremium(tester);
      expect(appPurchases.hasPremium.value, isFalse);

      // A purchase: the step closes the paywall itself.
      await _openPaywallFromStep(tester);
      expect(
        (paywallScreen.evaluate().length, planCards.evaluate().isNotEmpty),
        (1, true),
        reason: 'The paywall that the step showed has the plans of the '
            'provider of purchases.',
      );
      await inRealTime(tester, 'the purchase', () async {
        await tester.tap(purchaseButton);
        for (var turn = 0; turn < 300; turn++) {
          if (appPurchases.hasPremium.value) break;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
        }
      });
      expect(
        appPurchases.hasPremium.value,
        isTrue,
        reason: 'The purchase gives the user premium access.',
      );
      // Frames rather than a wait for the screen to settle: a paywall that
      // stayed would spin its button for as long as the user has premium
      // access.
      await _framesFor(tester, const Duration(seconds: 2));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await _framesFor(tester, const Duration(seconds: 1));
      _expectOnboardingGoesOn(tester, 'once the user bought a plan');
      await _closeOnboarding(tester);

      // With premium access, the onboarding leaves the step out.
      expect(
        paywallStepShows(),
        isFalse,
        reason: 'The step does not show for a user with premium access.',
      );
      await _showNewOnboarding(tester);
      for (var swipes = 0; swipes <= _pagesBefore; swipes++) {
        expect(
          _stepShown(tester),
          isFalse,
          reason: 'A new onboarding leaves out the step for a user with '
              'premium access.',
        );
        if (!await _swipe(tester)) break;
      }
      final action = showPaywall(tester.element(_onboarding));
      await tester.pumpAndSettle();
      expect(
        (
          builtPaywall.evaluate().length,
          await outcomeOf(tester, action.then((_) => null)),
        ),
        (0, null),
        reason: 'The action of the step shows nothing for a user with '
            'premium access, and completes at once.',
      );
      await _closeOnboarding(tester);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
