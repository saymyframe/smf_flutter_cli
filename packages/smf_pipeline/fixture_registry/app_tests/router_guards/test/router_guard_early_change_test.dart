// A test that continuous integration runs in the apps of the fixture
// modules with a router, whichever module provides it, and the fixture
// gates: a guard of the routes of the router role that starts allowing
// before the router shows its first location keeps the user from nothing.
// Something reads the router of the app while the first gate is closed, as
// the start-up of a module may, and the gate opens before the app starts.
// The router has no page then, so it has none to tell the guards of
// (RouterRole.guardedNavigation), and the app starts on the screen that it
// starts on, not in the flow of the guard, which is over. Once the app
// runs, a notification of the guard that changes nothing leaves that
// screen as it is. It uses what the tests of router_screens and of
// router_guards share. Each expectation gives its reason, which a provider
// of the role with a known bug fails the test with (brokenProviders of the
// fixture registry).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/app_router.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gates.dart';

import 'guards.dart';
import 'screens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'a guard that starts allowing before the router shows its first '
    'location lets the app start on its start screen',
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
      expect(
        builtScreens(tester),
        [FixtureHomeScreen],
        reason: 'With guards that allow when the app starts, the app shows '
            'no page of the flow of a guard.',
      );
      final home = shown(tester, FixtureHomeScreen);

      // A notification without a change, once the app runs.
      fixtureGate.poke();
      await tester.pumpAndSettle();
      expect(
        heard(),
        isEmpty,
        reason: 'A notification of a guard that changes nothing leaves the '
            'stack as it is, also when the guard changed before the router '
            'showed its first location.',
      );
      expect(
        home.mounted,
        isTrue,
        reason: 'A notification of a guard that changes nothing leaves the '
            'stack as it is, also when the guard changed before the router '
            'showed its first location.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
