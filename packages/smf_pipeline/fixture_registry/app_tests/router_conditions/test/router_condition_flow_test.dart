// A test that continuous integration runs in the apps of the fixture
// modules with a router, whichever module provides it, the fixture gates
// and the second fixture feature: the flow of a guard that stands for a
// condition while it is open over a page, as RouterRole.guardedNavigation
// says. The third guard of the fixture gates stands for the condition of
// the fixture badge role, three routes of the second fixture feature ask
// for it, and its flow is the gate screen with the step below it.
//
// The request that opened the flow waits while a page of the flow is among
// the pages of the router, so after a push() or a replace() inside the
// flow too. A further request for a route that asks for the condition does
// nothing then, also from a page outside the flow that was pushed from it.
// Once the condition holds, the router closes the pages of the flow with
// the pages over them, at once and whatever the navigator shows over them,
// and makes the request again. When the last page of the flow leaves in
// another way, the request is dropped. A flow that the code of the app
// opened itself closes like one that the router opened. In the turn in
// which the router closes the flow, the navigator still has the routes of
// its pages: a screen of the flow that closes itself then, which a screen
// should not do, or the back button of the system, closes such a route and
// no page of the router.
//
// Each expectation gives its reason, which a provider of the role with a
// known bug fails the test with (brokenProviders of the fixture registry).
import 'package:flutter/material.dart';
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

/// Why the router shows nothing for a request while the flow is open.
const _open = 'While the flow of a guard of a condition is open, a further '
    'request for a route that asks for the condition shows nothing.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the flow of a condition stays open for the request that opened it '
    'while one of its pages is among the pages, and closes with the pages '
    'over it once the condition holds',
    (tester) async {
      /// Goes to the details of the item [id], takes the badge away, and
      /// pushes the route of the members from there, which opens the flow
      /// over the details. Returns what that push has completed with so
      /// far.
      Future<Object? Function()> openFlow(int id) async {
        final below = await toDetails(tester, id);
        await takeBadge(tester);
        final result = pushed(below.nav.fakeSecond.members());
        await tester.pumpAndSettle();
        expect(
          heard(),
          [gateScreen],
          reason: 'push() of a route that asks for a condition that does '
              'not hold opens the target of the guard of the condition.',
        );
        expect(
          pagesBuilt(tester),
          [...pagesBelow, FixtureGateScreen],
          reason: 'The target of a guard of a condition opens over the page '
              'that the user is on.',
        );
        expect(
          result(),
          'not completed',
          reason: 'A push() that opened the flow of a guard waits while the '
              'flow is open.',
        );
        return result;
      }

      /// Checks that the router closed the flow and shows the route of the
      /// members over the details of the item [id], of which alone the
      /// listeners heard, and that the push of [result] completes with the
      /// value of that page. A failure gives [reason].
      Future<void> expectRequestMade(
        int id,
        Object? Function() result,
        String reason,
      ) async {
        expect(
          pagesBuilt(tester),
          [...pagesBelow, FixtureMembersScreen],
          reason: reason,
        );
        expect(
          heard(),
          [membersScreen],
          reason: '$reason The listeners of the screen hear only of the page '
              'that the user ends on.',
        );
        Navigator.of(shown(tester, FixtureMembersScreen)).pop(id);
        await tester.pumpAndSettle();
        expect(
          result(),
          id,
          reason: 'A push() that waited for a flow completes with the value '
              'of its page.',
        );
        expect(
          heard(),
          [detailsScreen(id)],
          reason: 'The page that the flow was opened over is heard of once '
              'when the page above it closes.',
        );
      }

      await startApp(tester);
      expect(
        heard(),
        [startScreen],
        reason: 'With guards that allow, the app starts on its start screen.',
      );

      // A further request while the target is on top.
      var first = await openFlow(1);
      var flow = shown(tester, FixtureGateScreen);
      final second = pushed(flow.nav.fakeSecond.memberCard());
      flow.nav.fakeSecond.members().go();
      flow.nav.fakeSecond.vault().replace();
      await tester.pumpAndSettle();
      expect(heard(), isEmpty, reason: _open);
      expect(
        pagesBuilt(tester),
        [...pagesBelow, FixtureGateScreen],
        reason: _open,
      );
      expect(flow.mounted, isTrue, reason: _open);
      expect(
        second(),
        isNull,
        reason: 'While the flow of a guard of a condition is open, a '
            'further push() of a route that asks for the condition '
            'completes with null.',
      );
      expect(
        first(),
        'not completed',
        reason: 'A further request while the flow is open leaves the first '
            'one waiting.',
      );
      await giveBadge(tester);
      await expectRequestMade(
        1,
        first,
        'Once the condition holds, the router makes the request that opened '
        'the flow, not one that came while the flow was open.',
      );

      // The code of the app pushes the target itself: no request waits,
      // and the router closes the flow like one that it opened.
      var below = await toDetails(tester, 2);
      await takeBadge(tester);
      var ofTarget = pushed(below.nav.fakeGate.gate());
      await tester.pumpAndSettle();
      expect(
        heard(),
        [gateScreen],
        reason: 'While a condition does not hold, the flow of its guard is '
            'not over, though the gate with that flow allows: push() of its '
            'target shows it.',
      );
      await back(tester);
      expect(
        heard(),
        [detailsScreen(2)],
        reason: 'Back from the target of a guard returns to the page that '
            'it was pushed from.',
      );
      expect(
        ofTarget(),
        isNull,
        reason: 'push() of the target of a guard completes with the value '
            'of its page.',
      );
      ofTarget = pushed(details(tester, 2).nav.fakeGate.gate());
      await tester.pumpAndSettle();
      expect(heard(), [gateScreen], reason: 'push() of the target shows it.');
      await giveBadge(tester);
      expect(
        heard(),
        [detailsScreen(2)],
        reason: 'Once the condition holds, the router closes the pages of '
            'its flow, also a target that the code of the app pushed.',
      );
      expect(
        pagesBuilt(tester),
        pagesBelow,
        reason: 'Once the condition holds, the router closes the pages of '
            'its flow, also a target that the code of the app pushed.',
      );
      expect(
        ofTarget(),
        isNull,
        reason: 'The push() of a page that the router closes completes with '
            'null.',
      );

      // A page outside the flow over the target: the flow is open below
      // it, so a further request shows nothing there too.
      first = await openFlow(3);
      var over = pushed(
        shown(tester, FixtureGateScreen).nav.fakeSecond.outside(),
      );
      await tester.pumpAndSettle();
      expect(
        heard(),
        [outsideScreen],
        reason: 'While a condition does not hold, a route that asks for '
            'nothing shows from the flow of its guard too.',
      );
      final outside = shown(tester, FixtureOutsideScreen);
      final again = pushed(outside.nav.fakeSecond.vault());
      outside.nav.fakeSecond.members().go();
      await tester.pumpAndSettle();
      expect(
        heard(),
        isEmpty,
        reason: '$_open That holds below a page outside the flow too: the '
            'flow does not open a second time.',
      );
      expect(
        pagesBuilt(tester),
        [...pagesBelow, FixtureGateScreen, FixtureOutsideScreen],
        reason: '$_open That holds below a page outside the flow too: the '
            'flow does not open a second time.',
      );
      expect(again(), isNull, reason: _open);
      await back(tester);
      expect(
        heard(),
        [gateScreen],
        reason: 'Back from a page over the target of a guard returns to the '
            'target.',
      );
      expect(
        first(),
        'not completed',
        reason: 'The request that opened a flow waits while a page of the '
            'flow is among the pages, also below another page.',
      );
      over = pushed(shown(tester, FixtureGateScreen).nav.fakeSecond.outside());
      await tester.pumpAndSettle();
      expect(heard(), [outsideScreen], reason: 'push() shows its location.');
      await giveBadge(tester);
      expect(
        over(),
        isNull,
        reason: 'The push() of a page that the router closes with the flow '
            'below it completes with null.',
      );
      await expectRequestMade(
        3,
        first,
        'Once the condition holds, the router closes the pages of the flow '
        'with the page over them, and makes the request that opened the '
        'flow.',
      );

      // The same with a target that the code of the app pushed: no page
      // of the flow stays below another page.
      below = await toDetails(tester, 4);
      await takeBadge(tester);
      pushed(below.nav.fakeGate.gate());
      await tester.pumpAndSettle();
      pushed(shown(tester, FixtureGateScreen).nav.fakeSecond.outside());
      await tester.pumpAndSettle();
      expect(
        heard(),
        [gateScreen, outsideScreen],
        reason: 'push() shows its location.',
      );
      await giveBadge(tester);
      expect(
        pagesBuilt(tester),
        pagesBelow,
        reason: 'Once the condition holds, a page of its flow leaves from '
            'below another page too, with that page: back never returns to '
            'a flow that is over.',
      );
      expect(
        heard(),
        [detailsScreen(4)],
        reason: 'Once the condition holds, a page of its flow leaves from '
            'below another page too, with that page: back never returns to '
            'a flow that is over.',
      );

      // push() inside the flow: the request waits, and both pages close.
      first = await openFlow(5);
      final ofStep =
          pushed(shown(tester, FixtureGateScreen).nav.fakeGate.step());
      await tester.pumpAndSettle();
      expect(
        heard(),
        [stepScreen],
        reason: 'While a condition does not hold, the routes of the flow of '
            'its guard show.',
      );
      await back(tester);
      expect(heard(), [gateScreen], reason: 'Back returns to the target.');
      expect(
        first(),
        'not completed',
        reason: 'The request that opened a flow waits while a page of the '
            'flow is among the pages.',
      );
      expect(ofStep(), isNull, reason: 'The page of the step closed.');
      final ofStepAgain = pushed(
        shown(tester, FixtureGateScreen).nav.fakeGate.step(),
      );
      await tester.pumpAndSettle();
      expect(heard(), [stepScreen], reason: 'push() shows its location.');
      await giveBadge(tester);
      expect(
        ofStepAgain(),
        isNull,
        reason: 'The push() of a page of a flow that the router closes '
            'completes with null.',
      );
      await expectRequestMade(
        5,
        first,
        'Once the condition holds, the router closes every page of the '
        'flow, and makes the request that opened the flow.',
      );

      // replace() inside the flow: the page that takes the place of the
      // target is one that the router can close too.
      first = await openFlow(6);
      shown(tester, FixtureGateScreen).nav.fakeGate.step().replace();
      await tester.pumpAndSettle();
      expect(
        heard(),
        [stepScreen],
        reason: 'replace() inside the flow of a guard shows its location.',
      );
      expect(
        pagesBuilt(tester),
        [...pagesBelow, FixtureGateStepScreen],
        reason: 'replace() inside the flow of a guard shows its location in '
            'place of the target, over the page that the flow was opened '
            'over.',
      );
      expect(
        first(),
        'not completed',
        reason: 'The request that opened a flow waits while a page of the '
            'flow is among the pages: after a replace() inside the flow, '
            'the page that took the place of the target.',
      );
      await giveBadge(tester);
      await expectRequestMade(
        6,
        first,
        'Once the condition holds, the router closes a page of the flow '
        'that replace() showed in place of the target, and makes the '
        'request that opened the flow.',
      );
      first = await openFlow(7);
      shown(tester, FixtureGateScreen).nav.fakeGate.step().replace();
      await tester.pumpAndSettle();
      heard();
      await back(tester);
      expect(
        heard(),
        [detailsScreen(7)],
        reason: 'Back from the page of a flow that took the place of the '
            'target returns to the page that the flow was opened over.',
      );
      expect(
        first(),
        isNull,
        reason: 'The request that opened a flow is dropped once no page of '
            'the flow is left.',
      );

      // go() inside the flow takes the place of the pages below, and the
      // request is lost with them.
      first = await openFlow(8);
      shown(tester, FixtureGateScreen).nav.fakeGate.step().go();
      await tester.pumpAndSettle();
      expect(
        pagesBuilt(tester),
        [FixtureGateScreen, FixtureGateStepScreen],
        reason: 'go() inside the flow of a guard shows the chain of its '
            'location in place of the stack.',
      );
      expect(heard(), [stepScreen], reason: 'go() shows its location.');
      await giveBadge(tester);
      expect(
        heard(),
        [startScreen],
        reason: 'Once the condition holds, a flow that took the place of '
            'the stack leaves for the screen that the app starts on.',
      );
      expect(
        pagesBuilt(tester),
        [FixtureHomeScreen],
        reason: 'Once the condition holds, a flow that took the place of '
            'the stack leaves for the screen that the app starts on.',
      );
      expect(
        first(),
        isNull,
        reason: 'The request that opened a flow is dropped when the flow '
            'has no page below it to make the request on.',
      );

      // The user leaves the flow for another location.
      first = await openFlow(9);
      shown(tester, FixtureGateScreen).nav.fakeFeature.home().go();
      await tester.pumpAndSettle();
      expect(heard(), [startScreen], reason: 'go() shows its location.');
      expect(
        first(),
        isNull,
        reason: 'The request that opened a flow is dropped when another '
            'location takes the place of the stack.',
      );
      await giveBadge(tester);
      expect(
        heard(),
        isEmpty,
        reason: 'A request that was dropped is not made once the condition '
            'holds.',
      );

      // A dialog over the target when the condition comes to hold: the
      // pages of the flow leave whatever the navigator shows over them.
      first = await openFlow(10);
      showDialog<void>(
        context: shown(tester, FixtureGateScreen),
        builder: (context) => const AlertDialog(title: Text('Checking')),
      ).ignore();
      await tester.pumpAndSettle();
      expect(find.text('Checking'), findsOneWidget);
      await giveBadge(tester);
      expect(
        find.text('Checking'),
        findsNothing,
        reason: 'Once the condition holds, the router closes the pages of '
            'the flow whatever the navigator shows over them, such as a '
            'dialog, which leaves with its page.',
      );
      await expectRequestMade(
        10,
        first,
        'Once the condition holds, the router closes the pages of the flow '
        'whatever the navigator shows over them, such as a dialog, and '
        'makes the request that opened the flow.',
      );

      // The condition holds and stops holding in one turn: the page of the
      // request, which the navigator has not built yet, closes at once.
      first = await openFlow(11);
      fixtureHolder.value = true;
      fixtureHolder.value = false;
      await tester.pumpAndSettle();
      expect(
        pagesBuilt(tester),
        pagesBelow,
        reason: 'When a condition holds and stops holding in one turn, the '
            'router closes the page of the request that it made again, '
            'though no frame showed that page.',
      );
      expect(
        first(),
        isNull,
        reason: 'When a condition holds and stops holding in one turn, the '
            'push() that waited completes with null.',
      );
      // Whether the listeners hear of a page that no frame showed is up to
      // the router.
      expect(
        heard(),
        anyOf([
          [detailsScreen(11)],
          [membersScreen, detailsScreen(11)],
        ]),
        reason: 'When a condition holds and stops holding in one turn, the '
            'user is on the page that the flow was opened over.',
      );

      // A screen of the flow makes the condition hold and closes itself in
      // the same turn: the navigator still has the route of the target,
      // which is what closes.
      first = await openFlow(12);
      flow = shown(tester, FixtureGateScreen);
      fixtureHolder.value = true;
      Navigator.of(flow).pop();
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'A screen of a flow that the router closed may close itself '
            'in the same turn.',
      );
      await expectRequestMade(
        12,
        first,
        'When a screen of a flow makes the condition hold and closes itself '
        'in the same turn, the page of the flow closes once, and the router '
        'makes the request that opened the flow.',
      );

      // The back button of the system in the turn in which the condition
      // comes to hold: it closes the page of the flow, which the user
      // still sees, and not the page of the request.
      first = await openFlow(13);
      fixtureHolder.value = true;
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'The back button of the system may close a page in the turn '
            'in which the router closed it.',
      );
      await expectRequestMade(
        13,
        first,
        'The back button of the system in the turn in which the router '
        'closed a flow closes the page of the flow once, and the router '
        'makes the request that opened the flow.',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
