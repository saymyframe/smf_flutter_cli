// A test of what only go_router does, which continuous integration runs in
// the apps of the fixture modules with go_router, the fixture gates and
// the second fixture feature: the redirect of go_router runs for every
// location that go_router parses, also for those that the router of the
// module hands it itself, and it asks the guards with no pages, as for a
// link. Asked so about a page of the flow of a guard that stands for a
// condition, the guards open it over the screen that the app starts on.
// So the router counts its own calls of go_router, and the redirect asks
// nothing within them: a page of such a flow that the code of the app asks
// for on a page shows as it was asked, over that page for push() and
// replace(), and in place of the stack for go(), and the target that the
// guards open for a request shows over the page that the user is on. It
// uses what the tests of router_screens, of router_guards and of the
// conditions share, which every app that it applies to has.
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gate_screens.dart';
import 'package:{{app_name}}/features/fake_second/fixture_outside_screen.dart';

import 'conditions.dart';
import 'guards.dart';
import 'screens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'a page of the flow of a condition that is asked for on a page shows '
    'as it was asked, and not over the screen that the app starts on as '
    'for a link',
    (tester) async {
      await startApp(tester);
      expect(
        heard(),
        [startScreen],
        reason: 'With guards that allow, the app starts on its start screen.',
      );

      // push() of the target of the guard, by the code of the app.
      var below = await toDetails(tester, 1);
      await takeBadge(tester);
      pushed(below.nav.fakeGate.gate());
      await tester.pumpAndSettle();
      expect(heard(), [gateScreen], reason: 'push() shows its location.');
      expect(
        pagesBuilt(tester),
        [...pagesBelow, FixtureGateScreen],
        reason: 'push() of a page of the flow of a condition shows it over '
            'the page that the user is on: the redirect of go_router does '
            'not ask the guards about a location that the router pushes.',
      );
      await back(tester);
      expect(
        heard(),
        [detailsScreen(1)],
        reason: 'Back from a page of the flow of a condition that push() '
            'showed returns to the page that it was pushed from.',
      );

      // The target that the guards open for a request.
      pushed(details(tester, 1).nav.fakeSecond.members());
      await tester.pumpAndSettle();
      expect(heard(), [gateScreen], reason: 'The flow opens over the page.');
      expect(
        pagesBuilt(tester),
        [...pagesBelow, FixtureGateScreen],
        reason: 'The target that the guards open for a request shows over '
            'the page that the user is on: the redirect of go_router does '
            'not ask the guards about the push of the router.',
      );
      await back(tester);
      expect(heard(), [detailsScreen(1)], reason: 'Back returns to the page.');

      // replace() with the target, on a page that a push showed.
      pushed(details(tester, 1).nav.fakeSecond.outside());
      await tester.pumpAndSettle();
      expect(heard(), [outsideScreen], reason: 'push() shows its location.');
      shown(tester, FixtureOutsideScreen).nav.fakeGate.gate().replace();
      await tester.pumpAndSettle();
      expect(heard(), [gateScreen], reason: 'replace() shows its location.');
      expect(
        pagesBuilt(tester),
        [...pagesBelow, FixtureGateScreen],
        reason: 'replace() with a page of the flow of a condition shows it '
            'in place of the page on top, over the pages below.',
      );

      // go() to the target, which is the choice of the code of the app.
      below = await toDetails(tester, 2);
      await takeBadge(tester);
      below.nav.fakeGate.gate().go();
      await tester.pumpAndSettle();
      expect(heard(), [gateScreen], reason: 'go() shows its location.');
      expect(
        pagesBuilt(tester),
        [FixtureGateScreen],
        reason: 'go() to a page of the flow of a condition, made on a page, '
            'shows it in place of the stack, as the code of the app asked.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
