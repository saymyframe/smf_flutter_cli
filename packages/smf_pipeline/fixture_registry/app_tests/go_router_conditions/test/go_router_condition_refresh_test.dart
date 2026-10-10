// A test of what only go_router does, which continuous integration runs in
// the apps of the fixture modules with go_router, the fixture gates and
// the second fixture feature: a refresh of its routes while the flow of a
// guard that stands for a condition is open over a page. go_router then
// matches its location again and shows its pages anew, with a new
// completer for each pushed page, and its redirect runs for the location
// below them, with no pages, as for a link. The router counts a refresh
// among its own calls, so the redirect asks the guards nothing then: no
// second flow opens, and the push that waits for the flow still completes
// with the value of its page once the condition holds. Asked, the guards
// would open a page of the flow that the code of the app went to with
// go(), which stands alone, over the screen that the app starts on, and a
// page that was pushed over it would be gone. The flow of a
// condition under any router is tested in router_conditions. It uses what
// the tests of router_screens, of router_guards and of the conditions
// share, which every app that it applies to has.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:{{app_name}}/core/router/app_router.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gate_screens.dart';
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
    'a refresh of the routes of go_router leaves the flow of a condition '
    'open, and the push that waits for it still completes with the value '
    'of its page',
    (tester) async {
      await startApp(tester);
      expect(heard(), [startScreen]);
      final router = appRouter.config as GoRouter;
      // The notifications of the delegate, without which the steps below
      // would test nothing.
      var notified = 0;
      router.routerDelegate.addListener(() => notified++);

      final below = await toDetails(tester, 1);
      await takeBadge(tester);
      final result = pushed(below.nav.fakeSecond.members());
      await tester.pumpAndSettle();
      expect(heard(), [gateScreen], reason: 'The flow opens over the page.');
      final flow = shown(tester, FixtureGateScreen);

      // A refresh while the flow is open, twice.
      for (var refresh = 0; refresh < 2; refresh++) {
        notified = 0;
        router.refresh();
        await tester.pumpAndSettle();
        expect(notified, isPositive, reason: 'go_router notified.');
        expect(
          heard(),
          isEmpty,
          reason: 'A refresh of the routes while the flow of a condition is '
              'open leaves the page on top as it is.',
        );
        expect(
          pagesBuilt(tester),
          [...pagesBelow, FixtureGateScreen],
          reason: 'A refresh of the routes while the flow of a condition is '
              'open opens no second flow, and closes none.',
        );
        expect(flow.mounted, isTrue, reason: 'The page of the target stayed.');
        expect(
          result(),
          'not completed',
          reason: 'A refresh of the routes while the flow of a condition is '
              'open leaves the request that opened it waiting.',
        );
      }

      // The condition holds: the router closes the flow, whose page has a
      // completer of go_router that is no longer the one of its push, and
      // makes the request again.
      await giveBadge(tester);
      expect(
        pagesBuilt(tester),
        [...pagesBelow, FixtureMembersScreen],
        reason: 'Once the condition holds after a refresh, the router '
            'closes the flow and shows the location that push() asked for.',
      );
      expect(heard(), [membersScreen]);

      // A refresh with the page of the request on top, and then its value.
      notified = 0;
      router.refresh();
      await tester.pumpAndSettle();
      expect(notified, isPositive, reason: 'go_router notified.');
      expect(heard(), isEmpty, reason: 'The page on top stayed.');
      Navigator.of(shown(tester, FixtureMembersScreen)).pop('closed');
      await tester.pumpAndSettle();
      expect(
        result(),
        'closed',
        reason: 'A push() that waited for a flow completes with the value '
            'of its page, also after go_router gave that page a new '
            'completer.',
      );
      expect(heard(), [detailsScreen(1)]);

      // The code of the app went to the target of the guard with go(),
      // which stands alone, and pushed a page over it: a refresh leaves
      // both as they are, and that push still completes with the value of
      // its page.
      final alone = await toDetails(tester, 2);
      await takeBadge(tester);
      alone.nav.fakeGate.gate().go();
      await tester.pumpAndSettle();
      expect(heard(), [gateScreen], reason: 'go() shows its location.');
      final over = pushed(
        shown(tester, FixtureGateScreen).nav.fakeSecond.outside(),
      );
      await tester.pumpAndSettle();
      expect(heard(), [outsideScreen], reason: 'push() shows its location.');
      notified = 0;
      router.refresh();
      await tester.pumpAndSettle();
      expect(notified, isPositive, reason: 'go_router notified.');
      expect(
        heard(),
        isEmpty,
        reason: 'A refresh of the routes over a page of the flow of a '
            'condition that stands alone leaves the page on top as it is.',
      );
      expect(
        pagesBuilt(tester),
        [FixtureGateScreen, FixtureOutsideScreen],
        reason: 'A refresh of the routes leaves a page of the flow of a '
            'condition that the code of the app went to, and the page that '
            'was pushed over it, as they are: the redirect of go_router '
            'does not ask the guards about the location that a refresh '
            'parses again.',
      );
      Navigator.of(shown(tester, FixtureOutsideScreen)).pop('closed');
      await tester.pumpAndSettle();
      expect(
        over(),
        'closed',
        reason: 'A push() over a page of the flow of a condition that '
            'stands alone completes with the value of its page after a '
            'refresh of the routes.',
      );
      expect(heard(), [gateScreen], reason: 'Back returns to the page.');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
