// A test that continuous integration runs in the apps of the fixture
// modules whose modules give the onboarding screen role steps, whichever
// module provides the role: the button of the action of a step calls the
// action once, takes no tap on the buttons of the step until the future of
// the action completes, and then shows the next page, also when the action
// fails. The error of such an action reaches the handlers of the errors of
// the app: the provider leaves it uncaught or reports it with
// FlutterError.reportError. The button of later shows the next page
// without the action (OnboardingScreenRole).
//
// It uses the step `ask` of the fixture steps, whose action notes each call
// in fixtureStepCalls, waits for fixtureAskHold and fails when
// fixtureAskFails, and the step `confirm`, which comes after it. The app
// starts once, since the start-up of an app runs once in a test file. Each
// expectation gives its reason, which a provider of the role with a known
// bug fails the test with (brokenProviders of the fixture registry).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/fixture_steps/fixture_steps.dart';

import 'of_app.dart';
import 'steps.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the action of a step runs once, takes no tap until its future '
    'completes and then shows the next page, also when it fails, and later '
    'shows the next page without it',
    (tester) async {
      final language = stepLanguages.first;
      final texts = textsOf(ask, language);
      addTearDown(() {
        fixtureAskHold = null;
        fixtureAskFails = false;
        fixtureStepCalls.clear();
      });
      await startApp(tester);

      // The action waits for what the test holds it back with.
      final hold = fixtureAskHold = Completer<void>();
      await showNewScreen(tester);
      await swipeToStep(tester, ask, language);
      final action = tester.getCenter(shown(find.text(texts.action)));
      final later = tester.getCenter(shown(find.text(texts.later!)));
      fixtureStepCalls.clear();
      await tester.tapAt(action);
      await pumpFor(tester, const Duration(seconds: 1));
      expect(
        fixtureStepCalls,
        ['ask'],
        reason: 'A tap on the button of the action of a step calls the '
            'action once.',
      );
      expect(
        stepShown(tester, language),
        ask,
        reason: 'While the future of the action of a step does not complete, '
            'the step stays.',
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
