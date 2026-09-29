// A test that continuous integration runs in the apps with Firebase
// Analytics and a router, on the real Firebase packages, whose platform
// side answers without a Firebase project: the app logs its first screen
// once, with the name of its route only, `{{start_screen}}`. The mocks of
// Firebase Core come with the tests of firebase_core, which every app with
// Firebase Analytics has.
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/app.dart';
import 'package:{{app_name}}/bootstrap.dart';

import 'firebase_analytics_mocks.dart';
import 'firebase_core_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The start-up of the app runs outside the widget test, whose fake time
  // the answers of the mocks of Firebase would wait for: main() in the
  // test, even through runAsync, never finishes.
  setUpAll(() async {
    mockFirebaseCore();
    mockFirebaseAnalytics();
    await bootstrap();
  });

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets('the first screen is logged once, with the name of its route',
      (tester) async {
    // The root widget of the app, without what main() may put around it,
    // such as the scope of the providers of Riverpod, which the start
    // screens do not need.
    await tester.pumpWidget(const App());
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
