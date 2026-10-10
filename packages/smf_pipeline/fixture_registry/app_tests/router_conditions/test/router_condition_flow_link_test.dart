// A test that continuous integration runs in the apps of the fixture
// modules with a router, whichever module provides it, the fixture gates
// and the second fixture feature: a link to a page of the flow of a guard
// that stands for a condition, while the condition does not hold and every
// gate allows, as a link to a sign-in screen for a guest. Such a flow is
// not over, so its pages show. A location from the platform takes the
// place of the stack, and the page would stand alone, with no way back
// into the app. So the router shows it over the screen that the app starts
// on (RouterRole.guardedNavigation), of which the listeners of the screen
// hear nothing: back leads into the app, and once the condition holds the
// router closes the flow and the user is on that screen.
//
// The platform opens the app on the target of the third guard of the
// fixture gates, which stands for the first condition of the fixture badge
// role. Then links arrive while the app runs: for the route below the
// target, with a query, which shows over the screen that the app starts on
// alone; for the target while the flow of the other guard is open; and for
// the target while the gate with the same flow does not allow, whose flow
// takes the place of the stack as before. And once the user went back
// from the page of a link, nothing of the link shows again: its request
// was dropped with the page.
//
// A router that takes no location from the platform starts on the screen
// that the app starts on. The test tells it from a router that shows that
// screen for the link by a location of a route that asks for nothing,
// which such a router shows to nobody when the platform asks for it.
//
// It uses what the tests of router_screens, of router_guards and of the
// conditions share. Each expectation gives its reason, which a provider of
// the role with a known bug fails the test with (brokenProviders of the
// fixture registry).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gate_screens.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gates.dart';

import 'conditions.dart';
import 'guards.dart';
import 'screens.dart';

/// The route of the second fixture feature that asks for the second
/// condition, as the listeners of the screen hear of it.
const _loungeScreen = ('fake_second.lounge', '/fake_second/lounge');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'a link to a page of the flow of a condition opens the page over the '
    'screen that the app starts on, back leads into the app, and the flow '
    'closes once the condition holds',
    (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          gateScreen.$2;
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      fixtureHolder.value = false;
      await startApp(tester);
      final opened = heard();
      expect(
        opened,
        anyOf(equals([gateScreen]), equals([startScreen])),
        reason: 'The app that the platform opens on a page of the flow of a '
            'condition that does not hold shows that page, of which alone '
            'the listeners of the screen hear; or its start screen, for a '
            'router that takes no location from the platform.',
      );
      if (opened.single == startScreen) {
        await tester.binding.handlePushRoute(detailsScreen(7).$2);
        await tester.pumpAndSettle();
        expect(
          heard(),
          isEmpty,
          reason: 'A router that takes locations from the platform shows a '
              'page of the flow of a condition that the platform opens the '
              'app on. Only a router that takes none, and so shows a '
              'location of a route that asks for nothing to nobody, starts '
              'on its start screen.',
        );
        return;
      }
      expect(
        pagesBuilt(tester),
        [FixtureHomeScreen, FixtureGateScreen],
        reason: 'A page of the flow of a condition that the platform opens '
            'the app on shows over the screen that the app starts on, which '
            'is built below it.',
      );
      await back(tester);
      expect(
        heard(),
        [startScreen],
        reason: 'Back from a page of the flow of a condition that a link '
            'opened leads into the app, to the screen that it starts on.',
      );
      expect(
        pagesBuilt(tester),
        [FixtureHomeScreen],
        reason: 'Back from a page of the flow of a condition that a link '
            'opened closes that page.',
      );

      // The request of the link was dropped with its page: when the router
      // next closes pages, as those of a route whose condition stops
      // holding, it asks for nothing of the link again.
      pushed(shown(tester, FixtureHomeScreen).nav.fakeSecond.lounge());
      await tester.pumpAndSettle();
      expect(
        heard(),
        [_loungeScreen],
        reason: 'While a condition holds, push() of a route that asks for it '
            'shows the route.',
      );
      fixtureSenior.value = false;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [startScreen],
        reason: 'A link whose page the user went back from is dropped: when '
            'the router next closes pages, the user is on the page below '
            'them, and the page of the link does not open again.',
      );
      expect(
        pagesBuilt(tester),
        [FixtureHomeScreen],
        reason: 'A link whose page the user went back from is dropped: when '
            'the router next closes pages, the page of the link does not '
            'open again.',
      );

      // A link while the app runs, for the route below the target, with a
      // query: the page shows over the screen that the app starts on
      // alone, without the page of the route above it.
      await toDetails(tester, 1);
      await takeBadge(tester);
      await tester.binding.handlePushRoute('${stepScreen.$2}?from=link');
      await tester.pumpAndSettle();
      expect(
        heard(),
        [(stepScreen.$1, '${stepScreen.$2}?from=link')],
        reason: 'A link to a route below the target of a guard of a '
            'condition shows that route, at its location with its query.',
      );
      expect(
        pagesBuilt(tester),
        [FixtureHomeScreen, FixtureGateStepScreen],
        reason: 'A link to a route below the target of a guard of a '
            'condition shows its page over the screen that the app starts '
            'on, in place of the stack.',
      );
      await back(tester);
      expect(
        heard(),
        [startScreen],
        reason: 'Back from a page of the flow of a condition that a link '
            'opened leads to the screen that the app starts on.',
      );

      // A link to the target while the flow of the other guard is open
      // over the screen that the app starts on: it takes the place of the
      // stack, and of that flow with its request.
      fixtureSenior.value = false;
      await tester.pumpAndSettle();
      final waiting = pushed(
        shown(tester, FixtureHomeScreen).nav.fakeSecond.lounge(),
      );
      await tester.pumpAndSettle();
      expect(
        heard(),
        [secondGateScreen],
        reason: 'push() of a route that asks for a condition that does not '
            'hold opens the target of the guard of the condition.',
      );
      await tester.binding.handlePushRoute(gateScreen.$2);
      await tester.pumpAndSettle();
      expect(
        heard(),
        [gateScreen],
        reason: 'A link to a page of the flow of a condition shows that '
            'page, of which alone the listeners of the screen hear, also '
            'while the flow of another guard is open.',
      );
      expect(
        pagesBuilt(tester),
        [FixtureHomeScreen, FixtureGateScreen],
        reason: 'A link to a page of the flow of a condition shows it over '
            'the screen that the app starts on, in place of the stack and '
            'of the flow of another guard that was open.',
      );
      expect(
        waiting(),
        isNull,
        reason: 'The request that waited for a flow is dropped when a link '
            'takes the place of the stack.',
      );

      // The condition holds: the flow closes, and nothing shows in its
      // place but the screen below it.
      await giveBadge(tester);
      expect(
        heard(),
        [startScreen],
        reason: 'Once the condition holds, the router closes a page of its '
            'flow that a link opened, and the user is on the screen that '
            'the app starts on, of which the listeners hear once.',
      );
      expect(
        pagesBuilt(tester),
        [FixtureHomeScreen],
        reason: 'Once the condition holds, the router closes a page of its '
            'flow that a link opened, and shows nothing in its place.',
      );

      // The gate with the same flow does not allow: the flow is the
      // gate's, and its page takes the place of the stack, as for any gate.
      await toDetails(tester, 3);
      await takeBadge(tester);
      fixtureGate.value = false;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [gateScreen],
        reason: 'A gate that stops allowing shows its target.',
      );
      await tester.binding.handlePushRoute(stepScreen.$2);
      await tester.pumpAndSettle();
      expect(
        heard(),
        [stepScreen],
        reason: 'While a gate does not allow, a link to a route of its flow '
            'shows that route.',
      );
      expect(
        pagesBuilt(tester),
        [FixtureGateScreen, FixtureGateStepScreen],
        reason: 'While a gate does not allow, a page of its flow takes the '
            'place of the stack, though a guard of a condition has the same '
            'flow: no page that the gate keeps the user from is below it.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
