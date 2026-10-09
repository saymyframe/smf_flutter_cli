// A test that continuous integration runs in the apps of the fixture
// modules with every module, a router, whichever module provides it, the
// fixture gates and the fixture late gate: the walk of the routes that the
// CLI keeps for the router role (integration_test/router_walk/walk.dart)
// holds while a guard of the routes keeps the user out, as on a device,
// where no test opens a guard, and once the guards allow. The first gate
// is closed before the app starts. The walk expects what the role says,
// shownFor() of the file that the matrix writes for it: the target of the
// guard in place of each location outside its flow, as redirectOf() of
// the app says, and the locations of its flow themselves. closedGuards()
// of that file names the guard, as the test of the walk does when it
// fails on it.
//
// Once the gate opens, the flows of all three guards are over, as
// flowIsOver() of the app says. The walk then expects the screen that the
// app starts on in place of each location of a flow, and reaches every
// other route. So it never shows a screen of a flow that is over, and no
// such screen can change what the walk sees of the locations after it.
//
// It uses what the tests of router_screens share, which every app that it
// applies to has. Each expectation gives its reason, which a provider of
// the role with a known bug fails the test with (brokenProviders of the
// fixture registry).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gate_screens.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gates.dart';
import 'package:{{app_name}}/features/fake_late_gate/fixture_late_gate_screen.dart';

import '../integration_test/router_walk/locations.dart';
import '../integration_test/router_walk/walk.dart';
import 'screens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the walk of the routes holds while a guard keeps the user out, and '
    'once the flows of the guards are over',
    (tester) async {
      fixtureGate.value = false;
      await startApp(tester);
      expect(
        closedGuards(),
        ['fake_gate.first'],
        reason: 'closedGuards() names each guard that does not allow.',
      );

      // What the walk expects for each location: the target of the guard,
      // but for the routes of its flow, which the walk goes to as well as
      // to routes outside it.
      const flow = {'fake_gate.gate', 'fake_gate.step'};
      final routes = [for (final walked in walkedLocations) walked.route];
      expect(
        routes,
        containsAll([
          ...flow,
          'fake_feature.home',
          'fake_gate.second',
          'fake_late_gate.gate',
        ]),
        reason: 'The walk goes to routes of the flow of the guard and to '
            'routes outside it.',
      );
      expect(
        [for (final walked in walkedLocations) shownFor(walked).route],
        [
          for (final route in routes)
            flow.contains(route) ? route : 'fake_gate.gate',
        ],
        reason: 'While a guard does not allow, the walk expects its target in '
            'place of each location outside its flow.',
      );
      final closed = await walkRoutes(tester.pumpAndSettle);
      expect(
        closed.all,
        isEmpty,
        reason: 'While a guard does not allow, each location outside its flow '
            'shows the target of the guard, and each location of its flow '
            'its own screen.',
      );

      // The gate opens: the flows of all three guards are over. The walk
      // expects the screen that the app starts on in place of each
      // location of a flow, and each other location itself.
      fixtureGate.value = true;
      await tester.pumpAndSettle();
      expect(
        closedGuards(),
        isEmpty,
        reason: 'closedGuards() names no guard that allows.',
      );
      const flows = {...flow, 'fake_gate.second', 'fake_late_gate.gate'};
      expect(
        startOfApp.route,
        isNotNull,
        reason: 'The app starts on a route, whose page the walk expects on '
            'top for a location in a flow that is over.',
      );
      expect(
        flows,
        isNot(contains(startOfApp.route)),
        reason: 'The screen that the app starts on is in no flow.',
      );
      expect(
        [for (final walked in walkedLocations) shownFor(walked).route],
        [
          for (final route in routes)
            flows.contains(route) ? startOfApp.route : route,
        ],
        reason: 'Once the guards allow, the walk expects the screen that the '
            'app starts on in place of each location of a flow, and each '
            'other location itself.',
      );
      // What each location shows of the screens of the flows, which the
      // test notes once the screen settled.
      final shownOfFlows = <String>[];
      Future<void> settle() async {
        await tester.pumpAndSettle();
        shownOfFlows.add(
          [
            if (find.byType(FixtureGateScreen).evaluate().isNotEmpty)
              'fake_gate.gate',
            if (find.byType(FixtureGateStepScreen).evaluate().isNotEmpty)
              'fake_gate.step',
            if (find.byType(FixtureSecondGateScreen).evaluate().isNotEmpty)
              'fake_gate.second',
            if (find.byType(FixtureLateGateScreen).evaluate().isNotEmpty)
              'fake_late_gate.gate',
          ].join(', '),
        );
      }

      final open = await walkRoutes(settle);
      expect(
        open.all,
        isEmpty,
        reason: 'Once the guards allow, each location outside the flows '
            'shows the page and the screen of its route, and each location '
            'of a flow the screen that the app starts on.',
      );
      expect(
        shownOfFlows,
        [for (final _ in routes) ''],
        reason: 'Once the guards allow, the walk shows no screen of a flow, '
            'which is over.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
