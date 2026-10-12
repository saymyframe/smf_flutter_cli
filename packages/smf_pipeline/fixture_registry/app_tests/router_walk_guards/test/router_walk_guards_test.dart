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
// Once the gate opens, the flows of all the guards are over, as
// flowIsOver() of the app says. The walk then expects the screen that the
// app starts on in place of each location of a flow, and reaches every
// other route. So it never shows a screen of a flow that is over, and no
// such screen can change what the walk sees of the locations after it.
//
// The walk holds while a guard that stands for a condition does not allow
// too, with every gate open: the third guard of the fixture gates, once
// the test takes the badge of the fixture away. Such a guard keeps the
// user only from the routes that ask for its condition, those of the
// second fixture feature in an app with that feature. The walk expects the
// target of the guard on top for them, which the router opens over the
// page that the walk is on, and every other location as before, but for
// the flow of the guard, which is that of the first gate too and is not
// over now: its locations show themselves. closedGuards() names that guard
// as it names a gate.
//
// It uses what the tests of router_screens share, which every app that it
// applies to has. Each expectation gives its reason, which a provider of
// the role with a known bug fails the test with (brokenProviders of the
// fixture registry).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/app_router.dart';
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
    'the walk of the routes holds while a guard keeps the user out, once '
    'the flows of the guards are over, and while a condition does not hold',
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

      // The gate opens: the flows of all the guards are over. The walk
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

      // The condition of the third guard stops holding, with every gate
      // open. The routes that ask for it are those that the guard names,
      // if the app has any: the walk expects its target on top for them.
      // Its flow, the one of the first gate too, is not over while it does
      // not allow, so the locations of that flow show themselves, and
      // every other location shows what it showed before.
      fixtureHolder.value = false;
      await tester.pumpAndSettle();
      expect(
        closedGuards(),
        ['fake_gate.holder'],
        reason: 'closedGuards() names a guard that stands for a condition '
            'that does not hold, as it names a gate.',
      );
      final holder = routeGuards.singleWhere(
        (guard) => guard.name == 'fake_gate.holder',
      );
      final asking = holder.routes!;
      expect(
        asking.intersection({...flows, startOfApp.route}),
        isEmpty,
        reason: 'No route of a flow asks for a condition, and neither does '
            'the screen that the app starts on.',
      );
      expect(
        [for (final walked in walkedLocations) shownFor(walked).route],
        [
          for (final route in routes)
            if (asking.contains(route))
              'fake_gate.gate'
            else if (flow.contains(route))
              route
            else if (flows.contains(route))
              startOfApp.route
            else
              route,
        ],
        reason: 'While a condition does not hold, the walk expects the '
            'target of its guard for each location that asks for it, the '
            'locations of the flow of that guard themselves, and each other '
            'location as with guards that allow.',
      );
      final kept = await walkRoutes(tester.pumpAndSettle);
      expect(
        kept.all,
        isEmpty,
        reason: 'While a condition does not hold, each location that asks '
            'for it shows the target of its guard, each location of the '
            'flow of that guard its own screen, and each other location '
            'what it shows with guards that allow.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
