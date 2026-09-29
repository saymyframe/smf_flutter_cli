// A test that continuous integration runs in the apps of the fixture
// modules with a router and no route that the app starts on, whichever
// module provides the router: the router shows the fallback screen of the
// app entry at `/`, and calls the listeners of the screen
// (RouterRole.screenListeners), here the listener of the fixture screen
// log, once for it, with no route and the location `/`. It starts the app
// with main() of lib/main.dart, which the app entry role puts into every
// app, so it applies to a new provider of the router role as it is.
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/app/fallback_start_screen.dart';
import 'package:{{app_name}}/core/fixture_screen_log/fixture_screen_log.dart';
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
  }, timeout: const Timeout(Duration(minutes: 2)));
}
