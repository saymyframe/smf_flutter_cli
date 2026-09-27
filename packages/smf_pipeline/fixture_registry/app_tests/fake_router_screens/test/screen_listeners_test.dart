// A test that continuous integration runs in the apps of the fixture
// modules with the fixture router: it calls the listeners of the screen,
// here the listener of the fixture analytics, which notes each call in
// fixtureScreens, once for each page that comes on top. It has no main
// navigation, and a location object that it has not shown makes a new
// page, even when it equals the one on top.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/fixture_analytics/fixture_analytics.dart';
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

  testWidgets('each page on top is heard of once', (tester) async {
    BuildContext details(int id) => tester.element(
          find.byWidgetPredicate(
            (widget) => widget is FixtureDetailsScreen && widget.id == id,
          ),
        );

    // The app starts as on a device, with what its main() puts around it.
    await app.main();
    await tester.pumpAndSettle();
    expect(_heard(), [('fake_feature.home', '/fake_feature')]);

    // go() to a child shows only the child.
    tester
        .element(find.byType(FixtureHomeScreen))
        .nav
        .fakeFeature
        .details(id: 1)
        .go();
    await tester.pumpAndSettle();
    expect(_heard(), [('fake_feature.details', '/fake_feature/details/1')]);

    // push() and the page below again when the pushed one closes.
    final pushed = details(1).nav.fakeFeature.details(id: 2).push<Object?>();
    await tester.pumpAndSettle();
    expect(_heard(), [('fake_feature.details', '/fake_feature/details/2')]);
    Navigator.of(details(2)).pop();
    await tester.pumpAndSettle();
    await pushed;
    expect(_heard(), [('fake_feature.details', '/fake_feature/details/1')]);

    // The same route with another value of its query parameter.
    details(1).nav.fakeFeature.details(id: 1, tab: 'b').go();
    await tester.pumpAndSettle();
    expect(_heard(), [
      ('fake_feature.details', '/fake_feature/details/1?tab=b'),
    ]);

    // A new location object equal to the one on top is a new page.
    details(1).nav.fakeFeature.details(id: 1, tab: 'b').go();
    await tester.pumpAndSettle();
    expect(_heard(), [
      ('fake_feature.details', '/fake_feature/details/1?tab=b'),
    ]);

    // The constant location on top, shown again, is the same page.
    details(1).nav.fakeFeature.home().go();
    await tester.pumpAndSettle();
    expect(_heard(), [('fake_feature.home', '/fake_feature')]);
    tester.element(find.byType(FixtureHomeScreen)).nav.fakeFeature.home().go();
    await tester.pumpAndSettle();
    expect(_heard(), isEmpty);
  });
}
