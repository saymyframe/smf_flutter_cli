// A test that continuous integration runs in the apps of the fixture
// modules with a router, whichever module provides it, and with two
// listeners of the screen, those of the fixture analytics and of the
// fixture screen log: the router calls each listener of the screen
// (RouterRole.screenListeners) on its own, so a listener that throws keeps
// no other listener from hearing the screen, and what it throws reaches no
// handler of the errors of Flutter. Both listeners throw once they noted
// the screen, so the test fails whichever of them the router calls first
// when one that throws stops the others. It uses what the tests of
// router_screens share, which every app that it applies to has. Each
// expectation gives its reason, which a provider of the role with a known
// bug fails the test with (brokenProviders of the fixture registry).
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/fixture_analytics/fixture_analytics.dart';
import 'package:{{app_name}}/core/fixture_screen_log/fixture_screen_log.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';

import 'screens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
      'a listener of the screen that throws keeps no other from hearing it',
      (tester) async {
    await startApp(tester);
    const home = ('fake_feature.home', '/fake_feature');
    expect(
      [fixtureScreens, fixtureScreenLog],
      [
        [home],
        [home],
      ],
      reason: 'Every listener hears of the first screen once.',
    );

    // Both listeners throw once they noted the screen. What reaches the
    // handler of the errors of Flutter meanwhile goes into errors, so that
    // it fails no expectation before the test looks at it.
    final errors = <Object>[];
    final onError = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.exception);
    fixtureScreensThrow = true;
    fixtureScreenLogThrows = true;
    try {
      tester
          .element(find.byType(FixtureHomeScreen))
          .nav
          .fakeFeature
          .details(id: 1)
          .go();
      await tester.pumpAndSettle();
    } finally {
      FlutterError.onError = onError;
      fixtureScreensThrow = false;
      fixtureScreenLogThrows = false;
    }
    const first = ('fake_feature.details', '/fake_feature/details/1');
    expect(
      [fixtureScreens, fixtureScreenLog],
      [
        [home, first],
        [home, first],
      ],
      reason: 'A listener of the screen that throws keeps no other from '
          'hearing it.',
    );
    expect(
      errors,
      isEmpty,
      reason: 'What a listener of the screen throws reaches no handler of the '
          'errors of Flutter.',
    );

    // The listeners hear of the next screen as before.
    details(tester, 1).nav.fakeFeature.details(id: 2).go();
    await tester.pumpAndSettle();
    const next = ('fake_feature.details', '/fake_feature/details/2');
    expect(
      [fixtureScreens, fixtureScreenLog],
      [
        [home, first, next],
        [home, first, next],
      ],
      reason: 'Every listener hears of the next screen once.',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
