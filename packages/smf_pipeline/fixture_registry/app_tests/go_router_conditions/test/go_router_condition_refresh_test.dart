// A test of what only go_router does, which continuous integration runs in
// the apps of the fixture modules with go_router, the fixture gates and
// the second fixture feature: a refresh of its routes while the flow of a
// guard that stands for a condition is open over a page. go_router then
// matches its location again and shows its pages anew, with a new
// completer for each pushed page, and its redirect runs for the location
// below them. The router asks the guards about that location, which opens
// no second flow, and the push that waits for the flow still completes
// with the value of its page once the condition holds. The flow of a
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
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
