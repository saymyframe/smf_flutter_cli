// A test that continuous integration runs in the apps of the fixture
// modules with a router, whichever module provides it, and the fixture
// gates: the router asks the guards of the routes of the router role in
// their order, as redirectOf() of the role does. Both gates are closed
// before the app starts. The first guard that does not allow shows its
// target, and the target of the guard after it is then a route like any
// other; once the first allows, the second shows its target; and once both
// allow, the router shows the location that the app starts on, which they
// kept the user from: the targets that the test asked for since are in the
// flows of the guards, and such a location is never the one that the user
// comes back to. Each expectation gives its reason, which a provider of the
// role with a known bug fails the test with (brokenProviders of the fixture
// registry).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gate_screens.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gates.dart';

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
      await startApp(tester);
      expect(
        heard(),
        [gateScreen],
        reason: 'Of two guards that do not allow, the first shows its target.',
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

      // The second gate opens too: the router shows the location that the
      // app starts on, which the guards kept the user from, and not the
      // target of a guard that the test asked for since, a location in a
      // flow.
      fixtureSecondGate.value = true;
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

      // The gates close in the other order: the target of the second
      // guard, and then that of the first, which decides before it.
      fixtureSecondGate.value = false;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [secondGateScreen],
        reason: 'When a guard stops allowing, the router shows its target.',
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
        reason: 'The router comes back to the screen that the user saw '
            'when the first of the guards stopped allowing.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
