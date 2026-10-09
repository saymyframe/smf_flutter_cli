// A test that continuous integration runs in the apps of the fixture
// modules with a router, whichever module provides it, the fixture gates
// and the fixture late gate: where the user comes to once a guard of the
// routes of the router role allows again is up to the guard, as
// RouterRole.guardedNavigation says. The guard of the fixture late gate
// does not bring the user back (RouteGuard.resumes), as the guard of a
// sign-in does not, and the first guard of the fixture gates does, as the
// guard of an onboarding does.
//
// The app starts as on a first launch, with both gates closed, and a
// location is asked for then. The late gate never allowed, so it did not
// stop: once both gates are open, the router shows that location. From
// then on, each time the late gate closes, the router forgets what it
// remembered, whichever guard made it remember. Once the gates are open
// again, it shows the screen that the app starts on, and neither a pushed
// page nor the location below it, when the late gate closes:
// - alone, with the pages of the app on the stack;
// - while the first gate is closed, which took the user from a location;
// - right after the first gate, or right before it, in one handler;
// - and opens again while the first gate is still closed;
// - after a location was asked for while the first gate was closed.
// A location that is asked for after the late gate closed is still the one
// that the user comes to, with its query.
//
// Each expectation gives its reason, which a provider of the role with a
// known bug fails the test with (brokenProviders of the fixture registry).
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
      /// Goes from the screen that the app starts on to the details of the
      /// item [id], a page on top of that screen.
      Future<void> toDetails(int id) async {
        shown(tester, FixtureHomeScreen).nav.fakeFeature.details(id: id).go();
        await tester.pumpAndSettle();
        expect(
          heard(),
          [('fake_feature.details', '/fake_feature/details/$id')],
          reason: 'With guards that allow, go() shows its location.',
        );
      }

      /// Opens the first gate and then the late gate, which is closed, and
      /// checks that the router shows the target of the late guard in
      /// between, and then the screen that the app starts on, alone. A
      /// failure of the last check gives [reason].
      Future<void> opensOnTheStart(String reason) async {
        fixtureGate.value = true;
        await tester.pumpAndSettle();
        expect(
          heard(),
          [lateGateScreen],
          reason: 'Once a guard allows, a guard of a later stage that does '
              'not allow shows its target.',
        );
        fixtureLateGate.value = true;
        await tester.pumpAndSettle();
        expect(heard(), [startScreen], reason: reason);
        expect(builtScreens(tester), [FixtureHomeScreen], reason: reason);
      }

      // A first launch: both gates are closed before the app starts, and a
      // location with a query is asked for while they are. The late gate
      // never allowed, so it did not stop.
      fixtureGate.value = false;
      fixtureLateGate.value = false;
      await startApp(tester);
      expect(
        heard(),
        [gateScreen],
        reason: 'Of the guards that do not allow, the first one of the '
            'earliest stage shows its target.',
      );
      final onGate = shown(tester, FixtureGateScreen);
      onGate.nav.fakeFeature.details(id: 9, tab: 'z').go();
      await tester.pumpAndSettle();
      expectHeardAtMostOnce(
        tester,
        onGate,
        gateScreen,
        reason: 'go() to a location that a guard keeps the user from shows '
            'the target of the guard.',
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
        [('fake_feature.details', '/fake_feature/details/9?tab=z')],
        reason: 'A guard that does not allow from the start of the app did '
            'not stop: the router shows the location that was asked for at '
            'the first launch once the guards allow.',
      );
      expect(
        builtScreens(tester),
        [FixtureHomeScreen, FixtureDetailsScreen],
        reason: 'A guard that does not allow from the start of the app did '
            'not stop: the router shows the location that was asked for at '
            'the first launch once the guards allow.',
      );

      // The late gate closes with a pushed page on top of that location:
      // its target takes the whole stack. Once it opens again, the router
      // shows the screen that the app starts on, alone.
      pushed(details(tester, 9).nav.fakeFeature.details(id: 2));
      await tester.pumpAndSettle();
      expect(
        heard(),
        [('fake_feature.details', '/fake_feature/details/2')],
        reason: 'With guards that allow, push() shows its location.',
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

      // A location that is asked for after the late gate closed, with a
      // query: the target stays, and once the gate opens, the router shows
      // that location, as go() to it does.
      await toDetails(3);
      fixtureLateGate.value = false;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [lateGateScreen],
        reason: 'When a guard stops allowing, the router shows its target in '
            'place of the pages that it keeps the user from.',
      );
      final onLateGate = shown(tester, FixtureLateGateScreen);
      onLateGate.nav.fakeFeature.details(id: 5, tab: 'b').go();
      await tester.pumpAndSettle();
      expectHeardAtMostOnce(
        tester,
        onLateGate,
        lateGateScreen,
        reason: 'go() to a location that a guard keeps the user from shows '
            'the target of the guard.',
      );
      fixtureLateGate.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [('fake_feature.details', '/fake_feature/details/5?tab=b')],
        reason: 'Once a guard that does not bring the user back allows, the '
            'router shows the latest location that was asked for after it '
            'stopped allowing, with its query.',
      );
      expect(
        builtScreens(tester),
        [FixtureHomeScreen, FixtureDetailsScreen],
        reason: 'Once a guard that does not bring the user back allows, the '
            'router shows the latest location that was asked for after it '
            'stopped allowing, with its query.',
      );

      // The first gate, whose guard brings the user back, closes over that
      // location, and the late gate closes while the flow of the first
      // guard is shown: the first guard decides all the while, and the
      // location that it took the user from is forgotten.
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
            'leaves the stack as it is.',
      );
      expect(
        first.mounted,
        isTrue,
        reason: 'A guard that stops allowing behind one that does not allow '
            'leaves the stack as it is.',
      );
      await opensOnTheStart(
        'When a guard that does not bring the user back stops allowing '
        'while the flow of another guard is shown, the router forgets the '
        'location that the other guard took the user from.',
      );

      // Both gates close in one handler, the first gate first, and then
      // the other way round: the screen that the app starts on either way.
      await toDetails(6);
      fixtureGate.value = false;
      fixtureLateGate.value = false;
      await tester.pumpAndSettle();
      expect(
        heard().lastOrNull,
        gateScreen,
        reason: 'When two guards stop allowing in one handler, the router '
            'shows the target of the one that the app asks first.',
      );
      expect(
        builtScreens(tester),
        [FixtureGateScreen],
        reason: 'When two guards stop allowing in one handler, the router '
            'shows the target of the one that the app asks first.',
      );
      await opensOnTheStart(
        'When a guard that does not bring the user back stops allowing '
        'right after a guard that does, in one handler, the router forgets '
        'the location that the other guard took the user from.',
      );
      await toDetails(7);
      fixtureLateGate.value = false;
      fixtureGate.value = false;
      await tester.pumpAndSettle();
      expect(
        heard().lastOrNull,
        gateScreen,
        reason: 'When two guards stop allowing in one handler, the router '
            'shows the target of the one that the app asks first.',
      );
      expect(
        builtScreens(tester),
        [FixtureGateScreen],
        reason: 'When two guards stop allowing in one handler, the router '
            'shows the target of the one that the app asks first.',
      );
      await opensOnTheStart(
        'When a guard that does not bring the user back stops allowing '
        'right before a guard that does, in one handler, the router '
        'remembers no location for either.',
      );

      // The late gate closes and opens again while the first gate is
      // closed: the router shows nothing of it, and the location that the
      // first guard took the user from is forgotten all the same.
      await toDetails(8);
      fixtureGate.value = false;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [gateScreen],
        reason: 'When a guard stops allowing, the router shows its target in '
            'place of the pages that it keeps the user from.',
      );
      final still = shown(tester, FixtureGateScreen);
      fixtureLateGate.value = false;
      await tester.pumpAndSettle();
      fixtureLateGate.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        isEmpty,
        reason: 'A guard that stops and starts allowing behind one that does '
            'not allow leaves the stack as it is.',
      );
      expect(
        still.mounted,
        isTrue,
        reason: 'A guard that stops and starts allowing behind one that does '
            'not allow leaves the stack as it is.',
      );
      fixtureGate.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [startScreen],
        reason: 'When a guard that does not bring the user back stopped and '
            'allows again while the flow of another guard is shown, the '
            'router has forgotten the location that the other guard took '
            'the user from.',
      );
      expect(
        builtScreens(tester),
        [FixtureHomeScreen],
        reason: 'When a guard that does not bring the user back stopped and '
            'allows again while the flow of another guard is shown, the '
            'router has forgotten the location that the other guard took '
            'the user from.',
      );

      // A location is asked for while the first gate is closed, and the
      // late gate closes after it: that location is forgotten too.
      await toDetails(4);
      fixtureGate.value = false;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [gateScreen],
        reason: 'When a guard stops allowing, the router shows its target in '
            'place of the pages that it keeps the user from.',
      );
      final asking = shown(tester, FixtureGateScreen);
      asking.nav.fakeFeature.details(id: 10, tab: 'c').go();
      await tester.pumpAndSettle();
      expectHeardAtMostOnce(
        tester,
        asking,
        gateScreen,
        reason: 'go() to a location that a guard keeps the user from shows '
            'the target of the guard.',
      );
      fixtureLateGate.value = false;
      await tester.pumpAndSettle();
      expect(
        heard(),
        isEmpty,
        reason: 'A guard that stops allowing behind one that does not allow '
            'leaves the stack as it is.',
      );
      await opensOnTheStart(
        'When a guard that does not bring the user back stops allowing, the '
        'router forgets a location that was asked for before, while another '
        'guard did not allow.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
