// A test that continuous integration runs in the apps of the fixture
// modules with a router, whichever module provides it, the fixture gates
// and the second fixture feature: a push() of a route that asks for two
// conditions before the router has shown a page, as the start-up of a
// module may make it. The flow of the first guard that does not allow
// opens over the screen that the app starts on, of which the listeners of
// the screen hear nothing, then that of the second, and the router never
// builds the screen of the route until both hold.
//
// What the request does then is one of two things, as
// RouterRole.guardedNavigation says of a router that has no page yet. A
// router that has a stack by then keeps the push waiting through both
// flows, shows the route over the screen that the app starts on, and
// completes the push with the value of its page. A router that has no
// stack to push on takes the request as go(): the push completes with
// null at once, and the route shows in place of the stack. The test takes
// either, and nothing between the two.
//
// It uses what the tests of router_screens, of router_guards and of the
// conditions share. Each expectation gives its reason, which a provider of
// the role with a known bug fails the test with (brokenProviders of the
// fixture registry).
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/app_router.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gate_screens.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gates.dart';
import 'package:{{app_name}}/features/fake_second/fixture_members_screens.dart';

import 'conditions.dart';
import 'guards.dart';
import 'screens.dart';

/// The route of the second fixture feature that asks for both conditions,
/// below a route that asks for the second, as the listeners of the screen
/// hear of it.
const _seatScreen = ('fake_second.loungeSeat', '/fake_second/lounge/seat');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'a push() of a route that asks for two conditions before the router has '
    'a page opens the flow of each guard in turn over the screen that the '
    'app starts on, and shows the route once both hold',
    (tester) async {
      /// The screens of the two routes of the lounge that the router built.
      List<Type> builtForSeniors() => [
            for (final widget in tester.allWidgets)
              if (widget is FixtureLoungeScreen ||
                  widget is FixtureLoungeSeatScreen)
                widget.runtimeType,
          ];

      fixtureHolder.value = false;
      fixtureSenior.value = false;
      // Any context navigates: the router of the app is not below it.
      await tester.pumpWidget(const SizedBox());
      Object? result = 'not completed';
      unawaited(
        appRouter
            .navigatorOf(tester.element(find.byType(SizedBox)))
            .push<Object?>(const FakeSecondLoungeSeatLocation())
            .then((value) => result = value),
      );
      await tester.pump();
      expect(
        result,
        anyOf(isNull, 'not completed'),
        reason: 'A push() of a route whose condition does not hold, before '
            'the router has a page, waits for the flow of the guard, or '
            'completes with null for a router that takes it as go().',
      );
      // What the router made of the request, which holds to the end.
      final asGo = result == null;

      await startApp(tester);
      expect(
        pagesBuilt(tester),
        [FixtureHomeScreen, FixtureGateScreen],
        reason: 'A request for a route that asks for a condition that does '
            'not hold, made before the router has a page, opens the target '
            'of the guard over the screen that the app starts on.',
      );
      expect(
        heard(),
        [gateScreen],
        reason: 'The listeners of the screen hear only of the target, not '
            'of the screen that the app starts on below it.',
      );

      await giveBadge(tester);
      expect(
        heard(),
        [secondGateScreen],
        reason: 'Once the first condition holds, the target of the guard of '
            'the second opens for a request that was made before the router '
            'had a page, and the listeners of the screen hear nothing of '
            'the screen that the app starts on between the two flows.',
      );
      expect(
        pagesBuilt(tester),
        [FixtureHomeScreen, FixtureSecondGateScreen],
        reason: 'Once the first condition holds, the target of the guard of '
            'the second opens over the screen that the app starts on, in '
            'place of the flow of the first.',
      );
      expect(
        builtForSeniors(),
        isEmpty,
        reason: 'The router builds no screen of a route while a condition '
            'that it asks for does not hold.',
      );
      expect(
        result,
        asGo ? isNull : 'not completed',
        reason: 'A push() that waits for a flow does not complete while a '
            'flow is open for it.',
      );

      fixtureSenior.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [_seatScreen],
        reason: 'Once both conditions hold, the router shows the location '
            'that was asked for before it had a page.',
      );
      if (asGo) {
        expect(
          pagesBuilt(tester),
          [FixtureLoungeScreen, FixtureLoungeSeatScreen],
          reason: 'A router that took a push() before its first page as '
              'go() shows the location as go() to it does: its chain in '
              'place of the stack.',
        );
        return;
      }
      expect(
        pagesBuilt(tester),
        [FixtureHomeScreen, FixtureLoungeSeatScreen],
        reason: 'A router that kept a push() before its first page waiting '
            'shows the location as push() does: over the screen that the '
            'app starts on.',
      );
      Navigator.of(shown(tester, FixtureLoungeSeatScreen)).pop('closed');
      await tester.pumpAndSettle();
      expect(
        result,
        'closed',
        reason: 'A push() that waited for a flow completes with the value '
            'of its page.',
      );
      expect(
        heard(),
        [startScreen],
        reason: 'The screen that the app starts on is heard of once when '
            'the page above it closes.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
