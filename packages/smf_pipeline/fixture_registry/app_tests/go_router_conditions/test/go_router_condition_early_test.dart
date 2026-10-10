// A test of what only go_router does, which continuous integration runs in
// the apps of the fixture modules with go_router, the fixture gates and
// the second fixture feature: a request for a route that asks for a
// condition before go_router has a page, as the start-up of a module may
// make it. go_router has no stack to push on then and no page to replace,
// so the router gives it the location as go() does, for push() too, which
// completes with null, and go_router asks the guards about it in its
// redirect when it parses it. The flow of the guard then opens over the
// screen that the app starts on, of which the listeners of the screen hear
// nothing, and once the condition holds the location shows as go() to it
// does. A router that always has a page never comes here. It uses what the
// tests of router_screens, of router_guards and of the conditions share,
// which every app that it applies to has.
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'a push() of a route that asks for a condition before go_router has a '
    'page opens the flow over the screen that the app starts on, and shows '
    'the route as go() does once the condition holds',
    (tester) async {
      fixtureHolder.value = false;
      // Any context navigates: the router of the app is not below it.
      await tester.pumpWidget(const SizedBox());
      Object? result = 'not completed';
      unawaited(
        appRouter
            .navigatorOf(tester.element(find.byType(SizedBox)))
            .push<Object?>(const FakeSecondMemberCardLocation())
            .then((value) => result = value),
      );
      await tester.pump();
      expect(
        result,
        isNull,
        reason: 'Before go_router has a page, push() gives it the location '
            'as go() does, and completes with null.',
      );
      await startApp(tester);
      expect(
        pagesBuilt(tester),
        [FixtureHomeScreen, FixtureGateScreen],
        reason: 'A request for a route that asks for a condition that does '
            'not hold, made before go_router has a page, opens the target '
            'of the guard over the screen that the app starts on.',
      );
      expect(
        heard(),
        [gateScreen],
        reason: 'The listeners of the screen hear only of the target, not '
            'of the screen that the app starts on below it.',
      );
      expect(
        pagesForHolders(),
        0,
        reason: 'The router shows no page of a route whose condition does '
            'not hold.',
      );
      await giveBadge(tester);
      expect(
        heard(),
        [memberCardScreen],
        reason: 'Once the condition holds, the router shows the location '
            'that was asked for before go_router had a page.',
      );
      expect(
        pagesBuilt(tester),
        [FixtureMembersScreen, FixtureMemberCardScreen],
        reason: 'Once the condition holds, the router shows the location '
            'that was asked for before go_router had a page as go() to it '
            'does: its chain in place of the stack.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
