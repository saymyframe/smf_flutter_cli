// A test that continuous integration runs in the apps of the fixture
// modules with every module, a router, whichever module provides it, and
// the fixture gates: the walk of the routes that the CLI keeps for the
// router role (integration_test/router_walk/walk.dart) holds while a guard
// of the routes keeps the user out, as on a device, where no test opens a
// guard. The first gate is closed before the app starts. The walk expects
// what the role says, redirectOf() of the app: the target of the guard in
// place of each location outside its flow, and the locations of its flow
// themselves. closedGuards() of the file that the matrix writes for the
// walk names the guard, as the test of the walk does when it fails on it.
// Once the gate opens, the walk reaches every route.
//
// The walk goes to the locations in the flows of the guards last, since a
// screen of a flow may change what its guard allows when it is shown: one
// that is shown although its flow is over may start the flow again, for
// example. The test stands in for such a screen: it closes the first gate
// as soon as the walk shows the gate screen. Every location outside the
// flows has shown its own screen by then, and the walk holds. The location
// of the flow of the second guard then shows the target of the first, which
// is all that the walk checks of it.
//
// It uses what the tests of router_screens share, which every app that it
// applies to has. Each expectation gives its reason, which a provider of
// the role with a known bug fails the test with (brokenProviders of the
// fixture registry).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gate_screens.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gates.dart';

import '../integration_test/router_walk/locations.dart';
import '../integration_test/router_walk/walk.dart';
import 'screens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the walk of the routes holds while a guard keeps the user out',
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
        containsAll([...flow, 'fake_feature.home', 'fake_gate.second']),
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

      // The gate opens: the walk expects each location itself again.
      fixtureGate.value = true;
      await tester.pumpAndSettle();
      expect(
        closedGuards(),
        isEmpty,
        reason: 'closedGuards() names no guard that allows.',
      );
      expect(
        [for (final walked in walkedLocations) shownFor(walked).route],
        routes,
        reason: 'Once the guards allow, the walk expects each location '
            'itself.',
      );
      final open = await walkRoutes(tester.pumpAndSettle);
      expect(
        open.all,
        isEmpty,
        reason: 'Once the guards allow, each location shows the page and the '
            'screen of its route.',
      );

      // A screen of the flow of the first guard makes the guard stop
      // allowing when it is shown: the test closes the gate as soon as the
      // walk shows the gate screen, and notes which screen of a flow each
      // location showed.
      const flows = {...flow, 'fake_gate.second'};
      expect(
        routes.skipWhile((route) => !flows.contains(route)),
        everyElement(isIn(flows)),
        reason: 'The walk goes to the locations in the flows of the guards '
            'after every other location.',
      );
      final shown = <String>[];
      Future<void> settle() async {
        await tester.pumpAndSettle();
        if (fixtureGate.value &&
            find.byType(FixtureGateScreen).evaluate().isNotEmpty) {
          fixtureGate.value = false;
          await tester.pumpAndSettle();
        }
        shown.add(
          [
            if (find.byType(FixtureGateScreen).evaluate().isNotEmpty)
              'fake_gate.gate',
            if (find.byType(FixtureGateStepScreen).evaluate().isNotEmpty)
              'fake_gate.step',
            if (find.byType(FixtureSecondGateScreen).evaluate().isNotEmpty)
              'fake_gate.second',
          ].join(', '),
        );
      }

      final closing = await walkRoutes(settle);
      expect(
        closing.all,
        isEmpty,
        reason: 'The walk holds when a screen of a flow makes its guard stop '
            'allowing while it is shown.',
      );
      expect(
        closedGuards(),
        ['fake_gate.first'],
        reason: 'The screen of the flow has made its guard stop allowing.',
      );
      expect(
        shown,
        [
          for (final route in routes)
            if (!flows.contains(route))
              // A screen of its own, which the walk has checked.
              ''
            else if (flow.contains(route))
              route
            else
              // The flow of the second guard, outside the flow of the first.
              'fake_gate.gate',
        ],
        reason: 'Every location outside the flows has shown its own screen '
            'before a screen of a flow made its guard stop allowing. The '
            'location of the flow of another guard then shows the target of '
            'that guard, which is all that the walk checks of it.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
