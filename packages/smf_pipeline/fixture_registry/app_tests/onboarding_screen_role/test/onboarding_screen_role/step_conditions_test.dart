// A test that continuous integration runs in the apps of the fixture
// modules whose modules give the onboarding screen role steps, whichever
// module provides the role: the onboarding asks each step for its showIf
// once each time it shows, and leaves out a step whose function returns
// false then. A step that it shows stays while the user is on it, also
// once the function would return false (OnboardingScreenRole).
//
// It uses the step `ask` of the fixture steps, whose showIf returns
// fixtureAskShows, and the step `confirm`, which the onboarding always
// shows. The app starts once, since the start-up of an app runs once in a
// test file. Each expectation gives its reason, which a provider of the
// role with a known bug fails the test with (brokenProviders of the fixture
// registry).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/fixture_steps/fixture_steps.dart';

import 'of_app.dart';
import 'steps.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'a step whose showIf leaves it out when the onboarding opens is not '
    'shown, and a step that shows stays once its showIf would leave it out',
    (tester) async {
      addTearDown(() => fixtureAskShows = true);
      await startApp(tester);
      final first = stepLanguages.first;
      await showNewScreen(tester);
      await swipeToStep(tester, ask, first);

      // The app builds the screen again in another language, with the
      // function of the step returning false.
      fixtureAskShows = false;
      final other = stepLanguages.last;
      await useLanguage(tester, other);
      expect(
        stepShown(tester, other),
        ask,
        reason: 'A step that the onboarding shows stays while the user is on '
            'it, also once its showIf would leave it out.',
      );
      await closeScreen(tester);

      // A new screen asks the steps again.
      final kept = keptSteps();
      expect(
        kept,
        allOf(isNot(contains(ask)), contains(confirm)),
        reason: 'The showIf of the step ask leaves it out now.',
      );
      await showNewScreen(tester);
      final pages = await swipeThrough(tester, other);
      expect(
        pages.whereType<int>(),
        kept,
        reason: 'A step whose condition does not hold when the onboarding '
            'starts is not shown.',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
