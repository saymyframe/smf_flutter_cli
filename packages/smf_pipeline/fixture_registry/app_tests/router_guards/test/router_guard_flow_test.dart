// A test that continuous integration runs in the apps of the fixture
// modules with a router, whichever module provides it, and the fixture
// gates: the router leaves the flow of a guard that starts allowing when
// it has no location to come back to, as RouterRole.guardedNavigation
// says. The app starts with its gates open, so the routes of the flows are
// routes like any other, and the user goes into the flow of the first
// guard. When its gate closes, the pages of the flow stay; when it opens,
// the router shows the screen that the app starts on. And a location in
// the flow of a guard is never the one that the user comes back to: from
// the target of the second guard, which the first guard takes out of the
// stack, the user comes to the start of the app too. So does the user of
// an app whose code goes to the target of a guard and then closes the
// guard, in one handler, as a sign-out does: the guard takes the user from
// no location, so the next user does not come to the page that the last
// one was on. Each expectation gives its reason, which a provider of the
// role with a known bug fails the test with (brokenProviders of the
// fixture registry).
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
    'a guard that starts allowing while its flow is shown, with no location '
    'to come back to, shows the screen that the app starts on',
    (tester) async {
      await startApp(tester);
      expect(
        heard(),
        [startScreen],
        reason: 'With guards that allow, the app starts on its start screen.',
      );

      // Into the flow while the guard allows: its routes are routes like
      // any other.
      shown(tester, FixtureHomeScreen).nav.fakeGate.step().go();
      await tester.pumpAndSettle();
      expect(
        heard(),
        [stepScreen],
        reason: 'With guards that allow, a route of a flow is a route like '
            'any other.',
      );
      final step = shown(tester, FixtureGateStepScreen);

      // The gate closes: the guard lets the user see the pages of its flow.
      fixtureGate.value = false;
      await tester.pumpAndSettle();
      expect(
        heard(),
        isEmpty,
        reason: 'A guard that stops allowing leaves the pages of its flow as '
            'they are.',
      );
      expect(
        step.mounted,
        isTrue,
        reason: 'A guard that stops allowing leaves the pages of its flow as '
            'they are.',
      );
      fixtureGate.poke();
      await tester.pumpAndSettle();
      expect(
        heard(),
        isEmpty,
        reason: 'A notification of a guard that changes nothing is not heard '
            'of.',
      );

      // The gate opens: nothing was asked for, so the router leaves the
      // flow for the screen that the app starts on.
      fixtureGate.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [startScreen],
        reason: 'When a guard starts allowing while a page of its flow is on '
            'top and there is no location to come back to, the router shows '
            'the screen that the app starts on.',
      );
      expect(
        builtScreens(tester),
        [FixtureHomeScreen],
        reason: 'The screen that the app starts on takes the place of the '
            'pages of the flow.',
      );

      // On a page of the flow of a guard that allows, a notification
      // without a change is not the end of the flow.
      shown(tester, FixtureHomeScreen).nav.fakeGate.gate().go();
      await tester.pumpAndSettle();
      expect(
        heard(),
        [gateScreen],
        reason: 'With guards that allow, the target of a guard is a route '
            'like any other.',
      );
      final gate = shown(tester, FixtureGateScreen);
      fixtureGate.poke();
      fixtureSecondGate.poke();
      await tester.pumpAndSettle();
      expect(
        heard(),
        isEmpty,
        reason: 'A notification of a guard that allowed before leaves a page '
            'of its flow as it is.',
      );
      expect(
        gate.mounted,
        isTrue,
        reason: 'A notification of a guard that allowed before leaves a page '
            'of its flow as it is.',
      );

      // The target of the second guard, a location in a flow, when the
      // first guard takes it out of the stack: it is not the location that
      // the user comes back to.
      gate.nav.fakeGate.second().go();
      await tester.pumpAndSettle();
      expect(
        heard(),
        [secondGateScreen],
        reason: 'With guards that allow, the target of a guard is a route '
            'like any other.',
      );
      fixtureGate.value = false;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [gateScreen],
        reason: 'When a guard stops allowing, the router shows its target in '
            'place of the pages that it keeps the user from.',
      );
      fixtureGate.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [startScreen],
        reason: 'A location in the flow of a guard is never the one that the '
            'user comes back to: the router shows the screen that the app '
            'starts on.',
      );
      expect(
        builtScreens(tester),
        [FixtureHomeScreen],
        reason: 'A location in the flow of a guard is never the one that the '
            'user comes back to: the router shows the screen that the app '
            'starts on.',
      );

      // A sign-out: on a page that is not the start of the app, the code
      // of the app goes to the target of the guard and closes the gate, in
      // one handler. The guard takes the user from no location, so once
      // the gate opens the user does not come back to that page.
      shown(tester, FixtureHomeScreen).nav.fakeFeature.details(id: 5).go();
      await tester.pumpAndSettle();
      expect(
        heard(),
        [('fake_feature.details', '/fake_feature/details/5')],
        reason: 'With guards that allow, go() shows the location.',
      );
      shown(tester, FixtureDetailsScreen).nav.fakeGate.gate().go();
      fixtureGate.value = false;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [gateScreen],
        reason: 'A guard that stops allowing right after go() to its target '
            'leaves its target as go() shows it.',
      );
      expect(
        builtScreens(tester),
        [FixtureGateScreen],
        reason: 'A guard that stops allowing right after go() to its target '
            'leaves its target as go() shows it.',
      );
      fixtureGate.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [startScreen],
        reason: 'A guard that stops allowing after go() to its target takes '
            'the user from no location: once it allows, the router shows the '
            'screen that the app starts on, not the page that the user was '
            'on.',
      );
      expect(
        builtScreens(tester),
        [FixtureHomeScreen],
        reason: 'A guard that stops allowing after go() to its target takes '
            'the user from no location: once it allows, the router shows the '
            'screen that the app starts on, not the page that the user was '
            'on.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
