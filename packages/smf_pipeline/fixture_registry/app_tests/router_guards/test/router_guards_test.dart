// A test that continuous integration runs in the apps of the fixture
// modules with a router, whichever module provides it, and the fixture
// gates: the router asks the guards of the routes of the router role
// (RoutesData.guards) about every location before it shows it, as
// RouterRole.guardedNavigation says. The first gate is closed before the
// app starts, so its guard does not allow: the router shows its target in
// place of the location the app starts on, and of each location that go(),
// push() and replace() of the navigation of the role are asked to show,
// from the target and from another page of the flow of the guard, but for
// the routes of that flow. Once the gate opens, it shows the latest
// location that was asked for, with its query, whichever of go(),
// replace() and push() asked for it, and then forgets it. The test knows
// only the role and the fixtures, so it applies to a new provider of the
// role as it is. Each expectation gives its reason, which a provider of
// the role with a known bug fails the test with (brokenProviders of the
// fixture registry).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_details_screen.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gate_screens.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gates.dart';

import 'guards.dart';
import 'screens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'a guard that does not allow shows its target in place of every '
    'location outside its flow',
    (tester) async {
      /// Navigates with [navigate] from the target of the guard, which the
      /// user sees, and checks that the target stays the screen the user
      /// sees, as the only page: the router keeps its page, or shows it
      /// anew. A failure gives [reason].
      Future<void> staysOnTheTarget(
        Future<void> Function(BuildContext gate) navigate, {
        required String reason,
      }) async {
        final gate = shown(tester, FixtureGateScreen);
        await navigate(gate);
        await tester.pumpAndSettle();
        expectHeardAtMostOnce(tester, gate, gateScreen, reason: reason);
        expect(builtScreens(tester), [FixtureGateScreen], reason: reason);
      }

      /// Goes from the target of the guard to the route below it, a page of
      /// its flow that is not the target, and returns the context of its
      /// screen.
      Future<BuildContext> toTheStep() async {
        shown(tester, FixtureGateScreen).nav.fakeGate.step().go();
        await tester.pumpAndSettle();
        expect(
          heard(),
          [stepScreen],
          reason: 'A guard that does not allow lets the user go to the routes '
              'of its flow.',
        );
        expect(
          builtScreens(tester),
          [FixtureGateScreen, FixtureGateStepScreen],
          reason: 'go() to a route of the flow shows it with the target '
              'below it.',
        );
        return shown(tester, FixtureGateStepScreen);
      }

      // The first location: the app starts as on a device, with the gate
      // closed.
      fixtureGate.value = false;
      await startApp(tester);
      expect(
        heard(),
        [gateScreen],
        reason: 'The target of a guard that does not allow is heard of once, '
            'in place of the location that the app starts on.',
      );
      expect(
        builtScreens(tester),
        [FixtureGateScreen],
        reason: 'The router builds the screen of the target of the guard, and '
            'not that of the location that the guard keeps the user from.',
      );
      expect(
        pagesShown(),
        isNot(contains(startScreen.$1)),
        reason: 'The router shows no page of a location that a guard keeps '
            'the user from.',
      );

      // go(), push() and replace() of a location outside the flow of the
      // guard, from its target.
      await staysOnTheTarget(
        (gate) async => gate.nav.fakeFeature.details(id: 1).go(),
        reason: 'go() to a location that a guard keeps the user from shows '
            'the target of the guard.',
      );
      late Object? Function() result;
      await staysOnTheTarget(
        (gate) async => result = pushed(gate.nav.fakeFeature.details(id: 2)),
        reason: 'push() of a location that a guard keeps the user from shows '
            'the target of the guard.',
      );
      expect(
        result(),
        isNull,
        reason: 'push() of a location that a guard keeps the user from '
            'completes with null.',
      );
      await staysOnTheTarget(
        (gate) async => gate.nav.fakeFeature.details(id: 3).replace(),
        reason: 'replace() with a location that a guard keeps the user from '
            'shows the target of the guard.',
      );
      // A location from the platform, of a route and then of none: the
      // router asks the guards about it, or takes no locations from the
      // platform and stays where it is.
      for (final location in ['/fake_feature/details/4', '/no/such/screen']) {
        await staysOnTheTarget(
          (gate) => tester.binding.handlePushRoute(location),
          reason: 'A location from the platform that a guard keeps the user '
              'from shows the target of the guard.',
        );
      }
      expect(
        pagesShown(),
        isNot(contains('fake_feature.details')),
        reason: 'The router shows no page of a location that a guard keeps '
            'the user from.',
      );

      // The flow of the guard, its target and the routes below it: the
      // guard lets the user see them. A notification of the guards that
      // changes nothing leaves a page of the flow as it is, and its push
      // completes with the value of the page.
      final step = pushed(shown(tester, FixtureGateScreen).nav.fakeGate.step());
      await tester.pumpAndSettle();
      expect(
        heard(),
        [stepScreen],
        reason: 'A guard that does not allow lets the user see the routes of '
            'its flow.',
      );
      final onTop = shown(tester, FixtureGateStepScreen);
      fixtureGate.poke();
      await tester.pumpAndSettle();
      expect(
        heard(),
        isEmpty,
        reason: 'A notification of a guard that changes nothing is not heard '
            'of.',
      );
      expect(
        onTop.mounted,
        isTrue,
        reason: 'A notification of a guard that changes nothing leaves the '
            'page on top as it is.',
      );
      Navigator.of(onTop).pop('closed');
      await tester.pumpAndSettle();
      expect(
        step(),
        'closed',
        reason: 'push() completes with the value of its page after a '
            'notification of a guard that changes nothing.',
      );
      expect(
        heard(),
        [gateScreen],
        reason: 'The page below is heard of once when the pushed page of the '
            'flow closes.',
      );

      // From a page of the flow that is not the target, a location outside
      // the flow: the target takes the whole stack, as go() to it does, so
      // it is the only page, whichever of the three asks.
      var fromFlow = await toTheStep();
      fromFlow.nav.fakeFeature.details(id: 6).go();
      await tester.pumpAndSettle();
      expect(
        heard(),
        [gateScreen],
        reason: 'go() to a location that a guard keeps the user from shows '
            'the target of the guard alone, from a page of its flow too.',
      );
      expect(
        builtScreens(tester),
        [FixtureGateScreen],
        reason: 'go() to a location that a guard keeps the user from shows '
            'the target of the guard alone, from a page of its flow too.',
      );
      fromFlow = await toTheStep();
      fromFlow.nav.fakeFeature.details(id: 7).replace();
      await tester.pumpAndSettle();
      expect(
        heard(),
        [gateScreen],
        reason: 'replace() with a location that a guard keeps the user from '
            'shows the target of the guard alone, from a page of its flow '
            'too.',
      );
      expect(
        builtScreens(tester),
        [FixtureGateScreen],
        reason: 'replace() with a location that a guard keeps the user from '
            'shows the target of the guard alone, from a page of its flow '
            'too.',
      );
      // A location from the platform: the router shows the target alone,
      // or takes no locations from the platform and stays on the page of
      // the flow.
      fromFlow = await toTheStep();
      await tester.binding.handlePushRoute('/fake_feature/details/8');
      await tester.pumpAndSettle();
      if (fromFlow.mounted) {
        expect(
          heard(),
          isEmpty,
          reason: 'A router that takes no locations from the platform stays '
              'where it is.',
        );
        expect(
          builtScreens(tester),
          [FixtureGateScreen, FixtureGateStepScreen],
          reason: 'A router that takes no locations from the platform stays '
              'where it is.',
        );
      } else {
        expect(
          heard(),
          [gateScreen],
          reason: 'A location from the platform that a guard keeps the user '
              'from shows the target of the guard alone, from a page of its '
              'flow too.',
        );
        expect(
          builtScreens(tester),
          [FixtureGateScreen],
          reason: 'A location from the platform that a guard keeps the user '
              'from shows the target of the guard alone, from a page of its '
              'flow too.',
        );
        fromFlow = await toTheStep();
      }
      final last = pushed(fromFlow.nav.fakeFeature.details(id: 9));
      await tester.pumpAndSettle();
      expect(
        last(),
        isNull,
        reason: 'push() of a location that a guard keeps the user from '
            'completes with null.',
      );
      expect(
        heard(),
        [gateScreen],
        reason: 'The target of a guard is heard of once when it takes the '
            'place of a page of its flow.',
      );
      expect(
        builtScreens(tester),
        [FixtureGateScreen],
        reason: 'push() of a location that a guard keeps the user from shows '
            'the target of the guard alone, from a page of its flow too.',
      );

      // The latest location that is asked for, with a query, by go(), then
      // by replace() and then by push(). Each time the gate opens, the
      // router shows that location, as go() to it does, and not the
      // location that the app starts on or another of those asked for
      // before; and when the gate closes again, the target of the guard
      // takes its place.
      final asks = <(int, String, void Function(NavLink link))>[
        (5, 'a', (link) => link.go()),
        (6, 'b', (link) => link.replace()),
        (7, 'c', pushed),
      ];
      for (final (id, tab, ask) in asks) {
        await staysOnTheTarget(
          (gate) async => ask(gate.nav.fakeFeature.details(id: id, tab: tab)),
          reason: 'A location that a guard keeps the user from shows the '
              'target of the guard.',
        );
        fixtureGate.value = true;
        await tester.pumpAndSettle();
        expect(
          heard(),
          [('fake_feature.details', '/fake_feature/details/$id?tab=$tab')],
          reason: 'Once the guards allow, the router shows the latest location '
              'that was asked for and that a guard kept the user from, with '
              'its query.',
        );
        expect(
          builtScreens(tester),
          [FixtureHomeScreen, FixtureDetailsScreen],
          reason: 'The router shows the location that the guards kept the user '
              'from as go() to it does, in place of the target of the guard.',
        );
        expect(
          tester
              .widget<FixtureDetailsScreen>(find.byType(FixtureDetailsScreen))
              .tab,
          tab,
          reason: 'The location that the guards kept the user from comes back '
              'with its query.',
        );
        if (id == asks.last.$1) break;
        fixtureGate.value = false;
        await tester.pumpAndSettle();
        expect(
          heard(),
          [gateScreen],
          reason: 'When a guard stops allowing, the router shows its target in '
              'place of the pages that it keeps the user from.',
        );
      }

      // That location is forgotten: from another screen, a notification of
      // the guards does not bring it back.
      shown(tester, FixtureDetailsScreen).nav.fakeFeature.home().go();
      await tester.pumpAndSettle();
      expect(
        heard(),
        [startScreen],
        reason: 'Once the guards allow, go() shows its location.',
      );
      fixtureGate.poke();
      await tester.pumpAndSettle();
      expect(
        heard(),
        isEmpty,
        reason: 'The location that the guards kept the user from is '
            'forgotten once the router has shown it.',
      );
      expect(
        builtScreens(tester),
        [FixtureHomeScreen],
        reason: 'The location that the guards kept the user from is '
            'forgotten once the router has shown it.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
