// What the tests of the listeners of the screen share, in the apps of the
// fixture modules with a router: the app starts with main() of
// lib/main.dart, which the app entry role puts into every app, the
// listener of the fixture analytics notes each call in fixtureScreens, its
// navigator observers note the routes that come on their navigators, and
// the screens of the fixture features navigate with the navigation facade
// of the router role.
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/fixture_analytics/fixture_analytics.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_details_screen.dart';
import 'package:{{app_name}}/main.dart' as app;

/// Starts the app as on a device, with what its main() puts around it, and
/// waits for its first screen.
///
/// main() runs in real time, so a start-up that waits for a timer or for
/// input and output, as that of a module may, does not keep the fake time
/// of the test waiting forever. An error of main() fails the test, which
/// tester.runAsync would only report to the handler of the errors of
/// Flutter. The handlers of errors that the start-up installs, such as
/// those of crash reporting, and the builder of the widget of an error go
/// back to those of the test once main() returns, so that flutter_test
/// reports the errors of the frames that follow, and an expectation that
/// fails, as in any test.
Future<void> startApp(WidgetTester tester) async {
  final onError = FlutterError.onError;
  final onPlatformError = PlatformDispatcher.instance.onError;
  final errorWidgetBuilder = ErrorWidget.builder;
  Object? error;
  StackTrace? stackTrace;
  try {
    await tester.runAsync(() async {
      try {
        await app.main();
      } on Object catch (thrown, stack) {
        error = thrown;
        stackTrace = stack;
      }
    });
  } finally {
    FlutterError.onError = onError;
    PlatformDispatcher.instance.onError = onPlatformError;
    ErrorWidget.builder = errorWidgetBuilder;
  }
  if (error != null) fail('main() threw $error\n$stackTrace');
  await tester.pumpAndSettle();
}

/// The lists in which other listeners of the screen note the screens they
/// hear of, as the listener of the fixture analytics does in
/// fixtureScreens: [heard] checks that each heard of the same screens.
final List<List<(String?, String)>> otherListeners = [];

/// The screens that the listeners heard of since the last call: the full
/// name of the route of each, or `null`, and its location. Every listener
/// of [otherListeners] heard of the same screens, in the same order.
List<(String?, String)> heard() {
  final screens = [...fixtureScreens];
  fixtureScreens.clear();
  for (final other in otherListeners) {
    expect(other, screens, reason: 'Every listener hears of each screen.');
    other.clear();
  }
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
/// stays, and [screen], the name of the route and the location of the page
/// on top, once if another page is on top, even at the same location. A
/// failure gives [reason], the step of the test, and which of the two it
/// expected.
///
/// Whether a navigation keeps the page on top, such as `go()` to its
/// location, is up to the router. A page that stays keeps the element of
/// its screen, which a new page does not.
void expectHeardAtMostOnce(
  WidgetTester tester,
  Element before,
  (String?, String) screen, {
  required String reason,
}) {
  final screens = heard();
  final stays = before.mounted &&
      tester
          .elementList(find.byType(before.widget.runtimeType))
          .contains(before);
  if (stays) {
    expect(
      screens,
      isEmpty,
      reason: '$reason The page on top stayed, so the listeners hear of '
          'nothing.',
    );
  } else {
    expect(
      screens,
      [screen],
      reason: '$reason Another page is on top, so the listeners hear of it '
          'once.',
    );
  }
}

/// The observer that the router created for [navigator] with the factory
/// of the fixture analytics; checks that [navigator] has one of its own,
/// which watches it.
FixtureObserver observerOf(NavigatorState navigator) {
  final observers = navigator.widget.observers.whereType<FixtureObserver>();
  expect(
    observers,
    hasLength(1),
    reason: 'The router calls each factory of observers for each navigator.',
  );
  expect(
    observers.single.navigator,
    same(navigator),
    reason: 'The observer of a navigator watches that navigator.',
  );
  return observers.single;
}

/// Checks that each navigator of the app, the navigators of the branches of
/// the main navigation that were shown included, has an observer of its own
/// from the factory of the fixture analytics; see [observerOf].
void expectObserverOfEachNavigator(WidgetTester tester) {
  final navigators = tester.stateList<NavigatorState>(
    find.byType(Navigator, skipOffstage: false),
  );
  expect(navigators, isNotEmpty, reason: 'The router shows a navigator.');
  navigators.forEach(observerOf);
}
