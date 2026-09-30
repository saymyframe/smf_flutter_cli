// A test that continuous integration runs in the apps with Firebase
// Analytics and a router, on the real Firebase packages, whose platform
// side answers without a Firebase project: the app logs its first screen
// once, with the name of its route only, `{{start_screen}}`. The matrix
// sets up the mocks of the platform side of every module of the app before
// the tests, those of Firebase among them, so the start-up runs whatever
// other modules the app has.
//
// It starts the app through what every app has, whichever module provides
// its entry: main() in lib/main.dart (AppEntryRole.mainFile), which runs
// bootstrap() and then runApp() with what the modules put around the root
// widget, such as the scope of the providers of Riverpod. main() runs in
// real time, outside the fake time of the widget test: the start-up of any
// module of the app may wait for a timer or for real I/O, which fake time
// never lets finish, or leave a timer running, which a widget test takes
// for a timer that the test left.
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/main.dart' as app;

import 'firebase_analytics_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets('the first screen is logged once, with the name of its route',
      (tester) async {
    // The start-up of the app may replace the handlers of the errors, as
    // that of an app that reports crashes sends the errors of Flutter and
    // those that nothing catches to its crash reporters, which this test
    // does not look at, and the widget that shows the errors of a build.
    // The test takes them back once main() returns, so that flutter_test
    // reports the errors of the frames that follow, and an expectation
    // that fails, as in any test, and finds its own widget of the errors.
    final onError = FlutterError.onError;
    final onPlatformError = PlatformDispatcher.instance.onError;
    final errorWidgetBuilder = ErrorWidget.builder;
    // runAsync hands an error of main() to FlutterError.onError, which the
    // start-up may have replaced with a handler that reports it only to
    // the crash reporters, so the test catches the error itself.
    (Object, StackTrace)? failed;
    try {
      await tester.runAsync(() async {
        try {
          await app.main();
        } catch (error, stackTrace) {
          failed = (error, stackTrace);
        }
      });
    } finally {
      FlutterError.onError = onError;
      PlatformDispatcher.instance.onError = onPlatformError;
      ErrorWidget.builder = errorWidgetBuilder;
    }
    if (failed case (final error, final stackTrace)) {
      Error.throwWithStackTrace(error, stackTrace);
    }
    await tester.pumpAndSettle();
    // Building every widget of the app again shows the same screen, which
    // is not logged again.
    final reassembled = tester.binding.reassembleApplication();
    await tester.pumpAndSettle();
    await reassembled;

    expect(screenViews, [
      {'screen_name': '{{start_screen}}'},
    ]);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
