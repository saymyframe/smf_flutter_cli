// A test that continuous integration runs in the apps of the fixture
// modules with a router, whichever module provides it, and the fixture
// gates: a guard of the routes of the router role that changes before the
// router shows its first location ends no flow later. Something reads the
// router of the app while the first gate is closed, as the start-up of a
// module may, and the gate opens before the app starts. The router has no
// page then, and tells the guards of none, so that they take note of what
// they allow (RouterRole.guardedNavigation). Once the app runs and the user
// is in the flow of the guard, a notification of the guard that changes
// nothing leaves the page as it is: the guard did not start allowing just
// then. It uses what the tests of router_screens and of router_guards
// share. Each expectation gives its reason, which a provider of the role
// with a known bug fails the test with (brokenProviders of the fixture
// registry).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/app_router.dart';
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
    'a guard that changes before the router shows its first location ends '
    'no flow later',
    (tester) async {
      // The router is created while the guard does not allow, before the
      // app starts, and the guard starts allowing before the first frame.
      fixtureGate.value = false;
      expect(
        appRouter,
        isA<AppRouter>(),
        reason: 'The router of the app is created on its first use.',
      );
      fixtureGate.value = true;
      await startApp(tester);
      expect(
        heard(),
        [startScreen],
        reason: 'With guards that allow when the app starts, the app starts '
            'on its start screen.',
      );

      // Into the flow of the guard, which allows.
      shown(tester, FixtureHomeScreen).nav.fakeGate.step().go();
      await tester.pumpAndSettle();
      expect(
        heard(),
        [stepScreen],
        reason: 'With guards that allow, a route of a flow is a route like '
            'any other.',
      );
      final step = shown(tester, FixtureGateStepScreen);

      // A notification without a change: the guard allowed before, so its
      // flow is not over now.
      fixtureGate.poke();
      await tester.pumpAndSettle();
      expect(
        heard(),
        isEmpty,
        reason: 'A notification of a guard that changes nothing leaves a '
            'page of its flow as it is, also when the guard changed before '
            'the router showed its first location.',
      );
      expect(
        step.mounted,
        isTrue,
        reason: 'A notification of a guard that changes nothing leaves a '
            'page of its flow as it is, also when the guard changed before '
            'the router showed its first location.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
