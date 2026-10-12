// A test that continuous integration runs in the apps of the fixture
// modules with a router and a layout, whichever modules provide them, and
// with both fixture features: go() out of the main navigation, to the
// screen of the second fixture feature outside it, and back to a
// destination throws nothing, at whatever time the main navigation comes
// back. That is in the same turn, so that no frame shows the page outside,
// and while the transition to that page is on its way, when the page of
// the main navigation that left is still in the tree. Whether the branches
// keep their pages then is up to the router, as is whether the listeners
// of the screen hear of a page that no frame showed. It navigates only
// through the navigation facade of the router role, and uses what the
// tests of router_screens share, which every app that it applies to has.
// Each expectation gives its reason, which a provider of the role with a
// known bug fails the test with (brokenProviders of the fixture registry).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';
import 'package:{{app_name}}/features/fake_second/fixture_outside_screen.dart';

import 'screens.dart';

/// The start screen of the app, the destination of the fixture feature, as
/// the listeners of the screen hear of it.
const _start = ('fake_feature.home', '/fake_feature');

/// The page outside the main navigation of the second fixture feature, as
/// the listeners of the screen hear of it.
const _outside = ('fake_second.outside', '/fake_second/outside');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'go() out of the main navigation and back shows the destination without '
    'an error, in one turn and while the transition is on its way',
    (tester) async {
      await startApp(tester);
      expect(heard(), [_start], reason: 'The first screen is heard of once.');

      // Out of the main navigation, to the page outside it, and back to the
      // destination, in one turn: no frame shows the page outside.
      final home = tester.element(find.byType(FixtureHomeScreen));
      final out = home.nav.fakeSecond.outside();
      final back = home.nav.fakeFeature.home();
      out.go();
      back.go();
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'go() out of the main navigation and back in one turn leaves '
            'the router with one main navigation, which it shows without an '
            'error.',
      );
      expect(
        heard(),
        anyOf(isEmpty, equals([_outside, _start])),
        reason: 'After go() out of the main navigation and back in one turn, '
            'the user is on the destination that the last go() was asked '
            'for.',
      );
      expect(
        find.byType(FixtureHomeScreen),
        findsOneWidget,
        reason: 'After go() out of the main navigation and back in one turn, '
            'the user sees the destination that the last go() was asked for.',
      );

      // Out again, and back while the transition to the page outside is on
      // its way: the page of the main navigation that left is still in the
      // tree. A router that shows its pages without a transition has none on
      // its way, and the steps above showed all there is to it.
      tester
          .element(find.byType(FixtureHomeScreen))
          .nav
          .fakeSecond
          .outside()
          .go();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        heard(),
        [_outside],
        reason: 'go() to the page outside the main navigation is heard of '
            'once.',
      );
      if (!tester.binding.hasScheduledFrame) return;
      tester
          .element(find.byType(FixtureOutsideScreen))
          .nav
          .fakeFeature
          .home()
          .go();
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'go() back into the main navigation while the transition to '
            'the page that took its place is on its way leaves the router '
            'with one main navigation, which it shows without an error.',
      );
      expect(
        heard(),
        [_start],
        reason: 'After go() back into the main navigation while the '
            'transition to the page that took its place is on its way, the '
            'user is on the destination that go() was asked for.',
      );
      expect(
        find.byType(FixtureHomeScreen),
        findsOneWidget,
        reason: 'After go() back into the main navigation while the '
            'transition to the page that took its place is on its way, the '
            'user sees the destination that go() was asked for.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
