// A test that continuous integration runs in the apps of the fixture
// modules with go_router and bottom tabs: the router calls the listeners of
// the screen, here the listener of the fixture analytics, which notes each
// call in fixtureScreens, once for each screen the user sees.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:{{app_name}}/core/fixture_analytics/fixture_analytics.dart';
import 'package:{{app_name}}/core/router/app_router.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_details_screen.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';
import 'package:{{app_name}}/main.dart' as app;

/// The screens that the listener heard of since the last call.
List<(String?, String)> _heard() {
  final screens = [...fixtureScreens];
  fixtureScreens.clear();
  return screens;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets('each screen the user sees is heard of once', (tester) async {
    BuildContext details(int id) => tester.element(
          find.byWidgetPredicate(
            (widget) => widget is FixtureDetailsScreen && widget.id == id,
          ),
        );

    // The app starts as on a device, with what its main() puts around it.
    await app.main();
    await tester.pumpAndSettle();
    expect(_heard(), [('fake_feature.home', '/fake_feature')]);

    // go() to a child shows only the child: its parent goes below it.
    tester
        .element(find.byType(FixtureHomeScreen))
        .nav
        .fakeFeature
        .details(id: 1)
        .go();
    await tester.pumpAndSettle();
    expect(_heard(), [('fake_feature.details', '/fake_feature/details/1')]);

    // Another tab, the tab of before again, which keeps its page, and the
    // tab that is selected.
    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle();
    expect(_heard(), [('fake_second.second', '/fake_second')]);
    await tester.tap(find.text('Fixture'));
    await tester.pumpAndSettle();
    expect(_heard(), [('fake_feature.details', '/fake_feature/details/1')]);
    await tester.tap(find.text('Fixture'));
    await tester.pumpAndSettle();
    expect(_heard(), isEmpty);

    // push() and the page below again when the pushed one closes. The test
    // does not wait for push(), which could keep it waiting forever.
    Object? result;
    unawaited(
      details(1)
          .nav
          .fakeFeature
          .details(id: 2)
          .push<Object?>()
          .then((value) => result = value),
    );
    await tester.pumpAndSettle();
    expect(_heard(), [('fake_feature.details', '/fake_feature/details/2')]);
    Navigator.of(details(2)).pop('closed');
    await tester.pumpAndSettle();
    expect(result, 'closed');
    expect(_heard(), [('fake_feature.details', '/fake_feature/details/1')]);

    // The same route with another value of its query parameter.
    details(1).nav.fakeFeature.details(id: 1, tab: 'b').go();
    await tester.pumpAndSettle();
    expect(_heard(), [
      ('fake_feature.details', '/fake_feature/details/1?tab=b'),
    ]);

    // A refresh of the routes shows the same page.
    (appRouter.config as GoRouter).refresh();
    await tester.pumpAndSettle();
    expect(_heard(), isEmpty);

    // The back button of the system closes the child. Whether the location
    // of the parent keeps the query of the child is up to go_router.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    final [(route, location)] = _heard();
    expect(route, 'fake_feature.home');
    expect(Uri.parse(location).path, '/fake_feature');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
