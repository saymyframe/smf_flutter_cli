// A test that continuous integration runs in the apps of the fixture
// modules with a router, whichever module provides it: the router calls
// the listeners of the screen (RouterRole.screenListeners), here the
// listener of the fixture analytics, once for each change of the screen
// the user sees. It starts the app with main() of lib/main.dart, which the
// app entry role puts into every app, and navigates only through the
// navigation facade of the router role and the navigators of Flutter, so
// it applies to a new provider of the role as it is. What only one router
// does is tested in the app tests of that router.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';
import 'package:{{app_name}}/main.dart' as app;

import 'screens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets('each screen the user sees is heard of once', (tester) async {
    // The app starts as on a device, with what its main() puts around it,
    // on the start screen, whose location is its path.
    await app.main();
    await tester.pumpAndSettle();
    expect(heard(), [('fake_feature.home', '/fake_feature')]);

    // go() to a child shows only the child: its parent goes below it.
    tester
        .element(find.byType(FixtureHomeScreen))
        .nav
        .fakeFeature
        .details(id: 1)
        .go();
    await tester.pumpAndSettle();
    expect(heard(), [('fake_feature.details', '/fake_feature/details/1')]);

    // push() and the page below again when the pushed one closes, with the
    // value that push() completes with. The test does not wait for push(),
    // which could keep it waiting forever.
    Object? result;
    unawaited(
      details(tester, 1)
          .nav
          .fakeFeature
          .details(id: 2)
          .push<Object?>()
          .then((value) => result = value),
    );
    await tester.pumpAndSettle();
    expect(heard(), [('fake_feature.details', '/fake_feature/details/2')]);
    Navigator.of(details(tester, 2)).pop('closed');
    await tester.pumpAndSettle();
    expect(result, 'closed');
    expect(heard(), [('fake_feature.details', '/fake_feature/details/1')]);

    // replace() puts another page on top.
    details(tester, 1).nav.fakeFeature.details(id: 3).replace();
    await tester.pumpAndSettle();
    expect(heard(), [('fake_feature.details', '/fake_feature/details/3')]);

    // The same route with another value of its query parameter.
    details(tester, 3).nav.fakeFeature.details(id: 3, tab: 'b').go();
    await tester.pumpAndSettle();
    expect(heard(), [
      ('fake_feature.details', '/fake_feature/details/3?tab=b'),
    ]);

    // go() to the location on top: the router keeps the page, or shows a
    // new page at the same location.
    final shown = details(tester, 3);
    shown.nav.fakeFeature.details(id: 3, tab: 'b').go();
    await tester.pumpAndSettle();
    expectHeardAtMostOnce(tester, shown);

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
    expectHeardAtMostOnce(tester, below);
    unawaited(
      showDialog<void>(context: below, builder: (_) => const Text('dialog')),
    );
    await tester.pumpAndSettle();
    expect(heard(), isEmpty);
    Navigator.of(tester.element(find.text('dialog'))).pop();
    await tester.pumpAndSettle();
    expectHeardAtMostOnce(tester, below);

    // The back button of the system closes the child. Whether the location
    // of the parent keeps the query of the child is up to the router.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    final [(route, location)] = heard();
    expect(route, 'fake_feature.home');
    expect(Uri.parse(location).path, '/fake_feature');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
