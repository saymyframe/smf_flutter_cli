// A test that continuous integration runs in the apps with the router role,
// whichever module provides it: the app starts with main() of
// lib/main.dart, which the app entry role puts into every app, and the walk
// of its routes (integration_test/router_walk/walk.dart) goes to each
// location of the app that needs no values through the navigation of the
// role. Each shows the page of its route on top of the innermost navigator
// on the screen, named after the route, and the screen of the route, with no
// ErrorWidget on the screen and no error of Flutter.
//
// The guards of the routes of the app must allow, so that the walk reaches
// every route outside their flows: the test fails on each guard that does
// not, by its name. The module of a guard opens it for the tests of the
// app in the mocks of its app test (MatrixAppTest.mocks), which the matrix
// sets up before the tests of each test file. On a device, where no test
// opens a guard, the walk expects the target of the guard in place of each
// location that the guard keeps the user from.
//
// A location in the flow of a guard shows only while the guard does not
// allow. So here, where the flows are over, the walk expects the screen
// that the app starts on in place of each of them, as the router role
// says, with its page on top if it is a route.
//
// It knows only the role. The matrix writes the locations of the app next
// to the walk, from the data of its router role, and sets up the mocks of
// the platform side of every module of the app before the tests of each
// test file (flutter_test_config.dart).
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/main.dart' as app;

import '../integration_test/router_walk/locations.dart';
import '../integration_test/router_walk/walk.dart';

/// Starts the app as on a device, with what its main() puts around it, and
/// waits for its first screen.
///
/// main() runs in real time, so a start-up that waits for a timer or for
/// input and output, as that of a module may, does not keep the fake time
/// of the test waiting forever. An error of main() fails the test, which
/// tester.runAsync would only report to the handler of the errors of
/// Flutter. The handlers of errors that the start-up installs, such as
/// those of crash reporting, and the builder of the widget of an error go
/// back to those of the test once main() returns.
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
  testWidgets(
    'each location that needs no values shows the page and the screen of '
    'its route',
    (tester) async {
      await _startApp(tester);

      expect(
        closedGuards(),
        isEmpty,
        reason: 'These guards of the routes do not allow, so the walk cannot '
            'reach the routes outside their flows, and the tests of the '
            'other modules of the app do not see the screens that they '
            'expect. The module of a guard opens it for the tests of the app '
            'in the mocks of its app test (MatrixAppTest.mocks), before the '
            'app starts.',
      );

      final walk = await walkRoutes(tester.pumpAndSettle);

      expect(
        walk.errors,
        isEmpty,
        reason: 'Going to each location shows no ErrorWidget, and Flutter '
            'reports no error.',
      );
      expect(
        walk.pages,
        isEmpty,
        reason: 'The page on top of the innermost navigator on the screen is '
            'named after the route of each location, or after the route '
            'that the app starts on for a location in a flow that is over.',
      );
      expect(
        walk.screens,
        isEmpty,
        reason: 'Each location shows the screen of its route, or the screen '
            'that the app starts on if it is in a flow that is over.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
