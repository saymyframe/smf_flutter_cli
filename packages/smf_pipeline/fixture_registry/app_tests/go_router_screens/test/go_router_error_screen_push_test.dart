// A test of what only go_router does, which continuous integration runs in
// the apps of the fixture modules with go_router: push() of the navigation
// of the router role while go_router shows its error screen in place of
// the whole stack, for a location that no route matches and for one that
// the redirect of its route refuses. go_router has no page of a route
// then, and GoRouter.push has none to push over: it keeps the error screen
// and never completes for a location outside the main navigation, of which
// the listeners of the screen would hear though nothing shows it, and it
// throws for a location in the main navigation. So the router of the
// module gives go_router the location as go() does: it shows in place of
// the error screen, with the pages of its chain below it, and the push
// completes with null at once. An error screen that a push showed over a
// page is a page of go_router, which pushes over it like over any other.
// The test asks for the routes of the fixture feature, which are in the
// main navigation of an app with one. A location outside the main
// navigation of such an app is asked for in router_screens, under any
// router. It uses what the tests of router_screens share, which every app
// that it applies to has.
import 'dart:async';

import 'package:flutter/widgets.dart';
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
      'push() on the error screen of go_router shows its location in place '
      'of that screen, as go() does, and completes with null', (tester) async {
    await startApp(tester);
    expect(heard(), [_startScreen]);
    final router = appRouter.config as GoRouter;
    // Any context navigates: the router of the app is not below it.
    final above = tester.binding.rootElement!;

    // An error screen that a push showed over a page is a page of
    // go_router: push() shows its location over it, and completes with the
    // value of its page. In an app with a main navigation, the routes of
    // the fixture feature are in it, and no router pushes one of them from
    // a page over the main navigation, so the step is for an app without
    // one.
    if (router.routerDelegate.currentConfiguration.matches.first
        is! ShellRouteMatch) {
      unawaited(router.push<Object?>('/no/such/screen'));
      await tester.pumpAndSettle();
      expect(heard(), [(null, '/no/such/screen')]);
      Object? over = 'not completed';
      unawaited(
        above.nav.fakeFeature
            .details(id: 9)
            .push<Object?>()
            .then((value) => over = value),
      );
      await tester.pumpAndSettle();
      expect(
        heard(),
        [('fake_feature.details', '/fake_feature/details/9')],
        reason: 'push() shows its location over an error screen that a push '
            'showed over a page.',
      );
      expect(
        over,
        'not completed',
        reason: 'push() over an error screen that a push showed over a page '
            'waits for the value of its page, as over any other page.',
      );
      Navigator.of(tester.element(find.byType(FixtureDetailsScreen)))
          .pop('closed');
      await tester.pumpAndSettle();
      expect(
        over,
        'closed',
        reason: 'push() over an error screen that a push showed over a page '
            'completes with the value of its page.',
      );
      expect(
        heard(),
        [(null, '/no/such/screen')],
        reason: 'The error screen that a push showed over a page is below '
            'the page that push() showed over it.',
      );
      router.go(_startScreen.$2);
      await tester.pumpAndSettle();
      expect(heard(), [_startScreen]);
    }

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
      /// no page that a push showed, and that the push of [result]
      /// completed with null.
      void expectShownAsGo(Object? result) {
        expect(
          tester.takeException(),
          isNull,
          reason: 'push() on the error screen for $unshown throws nothing.',
        );
        expect(
          result,
          isNull,
          reason: 'On its error screen for $unshown, go_router has no page '
              'to push over: push() gives it the location as go() does, and '
              'completes with null.',
        );
        final shown = router.routerDelegate.currentConfiguration;
        expect(
          [shown.isError, ...shown.matches.whereType<ImperativeRouteMatch>()],
          [false],
          reason: 'push() on the error screen for $unshown shows its '
              'location in place of that screen, as go() does, and not as '
              'a page over it.',
        );
      }

      // A route below the start route: its chain shows.
      await toErrorScreen();
      Object? pushed = 'not completed';
      unawaited(
        above.nav.fakeFeature
            .details(id: ++id)
            .push<Object?>()
            .then((value) => pushed = value),
      );
      await tester.pumpAndSettle();
      expectShownAsGo(pushed);
      expect(
        heard(),
        [('fake_feature.details', '/fake_feature/details/$id')],
        reason: 'The location that push() shows from the error screen for '
            '$unshown is heard of once.',
      );
      expect(
        [
          find.byType(FixtureDetailsScreen).evaluate().length,
          find.byType(FixtureHomeScreen, skipOffstage: false).evaluate().length,
        ],
        [1, 1],
        reason: 'push() on the error screen for $unshown shows its location '
            'as go() does: the chain of its route in place of the stack.',
      );
      expect(
        await tester.binding.handlePopRoute(),
        isTrue,
        reason: 'The back button of the system closes the page that push() '
            'showed from the error screen for $unshown, over the page of '
            'its parent.',
      );
      await tester.pumpAndSettle();
      expect(heard(), [isA<(String?, String)>()]);

      // The start route.
      await toErrorScreen();
      pushed = 'not completed';
      unawaited(
        above.nav.fakeFeature
            .home()
            .push<Object?>()
            .then((value) => pushed = value),
      );
      await tester.pumpAndSettle();
      expectShownAsGo(pushed);
      expect(
        heard(),
        [_startScreen],
        reason: 'The location that push() shows from the error screen for '
            '$unshown is heard of once.',
      );
      expect(
        find.byType(FixtureHomeScreen),
        findsOneWidget,
        reason: 'push() on the error screen for $unshown shows its location.',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
