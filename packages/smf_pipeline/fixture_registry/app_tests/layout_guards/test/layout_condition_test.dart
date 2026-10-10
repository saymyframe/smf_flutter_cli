// A test that continuous integration runs in the apps of the fixture
// modules with a router and a layout, whichever modules provide them, both
// fixture features and the fixture gates: a request from the main
// navigation for a route that asks for a condition, as when a guest opens
// an account screen from a tab (RouterRole.guardedNavigation). No route of
// the main navigation asks for a condition, so such a route is outside it,
// and the flow of its guard opens over the main navigation, which stays
// below with its destination selected and the pages of its branches. Back
// returns to the destination. Once the condition holds, the route shows
// over the main navigation for push(), and in its place for go(). And a
// page that a push showed in a branch stays when the flow closes, with its
// push still waiting for the value of the page.
//
// The test selects a destination as the layout does when the user selects
// it, with onSelect of AppShell, so it depends neither on the router nor
// on how the layout shows the destinations. It uses what the tests of
// router_screens and of router_guards share, which every app that it
// applies to has. Each expectation gives its reason, which a provider of a
// role with a known bug fails the test with (brokenProviders of the
// fixture registry).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/layout/app_shell.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_details_screen.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gate_screens.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gates.dart';
import 'package:{{app_name}}/features/fake_second/fixture_members_screens.dart';
import 'package:{{app_name}}/features/fake_second/fixture_second_screen.dart';

import 'guards.dart';
import 'screens.dart';

/// The route of the second fixture feature that asks for the condition of
/// the fixture badge role, outside the main navigation, as the listeners of
/// the screen hear of it.
const _membersScreen = ('fake_second.members', '/fake_second/members');

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
    'the flow of a condition opens over the main navigation, which stays '
    'below with its destination selected, and the route that was asked for '
    'shows over it once the condition holds',
    (tester) async {
      /// The index of the destination that the main navigation shows as
      /// selected.
      int selected() => tester.widget<AppShell>(_shells()).currentIndex;

      /// The screen of the type [screen] that is built last, also while a
      /// page covers it.
      Element built(Type screen) =>
          tester.elementList(find.byType(screen, skipOffstage: false)).last;

      await startApp(tester);
      expect(
        heard(),
        [startScreen],
        reason: 'With guards that allow, the app starts on its start screen.',
      );

      // The second destination, without the badge.
      final shell = tester.widget<AppShell>(_shells());
      final context = tester.element(_shells());
      // The label of the destination, in the language of the app, which
      // is English on the device of a test.
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
      fixtureHolder.value = false;
      await tester.pumpAndSettle();
      expect(
        heard(),
        isEmpty,
        reason: 'A condition that stops holding leaves a page that does not '
            'ask for it as it is.',
      );

      // push() from the destination, and back.
      final destination = shown(tester, FixtureSecondScreen);
      var result = pushed(destination.nav.fakeSecond.members());
      await tester.pumpAndSettle();
      expect(
        heard(),
        [gateScreen],
        reason: 'push() of a route that asks for a condition that does not '
            'hold opens the target of the guard of the condition.',
      );
      expect(
        _shells(),
        findsOneWidget,
        reason: 'The target of a guard of a condition opens over the main '
            'navigation, which stays below it.',
      );
      expect(
        destination.mounted,
        isTrue,
        reason: 'The target of a guard of a condition opens over the main '
            'navigation, whose branches keep their pages.',
      );
      expect(
        selected(),
        second,
        reason: 'The main navigation below the flow of a condition keeps '
            'its destination selected.',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        heard(),
        [_secondScreen],
        reason: 'Back from the target of a guard of a condition returns to '
            'the destination that the flow was opened from.',
      );
      expect(
        result(),
        isNull,
        reason: 'A push() that opened the flow of a guard completes with '
            'null when the user goes back from the flow.',
      );
      expect(selected(), second, reason: 'The destination stays selected.');

      // push() from the destination, and the condition holds: the route
      // shows over the main navigation.
      result = pushed(destination.nav.fakeSecond.members());
      await tester.pumpAndSettle();
      expect(heard(), [gateScreen], reason: 'The flow opens over the page.');
      fixtureHolder.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [_membersScreen],
        reason: 'Once the condition holds, the router shows the location '
            'that push() asked for, and the listeners of the screen hear '
            'nothing of the destination below the flow in between.',
      );
      expect(
        find.byType(FixtureGateScreen, skipOffstage: false),
        findsNothing,
        reason: 'Once the condition holds, the router closes the flow.',
      );
      expect(
        _shells(),
        findsOneWidget,
        reason: 'Once the condition holds, the location that push() asked '
            'for shows over the main navigation, which stays below it.',
      );
      expect(
        selected(),
        second,
        reason: 'The main navigation below the location that push() asked '
            'for keeps its destination selected.',
      );
      Navigator.of(shown(tester, FixtureMembersScreen)).pop('closed');
      await tester.pumpAndSettle();
      expect(
        result(),
        'closed',
        reason: 'A push() that waited for a flow completes with the value '
            'of its page.',
      );
      expect(
        heard(),
        [_secondScreen],
        reason: 'The destination is heard of once when the page over the '
            'main navigation closes.',
      );

      // A page that a push showed in the branch of the first destination,
      // and the flow over it: only the flow closes.
      shell.onSelect(0);
      await tester.pumpAndSettle();
      heard();
      final inBranch = pushed(
        shown(tester, FixtureHomeScreen).nav.fakeFeature.details(id: 4),
      );
      await tester.pumpAndSettle();
      expect(
        heard(),
        [('fake_feature.details', '/fake_feature/details/4')],
        reason: 'The page that push() shows in a branch is heard of once.',
      );
      fixtureHolder.value = false;
      await tester.pumpAndSettle();
      result = pushed(details(tester, 4).nav.fakeSecond.members());
      await tester.pumpAndSettle();
      expect(heard(), [gateScreen], reason: 'The flow opens over the page.');
      fixtureHolder.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [_membersScreen],
        reason: 'Once the condition holds, the router shows the location '
            'that push() asked for.',
      );
      expect(
        built(FixtureDetailsScreen).mounted,
        isTrue,
        reason: 'Once the condition holds, the router closes the pages of '
            'the flow and no page of a branch of the main navigation below '
            'them.',
      );
      expect(
        inBranch(),
        'not completed',
        reason: 'The push() of a page in a branch of the main navigation '
            'below the flow of a condition still waits when the flow '
            'closes.',
      );
      Navigator.of(shown(tester, FixtureMembersScreen)).pop();
      await tester.pumpAndSettle();
      Navigator.of(details(tester, 4)).pop('in the branch');
      await tester.pumpAndSettle();
      expect(
        inBranch(),
        'in the branch',
        reason: 'The push() of a page in a branch of the main navigation '
            'below the flow of a condition completes with the value of its '
            'page.',
      );
      expect(
        heard(),
        [('fake_feature.details', '/fake_feature/details/4'), startScreen],
        reason: 'Each page that shows again as the page above it closes is '
            'heard of once.',
      );

      // go() from a destination: the flow opens over the main navigation
      // too, and the location takes its place once the condition holds.
      fixtureHolder.value = false;
      await tester.pumpAndSettle();
      shown(tester, FixtureHomeScreen).nav.fakeSecond.members().go();
      await tester.pumpAndSettle();
      expect(
        heard(),
        [gateScreen],
        reason: 'go() to a route that asks for a condition that does not '
            'hold opens the target of the guard of the condition.',
      );
      expect(
        _shells(),
        findsOneWidget,
        reason: 'The target of a guard of a condition opens over the main '
            'navigation, which stays below it, for go() too.',
      );
      fixtureHolder.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [_membersScreen],
        reason: 'Once the condition holds, the router shows the location '
            'that go() asked for.',
      );
      expect(
        _shells(),
        findsNothing,
        reason: 'Once the condition holds, the location that go() asked '
            'for, which is outside the main navigation, takes the place of '
            'the stack, the main navigation included.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
