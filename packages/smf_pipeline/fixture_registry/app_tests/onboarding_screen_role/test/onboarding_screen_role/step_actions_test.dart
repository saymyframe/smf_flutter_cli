// A test that continuous integration runs in the apps of the fixture
// modules whose modules give the onboarding screen role steps, whichever
// module provides the role: the button of the action of a step calls the
// action once, with the context of the onboarding screen, takes no tap on
// the buttons of the step until the future of the action completes, and
// then shows the next page, also when the action fails. The error of such
// an action reaches the handlers of the errors of the app: the provider
// leaves it uncaught or reports it with FlutterError.reportError. The
// button of later shows the next page without the action. A screen that the
// action shows over the onboarding, with a route without a page on the
// navigator at the root of the app, stays there while the guards of the
// routes notify, also when a guard of a condition stops and starts allowing
// (OnboardingScreenRole).
//
// It uses the step `ask` of the fixture steps, whose action notes each call
// in fixtureStepCalls, fails when fixtureAskFails, and otherwise shows
// FixtureAskScreen over the app until the screen is closed and then waits
// for fixtureAskHold, and the step `confirm`, which comes after it. The
// matrix writes guards_of_app.dart next to this file: in an app with the
// fixture gates, keepOnGate() keeps the user on the target of a gate, as an
// onboarding keeps a new user on it, and notifyGuards() has the guards
// notify, and in another app both do nothing. The app starts once, since
// the start-up of an app runs once in a test file. Each expectation gives
// its reason, which a provider of the role with a known bug fails the test
// with (brokenProviders of the fixture registry).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show CloseButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/fixture_steps/fixture_steps.dart';

import 'guards_of_app.dart';
import 'of_app.dart';
import 'steps.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the action of a step runs once, with the context of the screen, takes '
    'no tap until its future completes and then shows the next page, also '
    'when it fails, a screen that it shows stays while the guards notify, '
    'and later shows the next page without it',
    (tester) async {
      final language = stepLanguages.first;
      final texts = textsOf(ask, language);
      addTearDown(() {
        fixtureAskHold = null;
        fixtureAskFails = false;
        fixtureStepCalls.clear();
        keepOnGate(keep: false);
      });
      await startApp(tester);
      // The onboarding over the target of a gate that does not allow, as an
      // onboarding that keeps a new user on it with a guard of the routes.
      keepOnGate(keep: true);
      await tester.pumpAndSettle();

      // The action shows a screen of its own, and once that screen is
      // closed, waits for what the test holds it back with.
      final hold = fixtureAskHold = Completer<void>();
      await showNewScreen(tester);
      await swipeToStep(tester, ask, language);
      final action = tester.getCenter(shown(find.text(texts.action)));
      final later = tester.getCenter(shown(find.text(texts.later!)));
      fixtureStepCalls.clear();
      await tester.tapAt(action);
      await pumpFor(tester, const Duration(seconds: 2));
      expect(
        fixtureStepCalls,
        ['ask'],
        reason: 'A tap on the button of the action of a step calls the '
            'action once.',
      );
      final askScreen = find.byType(FixtureAskScreen);
      expect(
        askScreen,
        findsOneWidget,
        reason: 'The action of a step gets the context of the onboarding '
            'screen, with which it shows a screen of its own over the '
            'onboarding, on the navigator at the root of the app.',
      );

      // The guards of the routes notify while that screen shows.
      await notifyGuards(
        () => pumpFor(tester, const Duration(milliseconds: 500)),
      );
      expect(
        fixtureAskRoute?.isCurrent,
        isTrue,
        reason: 'A route without a page that the action of a step pushes on '
            'the navigator at the root of the app stays on top while the '
            'guards of the routes notify, also when a guard of a condition '
            'stops and starts allowing.',
      );
      expect(
        askScreen,
        findsOneWidget,
        reason: 'The screen that the action of a step shows over the '
            'onboarding stays while the guards of the routes notify.',
      );
      await tester.tap(
        find.descendant(of: askScreen, matching: find.byType(CloseButton)),
      );
      await pumpFor(tester, const Duration(seconds: 2));
      expect(
        askScreen,
        findsNothing,
        reason: 'The screen that the action of a step showed closes.',
      );
      expect(
        stepShown(tester, language),
        ask,
        reason: 'Below the screen that the action of a step showed, the '
            'onboarding stays on the step, also once the guards of the routes '
            'notified, and the step stays while the future of the action does '
            'not complete.',
      );
      await tester.tapAt(action);
      await tester.tapAt(later);
      await pumpFor(tester, const Duration(seconds: 1));
      expect(
        fixtureStepCalls,
        ['ask'],
        reason: 'While the future of the action of a step does not complete, '
            'the button of the action takes no tap.',
      );
      expect(
        stepShown(tester, language),
        ask,
        reason: 'While the future of the action of a step does not complete, '
            'neither its action nor its later shows the next page.',
      );
      hold.complete();
      // Frames for a while rather than until the screen settles: a provider
      // whose button keeps spinning fails the expectation below, with its
      // reason, rather than time out.
      await pumpFor(tester, const Duration(seconds: 2));
      expect(
        stepShown(tester, language),
        confirm,
        reason: 'Once the future of the action of a step completes, the '
            'onboarding shows the next page, the next step.',
      );
      expect(
        fixtureStepCalls,
        ['ask'],
        reason: 'The onboarding calls no action of the next step for it.',
      );
      await closeScreen(tester);
      keepOnGate(keep: false);
      await tester.pumpAndSettle();

      // Later goes on without the action.
      fixtureAskHold = null;
      await showNewScreen(tester);
      await swipeToStep(tester, ask, language);
      fixtureStepCalls.clear();
      await tester.tap(shown(find.text(texts.later!)));
      await tester.pumpAndSettle();
      expect(
        stepShown(tester, language),
        confirm,
        reason: 'The button of later shows the next page.',
      );
      expect(
        fixtureStepCalls,
        isEmpty,
        reason: 'The button of later shows the next page without calling '
            'the action of the step.',
      );
      await closeScreen(tester);

      // An action that fails. Its error reaches the zone in which the tap
      // called the action if the provider leaves it uncaught, or the
      // handler of the errors of Flutter if the provider reports it there,
      // rather than this test.
      fixtureAskFails = true;
      await showNewScreen(tester);
      await swipeToStep(tester, ask, language);
      fixtureStepCalls.clear();
      final at = tester.getCenter(shown(find.text(texts.action)));
      final uncaught = <Object>[];
      final reported = <Object>[];
      final onError = FlutterError.onError;
      FlutterError.onError = (details) => reported.add(details.exception);
      try {
        late Future<void> tapped;
        runZonedGuarded(
          () => tapped = tester.tapAt(at),
          (error, _) => uncaught.add(error),
        );
        await tapped;
        // As above: a provider that stays busy once the action failed fails
        // the expectations below, with their reasons.
        await pumpFor(tester, const Duration(seconds: 2));
      } finally {
        FlutterError.onError = onError;
      }
      expect(
        fixtureStepCalls,
        ['ask'],
        reason: 'A tap on the button of the action of a step calls the '
            'action once.',
      );
      expect(
        stepShown(tester, language),
        confirm,
        reason: 'Once the future of the action of a step fails, the '
            'onboarding shows the next page too.',
      );
      expect(
        [...uncaught, ...reported],
        [isA<StateError>()],
        reason: 'The error of the action of a step reaches the handlers of '
            'the errors of the app once: the onboarding leaves it uncaught '
            'or reports it with FlutterError.reportError.',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
