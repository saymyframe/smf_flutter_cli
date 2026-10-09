// A test that continuous integration runs in the apps of the fixture
// modules with a router and a layout, whichever modules provide them, both
// fixture features, the fixture gates and the fixture late gate: a guard of
// the routes of the router role that does not bring the user back
// (RouteGuard.resumes), that of the fixture late gate, stops allowing while
// a page is shown over the main navigation, as a push shows it, and both
// branches have a page that a push showed. Once the guard allows again,
// the user is in the main navigation on the screen that the app starts on,
// whichever destination the page over the main navigation was opened from
// (RouterRole.guardedNavigation). The target of the guard took the stacks
// of every branch, the selected one too, which no location that the user
// comes back to puts back on its destination here: each branch shows its
// destination when the user selects it, and no page that the guard kept
// the user from. It selects a destination as the layout does when the user
// selects it, with onSelect of AppShell, so it depends neither on the
// router nor on how the layout shows the destinations. It uses what the
// tests of router_screens and of router_guards share, which every app that
// it applies to has. Each expectation gives its reason, which a provider
// of a role with a known bug fails the test with (brokenProviders of the
// fixture registry).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/layout/app_shell.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_details_screen.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';
import 'package:{{app_name}}/features/fake_late_gate/fixture_late_gate.dart';
import 'package:{{app_name}}/features/fake_late_gate/fixture_late_gate_screen.dart';
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
    'after a guard that does not bring the user back, the user is in the '
    'main navigation on the screen that the app starts on, and every branch '
    'is back on its destination',
    (tester) async {
      await startApp(tester);
      expect(
        heard(),
        [startScreen],
        reason: 'With guards that allow, the app starts on its start screen.',
      );

      // A page in the branch of the first destination, as a push shows
      // it. Then the second destination, a page in its branch, and over
      // the main navigation the page outside it, each as a push shows it.
      pushed(shown(tester, FixtureHomeScreen).nav.fakeFeature.details(id: 3));
      await tester.pumpAndSettle();
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
      pushed(shown(tester, FixtureSecondScreen).nav.fakeFeature.details(id: 7));
      await tester.pumpAndSettle();
      pushed(details(tester, 7).nav.fakeSecond.outside());
      await tester.pumpAndSettle();
      expect(
        heard(),
        [
          ('fake_feature.details', '/fake_feature/details/3'),
          _secondScreen,
          ('fake_feature.details', '/fake_feature/details/7'),
          _outsideScreen,
        ],
        reason: 'The pages that push() shows in a branch and over the main '
            'navigation, and a switch to another destination, are heard of '
            'once each.',
      );

      // The late gate closes: the target of its guard takes the whole
      // stack, the main navigation included.
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
      expect(
        _shells(),
        findsNothing,
        reason: 'While a guard does not allow, the main navigation is not '
            'shown.',
      );

      // The late gate opens: the user is in the main navigation, on the
      // screen that the app starts on, and not on the destination that the
      // page was opened from.
      fixtureLateGate.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [startScreen],
        reason: 'Once a guard that does not bring the user back allows '
            'again, the user comes to the screen that the app starts on, '
            'and not to the destination that the pushed page was opened '
            'from.',
      );
      expect(
        _shells(),
        findsOneWidget,
        reason: 'The screen that the app starts on is a destination, so the '
            'user is back in the main navigation.',
      );
      expect(
        tester.widget<AppShell>(_shells()).currentIndex,
        first,
        reason: 'Once a guard that does not bring the user back allows '
            'again, the destination of the screen that the app starts on is '
            'selected.',
      );
      expect(
        find.byType(FixtureHomeScreen),
        findsOneWidget,
        reason: 'Once a guard that does not bring the user back allows '
            'again, the screen that the app starts on is the screen the '
            'user sees.',
      );
      expect(
        find.byType(FixtureOutsideScreen, skipOffstage: false),
        findsNothing,
        reason: 'Once a guard that does not bring the user back allows '
            'again, the page that the push showed over the main navigation '
            'is gone.',
      );
      expect(
        find.byType(FixtureDetailsScreen),
        findsNothing,
        reason: 'The target of a guard takes the stacks of every branch of '
            'the main navigation: the branch of the screen that the app '
            'starts on is back on its destination.',
      );

      // The branch of the second destination, which was selected when the
      // gate closed: the page that the push showed there is gone too,
      // though the user did not come back to that branch.
      tester.widget<AppShell>(_shells()).onSelect(second);
      await tester.pumpAndSettle();
      expect(
        heard(),
        [_secondScreen],
        reason: 'The target of a guard takes the stacks of every branch of '
            'the main navigation, the selected one too: when the user does '
            'not come back to that branch, it is back on its destination '
            'all the same.',
      );
      expect(
        find.byType(FixtureDetailsScreen, skipOffstage: false),
        findsNothing,
        reason: 'The target of a guard takes the stacks of every branch of '
            'the main navigation, the selected one too: no page that the '
            'guard kept the user from is left in a branch.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
