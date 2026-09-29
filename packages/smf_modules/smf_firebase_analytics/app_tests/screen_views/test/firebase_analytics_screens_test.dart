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
// widget, such as the scope of the providers of Riverpod.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/main.dart' as app;

import 'firebase_analytics_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets('the first screen is logged once, with the name of its route',
      (tester) async {
    // bootstrap() of an app that reports crashes sends the errors of
    // Flutter and those that nothing catches to its crash reporters, which
    // this test does not look at. The test takes them back once main()
    // returns, so that flutter_test reports the errors of the frames that
    // follow, and an expectation that fails, as in any test.
    final onError = FlutterError.onError;
    final onPlatformError = PlatformDispatcher.instance.onError;
    try {
      await app.main();
    } finally {
      FlutterError.onError = onError;
      PlatformDispatcher.instance.onError = onPlatformError;
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
