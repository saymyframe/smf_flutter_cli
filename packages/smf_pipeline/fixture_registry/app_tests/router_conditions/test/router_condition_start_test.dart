// A test that continuous integration runs in the apps of the fixture
// modules with a router, whichever module provides it, the fixture gates
// and the second fixture feature: the platform opens the app on a route
// that asks for two conditions, neither of which holds, as a link to a
// screen of a paid account does for a guest. Every gate allows. A location
// from the platform takes the place of the stack, so the flow of the first
// guard that does not allow opens over the screen that the app starts on,
// of which the listeners of the screen hear nothing, and the router never
// builds the screen of the route (RouterRole.guardedNavigation). Once the
// first condition holds, the router closes that flow and asks about the
// location again, so the flow of the next guard opens over the screen that
// the app starts on, of which the listeners still hear nothing. Once both
// hold, the router shows the location as go() to it does. A router that
// takes no location from the platform starts on the screen that the app
// starts on, and nothing happens once the conditions hold.
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

/// The route of the second fixture feature that asks for both conditions,
/// below a route that asks for the second, as the listeners of the screen
/// hear of it.
const _seatScreen = ('fake_second.loungeSeat', '/fake_second/lounge/seat');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the app that the platform opens on a route that asks for two '
    'conditions shows the flow of each guard in turn over the screen that '
    'the app starts on, and the route once both hold',
    (tester) async {
      /// The screens of the two routes of the lounge that the router built.
      List<Type> builtForSeniors() => [
            for (final widget in tester.allWidgets)
              if (widget is FixtureLoungeScreen ||
                  widget is FixtureLoungeSeatScreen)
                widget.runtimeType,
          ];

      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          _seatScreen.$2;
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      fixtureHolder.value = false;
      fixtureSenior.value = false;
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
        builtForSeniors(),
        isEmpty,
        reason: 'The router builds no screen of a route whose condition '
            'does not hold.',
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
        [secondGateScreen],
        reason: 'Once the first condition holds, the target of the guard of '
            'the second opens for the location that the platform opened the '
            'app on, and the listeners of the screen hear nothing of the '
            'screen that the app starts on between the two flows.',
      );
      expect(
        pagesBuilt(tester),
        [FixtureHomeScreen, FixtureSecondGateScreen],
        reason: 'Once the first condition holds, the target of the guard of '
            'the second opens over the screen that the app starts on, in '
            'place of the flow of the first.',
      );
      expect(
        builtForSeniors(),
        isEmpty,
        reason: 'The router builds no screen of a route while a condition '
            'that it asks for does not hold.',
      );

      fixtureSenior.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [_seatScreen],
        reason: 'Once both conditions hold, the router shows the location '
            'that the platform opened the app on.',
      );
      expect(
        pagesBuilt(tester),
        [FixtureLoungeScreen, FixtureLoungeSeatScreen],
        reason: 'Once both conditions hold, the router shows the location '
            'that the platform opened the app on as go() to it does: its '
            'chain in place of the stack.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
