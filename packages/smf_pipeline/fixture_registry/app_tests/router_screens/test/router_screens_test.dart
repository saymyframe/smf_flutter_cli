// A test that continuous integration runs in the apps of the fixture
// modules with a router, whichever module provides it: the router calls
// the listeners of the screen (RouterRole.screenListeners), here the
// listener of the fixture analytics, once for each change of the screen
// the user sees, gives each navigator observers of its own
// (RouterRole.observers), and closes the route on top with the back button
// of the system. It starts the app with main() of lib/main.dart, which the
// app entry role puts into every app, and navigates only through the
// navigation facade of the router role and the navigators of Flutter, so
// it applies to a new provider of the role as it is. What only one router
// does is tested in the app tests about that router, such as
// go_router_screens.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';

import 'screens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets('each screen the user sees is heard of once', (tester) async {
    // The app starts as on a device, on the start screen, whose location is
    // its path.
    await startApp(tester);
    expect(heard(), [('fake_feature.home', '/fake_feature')]);

    // go() to the location on top: the router keeps the page, or shows a
    // new page at the same location.
    final home = tester.element(find.byType(FixtureHomeScreen));
    home.nav.fakeFeature.home().go();
    await tester.pumpAndSettle();
    expectHeardAtMostOnce(tester, home, ('fake_feature.home', '/fake_feature'));

    // go() to a child shows only the child: its parent goes below it.
    tester
        .element(find.byType(FixtureHomeScreen))
        .nav
        .fakeFeature
        .details(id: 1)
        .go();
    await tester.pumpAndSettle();
    expect(heard(), [('fake_feature.details', '/fake_feature/details/1')]);

    // The page on top shows another location: the same route with another
    // value of its query parameter, then of its path parameter, whether
    // the router keeps the page or shows a new one.
    details(tester, 1).nav.fakeFeature.details(id: 1, tab: 'b').go();
    await tester.pumpAndSettle();
    expect(heard(), [
      ('fake_feature.details', '/fake_feature/details/1?tab=b'),
    ]);
    details(tester, 1).nav.fakeFeature.details(id: 4).go();
    await tester.pumpAndSettle();
    expect(heard(), [('fake_feature.details', '/fake_feature/details/4')]);

    // push() and the page below again when the pushed one closes, with the
    // value that push() completes with. The test does not wait for push(),
    // which could keep it waiting forever. The observer of the navigator
    // of the pushed page sees it come, under the full name of its route,
    // and each navigator has an observer of its own.
    Object? result;
    unawaited(
      details(tester, 4)
          .nav
          .fakeFeature
          .details(id: 2)
          .push<Object?>()
          .then((value) => result = value),
    );
    await tester.pumpAndSettle();
    expect(heard(), [('fake_feature.details', '/fake_feature/details/2')]);
    expect(
      observerOf(Navigator.of(details(tester, 2))).pushed.last,
      'fake_feature.details',
    );
    expectObserverOfEachNavigator(tester);
    Navigator.of(details(tester, 2)).pop('closed');
    await tester.pumpAndSettle();
    expect(result, 'closed');
    expect(heard(), [('fake_feature.details', '/fake_feature/details/4')]);

    // replace() puts another page on top.
    details(tester, 4).nav.fakeFeature.details(id: 3).replace();
    await tester.pumpAndSettle();
    expect(heard(), [('fake_feature.details', '/fake_feature/details/3')]);

    // go() to another location from the page that replace() put on top.
    details(tester, 3).nav.fakeFeature.details(id: 3, tab: 'b').go();
    await tester.pumpAndSettle();
    expect(heard(), [
      ('fake_feature.details', '/fake_feature/details/3?tab=b'),
    ]);

    // go() to the location on top: the router keeps the page, or shows a
    // new page at the same location.
    const onTop = ('fake_feature.details', '/fake_feature/details/3?tab=b');
    final shown = details(tester, 3);
    shown.nav.fakeFeature.details(id: 3, tab: 'b').go();
    await tester.pumpAndSettle();
    expectHeardAtMostOnce(tester, shown, onTop);

    // A page shown past the router and a dialog are not pages of the
    // router: the page below stays the screen of the router.
    final below = details(tester, 3);
    unawaited(
      Navigator.of(below).push(
        MaterialPageRoute<void>(builder: (_) => const Text('past')),
      ),
    );
    await tester.pumpAndSettle();
    expect(heard(), isEmpty);
    Navigator.of(tester.element(find.text('past'))).pop();
    await tester.pumpAndSettle();
    expectHeardAtMostOnce(tester, below, onTop);
    unawaited(
      showDialog<void>(context: below, builder: (_) => const Text('dialog')),
    );
    await tester.pumpAndSettle();
    expect(heard(), isEmpty);
    Navigator.of(tester.element(find.text('dialog'))).pop();
    await tester.pumpAndSettle();
    expectHeardAtMostOnce(tester, below, onTop);

    // The back button of the system closes the route on top of the
    // innermost navigator that the user sees: a dialog before the page
    // below it, which stays on top, so the listeners hear of nothing.
    unawaited(
      showDialog<void>(context: below, builder: (_) => const Text('dialog')),
    );
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(heard(), isEmpty);
    expect(find.text('dialog'), findsNothing);
    expect(below.mounted, isTrue, reason: 'The page below the dialog stays.');

    // The back button of the system closes the child. Whether the location
    // of the parent keeps the query of the child is up to the router.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(heard(), [
      isA<(String?, String)>()
          .having((screen) => screen.$1, 'route', 'fake_feature.home')
          .having(
            (screen) => Uri.parse(screen.$2).path,
            'path of the location',
            '/fake_feature',
          ),
    ]);

    // A location from the platform that no route matches: the router shows
    // its error screen at that location, or takes no locations from the
    // platform and stays where it is.
    await tester.binding.handlePushRoute('/no/such/screen?x=1');
    await tester.pumpAndSettle();
    expect(heard(), anyOf(isEmpty, [(null, '/no/such/screen?x=1')]));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
