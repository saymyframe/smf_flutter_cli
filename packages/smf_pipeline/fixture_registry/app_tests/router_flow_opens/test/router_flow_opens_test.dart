// A test that continuous integration runs in the apps of the fixture
// modules with a router, whichever module provides it, the fixture gates
// and the second fixture feature: a request for a route that asks for a
// condition that does not hold opens the target of the guard of the
// condition over the page that the user is on, once, and the router
// throws nothing (RouterRole.guardedNavigation). The third guard of the
// fixture gates stands for the condition of the fixture badge role, and a
// route of the second fixture feature asks for it.
//
// The router shows that target itself. A router whose own navigation
// reaches the guards again, with no pages, as one whose redirect runs for
// each location that it goes to, gets the answer for a link there: to open
// the target over the screen that the app starts on, which it would do
// without end. Such a router must fail rather than hang the app, and this
// test fails on that failure: it makes the request in a zone of its own,
// which hears of what the router throws later, as from a microtask.
//
// The other tests of the conditions are in router_conditions, which need
// the late gate too: this one needs fewer modules, so the app of a router
// with that known bug has few other tests (brokenProviders of the fixture
// registry). It uses what the tests of router_screens share, which every
// app that it applies to has.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gate_screens.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gates.dart';

import 'screens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'a request for a route that asks for a condition opens the target of '
    'its guard once, without an error',
    (tester) async {
      await startApp(tester);
      expect(
        heard(),
        [('fake_feature.home', '/fake_feature')],
        reason: 'With guards that allow, the app starts on its start screen.',
      );
      fixtureHolder.value = false;
      await tester.pumpAndSettle();

      // What a router throws once the request has returned, as from a
      // microtask, nothing can catch: the zone of the request hears of it.
      final thrown = <Object>[];
      final home = tester.element(find.byType(FixtureHomeScreen));
      runZonedGuarded(
        () => unawaited(home.nav.fakeSecond.members().push<Object?>()),
        (error, _) => thrown.add(error),
      );
      await tester.pumpAndSettle();
      final reported = tester.takeException() as Object?;
      if (reported != null) thrown.add(reported);
      expect(
        thrown,
        isEmpty,
        reason: 'A router throws nothing when it opens the target of a guard '
            'for a request.',
      );
      expect(
        heard(),
        [('fake_gate.gate', '/fake_gate')],
        reason: 'push() of a route that asks for a condition that does not '
            'hold opens the target of the guard of the condition, of which '
            'the listeners of the screen hear once.',
      );
      expect(
        [
          find.byType(FixtureHomeScreen, skipOffstage: false).evaluate().length,
          find.byType(FixtureGateScreen).evaluate().length,
        ],
        [1, 1],
        reason: 'The target of a guard of a condition opens once, over the '
            'page that the user is on, which stays below it.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
