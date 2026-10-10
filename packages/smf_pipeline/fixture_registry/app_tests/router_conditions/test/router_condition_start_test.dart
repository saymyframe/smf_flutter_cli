// A test that continuous integration runs in the apps of the fixture
// modules with a router, whichever module provides it, the fixture gates
// and the second fixture feature: the platform opens the app on a route
// that asks for a condition that does not hold, as a link to a screen of an
// account does for a guest. Every gate allows. A location from the
// platform takes the place of the stack, so the flow of the guard of the
// condition opens over the screen that the app starts on, of which the
// listeners of the screen hear nothing, and the router never builds the
// screen of the route (RouterRole.guardedNavigation). Once the condition
// holds, the router closes the flow and shows the location as go() to it
// does. A router that takes no location from the platform starts on the
// screen that the app starts on, and nothing happens once the condition
// holds.
//
// It uses what the tests of router_screens, of router_guards and of the
// conditions share. Each expectation gives its reason, which a provider of
// the role with a known bug fails the test with (brokenProviders of the
// fixture registry).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gate_screens.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gates.dart';
import 'package:{{app_name}}/features/fake_second/fixture_members_screens.dart';

import 'conditions.dart';
import 'guards.dart';
import 'screens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the app that the platform opens on a route that asks for a condition '
    'shows the flow of its guard over the screen that the app starts on, '
    'and the route once the condition holds',
    (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          memberCardScreen.$2;
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      fixtureHolder.value = false;
      await startApp(tester);
      final opened = heard();
      expect(
        opened,
        anyOf(equals([gateScreen]), equals([startScreen])),
        reason: 'The app that the platform opens on a route that asks for a '
            'condition that does not hold shows the target of the guard of '
            'the condition, of which alone the listeners of the screen '
            'hear; or its start screen, for a router that takes no location '
            'from the platform.',
      );
      expect(
        pagesForHolders(),
        0,
        reason: 'The router shows no page of a route whose condition does '
            'not hold.',
      );
      final inFlow = opened.single == gateScreen;
      expect(
        pagesBuilt(tester),
        inFlow ? [FixtureHomeScreen, FixtureGateScreen] : [FixtureHomeScreen],
        reason: 'The flow of a condition that a location from the platform '
            'opens is over the screen that the app starts on, which stays '
            'below it.',
      );

      await giveBadge(tester);
      if (!inFlow) {
        expect(
          heard(),
          isEmpty,
          reason: 'A condition that comes to hold leaves a page that does '
              'not ask for it as it is, with nothing that was asked for.',
        );
        return;
      }
      expect(
        heard(),
        [memberCardScreen],
        reason: 'Once the condition holds, the router shows the location '
            'that the platform opened the app on.',
      );
      expect(
        pagesBuilt(tester),
        [FixtureMembersScreen, FixtureMemberCardScreen],
        reason: 'Once the condition holds, the router shows the location '
            'that the platform opened the app on as go() to it does: its '
            'chain in place of the stack.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
