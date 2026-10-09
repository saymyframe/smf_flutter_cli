// A test that continuous integration runs in the apps of the fixture
// modules with a router and a layout, whichever modules provide them, both
// fixture features and the fixture gates: when a guard of the routes of
// the router role stops allowing while a page is shown over the main
// navigation, as a push shows it, the user comes back into the main
// navigation once the guard allows, to the destination that the page was
// opened from, and not to that page alone, with no way back
// (RouterRole.guardedNavigation). While the guard does not allow, the main
// navigation is not shown, and the target of the guard takes the stacks of
// every branch: a branch that was not selected is back on its destination
// when the user selects it. A location in a flow that is over is another
// matter: asked for from the main navigation, it shows the screen that the
// app starts on, as go() to that screen does, and hides nothing from the
// user. So whether a branch that is not selected keeps its pages then is
// up to the router, and the test does not look at it. It selects a
// destination as the layout does when the user selects it, with onSelect
// of AppShell, so it depends neither on the router nor on how the layout
// shows the destinations. It uses what the tests of router_screens and of
// router_guards share, which every app that it applies to has. Each
// expectation gives its reason, which a provider of a role with a known
// bug fails the test with (brokenProviders of the fixture registry).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/layout/app_shell.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_details_screen.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gate_screens.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gates.dart';
import 'package:{{app_name}}/features/fake_second/fixture_outside_screen.dart';
import 'package:{{app_name}}/features/fake_second/fixture_second_screen.dart';

import 'guards.dart';
import 'screens.dart';

/// The page outside the main navigation of the second fixture feature, as
/// the listeners of the screen hear of it.
const _outsideScreen = ('fake_second.outside', '/fake_second/outside');

/// The destination of the second fixture feature, as the listeners of the
/// screen hear of it.
const _secondScreen = ('fake_second.second', '/fake_second');

/// The main navigations in the tree, the one that a page covers too.
Finder _shells() => find.byType(AppShell, skipOffstage: false);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the user comes back into the main navigation, to the destination that '
    'a pushed page was opened from',
    (tester) async {
      await startApp(tester);
      expect(
        heard(),
        [startScreen],
        reason: 'With guards that allow, the app starts on its start screen.',
      );

      // A page in the branch of the first destination, as a push shows
      // it. Then the second destination, and over the main navigation the
      // page outside it, as a push shows it.
      pushed(shown(tester, FixtureHomeScreen).nav.fakeFeature.details(id: 3));
      await tester.pumpAndSettle();
      expect(
        heard(),
        [('fake_feature.details', '/fake_feature/details/3')],
        reason: 'The page that push() shows in a branch is heard of once.',
      );
      final shell = tester.widget<AppShell>(_shells());
      final first = shell.currentIndex;
      // The label of the destination, in the language of the app, which
      // is English on the device of a test.
      final context = tester.element(_shells());
      final second = shell.destinations.indexWhere(
        (destination) => destination.label(context) == 'Second',
      );
      expect(second, isNonNegative, reason: 'The AppShell has Second.');
      shell.onSelect(second);
      await tester.pumpAndSettle();
      expect(
        heard(),
        [_secondScreen],
        reason: 'A switch to another destination is heard of once.',
      );
      pushed(shown(tester, FixtureSecondScreen).nav.fakeSecond.outside());
      await tester.pumpAndSettle();
      expect(
        heard(),
        [_outsideScreen],
        reason: 'The page that push() shows over the main navigation is '
            'heard of once.',
      );
      expect(
        _shells(),
        findsOneWidget,
        reason: 'The main navigation stays below a page shown over it.',
      );

      // The gate closes: the target of its guard takes the whole stack,
      // the main navigation included.
      fixtureGate.value = false;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [gateScreen],
        reason: 'When a guard stops allowing, the router shows its target in '
            'place of the pages that it keeps the user from.',
      );
      expect(
        builtScreens(tester),
        [FixtureGateScreen],
        reason: 'When a guard stops allowing, no page that it keeps the user '
            'from stays in the stack.',
      );
      expect(
        _shells(),
        findsNothing,
        reason: 'While a guard does not allow, the main navigation is not '
            'shown.',
      );

      // The gate opens: the user is back in the main navigation, on the
      // destination that the page was opened from, and not on that page
      // alone.
      fixtureGate.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [_secondScreen],
        reason: 'Once a guard allows again, the user comes back to the '
            'destination that the pushed page was opened from.',
      );
      expect(
        _shells(),
        findsOneWidget,
        reason: 'Once a guard allows again, the user comes back into the '
            'main navigation.',
      );
      expect(
        tester.widget<AppShell>(_shells()).currentIndex,
        second,
        reason: 'Once a guard allows again, the destination that the pushed '
            'page was opened from is selected.',
      );
      expect(
        find.byType(FixtureOutsideScreen, skipOffstage: false),
        findsNothing,
        reason: 'Once a guard allows again, the page that the push showed is '
            'not shown alone, with no way back.',
      );
      expect(
        find.byType(FixtureHomeScreen),
        findsNothing,
        reason: 'Once a guard allows again, the destination that the pushed '
            'page was opened from is the screen the user sees.',
      );

      // The branch of the first destination, which was not selected when
      // the gate closed: the page that the push showed there is gone.
      tester.widget<AppShell>(_shells()).onSelect(first);
      await tester.pumpAndSettle();
      expect(
        heard(),
        [startScreen],
        reason: 'The target of a guard takes the stacks of every branch of '
            'the main navigation: a branch that was not selected is back on '
            'its destination.',
      );
      expect(
        find.byType(FixtureDetailsScreen, skipOffstage: false),
        findsNothing,
        reason: 'The target of a guard takes the stacks of every branch of '
            'the main navigation: a branch that was not selected is back on '
            'its destination.',
      );

      // A location in a flow that is over, asked for from the main
      // navigation while the branch that is not selected has a pushed
      // page: the second destination, a page that a push shows in its
      // branch, the first destination again, and there push() of the
      // target of the guard, which allows.
      tester.widget<AppShell>(_shells()).onSelect(second);
      await tester.pumpAndSettle();
      expect(
        heard(),
        [_secondScreen],
        reason: 'A switch to another destination is heard of once.',
      );
      pushed(shown(tester, FixtureSecondScreen).nav.fakeFeature.details(id: 5));
      await tester.pumpAndSettle();
      expect(
        heard(),
        [('fake_feature.details', '/fake_feature/details/5')],
        reason: 'The page that push() shows in a branch is heard of once.',
      );
      tester.widget<AppShell>(_shells()).onSelect(first);
      await tester.pumpAndSettle();
      expect(
        heard(),
        [startScreen],
        reason: 'A switch to another destination is heard of once.',
      );
      final home = shown(tester, FixtureHomeScreen);
      final result = pushed(home.nav.fakeGate.gate());
      await tester.pumpAndSettle();
      expectHeardAtMostOnce(
        tester,
        home,
        startScreen,
        reason: 'push() of a location in a flow that is over shows the '
            'screen that the app starts on, from the main navigation too.',
      );
      expect(
        result(),
        isNull,
        reason: 'push() of a location in a flow that is over completes with '
            'null, from the main navigation too.',
      );
      expect(
        find.byType(FixtureGateScreen, skipOffstage: false),
        findsNothing,
        reason: 'The router shows no page of a location in a flow that is '
            'over, on the main navigation either.',
      );
      expect(
        find.byType(FixtureHomeScreen),
        findsOneWidget,
        reason: 'push() of a location in a flow that is over shows the '
            'screen that the app starts on, from the main navigation too.',
      );
      expect(
        _shells(),
        findsOneWidget,
        reason: 'The screen that the app starts on is a destination, so the '
            'user stays in the main navigation.',
      );
      expect(
        tester.widget<AppShell>(_shells()).currentIndex,
        first,
        reason: 'The destination of the screen that the app starts on is '
            'selected.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
