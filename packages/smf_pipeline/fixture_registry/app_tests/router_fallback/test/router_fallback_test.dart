// A test that continuous integration runs in the apps of the fixture
// modules with a router and no route that the app starts on, whichever
// module provides the router: the router shows the fallback screen of the
// app entry at `/`, and calls the listeners of the screen
// (RouterRole.screenListeners), here the listener of the fixture screen
// log, once for it, with no route and the location `/`. goToStart() of the
// navigation of the role keeps the user on that screen. For a location from
// the platform that no route matches, a router that takes locations from
// the platform shows the not-found screen of the role, whose button shows
// the fallback screen in its place. It starts the app with main() of
// lib/main.dart, which the app entry role puts into every app, so it
// applies to a new provider of the router role as it is.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/app/fallback_start_screen.dart';
import 'package:{{app_name}}/core/fixture_screen_log/fixture_screen_log.dart';
import 'package:{{app_name}}/core/router/app_router.dart';
import 'package:{{app_name}}/core/router/not_found_screen.dart';
import 'package:{{app_name}}/main.dart' as app;

/// Starts the app as on a device, with what its main() puts around it, and
/// waits for its first screen.
///
/// main() runs in real time, so a start-up that waits for a timer or for
/// input and output, as that of a module may, does not keep the fake time of
/// the test waiting forever. An error of main() fails the test, which
/// tester.runAsync would only report to the handler of the errors of
/// Flutter. An error of bootstrap() reaches FlutterError.onError through
/// main(), which fails the test too. The handlers of errors that the
/// start-up installs, such as those of crash reporting, and the builder of
/// the widget of an error go back to those of the test once main() returns,
/// so that flutter_test reports the errors of the frames that follow, and an
/// expectation that fails, as in any test.
Future<void> _startApp(WidgetTester tester) async {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets('the fallback screen is heard of once, at /', (tester) async {
    await _startApp(tester);
    expect(find.byType(FallbackStartScreen), findsOneWidget);
    expect(fixtureScreenLog, [(null, '/')]);

    // Building every widget of the app again shows the same screen, which
    // is not heard of again.
    final reassembled = tester.binding.reassembleApplication();
    await tester.pumpAndSettle();
    await reassembled;
    expect(fixtureScreenLog, [(null, '/')]);

    // goToStart() on the fallback screen: the router keeps its page, which
    // the listeners hear nothing of, or shows a new page of it, which they
    // hear of once.
    final fallback = tester.element(find.byType(FallbackStartScreen));
    appRouter.navigatorOf(fallback).goToStart();
    await tester.pumpAndSettle();
    expect(
      find.byType(FallbackStartScreen),
      findsOneWidget,
      reason: 'goToStart() keeps the user on the fallback screen, the screen '
          'that an app starts on when no route starts it.',
    );
    final stays = tester
        .elementList(find.byType(FallbackStartScreen))
        .contains(fallback);
    expect(
      fixtureScreenLog,
      [(null, '/'), if (!stays) (null, '/')],
      reason: 'goToStart() on the fallback screen is heard of at most once.',
    );
    fixtureScreenLog.clear();

    // A location from the platform that no route matches: the router shows
    // the not-found screen of the router role, or takes no locations from
    // the platform and stays where it is.
    await tester.binding.handlePushRoute('/no/such/screen');
    await tester.pumpAndSettle();
    if (fixtureScreenLog.isEmpty) {
      expect(
        find.byType(FallbackStartScreen),
        findsOneWidget,
        reason: 'A router that takes no locations from the platform stays '
            'where it is.',
      );
      return;
    }
    expect(
      fixtureScreenLog,
      [(null, '/no/such/screen')],
      reason: 'The not-found screen is heard of once, with no route, at the '
          'location that no route matches.',
    );
    expect(
      find.byType(NotFoundScreen),
      findsOneWidget,
      reason: 'For a location from the platform that no route matches, the '
          'router shows the not-found screen of the router role.',
    );
    fixtureScreenLog.clear();
    await tester.tap(
      find.descendant(
        of: find.byType(NotFoundScreen),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byType(FallbackStartScreen),
      findsOneWidget,
      reason: 'The button of the not-found screen shows the fallback screen '
          'in an app that no route starts.',
    );
    expect(
      fixtureScreenLog,
      [(null, '/')],
      reason: 'The fallback screen that the button of the not-found screen '
          'shows is heard of once.',
    );
    expect(
      find.byType(NotFoundScreen),
      findsNothing,
      reason: 'The button of the not-found screen shows the fallback screen '
          'in place of it.',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
