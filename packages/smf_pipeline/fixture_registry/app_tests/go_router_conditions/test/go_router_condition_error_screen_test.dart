// A test of what only go_router does, which continuous integration runs in
// the apps of the fixture modules with go_router, the fixture gates and
// the second fixture feature: a request for a route that asks for a
// condition while go_router shows its error screen alone, as after a link
// that no route matches. go_router has no page of a route then, so it has
// no page to open the flow of the guard over: the router gives it the
// location as go() does, for push() and replace() too, and go_router asks
// the guards about it in its redirect when it parses it. The flow then
// opens over the screen that the app starts on, in place of the error
// screen, and once the condition holds the location shows as go() to it
// does. A push() completes with null at once. A router whose error screen
// is a page of its own stack opens the flow over that page. It uses what
// the tests of router_screens, of router_guards and of the conditions
// share, which every app that it applies to has.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gate_screens.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gates.dart';
import 'package:{{app_name}}/features/fake_second/fixture_members_screens.dart';

import 'conditions.dart';
import 'guards.dart';
import 'screens.dart';

/// A location that no route matches, as the listeners of the screen hear of
/// the error screen there.
const _errorScreen = (null, '/no/such/screen');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'a request for a route that asks for a condition while go_router shows '
    'its error screen alone opens the flow over the screen that the app '
    'starts on, and shows the route as go() does once the condition holds',
    (tester) async {
      /// A context above the router: any context navigates.
      BuildContext above() => tester.binding.rootElement!;

      /// Has the platform ask for a location that no route matches, with
      /// the badge held, and takes the badge away on the error screen.
      Future<void> toErrorScreen() async {
        fixtureHolder.value = true;
        await tester.pumpAndSettle();
        heard();
        await tester.binding.handlePushRoute(_errorScreen.$2);
        await tester.pumpAndSettle();
        expect(
          heard(),
          [_errorScreen],
          reason: 'go_router shows its error screen at a location that no '
              'route matches.',
        );
        expect(
          pagesBuilt(tester),
          isEmpty,
          reason: 'go_router shows its error screen in place of the stack.',
        );
        fixtureHolder.value = false;
        await tester.pumpAndSettle();
        expect(
          heard(),
          isEmpty,
          reason: 'A condition that stops holding leaves the error screen '
              'as it is.',
        );
      }

      /// Checks that the target of the guard of the condition is open over
      /// the screen that the app starts on, of which the listeners heard
      /// nothing. A failure gives [reason].
      void expectFlowOverStart(String reason) {
        expect(tester.takeException(), isNull, reason: reason);
        expect(
          pagesBuilt(tester),
          [FixtureHomeScreen, FixtureGateScreen],
          reason: '$reason The target opens over the screen that the app '
              'starts on, in place of the error screen.',
        );
        expect(
          heard(),
          [gateScreen],
          reason: '$reason The listeners of the screen hear only of the '
              'target, not of the screen that the app starts on below it.',
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

      // go(), and back from the flow.
      await toErrorScreen();
      above().nav.fakeSecond.members().go();
      await tester.pumpAndSettle();
      expectFlowOverStart(
        'go() from the error screen of go_router to a route that asks for a '
        'condition that does not hold opens the target of the guard of the '
        'condition.',
      );
      await back(tester);
      expect(
        heard(),
        [startScreen],
        reason: 'Back from a flow that was opened from the error screen of '
            'go_router returns to the screen that the app starts on.',
      );
      expect(
        pagesBuilt(tester),
        [FixtureHomeScreen],
        reason: 'Back from a flow that was opened from the error screen of '
            'go_router returns to the screen that the app starts on.',
      );

      // push(): it completes at once, and the location shows as go() to it
      // does once the condition holds.
      await toErrorScreen();
      final result = pushed(above().nav.fakeSecond.memberCard());
      await tester.pumpAndSettle();
      expectFlowOverStart(
        'push() from the error screen of go_router of a route that asks for '
        'a condition that does not hold opens the target of the guard of '
        'the condition.',
      );
      expect(
        result(),
        isNull,
        reason: 'On its error screen, go_router has no page to push on: '
            'push() gives it the location as go() does, and completes with '
            'null.',
      );
      await giveBadge(tester);
      expect(
        heard(),
        [memberCardScreen],
        reason: 'Once the condition holds, the router shows the location '
            'that was asked for from the error screen of go_router.',
      );
      expect(
        pagesBuilt(tester),
        [FixtureMembersScreen, FixtureMemberCardScreen],
        reason: 'Once the condition holds, the router shows the location '
            'that was asked for from the error screen of go_router as go() '
            'to it does: its chain in place of the stack.',
      );

      // replace(): go_router has no page of a route to replace either.
      await toErrorScreen();
      above().nav.fakeSecond.members().replace();
      await tester.pumpAndSettle();
      expectFlowOverStart(
        'replace() from the error screen of go_router with a route that '
        'asks for a condition that does not hold opens the target of the '
        'guard of the condition.',
      );
      await giveBadge(tester);
      expect(
        heard(),
        [membersScreen],
        reason: 'Once the condition holds, the router shows the location '
            'that was asked for from the error screen of go_router.',
      );
      expect(
        pagesBuilt(tester),
        [FixtureMembersScreen],
        reason: 'Once the condition holds, the router shows the location '
            'that was asked for from the error screen of go_router as go() '
            'to it does: in place of the stack.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
