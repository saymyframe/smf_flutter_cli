// A test that continuous integration runs in the apps of the fixture
// modules with a router, whichever module provides it, and the fixture
// gates: a guard of the routes of the router role that starts allowing
// before the router shows its first location keeps the user from nothing.
// The platform opens the app on a location outside every flow, as a link
// does. Something reads the router of the app while the first gate is
// closed, as the start-up of a module may, and the gate notifies and then
// opens before the app starts. The router has no page then, so it has none
// to tell the guards of (RouterRole.guardedNavigation). The app starts on
// the location that it is opened with, the one from the platform or, for a
// router that takes no location from the platform, the screen that it
// starts on, and not in the flow of the guard, which is over. Once the app
// runs, a notification of the guard that changes nothing leaves that
// screen as it is. It uses what the tests of router_screens and of
// router_guards share. Each expectation gives its reason, which a provider
// of the role with a known bug fails the test with (brokenProviders of the
// fixture registry).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/app_router.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_details_screen.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gates.dart';

import 'guards.dart';
import 'screens.dart';

/// The location that the platform opens the app with: a route of the
/// fixture feature outside every flow, with a query, as the listeners of
/// the screen hear of it.
const _linked = ('fake_feature.details', '/fake_feature/details/7?tab=a');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'a guard that starts allowing before the router shows its first '
    'location lets the app start on the location that it is opened with',
    (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = _linked.$2;
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      // The router is created while the guard does not allow, before the
      // app starts. The guard notifies without a change, and then starts
      // allowing, both before the first frame.
      fixtureGate.value = false;
      expect(
        appRouter,
        isA<AppRouter>(),
        reason: 'The router of the app is created on its first use.',
      );
      fixtureGate.poke();
      fixtureGate.value = true;
      await startApp(tester);
      final opened = heard();
      expect(
        opened,
        anyOf(equals([_linked]), equals([startScreen])),
        reason: 'With guards that allow when the app starts, the app starts '
            'on the location that it is opened with: the one from the '
            'platform, or its start screen for a router that takes no '
            'location from the platform.',
      );
      final onLinked = opened.single == _linked;
      expect(
        builtScreens(tester),
        onLinked
            ? [FixtureHomeScreen, FixtureDetailsScreen]
            : [FixtureHomeScreen],
        reason: 'With guards that allow when the app starts, the app shows '
            'no page of the flow of a guard.',
      );
      final onTop =
          onLinked ? details(tester, 7) : shown(tester, FixtureHomeScreen);

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
        onTop.mounted,
        isTrue,
        reason: 'A notification of a guard that changes nothing leaves the '
            'stack as it is, also when the guard changed before the router '
            'showed its first location.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
