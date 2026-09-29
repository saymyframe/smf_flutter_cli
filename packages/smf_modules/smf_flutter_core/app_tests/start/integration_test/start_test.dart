// A test that continuous integration runs on an Android emulator and on an
// iOS simulator in some of the apps it generates: the app starts. main()
// runs the start-up of the app, with what its modules put into bootstrap(),
// and the root widget of the app shows its first screen without an error.
// The matrix of the apps only analyzes it, since `flutter test` runs only
// the tests of `test/`.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:{{app_name}}/app.dart';
import 'package:{{app_name}}/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the app starts and shows its first screen',
    (tester) async {
      // bootstrap() of an app that reports crashes sends the errors of
      // Flutter and those that nothing catches to the crash reporter, where
      // the test would not see them. The test takes them back once main()
      // returns, so that an error in the frames of the first screen fails
      // it, and leaves the handlers as they were.
      final flutterErrors = FlutterError.onError;
      final uncaughtErrors = PlatformDispatcher.instance.onError;
      try {
        await app.main();
      } finally {
        FlutterError.onError = flutterErrors;
        PlatformDispatcher.instance.onError = uncaughtErrors;
      }
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );

      expect(find.byType(App), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
