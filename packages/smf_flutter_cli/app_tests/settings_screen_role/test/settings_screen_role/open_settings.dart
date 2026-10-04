// What the tests of the settings screen role share, in the apps with the
// role, whichever module provides it: the app starts with main() of
// lib/main.dart, which the app entry role puts into every app, and goes to
// the route of the settings screen with go() of the navigator of the router
// role.
//
// It knows only the role. The matrix writes settings.dart next to it, from
// the data of the settings screen role of the app: the location and the
// type of the screen, and the types of the widgets of the entries. It sets
// up the mocks of the platform side of every module of the app before the
// tests of each test file (flutter_test_config.dart).
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/app_router.dart';
import 'package:{{app_name}}/main.dart' as app;

import 'settings.dart';

/// The height of the surface of the tests: a screen may build the rows of
/// its list only as they come into view, and this one is tall enough for
/// the entries of an app to be all in view, some seventy rows.
const double _height = 4000;

/// Starts the app on a tall surface and goes to the settings screen, the
/// location of the route that the provider of the role names, from the
/// navigator of the page that the user sees.
Future<void> openSettings(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(800, _height)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await _startApp(tester);
  appRouter
      .navigatorOf(tester.element(find.byType(Navigator).last))
      .go(settingsLocation);
  await tester.pumpAndSettle();
}

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
/// reports an expectation that fails as in any test.
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
