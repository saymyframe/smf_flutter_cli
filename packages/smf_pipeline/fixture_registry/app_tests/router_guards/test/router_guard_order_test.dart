// A test that continuous integration runs in the apps of the fixture
// modules with a router, whichever module provides it, the fixture gates
// and the fixture late gate: the router asks the guards of the routes of
// the router role in their order, as redirectOf() of the role does. That
// order is by the stages of the guards, whatever the order of the modules:
// the guards of the fixture gates are of the stage before that of the
// guard of the fixture late gate, whose module the app lists before
// theirs. The gates come before the guards that stand for a condition: the
// fixture gates declare such a guard between their two gates, with the
// stage of both, and the app lists it last. Its condition holds here, so
// it keeps the user from nothing. All three gates are closed before the
// app starts. The first
// guard that does not allow shows its target, and the targets of the
// guards after it are then routes like any other; once the first allows,
// the second shows its target, and once that one allows, the guard of the
// later stage. Once all allow, the router shows the location that the app
// starts on, which they kept the user from: the targets that the test
// asked for since are in the flows of the guards, and such a location is
// never the one that the user comes back to. Each expectation gives its
// reason, which a provider of the role with a known bug fails the test
// with (brokenProviders of the fixture registry).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/app_router.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gate_screens.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gates.dart';
import 'package:{{app_name}}/features/fake_late_gate/fixture_late_gate.dart';
import 'package:{{app_name}}/features/fake_late_gate/fixture_late_gate_screen.dart';

import 'guards.dart';
import 'screens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the first guard that does not allow shows its target, and the next one '
    'once it allows',
    (tester) async {
      fixtureGate.value = false;
      fixtureSecondGate.value = false;
      fixtureLateGate.value = false;
      await startApp(tester);
      expect(
        heard(),
        [gateScreen],
        reason: 'Of the guards that do not allow, the first one of the '
            'earliest stage shows its target, whatever the order of the '
            'modules.',
      );
      expect(
        [for (final guard in routeGuards) guard.name],
        [
          'fake_gate.first',
          'fake_gate.second',
          'fake_late_gate.late',
          'fake_gate.holder',
          'fake_gate.senior',
        ],
        reason: 'The app lists its gates by their stages, and those of one '
            'stage in the order of the modules and of their declarations, '
            'and then its guards that stand for a condition.',
      );
      final gate = shown(tester, FixtureGateScreen);
      gate.nav.fakeGate.second().go();
      await tester.pumpAndSettle();
      expectHeardAtMostOnce(
        tester,
        gate,
        gateScreen,
        reason: 'While a guard does not allow, the target of a guard after '
            'it is a route like any other.',
      );
      expect(
        builtScreens(tester),
        [FixtureGateScreen],
        reason: 'While a guard does not allow, the target of a guard after '
            'it is a route like any other.',
      );
      final still = shown(tester, FixtureGateScreen);
      still.nav.fakeLateGate.gate().go();
      await tester.pumpAndSettle();
      expectHeardAtMostOnce(
        tester,
        still,
        gateScreen,
        reason: 'While a guard does not allow, the target of a guard of a '
            'later stage is a route like any other.',
      );

      // The first gate opens: the second guard shows its target, and the
      // flow of the first is then outside the flow of the one that decides.
      fixtureGate.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [secondGateScreen],
        reason: 'Once a guard allows, the next one that does not allow shows '
            'its target.',
      );
      expect(
        builtScreens(tester),
        [FixtureSecondGateScreen],
        reason: 'Once a guard allows, the target of the next one that does '
            'not allow takes the whole stack.',
      );
      final second = shown(tester, FixtureSecondGateScreen);
      second.nav.fakeGate.gate().go();
      await tester.pumpAndSettle();
      expectHeardAtMostOnce(
        tester,
        second,
        secondGateScreen,
        reason: 'While a guard does not allow, the flow of a guard that '
            'allows is outside its flow.',
      );

      // The second gate opens too: the guard of the later stage shows its
      // target, after every guard of the stage before it.
      fixtureSecondGate.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [lateGateScreen],
        reason: 'Once the guards of a stage allow, a guard of a later stage '
            'that does not allow shows its target.',
      );
      expect(
        builtScreens(tester),
        [FixtureLateGateScreen],
        reason: 'Once the guards of a stage allow, the target of a guard of '
            'a later stage that does not allow takes the whole stack.',
      );

      // The late gate opens too: the router shows the location that the
      // app starts on, which the guards kept the user from, and not the
      // target of a guard that the test asked for since, a location in a
      // flow.
      fixtureLateGate.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [startScreen],
        reason: 'Once every guard allows, the router shows the location '
            'that the guards kept the user from, and never one in the flow '
            'of a guard.',
      );
      expect(
        builtScreens(tester),
        [FixtureHomeScreen],
        reason: 'Once every guard allows, the router shows the location '
            'that the guards kept the user from, and never one in the flow '
            'of a guard.',
      );

      // The gates close in the other order: the target of the guard of the
      // later stage, then that of the second guard, and then that of the
      // first, each of which decides before the ones after it.
      fixtureLateGate.value = false;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [lateGateScreen],
        reason: 'When a guard stops allowing, the router shows its target.',
      );
      fixtureSecondGate.value = false;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [secondGateScreen],
        reason: 'When a guard stops allowing, it decides before a guard of a '
            'later stage.',
      );
      fixtureGate.value = false;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [gateScreen],
        reason: 'When a guard stops allowing, it decides before the guards '
            'after it.',
      );
      final first = shown(tester, FixtureGateScreen);
      fixtureSecondGate.value = true;
      fixtureLateGate.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        isEmpty,
        reason: 'A guard that starts allowing behind one that does not '
            'changes nothing.',
      );
      expect(
        first.mounted,
        isTrue,
        reason: 'A guard that starts allowing behind one that does not '
            'changes nothing.',
      );
      fixtureGate.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [startScreen],
        reason: 'Once the last guard that does not allow allows, the router '
            'leaves its flow for the screen that the app starts on.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
