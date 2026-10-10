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
// asks for it below a route that asks for nothing. The router then shows
// the target of the guard, once, and no screen of a route that asks for
// the condition stays.
//
// The guard does not bring the user back, so once the condition holds
// again, the router leaves the target for the screen that the app starts
// on. Each expectation gives its reason, which a provider of the role with
// a known bug fails the test with (brokenProviders of the fixture
// registry).
import 'package:flutter_test/flutter_test.dart';
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
    'a condition that stops holding shows the target of its guard in place '
    'of a page that asks for it, a pushed one and one below a route that '
    'asks for nothing',
    (tester) async {
      /// Checks that the target of the guard of the condition is on top,
      /// which the listeners heard of once, that it is the only page, and
      /// that no screen of a route that asks for the condition is left. A
      /// failure gives [reason].
      void expectTargetOnTop(String reason) {
        expect(heard(), [gateScreen], reason: reason);
        expect(
          builtScreens(tester),
          [FixtureGateScreen],
          reason: '$reason The target takes the place of the whole stack.',
        );
        expect(
          builtForHolders(tester),
          isEmpty,
          reason: 'When a condition stops holding, no page that asks for it '
              'stays in the stack.',
        );
      }

      /// Gives the badge back, and checks that the router leaves the target
      /// of the guard for the screen that the app starts on.
      Future<void> holdAgain() async {
        fixtureHolder.value = true;
        await tester.pumpAndSettle();
        expect(
          heard(),
          [startScreen],
          reason: 'Once a condition holds again whose guard does not bring '
              'the user back, the router leaves the target of the guard for '
              'the screen that the app starts on.',
        );
        expect(
          builtScreens(tester),
          [FixtureHomeScreen],
          reason: 'Once a condition holds again whose guard does not bring '
              'the user back, the router leaves the target of the guard for '
              'the screen that the app starts on.',
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
      shown(tester, FixtureHomeScreen).nav.fakeFeature.details(id: 1).go();
      await tester.pumpAndSettle();
      expect(
        heard(),
        [('fake_feature.details', '/fake_feature/details/1')],
        reason: 'A route that asks for no condition shows as it is.',
      );
      pushed(details(tester, 1).nav.fakeSecond.memberCard());
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
      fixtureHolder.value = false;
      await tester.pumpAndSettle();
      expectTargetOnTop(
        'When a condition stops holding, the router shows the target of its '
        'guard in place of a pushed page that asks for the condition, over '
        'a page that asks for none.',
      );
      await holdAgain();

      // A route that asks for the condition by itself, below a route that
      // asks for nothing, which go() showed.
      shown(tester, FixtureHomeScreen).nav.fakeSecond.vault().go();
      await tester.pumpAndSettle();
      expect(
        heard(),
        [vaultScreen],
        reason: 'While a condition holds, go() to a route that asks for it '
            'shows the route.',
      );
      expect(
        builtForHolders(tester),
        [FixtureVaultScreen],
        reason: 'While a condition holds, go() to a route that asks for it '
            'shows the route.',
      );
      fixtureHolder.value = false;
      await tester.pumpAndSettle();
      expectTargetOnTop(
        'When a condition stops holding, the router shows the target of its '
        'guard in place of a route that asks for the condition, below a '
        'route that asks for none.',
      );
      await holdAgain();

      // A pushed page that asks for the condition by itself, over a route
      // that asks for it too.
      shown(tester, FixtureHomeScreen).nav.fakeSecond.members().go();
      await tester.pumpAndSettle();
      expect(
        heard(),
        [membersScreen],
        reason: 'While a condition holds, go() to a route that asks for it '
            'shows the route.',
      );
      pushed(shown(tester, FixtureMembersScreen).nav.fakeSecond.vault());
      await tester.pumpAndSettle();
      expect(
        heard(),
        [vaultScreen],
        reason: 'While a condition holds, push() of a route that asks for it '
            'shows the route.',
      );
      fixtureHolder.value = false;
      await tester.pumpAndSettle();
      expectTargetOnTop(
        'When a condition stops holding, the router shows the target of its '
        'guard in place of the pages that ask for the condition.',
      );
      await holdAgain();
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
