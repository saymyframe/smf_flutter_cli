// A test that continuous integration runs in the apps of the fixture
// modules with every module that have the fixture gates and the second
// fixture feature, whichever modules provide the router and the review
// role: no review is due while the user is in the flow of a guard of the
// routes, as the review role says. While a gate does not allow, its flow
// keeps the user, and so does the target of a guard that stands for a
// condition while it is open over a page, which the router tells the
// listener of the screen that the template of the role gives it. Once the
// user is out of every flow, the review is due, and the app asks once.
//
// It is a test of the review role and of the router role: the template of
// the review role knows the guards only through what the router role
// publishes, and the router has to tell the listeners of the screen of the
// target of the guard. It uses what the tests of the review role, of
// router_screens, of router_guards and of router_conditions share, which
// every app that it applies to has: a controller of the test with a review
// that is due, over a service of the tests that scripts what a provider
// answers, and the gates and the badge of the fixture, which the test
// closes and opens. Each expectation gives its reason.
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gates.dart';

import 'conditions.dart';
import 'guards.dart';
import 'review_role/review_role.dart' hide startApp;
import 'screens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'no review is due while a gate does not allow, nor while the target of '
    'a guard of a condition is open over a page, and the app asks once out '
    'of every flow',
    (tester) async {
      await startApp(tester);
      expect(
        heard(),
        [startScreen],
        reason: 'With guards that allow, the app starts on its start screen.',
      );
      final now = DateTime.now().toUtc();
      await inRealTime(
        tester,
        'saving a review that is due',
        () => saveDueState(now: now),
      );
      final service = ScriptedReview();
      final app = await launchWith(tester, service, now: () => now);

      // A gate that does not allow.
      fixtureGate.value = false;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [gateScreen],
        reason: 'While a gate does not allow, the router shows its target.',
      );
      await requestIfDue(tester, app);
      final whileGateCloses = service.requests;
      fixtureGate.value = true;
      await tester.pumpAndSettle();

      // The target of the guard of the badge, open over a page.
      final below = await toDetails(tester, 1);
      await takeBadge(tester);
      pushed(below.nav.fakeSecond.members());
      await tester.pumpAndSettle();
      expect(
        heard(),
        [gateScreen],
        reason: 'A request for a route whose condition does not hold opens '
            'the target of its guard over the page.',
      );
      await requestIfDue(tester, app);
      final inTheFlow = service.requests;

      // Back out of the flow.
      await back(tester);
      expect(
        heard(),
        [detailsScreen(1)],
        reason: 'Back from the target of a guard of a condition returns to '
            'the page below it.',
      );
      await requestIfDue(tester, app);
      final outOfEveryFlow = service.requests;
      await giveBadge(tester);

      expect(
        whileGateCloses,
        0,
        reason: 'No review is due while a gate of the routes does not allow: '
            'the user is in its flow.',
      );
      expect(
        inTheFlow,
        0,
        reason: 'No review is due while the target of a guard of a condition '
            'is open over a page: the user is in its flow.',
      );
      expect(
        outOfEveryFlow,
        1,
        reason: 'Once the user is out of every flow of a guard, a review is '
            'due, and the app asks once.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
