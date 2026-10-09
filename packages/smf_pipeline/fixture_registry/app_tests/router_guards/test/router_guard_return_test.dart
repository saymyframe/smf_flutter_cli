// A test that continuous integration runs in the apps of the fixture
// modules with a router, whichever module provides it, the fixture gates
// and the fixture late gate: where the user comes to once a guard of the
// routes of the router role allows again is up to the guard, as
// RouterRole.guardedNavigation says. The guard of the fixture late gate
// does not bring the user back (RouteGuard.resumes). When its gate closes,
// its target takes the place of the pages of the app, and once the gate
// opens, the router shows the screen that the app starts on, and neither
// the page that a push showed nor the location below it. A location that
// is asked for while the gate is closed is still the one that the user
// comes to, with its query. And the guard forgets nothing that another
// guard made the router remember: the first guard of the fixture gates,
// which brings the user back, closes over a location, the late gate
// closes and opens behind it, and the user is back on that location once
// both allow. The app starts with its gates open. Each expectation gives
// its reason, which a provider of the role with a known bug fails the test
// with (brokenProviders of the fixture registry).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_details_screen.dart';
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
    'a guard that does not bring the user back shows the screen that the '
    'app starts on once it allows again, or a location that was asked for '
    'while it did not allow',
    (tester) async {
      await startApp(tester);
      expect(
        heard(),
        [startScreen],
        reason: 'With guards that allow, the app starts on its start screen.',
      );

      // A pushed page on top of a child, whose location has a query, and
      // its parent: the gate closes, and its target takes the whole stack.
      shown(tester, FixtureHomeScreen)
          .nav
          .fakeFeature
          .details(id: 1, tab: 'a')
          .go();
      await tester.pumpAndSettle();
      pushed(details(tester, 1).nav.fakeFeature.details(id: 2));
      await tester.pumpAndSettle();
      expect(
        heard(),
        [
          ('fake_feature.details', '/fake_feature/details/1?tab=a'),
          ('fake_feature.details', '/fake_feature/details/2'),
        ],
        reason: 'With guards that allow, go() and push() show their '
            'locations.',
      );
      fixtureLateGate.value = false;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [lateGateScreen],
        reason: 'When a guard stops allowing, the router shows its target in '
            'place of the pages that it keeps the user from.',
      );
      expect(
        builtScreens(tester),
        [FixtureLateGateScreen],
        reason: 'When a guard stops allowing, no page that it keeps the user '
            'from stays in the stack.',
      );

      // The gate opens again: the screen that the app starts on, alone, and
      // not the location that the guard took the user from.
      fixtureLateGate.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [startScreen],
        reason: 'Once a guard that does not bring the user back allows '
            'again, the router shows the screen that the app starts on, and '
            'not the location that the guard took the user from.',
      );
      expect(
        builtScreens(tester),
        [FixtureHomeScreen],
        reason: 'Once a guard that does not bring the user back allows '
            'again, the router shows the screen that the app starts on, and '
            'not the location that the guard took the user from.',
      );

      // A location that is asked for while the gate is closed, with a
      // query: the target stays, and once the gate opens, the router shows
      // that location, as go() to it does.
      shown(tester, FixtureHomeScreen).nav.fakeFeature.details(id: 3).go();
      await tester.pumpAndSettle();
      expect(
        heard(),
        [('fake_feature.details', '/fake_feature/details/3')],
        reason: 'With guards that allow, go() shows its location.',
      );
      fixtureLateGate.value = false;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [lateGateScreen],
        reason: 'When a guard stops allowing, the router shows its target in '
            'place of the pages that it keeps the user from.',
      );
      final gate = shown(tester, FixtureLateGateScreen);
      gate.nav.fakeFeature.details(id: 5, tab: 'b').go();
      await tester.pumpAndSettle();
      expectHeardAtMostOnce(
        tester,
        gate,
        lateGateScreen,
        reason: 'go() to a location that a guard keeps the user from shows '
            'the target of the guard.',
      );
      expect(
        builtScreens(tester),
        [FixtureLateGateScreen],
        reason: 'go() to a location that a guard keeps the user from shows '
            'the target of the guard.',
      );
      fixtureLateGate.value = true;
      await tester.pumpAndSettle();
      const asked = ('fake_feature.details', '/fake_feature/details/5?tab=b');
      expect(
        heard(),
        [asked],
        reason: 'Once a guard that does not bring the user back allows, the '
            'router shows the latest location that was asked for while it '
            'did not allow, with its query.',
      );
      expect(
        builtScreens(tester),
        [FixtureHomeScreen, FixtureDetailsScreen],
        reason: 'Once a guard that does not bring the user back allows, the '
            'router shows the latest location that was asked for while it '
            'did not allow, with its query.',
      );

      // A guard that brings the user back closes over that location, and
      // the late gate closes and opens behind it: the first guard decides
      // all the while, and what it made the router remember stays.
      fixtureGate.value = false;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [gateScreen],
        reason: 'When a guard stops allowing, the router shows its target in '
            'place of the pages that it keeps the user from.',
      );
      final first = shown(tester, FixtureGateScreen);
      fixtureLateGate.value = false;
      await tester.pumpAndSettle();
      expect(
        heard(),
        isEmpty,
        reason: 'A guard that stops allowing behind one that does not allow '
            'changes nothing.',
      );
      expect(
        first.mounted,
        isTrue,
        reason: 'A guard that stops allowing behind one that does not allow '
            'changes nothing.',
      );
      fixtureGate.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [lateGateScreen],
        reason: 'Once a guard allows, a guard of a later stage that does not '
            'allow shows its target.',
      );
      fixtureLateGate.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [asked],
        reason: 'A guard that does not bring the user back forgets nothing: '
            'the router shows the location that a guard before it took the '
            'user from.',
      );
      expect(
        tester
            .widget<FixtureDetailsScreen>(find.byType(FixtureDetailsScreen))
            .tab,
        'b',
        reason: 'A guard that does not bring the user back forgets nothing: '
            'the router shows the location that a guard before it took the '
            'user from, with its query.',
      );

      // That location is forgotten once the router has shown it: the late
      // gate closes and opens, and the user is on the screen that the app
      // starts on.
      fixtureLateGate.value = false;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [lateGateScreen],
        reason: 'When a guard stops allowing, the router shows its target in '
            'place of the pages that it keeps the user from.',
      );
      fixtureLateGate.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [startScreen],
        reason: 'Each time a guard that does not bring the user back allows '
            'again, the router shows the screen that the app starts on.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
