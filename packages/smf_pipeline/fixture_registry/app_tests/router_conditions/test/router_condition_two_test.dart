// A test that continuous integration runs in the apps of the fixture
// modules with a router, whichever module provides it, the fixture gates
// and the second fixture feature: two guards that stand for a condition,
// each with a flow of its own, as RouterRole.guardedNavigation says. The
// third guard of the fixture gates stands for the first condition of the
// fixture badge role, with the flow of the gate screen, and the fourth for
// the second, with the flow of the second gate screen. A route of the
// second fixture feature asks for the second condition, and the route
// below it for both.
//
// For a route that asks for two conditions, the flow of the first guard
// that does not allow opens. Once that guard allows, the router closes its
// flow and asks about the request again, so the flow of the next guard
// opens in turn, and the route shows once both hold: a push() that waited
// through both flows completes with the value of its page. The router
// keeps one request waiting: when a request opens the flow of another
// guard over an open flow, the request that waited is dropped. And when
// the flow on top closes, the router makes its request again over the
// flow below, which stays open until its own guard allows.
//
// Each expectation gives its reason, which a provider of the role with a
// known bug fails the test with (brokenProviders of the fixture registry).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gate_screens.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gates.dart';
import 'package:{{app_name}}/features/fake_second/fixture_members_screens.dart';

import 'conditions.dart';
import 'guards.dart';
import 'screens.dart';

/// The route of the second fixture feature that asks for the second
/// condition, as the listeners of the screen hear of it.
const _loungeScreen = ('fake_second.lounge', '/fake_second/lounge');

/// The route below it, which asks for both conditions, as the listeners of
/// the screen hear of it.
const _seatScreen = ('fake_second.loungeSeat', '/fake_second/lounge/seat');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'for a route that asks for two conditions, the flow of the first guard '
    'that does not allow opens, and that of the next once the first allows; '
    'the router keeps one request waiting',
    (tester) async {
      /// The screens of the two routes of the lounge that the router built.
      List<Type> builtForSeniors() => [
            for (final widget in tester.allWidgets)
              if (widget is FixtureLoungeScreen ||
                  widget is FixtureLoungeSeatScreen)
                widget.runtimeType,
          ];

      await startApp(tester);
      expect(
        heard(),
        [startScreen],
        reason: 'With guards that allow, the app starts on its start screen.',
      );

      // A route that asks for two conditions, neither of which holds.
      var below = await toDetails(tester, 1);
      fixtureSenior.value = false;
      await takeBadge(tester);
      var result = pushed(below.nav.fakeSecond.loungeSeat());
      await tester.pumpAndSettle();
      expect(
        heard(),
        [gateScreen],
        reason: 'For a route that asks for two conditions that do not hold, '
            'the target of the first guard of the app that stands for one '
            'of them opens.',
      );
      expect(
        pagesBuilt(tester),
        [...pagesBelow, FixtureGateScreen],
        reason: 'The target of a guard of a condition opens over the page '
            'that the user is on.',
      );
      await giveBadge(tester);
      expect(
        heard(),
        [secondGateScreen],
        reason: 'Once the first condition holds, the router closes its flow '
            'and asks about the request again: the target of the guard of '
            'the second condition opens, and the listeners of the screen '
            'hear nothing of the page below in between.',
      );
      expect(
        pagesBuilt(tester),
        [...pagesBelow, FixtureSecondGateScreen],
        reason: 'Once the first condition holds, the target of the guard of '
            'the second opens over the page that the request was made on, '
            'in place of the flow of the first.',
      );
      expect(
        builtForSeniors(),
        isEmpty,
        reason: 'The router builds no screen of a route while a condition '
            'that it asks for does not hold.',
      );
      expect(
        result(),
        'not completed',
        reason: 'A push() of a route that asks for two conditions waits '
            'through the flows of both guards.',
      );
      fixtureSenior.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [_seatScreen],
        reason: 'Once both conditions hold, the router shows the location '
            'that was asked for.',
      );
      expect(
        pagesBuilt(tester).sublist(0, 2),
        pagesBelow,
        reason: 'Once both conditions hold, the location that push() asked '
            'for shows over the page that the first flow was opened over.',
      );
      expect(builtForSeniors(), [FixtureLoungeSeatScreen]);
      Navigator.of(shown(tester, FixtureLoungeSeatScreen)).pop('closed');
      await tester.pumpAndSettle();
      expect(
        result(),
        'closed',
        reason: 'A push() that waited through the flows of two guards '
            'completes with the value of its page.',
      );
      expect(heard(), [detailsScreen(1)]);

      // The flow of a second guard over the open flow of the first: the
      // router keeps the latest request, and drops the one that waited.
      below = await toDetails(tester, 2);
      fixtureSenior.value = false;
      await takeBadge(tester);
      final first = pushed(below.nav.fakeSecond.members());
      await tester.pumpAndSettle();
      expect(heard(), [gateScreen], reason: 'The flow opens over the page.');
      result = pushed(shown(tester, FixtureGateScreen).nav.fakeSecond.lounge());
      await tester.pumpAndSettle();
      expect(
        heard(),
        [secondGateScreen],
        reason: 'A request for a route that asks for another condition '
            'opens the flow of its guard over the open flow of the first: a '
            'flow is open for the guards that have it.',
      );
      expect(
        pagesBuilt(tester),
        [...pagesBelow, FixtureGateScreen, FixtureSecondGateScreen],
        reason: 'A request for a route that asks for another condition '
            'opens the flow of its guard over the open flow of the first.',
      );
      expect(
        first(),
        isNull,
        reason: 'The router keeps one request waiting: when a request opens '
            'another flow, the push() that waited before completes with '
            'null.',
      );
      // The second condition holds: only its flow closes, and its request
      // shows over the flow of the first, which is not over.
      fixtureSenior.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [_loungeScreen],
        reason: 'Once the condition of the flow on top holds, the router '
            'closes that flow and makes its request again, over the open '
            'flow of the other guard.',
      );
      expect(
        pagesBuilt(tester),
        [...pagesBelow, FixtureGateScreen, FixtureLoungeScreen],
        reason: 'Once the condition of the flow on top holds, the flow of '
            'the other guard, which is not over, stays below the location '
            'that was asked for.',
      );
      // The first condition holds: its target leaves from below the page
      // of the lounge, with that page.
      await giveBadge(tester);
      expect(
        heard(),
        [detailsScreen(2)],
        reason: 'Once a condition holds, the router closes the pages of its '
            'flow with the pages over them, a page that asks for another '
            'condition too.',
      );
      expect(pagesBuilt(tester), pagesBelow);
      expect(
        result(),
        isNull,
        reason: 'The push() of a page that the router closes with a flow '
            'below it completes with null.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
