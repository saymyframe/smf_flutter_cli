// A test that continuous integration runs in the apps of the fixture
// modules with a router, whichever module provides it, the fixture gates
// and the second fixture feature: a guard that stands for a condition
// (RouteGuard.condition) keeps the user only from the routes that ask for
// that condition (Route.conditions), and the router opens its flow over
// the page that the user is on, as RouterRole.guardedNavigation says.
// Three routes of the second fixture feature ask for the condition of the
// fixture badge role, and the third guard of the fixture gates stands for
// it. One of them asks by being below another, and one lists the
// condition itself, below a route that asks for nothing: a router that
// asked the guards about the route above a route would show it to
// everyone. The feature knows nothing of that guard: both know only the
// role.
//
// While the condition does not hold, a request for such a route opens the
// target of the guard over the page that the user is on, whichever of
// go(), push() and replace() asks, and the router never builds the screen
// of the route. The request waits: back returns to that page, and a push()
// then completes with null. Once the condition holds, the router closes
// the flow and does what was asked. push() shows the route over the page
// that the user was on, and completes with the value of its page. go()
// shows it in place of the stack, and replace() in place of that page. A
// location from the platform opens the flow over the screen that the app
// starts on. The listeners of the screen hear only of pages that the user
// saw.
//
// Each expectation gives its reason, which a provider of the role with a
// known bug fails the test with (brokenProviders of the fixture registry).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gate_screens.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gates.dart';
import 'package:{{app_name}}/features/fake_second/fixture_members_screens.dart';
import 'package:{{app_name}}/features/fake_second/fixture_outside_screen.dart';

import 'conditions.dart';
import 'guards.dart';
import 'screens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'a request for a route that asks for a condition opens the flow of its '
    'guard over the page that the user is on, back returns to that page, '
    'and the router does what was asked once the condition holds',
    (tester) async {
      /// Checks that the target of the guard of the condition is open over
      /// the pages of [below], which stay, that the listeners heard of it
      /// once, and that the router built no screen of a route that asks
      /// for the condition. A failure gives [reason].
      void expectFlowOver(List<Type> below, String reason) {
        expect(heard(), [gateScreen], reason: reason);
        expect(
          pagesBuilt(tester),
          [...below, FixtureGateScreen],
          reason: '$reason The target opens over the page that the user is '
              'on, and the pages below it stay.',
        );
        expect(
          builtForHolders(tester),
          isEmpty,
          reason: 'The router builds no screen of a route whose condition '
              'does not hold.',
        );
      }

      await startApp(tester);
      expect(
        heard(),
        [startScreen],
        reason: 'With guards that allow, the app starts on its start screen.',
      );

      // push(), and back from the flow.
      var below = await toDetails(tester, 1);
      await takeBadge(tester);
      var result = pushed(below.nav.fakeSecond.members());
      await tester.pumpAndSettle();
      expectFlowOver(
        pagesBelow,
        'push() of a route that asks for a condition that does not hold '
        'opens the target of the guard of the condition.',
      );
      expect(
        pagesForHolders(),
        0,
        reason: 'The router shows no page of a route whose condition does '
            'not hold.',
      );
      expect(
        result(),
        'not completed',
        reason: 'A push() that opened the flow of a guard waits while the '
            'flow is open.',
      );
      await back(tester);
      expect(
        heard(),
        [detailsScreen(1)],
        reason: 'Back from the target of a guard of a condition returns to '
            'the page that the flow was opened over.',
      );
      expect(
        pagesBuilt(tester),
        pagesBelow,
        reason: 'Back from the target of a guard of a condition returns to '
            'the page that the flow was opened over.',
      );
      expect(
        result(),
        isNull,
        reason: 'A push() that opened the flow of a guard completes with '
            'null when the user goes back from the flow.',
      );
      await giveBadge(tester);
      expect(
        heard(),
        isEmpty,
        reason: 'A request that was dropped when the user went back from '
            'the flow is not made once the condition holds.',
      );

      // push(), and the condition holds.
      await takeBadge(tester);
      result = pushed(details(tester, 1).nav.fakeSecond.members());
      await tester.pumpAndSettle();
      expectFlowOver(
        pagesBelow,
        'push() of a route that asks for a condition that does not hold '
        'opens the target of the guard of the condition.',
      );
      final open = shown(tester, FixtureGateScreen);
      fixtureHolder.poke();
      await tester.pumpAndSettle();
      expect(
        heard(),
        isEmpty,
        reason: 'A notification of a guard that changes nothing leaves the '
            'flow of a condition open.',
      );
      expect(
        open.mounted,
        isTrue,
        reason: 'A notification of a guard that changes nothing leaves the '
            'flow of a condition open.',
      );
      await giveBadge(tester);
      expect(
        pagesBuilt(tester),
        [...pagesBelow, FixtureMembersScreen],
        reason: 'Once the condition holds, the router closes the flow and '
            'shows the location that push() asked for over the page that '
            'the flow was opened over.',
      );
      expect(
        heard(),
        [membersScreen],
        reason: 'Once the condition holds, the listeners of the screen hear '
            'of the page that the user ends on, and not of the page below '
            'the flow in between.',
      );
      expect(
        result(),
        'not completed',
        reason: 'A push() that waited for a flow completes with the value '
            'of its page, not when the flow closes.',
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
        [detailsScreen(1)],
        reason: 'The page that the flow was opened over is heard of once '
            'when the page above it closes.',
      );

      // go(): the flow opens over the page too, and the location takes the
      // place of the stack once the condition holds.
      below = await toDetails(tester, 2);
      await takeBadge(tester);
      below.nav.fakeSecond.members().go();
      await tester.pumpAndSettle();
      expectFlowOver(
        pagesBelow,
        'go() to a route that asks for a condition that does not hold opens '
        'the target of the guard of the condition.',
      );
      await back(tester);
      expect(
        heard(),
        [detailsScreen(2)],
        reason: 'Back from the target of a guard of a condition returns to '
            'the page that go() was asked from.',
      );
      details(tester, 2).nav.fakeSecond.memberCard().go();
      await tester.pumpAndSettle();
      expectFlowOver(
        pagesBelow,
        'go() to a route below a route that asks for a condition that does '
        'not hold opens the target of the guard of the condition.',
      );
      await giveBadge(tester);
      expect(
        heard(),
        [memberCardScreen],
        reason: 'Once the condition holds, the router shows the location '
            'that go() asked for.',
      );
      expect(
        pagesBuilt(tester),
        [FixtureMembersScreen, FixtureMemberCardScreen],
        reason: 'Once the condition holds, the router shows the location '
            'that go() asked for as go() does: its chain in place of the '
            'stack.',
      );

      // push() of the route that lists the condition itself, below a route
      // that asks for nothing: the router asks about the route of the
      // location, not about the route above it.
      below = await toDetails(tester, 3);
      await takeBadge(tester);
      result = pushed(below.nav.fakeSecond.vault());
      await tester.pumpAndSettle();
      expectFlowOver(
        pagesBelow,
        'push() of a route that asks for a condition that does not hold, '
        'below a route that asks for none, opens the target of the guard of '
        'the condition.',
      );
      await giveBadge(tester);
      expect(
        heard(),
        [vaultScreen],
        reason: 'Once the condition holds, the router shows the location '
            'that push() asked for, below a route that asks for no '
            'condition.',
      );
      expect(
        builtForHolders(tester),
        [FixtureVaultScreen],
        reason: 'Once the condition holds, the router shows the location '
            'that push() asked for, below a route that asks for no '
            'condition.',
      );
      expect(
        pagesBuilt(tester).sublist(0, 2),
        pagesBelow,
        reason: 'Once the condition holds, the pages that the flow was '
            'opened over are still below the location that push() asked '
            'for.',
      );

      // replace(): the flow opens over the page that it would replace,
      // which stays until the condition holds.
      below = await toDetails(tester, 4);
      pushed(below.nav.fakeSecond.outside());
      await tester.pumpAndSettle();
      expect(
        heard(),
        [outsideScreen],
        reason: 'push() of a route that asks for no condition shows it.',
      );
      await takeBadge(tester);
      shown(tester, FixtureOutsideScreen).nav.fakeSecond.members().replace();
      await tester.pumpAndSettle();
      expectFlowOver(
        [...pagesBelow, FixtureOutsideScreen],
        'replace() with a route that asks for a condition that does not '
        'hold opens the target of the guard of the condition.',
      );
      await back(tester);
      expect(
        heard(),
        [outsideScreen],
        reason: 'Back from the target of a guard of a condition returns to '
            'the page that replace() was asked on, which is still there.',
      );
      shown(tester, FixtureOutsideScreen).nav.fakeSecond.members().replace();
      await tester.pumpAndSettle();
      expectFlowOver(
        [...pagesBelow, FixtureOutsideScreen],
        'replace() with a route that asks for a condition that does not '
        'hold opens the target of the guard of the condition.',
      );
      await giveBadge(tester);
      expect(
        heard(),
        [membersScreen],
        reason: 'Once the condition holds, the router shows the location '
            'that replace() asked for.',
      );
      expect(
        pagesBuilt(tester),
        [...pagesBelow, FixtureMembersScreen],
        reason: 'Once the condition holds, the router shows the location '
            'that replace() asked for in place of the page that it was '
            'asked on.',
      );

      // A location from the platform: the router asks the guards about it,
      // or takes no locations from the platform and stays where it is.
      final fromPlatform = await toDetails(tester, 5);
      await takeBadge(tester);
      await tester.binding.handlePushRoute(membersScreen.$2);
      await tester.pumpAndSettle();
      if (fromPlatform.mounted) {
        expect(
          heard(),
          isEmpty,
          reason: 'A router that takes no locations from the platform stays '
              'where it is.',
        );
        await giveBadge(tester);
        expect(
          heard(),
          isEmpty,
          reason: 'A condition that comes to hold leaves a page that does '
              'not ask for it as it is, with nothing that was asked for.',
        );
      } else {
        expectFlowOver(
          [FixtureHomeScreen],
          'A location from the platform of a route that asks for a '
          'condition that does not hold opens the target of the guard of '
          'the condition over the screen that the app starts on, of which '
          'the listeners of the screen hear nothing.',
        );
        await back(tester);
        expect(
          heard(),
          [startScreen],
          reason: 'Back from a flow that a location from the platform '
              'opened returns to the screen that the app starts on.',
        );
        // Again, from the screen that the app starts on itself.
        await tester.binding.handlePushRoute(membersScreen.$2);
        await tester.pumpAndSettle();
        expectFlowOver(
          [FixtureHomeScreen],
          'A location from the platform of a route that asks for a '
          'condition that does not hold opens the target of the guard of '
          'the condition, also when the user is on the screen that the app '
          'starts on.',
        );
        await giveBadge(tester);
        expect(
          heard(),
          [membersScreen],
          reason: 'Once the condition holds, the router shows the location '
              'that the platform asked for.',
        );
        expect(
          pagesBuilt(tester),
          [FixtureMembersScreen],
          reason: 'Once the condition holds, the router shows the location '
              'that the platform asked for as go() to it does.',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
