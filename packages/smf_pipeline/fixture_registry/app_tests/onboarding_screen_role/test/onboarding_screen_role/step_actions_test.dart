// A test that continuous integration runs in the apps of the fixture
// modules whose modules give the onboarding screen role steps, whichever
// module provides the role: the button of the action of a step calls the
// action once, takes no tap on the buttons of the step until the future of
// the action completes, and then shows the next page, also when the action
// fails, whose error goes on to the handlers of the uncaught errors of the
// app. The button of later shows the next page without the action
// (OnboardingScreenRole).
//
// It uses the step `ask` of the fixture steps, whose action notes each call
// in fixtureStepCalls, waits for fixtureAskHold and fails when
// fixtureAskFails, and the step `confirm`, which comes after it. The app
// starts once, since the start-up of an app runs once in a test file. Each
// expectation gives its reason, which a provider of the role with a known
// bug fails the test with (brokenProviders of the fixture registry).
import 'dart:async';

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
      await tester.pumpAndSettle();
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

      // An action that fails: its error is uncaught, so it reaches the
      // zone in which the tap called the action, rather than this test.
      fixtureAskFails = true;
      await showNewScreen(tester);
      await swipeToStep(tester, ask, language);
      fixtureStepCalls.clear();
      final at = tester.getCenter(shown(find.text(texts.action)));
      final uncaught = <Object>[];
      late Future<void> tapped;
      runZonedGuarded(
        () => tapped = tester.tapAt(at),
        (error, _) => uncaught.add(error),
      );
      await tapped;
      await tester.pumpAndSettle();
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
        uncaught,
        [isA<StateError>()],
        reason: 'The error of the action of a step goes on to the handlers '
            'of the uncaught errors of the app.',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
