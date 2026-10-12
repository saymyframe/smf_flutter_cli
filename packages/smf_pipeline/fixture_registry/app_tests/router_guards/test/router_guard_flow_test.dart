// A test that continuous integration runs in the apps of the fixture
// modules with a router, whichever module provides it, and the fixture
// gates: the routes of the flow of a guard show only while the guard does
// not allow, as RouterRole.guardedNavigation says. The platform opens the
// app on a location of the flow of the first guard, as a link does, with
// the gate closed. A router that takes the location that the platform
// opens the app with shows it, and another shows the target of the guard
// in place of the location that the app starts on. When the gate opens,
// the router leaves the flow for the screen that the app starts on. From
// then on the flow is over: go(), push() and replace() of a location of
// it, and such a location from the platform, show the screen that the app
// starts on in place of the whole stack, and the router shows no page of
// the flow. The same holds for the flow of the second guard. When the gate
// closes again, the flow shows again, and once it opens, the user is back
// where they were, with the flow over again. Each expectation gives its
// reason, which a provider of the role with a known bug fails the test
// with (brokenProviders of the fixture registry).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_details_screen.dart';
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
    'the routes of the flow of a guard show only while the guard does not '
    'allow, and the screen that the app starts on in their place once the '
    'flow is over',
    (tester) async {
      /// Goes from the screen that the app starts on to the details of the
      /// item [id], a page on top of that screen, and returns its context:
      /// the page that the test asks for a location of a flow from.
      Future<BuildContext> toDetails(int id) async {
        shown(tester, FixtureHomeScreen).nav.fakeFeature.details(id: id).go();
        await tester.pumpAndSettle();
        expect(
          heard(),
          [('fake_feature.details', '/fake_feature/details/$id')],
          reason: 'With guards that allow, go() shows its location.',
        );
        return details(tester, id);
      }

      /// Checks that the screen that the app starts on is the only page,
      /// and that the listeners heard of it once. A failure gives [reason].
      void expectStartAlone(String reason) {
        expect(heard(), [startScreen], reason: reason);
        expect(builtScreens(tester), [FixtureHomeScreen], reason: reason);
      }

      /// How many pages of the routes of the fixture gates, the flows of
      /// the two guards, came on the navigators of the router so far.
      int pagesOfFlows() => pagesShown()
          .where((name) => name != null && name.startsWith('fake_gate.'))
          .length;

      // The platform opens the app on a location of the flow, as a link
      // does, with the gate closed.
      fixtureGate.value = false;
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          stepScreen.$2;
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      await startApp(tester);
      final opened = heard();
      expect(
        opened,
        anyOf(equals([stepScreen]), equals([gateScreen])),
        reason: 'While a guard does not allow, the app opens in its flow: on '
            'the location of the flow that the platform opens it with, or, '
            'for a router that takes no location from the platform, on the '
            'target of the guard.',
      );
      expect(
        builtScreens(tester),
        opened.single == stepScreen
            ? [FixtureGateScreen, FixtureGateStepScreen]
            : [FixtureGateScreen],
        reason: 'While a guard does not allow, the app shows the pages of '
            'its flow and no other.',
      );
      fixtureGate.poke();
      await tester.pumpAndSettle();
      expect(
        heard(),
        isEmpty,
        reason: 'A notification of a guard that changes nothing leaves the '
            'pages of its flow as they are.',
      );

      // The gate opens: the flow is over, and the router leaves it for the
      // screen that the app starts on.
      fixtureGate.value = true;
      await tester.pumpAndSettle();
      expectStartAlone(
        'When a guard starts allowing while a page of its flow is on top, '
        'the router leaves the flow: it shows the screen that the app '
        'starts on.',
      );
      final before = pagesOfFlows();

      // A location of the flow that is over, from a page that is not the
      // screen that the app starts on: that screen takes the whole stack,
      // whichever of go(), push() and replace() asks for the location, and
      // also for a route of the flow of the second guard.
      (await toDetails(1)).nav.fakeGate.step().go();
      await tester.pumpAndSettle();
      expectStartAlone(
        'go() to a location in a flow that is over shows the screen that '
        'the app starts on.',
      );
      final result = pushed((await toDetails(2)).nav.fakeGate.gate());
      await tester.pumpAndSettle();
      expectStartAlone(
        'push() of a location in a flow that is over shows the screen that '
        'the app starts on.',
      );
      expect(
        result(),
        isNull,
        reason: 'push() of a location in a flow that is over completes with '
            'null.',
      );
      (await toDetails(3)).nav.fakeGate.second().replace();
      await tester.pumpAndSettle();
      expectStartAlone(
        'replace() with a location in a flow that is over shows the screen '
        'that the app starts on.',
      );
      // A location from the platform: the router shows the screen that the
      // app starts on, or takes no locations from the platform and stays
      // where it is.
      final fromPlatform = await toDetails(4);
      await tester.binding.handlePushRoute(stepScreen.$2);
      await tester.pumpAndSettle();
      if (fromPlatform.mounted) {
        expect(
          heard(),
          isEmpty,
          reason: 'A router that takes no locations from the platform stays '
              'where it is.',
        );
        fromPlatform.nav.fakeFeature.home().go();
        await tester.pumpAndSettle();
        expect(
          heard(),
          [startScreen],
          reason: 'With guards that allow, go() shows its location.',
        );
      } else {
        expectStartAlone(
          'A location from the platform in a flow that is over shows the '
          'screen that the app starts on.',
        );
      }
      expect(
        pagesOfFlows(),
        before,
        reason: 'The router shows no page of a location in a flow that is '
            'over.',
      );

      // The gate closes: the flow shows again, with the target of the
      // guard in place of the stack, and the user goes on in it.
      await toDetails(5);
      fixtureGate.value = false;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [gateScreen],
        reason: 'When a guard stops allowing, the router shows its target in '
            'place of the pages that it keeps the user from.',
      );
      shown(tester, FixtureGateScreen).nav.fakeGate.step().go();
      await tester.pumpAndSettle();
      expect(
        heard(),
        [stepScreen],
        reason: 'While a guard does not allow, the routes of its flow show '
            'again.',
      );
      expect(
        builtScreens(tester),
        [FixtureGateScreen, FixtureGateStepScreen],
        reason: 'While a guard does not allow, the routes of its flow show '
            'again.',
      );

      // The gate opens: the user is back where they were, and the flow is
      // over again.
      fixtureGate.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [('fake_feature.details', '/fake_feature/details/5')],
        reason: 'Once a guard allows again, the router leaves its flow for '
            'the location that the guard took the user from.',
      );
      expect(
        builtScreens(tester),
        [FixtureHomeScreen, FixtureDetailsScreen],
        reason: 'Once a guard allows again, the router leaves its flow for '
            'the location that the guard took the user from.',
      );
      details(tester, 5).nav.fakeGate.gate().go();
      await tester.pumpAndSettle();
      expectStartAlone(
        'Each time a guard allows again, its flow is over again: go() to '
        'its target shows the screen that the app starts on.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
