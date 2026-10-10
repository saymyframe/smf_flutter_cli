// A test that continuous integration runs in the apps of the fixture
// modules with a router, whichever module provides it, the fixture gates
// and the second fixture feature: a guard that stands for a condition
// (RouteGuard.condition) keeps the user only from the routes that ask for
// that condition (Route.conditions), as RouterRole.guardedNavigation says.
// Three routes of the second fixture feature ask for the condition of the
// fixture badge role, and the third guard of the fixture gates stands for
// it. One of them asks by being below another, and one asks by itself,
// below a route that asks for nothing: a router that asked the guards
// about the route above a route would show it to everyone. The feature
// knows nothing of that guard: both know only the role.
//
// While the condition does not hold, the router shows the target of the
// guard in place of a route that asks for it, whichever of go(), push(),
// replace() and the platform asks, and never builds the screen of that
// route. Every other route shows as it is, the routes of the flow of the
// guard among them: the gate that has the same flow allows, but the flow
// is over only once the condition holds too. Once it holds, the router
// shows the location that was asked for, and the flow is over.
//
// The target takes the place of the whole stack, as the target of a gate
// does, whichever page the route was asked from, and such a push()
// completes with null. Each expectation gives its reason, which a provider
// of the role with a known bug fails the test with (brokenProviders of the
// fixture registry).
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

/// Why nothing happens when the condition stops holding on a page of a
/// route that does not ask for it.
const _stays = 'A condition that stops holding leaves a page that does not '
    'ask for it as it is.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'a route that asks for a condition shows only while the condition '
    'holds, the target of its guard in its place until then, and every '
    'other route as it is',
    (tester) async {
      /// Goes to the screen that the app starts on, and then to the details
      /// of the item [id], a page on top of that screen, which asks for no
      /// condition; returns its context.
      Future<BuildContext> toDetails(int id) async {
        final from = tester.element(find.byType(Navigator).first);
        from.nav.fakeFeature.home().go();
        await tester.pumpAndSettle();
        heard();
        shown(tester, FixtureHomeScreen).nav.fakeFeature.details(id: id).go();
        await tester.pumpAndSettle();
        expect(
          heard(),
          [('fake_feature.details', '/fake_feature/details/$id')],
          reason: 'A route that asks for no condition shows as it is, while '
              'a condition holds and while it does not.',
        );
        return details(tester, id);
      }

      /// Checks that the target of the guard of the condition is on top,
      /// which the listeners heard of once, that it is the only page, and
      /// that the router built no screen of a route that asks for the
      /// condition. A failure gives [reason].
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
          reason: 'The router builds no screen of a route whose condition '
              'does not hold.',
        );
      }

      /// How many pages of the routes that ask for the condition came on
      /// the navigators of the router so far.
      int pagesForHolders() => pagesShown()
          .where(
            {membersScreen.$1, memberCardScreen.$1, vaultScreen.$1}.contains,
          )
          .length;

      await startApp(tester);
      expect(
        heard(),
        [startScreen],
        reason: 'With guards that allow, the app starts on its start screen.',
      );

      // The condition stops holding while no page asks for it.
      final home = shown(tester, FixtureHomeScreen);
      fixtureHolder.value = false;
      await tester.pumpAndSettle();
      expect(heard(), isEmpty, reason: _stays);
      expect(home.mounted, isTrue, reason: _stays);

      // go() to a route that asks for it, from a page of another route.
      (await toDetails(1)).nav.fakeSecond.members().go();
      await tester.pumpAndSettle();
      expectTargetOnTop(
        'go() to a route that asks for a condition that does not hold shows '
        'the target of the guard of the condition.',
      );
      expect(
        pagesForHolders(),
        0,
        reason: 'The router shows no page of a route whose condition does '
            'not hold.',
      );

      // The flow of the guard: its gate allows, and the condition does not
      // hold, so the flow is not over, and its routes show like any other.
      final step = pushed(shown(tester, FixtureGateScreen).nav.fakeGate.step());
      await tester.pumpAndSettle();
      expect(
        heard(),
        [stepScreen],
        reason: 'While a condition does not hold, the routes of the flow of '
            'its guard show, though the gate with that flow allows.',
      );
      Navigator.of(shown(tester, FixtureGateStepScreen)).pop('closed');
      await tester.pumpAndSettle();
      expect(
        step(),
        'closed',
        reason: 'While a condition does not hold, push() of a route of the '
            'flow of its guard completes with the value of its page.',
      );
      expect(
        heard(),
        [gateScreen],
        reason: 'The target of the guard is heard of once when the page '
            'above it closes.',
      );

      // The condition holds: the router shows what was asked for, as go()
      // to it does, and the flow is over.
      fixtureHolder.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [membersScreen],
        reason: 'Once the condition holds, the router shows the location '
            'that was asked for.',
      );
      expect(
        builtForHolders(tester),
        [FixtureMembersScreen],
        reason: 'Once the condition holds, the router shows the location '
            'that go() asked for as go() does.',
      );
      expect(
        builtScreens(tester),
        isEmpty,
        reason: 'Once the condition holds, the router shows the location '
            'that go() asked for in place of the stack, the target of the '
            'guard too.',
      );
      shown(tester, FixtureMembersScreen).nav.fakeGate.gate().go();
      await tester.pumpAndSettle();
      expect(
        heard(),
        [startScreen],
        reason: 'Once the gate and the condition with one flow both allow, '
            'the flow is over: go() to its target shows the screen that the '
            'app starts on.',
      );

      // go() to the route that asks for it by itself, below a route that
      // asks for nothing: the router asks about the route of the location,
      // not about the route above it.
      fixtureHolder.value = false;
      await tester.pumpAndSettle();
      expect(heard(), isEmpty, reason: _stays);
      (await toDetails(2)).nav.fakeSecond.vault().go();
      await tester.pumpAndSettle();
      expectTargetOnTop(
        'go() to a route that asks for a condition that does not hold, '
        'below a route that asks for none, shows the target of the guard of '
        'the condition.',
      );
      fixtureHolder.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [vaultScreen],
        reason: 'Once the condition holds, the router shows the location '
            'that was asked for, below a route that asks for no condition.',
      );
      expect(
        builtForHolders(tester),
        [FixtureVaultScreen],
        reason: 'Once the condition holds, the router shows the location '
            'that was asked for, below a route that asks for no condition.',
      );

      // push() of that route.
      shown(tester, FixtureVaultScreen).nav.fakeFeature.home().go();
      await tester.pumpAndSettle();
      expect(
        heard(),
        [startScreen],
        reason: 'A route that asks for no condition shows as it is.',
      );
      fixtureHolder.value = false;
      await tester.pumpAndSettle();
      expect(heard(), isEmpty, reason: _stays);
      final vault = pushed(
        shown(tester, FixtureHomeScreen).nav.fakeSecond.vault(),
      );
      await tester.pumpAndSettle();
      expectTargetOnTop(
        'push() of a route that asks for a condition that does not hold, '
        'below a route that asks for none, shows the target of the guard of '
        'the condition.',
      );
      expect(
        vault(),
        isNull,
        reason: 'push() of a route that asks for a condition that does not '
            'hold completes with null.',
      );
      fixtureHolder.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [vaultScreen],
        reason: 'Once the condition holds, the router shows the location '
            'that push() asked for.',
      );
      expect(
        builtForHolders(tester).last,
        FixtureVaultScreen,
        reason: 'Once the condition holds, the router shows the location '
            'that push() asked for.',
      );

      // replace() with that route.
      final replaced = await toDetails(3);
      fixtureHolder.value = false;
      await tester.pumpAndSettle();
      expect(heard(), isEmpty, reason: _stays);
      replaced.nav.fakeSecond.vault().replace();
      await tester.pumpAndSettle();
      expectTargetOnTop(
        'replace() with a route that asks for a condition that does not '
        'hold shows the target of the guard of the condition.',
      );
      fixtureHolder.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [vaultScreen],
        reason: 'Once the condition holds, the router shows the location '
            'that replace() asked for.',
      );

      // A location from the platform: the router asks the guards about it,
      // or takes no locations from the platform and stays where it is.
      final fromPlatform = await toDetails(4);
      fixtureHolder.value = false;
      await tester.pumpAndSettle();
      expect(heard(), isEmpty, reason: _stays);
      await tester.binding.handlePushRoute(membersScreen.$2);
      await tester.pumpAndSettle();
      if (fromPlatform.mounted) {
        expect(
          heard(),
          isEmpty,
          reason: 'A router that takes no locations from the platform stays '
              'where it is.',
        );
        fixtureHolder.value = true;
        await tester.pumpAndSettle();
        expect(
          heard(),
          isEmpty,
          reason: 'A condition that comes to hold leaves a page that does '
              'not ask for it as it is, with nothing that was asked for.',
        );
      } else {
        expectTargetOnTop(
          'A location from the platform of a route that asks for a '
          'condition that does not hold shows the target of the guard of '
          'the condition.',
        );
        fixtureHolder.value = true;
        await tester.pumpAndSettle();
        expect(
          heard(),
          [membersScreen],
          reason: 'Once the condition holds, the router shows the location '
              'that the platform asked for.',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
