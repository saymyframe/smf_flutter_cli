// A test of what only go_router does, which continuous integration runs in
// the apps of the fixture modules with go_router: replace() of the
// navigation of the router role while go_router shows its error screen in
// place of the whole stack, for a location that no route matches and for
// one that the redirect of its route refuses. go_router has no page of a
// route then, and GoRouter.pushReplacement throws for want of a page to
// replace. So the router of the module gives go_router the location as
// go() does: it shows in place of the error screen, with the pages of its
// chain below it. A location outside the main navigation of an app with
// one is asked for in router_screens, under any router. It uses what the
// tests of router_screens share, which every app that it applies to has.
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:{{app_name}}/core/router/app_router.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_details_screen.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';

import 'screens.dart';

/// The start screen of the app, as the listeners of the screen hear of it.
const _startScreen = ('fake_feature.home', '/fake_feature');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
      'replace() on the error screen of go_router shows its location in '
      'place of that screen, as go() does', (tester) async {
    await startApp(tester);
    expect(heard(), [_startScreen]);
    final router = appRouter.config as GoRouter;
    // Any context navigates: the router of the app is not below it.
    final above = tester.binding.rootElement!;

    var id = 0;
    for (final unshown in ['/no/such/screen', '/fake_feature/details/abc']) {
      /// Shows the error screen of go_router for [unshown] in place of the
      /// stack.
      Future<void> toErrorScreen() async {
        router.go(unshown);
        await tester.pumpAndSettle();
        expect(heard(), [(null, unshown)]);
        expect(
          router.routerDelegate.currentConfiguration.matches,
          isEmpty,
          reason: 'On its error screen for $unshown, go_router has no page '
              'of a route. Otherwise the steps below test nothing.',
        );
      }

      /// Checks that go_router shows a location as go() to it does, with
      /// no page that a push showed.
      void expectShownAsGo() {
        expect(
          tester.takeException(),
          isNull,
          reason: 'replace() on the error screen for $unshown throws '
              'nothing.',
        );
        final shown = router.routerDelegate.currentConfiguration;
        expect(
          [shown.isError, ...shown.matches.whereType<ImperativeRouteMatch>()],
          [false],
          reason: 'replace() on the error screen for $unshown shows its '
              'location in place of that screen, as go() does.',
        );
      }

      // A route below the start route: its chain shows.
      await toErrorScreen();
      above.nav.fakeFeature.details(id: ++id).replace();
      await tester.pumpAndSettle();
      expectShownAsGo();
      expect(
        heard(),
        [('fake_feature.details', '/fake_feature/details/$id')],
        reason: 'The location that replace() shows from the error screen '
            'for $unshown is heard of once.',
      );
      expect(
        [
          find.byType(FixtureDetailsScreen).evaluate().length,
          find.byType(FixtureHomeScreen, skipOffstage: false).evaluate().length,
        ],
        [1, 1],
        reason: 'replace() on the error screen for $unshown shows its '
            'location as go() does: the chain of its route in place of the '
            'stack.',
      );

      // The start route.
      await toErrorScreen();
      above.nav.fakeFeature.home().replace();
      await tester.pumpAndSettle();
      expectShownAsGo();
      expect(
        heard(),
        [_startScreen],
        reason: 'The location that replace() shows from the error screen '
            'for $unshown is heard of once.',
      );
      expect(
        find.byType(FixtureHomeScreen),
        findsOneWidget,
        reason: 'replace() on the error screen for $unshown shows its '
            'location.',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
