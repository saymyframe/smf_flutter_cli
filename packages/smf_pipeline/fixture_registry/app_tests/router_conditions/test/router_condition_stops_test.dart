// A test that continuous integration runs in the apps of the fixture
// modules with a router, whichever module provides it, the fixture gates
// and the second fixture feature: a condition that stops holding while a
// page that asks for it is on the stack, as when a user signs out on a
// screen of the account. The third guard of the fixture gates stands for
// the condition of the fixture badge role, and three routes of the second
// fixture feature ask for it.
//
// The router tells the guards of its pages when one of them changes, each
// page under the name of its own route, as RouterRole.guardedNavigation
// says. A gate keeps the user from every route outside its flow, so only a
// guard that stands for a condition shows whether a router names a page
// rightly: it keeps the user from a pushed page that asks for the
// condition though the page below asks for nothing, and from a route that
// asks for it below a route that asks for nothing. The router then closes
// each page that asks for the condition with the pages over it, and the
// user is on the page below. A page that asks for it and has no page below
// it, as after go() to it, leaves for the screen that the app starts on.
// Nothing happens once the condition holds again: no request waits. A page
// that ends the condition itself and closes itself in the same turn, which
// a screen should not do, closes once: the page below it stays, and the
// router does not fail.
//
// Each expectation gives its reason, which a provider of the role with a
// known bug fails the test with (brokenProviders of the fixture registry).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';
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
    'a condition that stops holding closes the pages that ask for it with '
    'the pages over them, a pushed one and one below a route that asks for '
    'nothing, and the user is on the page below',
    (tester) async {
      /// Takes the badge away, and checks that the user is on the details
      /// of the item [id] again, with the pages of [pagesBelow] alone, of
      /// which the listeners heard once, and that no screen of a route
      /// that asks for the condition is left. A failure gives [reason].
      Future<void> expectBackOnDetails(int id, String reason) async {
        fixtureHolder.value = false;
        await tester.pumpAndSettle();
        expect(pagesBuilt(tester), pagesBelow, reason: reason);
        expect(
          heard(),
          [detailsScreen(id)],
          reason: '$reason The listeners of the screen hear once of the '
              'page that the user ends on.',
        );
      }

      /// Takes the badge away, and checks that the user is on the screen
      /// that the app starts on, alone, and that no screen of a route that
      /// asks for the condition is left. A failure gives [reason].
      Future<void> expectOnStart(String reason) async {
        fixtureHolder.value = false;
        await tester.pumpAndSettle();
        expect(heard(), [startScreen], reason: reason);
        expect(pagesBuilt(tester), [FixtureHomeScreen], reason: reason);
      }

      /// Gives the badge back, which changes nothing: no request waits.
      Future<void> holdAgain() async {
        await giveBadge(tester);
        expect(
          heard(),
          isEmpty,
          reason: 'Once a condition holds again, the router leaves the user '
              'where they are: it closed the pages that asked for it, and '
              'no request waits.',
        );
      }

      await startApp(tester);
      expect(
        heard(),
        [startScreen],
        reason: 'With guards that allow, the app starts on its start screen.',
      );

      // A page that a push showed and that asks for the condition, by
      // being below a route that does, over a page that asks for nothing.
      var below = await toDetails(tester, 1);
      var result = pushed(below.nav.fakeSecond.memberCard());
      await tester.pumpAndSettle();
      expect(
        heard(),
        [memberCardScreen],
        reason: 'While a condition holds, push() of a route that asks for it '
            'shows the route.',
      );
      expect(
        builtForHolders(tester),
        [FixtureMemberCardScreen],
        reason: 'While a condition holds, push() of a route that asks for it '
            'shows the route.',
      );
      await expectBackOnDetails(
        1,
        'When a condition stops holding, the router closes a pushed page '
        'that asks for the condition, over a page that asks for none: the '
        'user is on the page below.',
      );
      expect(
        result(),
        isNull,
        reason: 'The push() of a page that the router closes completes with '
            'null.',
      );
      await holdAgain();

      // A page that asks for nothing over a page that asks for the
      // condition: both close, and the listeners hear of one page.
      below = await toDetails(tester, 2);
      result = pushed(below.nav.fakeSecond.members());
      await tester.pumpAndSettle();
      final over = pushed(
        shown(tester, FixtureMembersScreen).nav.fakeSecond.outside(),
      );
      await tester.pumpAndSettle();
      expect(
        heard(),
        [membersScreen, outsideScreen],
        reason: 'While a condition holds, push() shows its location.',
      );
      expect(
        pagesBuilt(tester),
        [...pagesBelow, FixtureMembersScreen, FixtureOutsideScreen],
        reason: 'While a condition holds, push() shows its location.',
      );
      await expectBackOnDetails(
        2,
        'When a condition stops holding, the router closes a page that '
        'asks for it with the page that was pushed over it.',
      );
      expect(
        [result(), over()],
        [isNull, isNull],
        reason: 'The push() of each page that the router closes completes '
            'with null.',
      );
      await holdAgain();

      // A route that lists the condition itself, below a route that asks
      // for nothing, which go() showed: it has no page below it that the
      // router could leave the user on.
      details(tester, 2).nav.fakeSecond.vault().go();
      await tester.pumpAndSettle();
      expect(
        heard(),
        [vaultScreen],
        reason: 'While a condition holds, go() to a route that asks for it '
            'shows the route.',
      );
      expect(
        pagesBuilt(tester),
        [FixtureOutsideScreen, FixtureVaultScreen],
        reason: 'While a condition holds, go() to a route that asks for it '
            'shows the chain of the route.',
      );
      await expectOnStart(
        'When a condition stops holding on a route that asks for it, below '
        'a route that asks for none, which took the place of the stack, the '
        'user comes to the screen that the app starts on.',
      );
      await holdAgain();

      // A pushed page over a route that asks for the condition and that
      // took the place of the stack.
      shown(tester, FixtureHomeScreen).nav.fakeSecond.members().go();
      await tester.pumpAndSettle();
      expect(
        heard(),
        [membersScreen],
        reason: 'While a condition holds, go() to a route that asks for it '
            'shows the route.',
      );
      pushed(shown(tester, FixtureMembersScreen).nav.fakeSecond.outside());
      await tester.pumpAndSettle();
      expect(
        heard(),
        [outsideScreen],
        reason: 'push() of a route that asks for no condition shows it.',
      );
      await expectOnStart(
        'When a condition stops holding on a route that asks for it and '
        'has no page below it, the user comes to the screen that the app '
        'starts on, from a page that was pushed over that route too.',
      );
      await holdAgain();

      // A page that asks for the condition ends it and closes itself in
      // the same turn, as a sign-out on a screen of an account would. The
      // navigator still has the route of the page that the router closed,
      // so the page closes once, and the page below it stays.
      below = await toDetails(tester, 3);
      result = pushed(below.nav.fakeSecond.members());
      await tester.pumpAndSettle();
      expect(
        heard(),
        [membersScreen],
        reason: 'While a condition holds, push() of a route that asks for it '
            'shows the route.',
      );
      final asking = shown(tester, FixtureMembersScreen);
      fixtureHolder.value = false;
      Navigator.of(asking).pop('closed by its screen');
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'A page that the router closed may close itself in the same '
            'turn.',
      );
      expect(
        pagesBuilt(tester),
        pagesBelow,
        reason: 'When a page that asks for a condition ends it and closes '
            'itself in the same turn, that page closes once: the router '
            'closed it already, and the page below it stays.',
      );
      expect(
        heard(),
        [detailsScreen(3)],
        reason: 'When a page that asks for a condition ends it and closes '
            'itself in the same turn, the listeners of the screen hear once '
            'of the page below it.',
      );
      expect(
        result(),
        anyOf(isNull, 'closed by its screen'),
        reason: 'The push() of a page that the router closes completes with '
            'null, or with the value that the page closed itself with '
            'before the frame was over.',
      );
      await holdAgain();
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
