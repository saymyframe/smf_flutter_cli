// A test that continuous integration runs in the apps of the fixture
// modules with a router, whichever module provides it, and the fixture
// gates: the router tells the guards of the routes of the router role of
// its pages when one of them starts or stops allowing, and shows what they
// answer, as RouterRole.guardedNavigation says. The app starts with its
// gates open. A notification of a guard that changes nothing leaves the
// stack as it is, and a push still completes with the value of its page.
// When the first gate closes, the target of its guard takes the place of
// the pages that the guard keeps the user from, those below the page on
// top too, and when it opens again, the router shows the location below
// the pages that pushes showed, with its query, as go() to it does. For a
// router that takes locations from the platform, the same holds while it
// shows a location that no route matches. Each expectation gives its
// reason, which a provider of the role with a known bug fails the test with
// (brokenProviders of the fixture registry).
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
    'a guard that stops allowing shows its target, and the location below '
    'the pushed pages once it allows again',
    (tester) async {
      await startApp(tester);
      expect(
        heard(),
        [startScreen],
        reason: 'With guards that allow, the app starts on its start screen.',
      );

      // A notification that changes nothing, with a pushed page on top of
      // a child, whose location has a query, and its parent.
      const child = ('fake_feature.details', '/fake_feature/details/1?tab=a');
      shown(tester, FixtureHomeScreen)
          .nav
          .fakeFeature
          .details(id: 1, tab: 'a')
          .go();
      await tester.pumpAndSettle();
      final result = pushed(details(tester, 1).nav.fakeFeature.details(id: 2));
      await tester.pumpAndSettle();
      expect(
        heard(),
        [
          child,
          ('fake_feature.details', '/fake_feature/details/2'),
        ],
        reason: 'With guards that allow, go() and push() show their '
            'locations.',
      );
      final onTop = details(tester, 2);
      fixtureGate.poke();
      fixtureSecondGate.poke();
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
        result(),
        'closed',
        reason: 'push() completes with the value of its page after a '
            'notification of a guard that changes nothing.',
      );
      expect(
        heard(),
        [child],
        reason: 'A notification of a guard that changes nothing leaves the '
            'stack as it is.',
      );

      // The gate closes with a pushed page on top: the target of its guard
      // takes the whole stack.
      pushed(details(tester, 1).nav.fakeFeature.details(id: 2));
      await tester.pumpAndSettle();
      expect(
        heard(),
        [('fake_feature.details', '/fake_feature/details/2')],
        reason: 'With guards that allow, push() shows its location.',
      );
      fixtureGate.value = false;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [gateScreen],
        reason: 'When a guard stops allowing, the router shows its target in '
            'place of the pages that it keeps the user from.',
      );
      expect(
        builtScreens(tester),
        [FixtureGateScreen],
        reason: 'When a guard stops allowing, no page that it keeps the user '
            'from stays in the stack.',
      );

      // The gate opens again: the router shows the location below the page
      // that the push showed, where the user opened that page from, with
      // its parent below it, and not the pushed page.
      fixtureGate.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [child],
        reason: 'Once a guard allows again, the router shows the location '
            'below the pages that pushes showed when it stopped allowing, '
            'with its query.',
      );
      expect(
        [
          for (final screen in tester.widgetList<FixtureDetailsScreen>(
            find.byType(FixtureDetailsScreen, skipOffstage: false),
          ))
            (screen.id, screen.tab),
        ],
        [(1, 'a')],
        reason: 'Once a guard allows again, the router shows the location '
            'below the pages that pushes showed when it stopped allowing, '
            'with its query.',
      );
      expect(
        builtScreens(tester),
        [FixtureHomeScreen, FixtureDetailsScreen],
        reason: 'The router shows the location that the user comes back to '
            'as go() to it does: with the chain of its parents below it.',
      );
      details(tester, 1).nav.fakeFeature.home().go();
      await tester.pumpAndSettle();
      expect(
        heard(),
        [startScreen],
        reason: 'With guards that allow, go() shows its location.',
      );

      // The target of the guard on top of another page, as a push shows
      // it, when the gate closes: the page on top stays, or comes anew, and
      // the page below it leaves the stack.
      pushed(shown(tester, FixtureHomeScreen).nav.fakeGate.gate());
      await tester.pumpAndSettle();
      expect(
        heard(),
        [gateScreen],
        reason: 'With guards that allow, the target of a guard is a route '
            'like any other.',
      );
      final gate = shown(tester, FixtureGateScreen);
      fixtureGate.value = false;
      await tester.pumpAndSettle();
      expectHeardAtMostOnce(
        tester,
        gate,
        gateScreen,
        reason: 'When a guard stops allowing a page below the one on top, '
            'its target stays the screen the user sees.',
      );
      expect(
        builtScreens(tester),
        [FixtureGateScreen],
        reason: 'When a guard stops allowing, no page that it keeps the user '
            'from stays in the stack, below the page on top either.',
      );
      fixtureGate.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [startScreen],
        reason: 'Once a guard allows again, the router shows the page that '
            'the guard took out of the stack.',
      );

      // A location from the platform that no route matches: a router that
      // takes locations from the platform shows its error screen, which is
      // a page like any other to the guards; another router stays where it
      // is.
      const unknown = (null, '/no/such/screen');
      final home = shown(tester, FixtureHomeScreen);
      await tester.binding.handlePushRoute(unknown.$2);
      await tester.pumpAndSettle();
      final onError = heard();
      if (onError.isEmpty) {
        expect(
          home.mounted,
          isTrue,
          reason: 'A router that takes no locations from the platform stays '
              'where it is.',
        );
        return;
      }
      expect(
        onError,
        [unknown],
        reason: 'A location that no route matches is heard of with no route.',
      );
      fixtureGate.value = false;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [gateScreen],
        reason: 'When a guard stops allowing while the router shows a '
            'location that no route matches, its target takes the place of '
            'that screen.',
      );
      expect(
        builtScreens(tester),
        [FixtureGateScreen],
        reason: 'When a guard stops allowing while the router shows a '
            'location that no route matches, its target takes the place of '
            'that screen.',
      );
      fixtureGate.value = true;
      await tester.pumpAndSettle();
      expect(
        heard(),
        [unknown],
        reason: 'Once a guard allows again, the router shows the location '
            'that no route matches again.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
