// A test of what only go_router does, which continuous integration runs in
// the apps of the fixture modules with go_router: the back button of the
// system on its error screen, for the locations that only GoRouter can be
// asked for, since the navigation of the router role has a location only
// for a route. For a location that GoRouter.go cannot show, go_router shows
// its error screen in place of the whole stack, with no page of a route,
// and its delegate throws when it is asked to close the route on top then
// (https://github.com/flutter/flutter/issues/187616). So the router of the
// module asks the root navigator there: with no route to close, the button
// is left to the system. An error screen that GoRouter.push shows over a
// page is a page of go_router, which the button closes. And a
// BackButtonListener below the router hears of the button before the
// router does, on the error screen too. The router has a dispatcher of the
// button of its own for this, which wraps the callback of the Router of
// Flutter: when the root of the app is mounted anew over the same router,
// the dispatcher lets the Router that leaves take its callback back, so the
// button asks the router once. The back button after a location from the
// platform that a router cannot show is tested in router_screens, under
// any router. It uses what the tests of router_screens share, which every
// app that it applies to has.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:{{app_name}}/core/router/app_router.dart';

import 'screens.dart';

/// The start screen of the app, as the listeners of the screen hear of it.
const _startScreen = ('fake_feature.home', '/fake_feature');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
      'the back button of the system throws nothing on the error screen, and '
      'closes one that a push showed', (tester) async {
    await startApp(tester);
    expect(heard(), [_startScreen]);
    final router = appRouter.config as GoRouter;

    // An error screen that a push showed over the start screen is a page
    // of go_router: the button closes it, and its push completes. The test
    // does not wait for push(), which could keep it waiting forever.
    Object? pushed = 'not completed';
    unawaited(
      router.push<Object?>('/no/such/screen').then((value) => pushed = value),
    );
    await tester.pumpAndSettle();
    expect(heard(), [(null, '/no/such/screen')]);
    expect(
      await tester.binding.handlePopRoute(),
      isTrue,
      reason: 'The back button of the system closes an error screen that a '
          'push showed over a page.',
    );
    await tester.pumpAndSettle();
    expect(heard(), [_startScreen]);
    expect(
      pushed,
      isNull,
      reason: 'The push of an error screen completes when the back button '
          'of the system closes it.',
    );

    // An error screen in place of the whole stack: for a location that no
    // route matches, and for one that the redirect of its route refuses,
    // the id that the route requires being no number.
    for (final location in ['/no/such/screen', '/fake_feature/details/abc']) {
      router.go(location);
      await tester.pumpAndSettle();
      expect(heard(), [(null, location)]);
      expect(
        router.routerDelegate.currentConfiguration.matches,
        isEmpty,
        reason: 'On its error screen for $location, go_router has no page '
            'of a route. Otherwise the steps below test nothing.',
      );
      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'The back button of the system throws nothing on the error '
            'screen for $location.',
      );
      expect(
        handled,
        isFalse,
        reason: 'With no route to close on the error screen for $location, '
            'the router leaves the back button of the system to the system.',
      );
      expect(
        heard(),
        isEmpty,
        reason: 'The error screen for $location stays when the back button '
            'of the system has no route to close.',
      );
      router.go(_startScreen.$2);
      await tester.pumpAndSettle();
      expect(heard(), [_startScreen]);
    }

    // A BackButtonListener in a route over the error screen: it hears of
    // the button first and answers that it handled it, so the route stays.
    router.go('/no/such/screen');
    await tester.pumpAndSettle();
    expect(heard(), [(null, '/no/such/screen')]);
    var pressed = 0;
    unawaited(
      router.routerDelegate.navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => BackButtonListener(
            onBackButtonPressed: () async {
              pressed++;
              return true;
            },
            child: const Text('listener'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      await tester.binding.handlePopRoute(),
      isTrue,
      reason: 'A BackButtonListener over the error screen handles the back '
          'button of the system.',
    );
    await tester.pumpAndSettle();
    expect(
      pressed,
      1,
      reason: 'A BackButtonListener over the error screen hears of the back '
          'button of the system once, before the router.',
    );
    expect(
      find.text('listener'),
      findsOneWidget,
      reason: 'The route of a BackButtonListener that handled the back '
          'button of the system stays over the error screen.',
    );
    expect(tester.takeException(), isNull);

    // The root of the app mounted anew over the same router, as when a
    // widget above it is replaced: the Router of Flutter that leaves takes
    // its callback back from the dispatcher of the button, and the new one
    // gives its own. So the button asks the router once, and closes a
    // dialog over the start screen.
    router.go(_startScreen.$2);
    await tester.pumpAndSettle();
    expect(heard(), [_startScreen]);
    final app = tester.widget<View>(find.byType(View)).child;
    await tester.pumpWidget(KeyedSubtree(key: UniqueKey(), child: app));
    await tester.pumpAndSettle();
    expect(
      heard(),
      isEmpty,
      reason: 'The start screen stays the screen of the router when the root '
          'of the app is mounted anew.',
    );
    unawaited(
      showDialog<void>(
        context:
            router.routerDelegate.navigatorKey.currentState!.overlay!.context,
        builder: (_) => const Text('dialog'),
      ),
    );
    await tester.pumpAndSettle();
    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'The back button of the system throws nothing once the root of '
          'the app is mounted anew over the router.',
    );
    expect(
      handled,
      isTrue,
      reason: 'The back button of the system still reaches the router once '
          'the root of the app is mounted anew, and the router handles it.',
    );
    expect(
      find.text('dialog'),
      findsNothing,
      reason: 'The back button of the system closes a dialog once the root '
          'of the app is mounted anew over the router.',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
