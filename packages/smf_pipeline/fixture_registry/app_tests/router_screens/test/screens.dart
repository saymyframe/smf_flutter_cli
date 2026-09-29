// What the tests of the listeners of the screen share, in the apps of the
// fixture modules with a router: the listener of the fixture analytics
// notes each call in fixtureScreens, and the screens of the fixture
// features navigate with the navigation facade of the router role.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/fixture_analytics/fixture_analytics.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_details_screen.dart';

/// The screens that the listeners heard of since the last call: the full
/// name of the route of each, or `null`, and its location.
List<(String?, String)> heard() {
  final screens = [...fixtureScreens];
  fixtureScreens.clear();
  return screens;
}

/// The element, a context, of the details screen of the item [id] that
/// the user sees.
Element details(WidgetTester tester, int id) => tester.element(
      find.byWidgetPredicate(
        (widget) => widget is FixtureDetailsScreen && widget.id == id,
      ),
    );

/// Checks what the listeners heard of after a navigation that may leave
/// the page on top as it is, whose screen was [before]: nothing if the page
/// stays, once if another page is on top, even at the same location.
///
/// Whether a navigation keeps the page on top, such as `go()` to its
/// location, is up to the router. A page that stays keeps the element of
/// its screen, which a new page does not.
void expectHeardAtMostOnce(WidgetTester tester, Element before) {
  final screens = heard();
  final stays = before.mounted &&
      tester
          .elementList(find.byType(before.widget.runtimeType))
          .contains(before);
  if (stays) {
    expect(screens, isEmpty, reason: 'The page on top stayed.');
  } else {
    expect(screens, hasLength(1), reason: 'Another page is on top.');
  }
}
