// A test that continuous integration runs in the apps of the fixture
// modules with the fixture whose start-up fails when a test says so
// (fake_start_failure), whichever module provides the app entry: when
// bootstrap() throws, main() shows the screen of a failed start of the
// template of the role in place of the app, which it does not run, and
// reports the error once to the handler of the errors of Flutter, and not to
// the handler of the uncaught errors of the platform, which would report it
// a second time. In the apps with every module, crash reporting has started
// before the error, and its handler calls the handler of the test, so the
// error reaches both; its handler of the uncaught errors of the platform
// takes the place of that of the test, so only the app of the fixture alone
// shows a report there.
//
// The app starts with main() of lib/main.dart, which the app entry role puts
// into every app. Each expectation gives its reason, which a provider of the
// app entry with a known bug fails the test with (brokenProviders of the
// fixture registry).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/app/failed_start.dart';
import 'package:{{app_name}}/core/fixture_start_failure/fixture_start_failure.dart';
import 'package:{{app_name}}/main.dart' as app;

/// The title of the screen of a failed start, in every build.
const _title = 'The app could not start';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'a start-up that throws shows the screen of a failed start in place of '
    'the app, and reports the error once',
    (tester) async {
      failFixtureStart = true;
      addTearDown(() => failFixtureStart = false);

      // What reaches the handler of the errors of Flutter, and the handler
      // of the uncaught errors of the platform, while main() runs and the
      // app shows its first frame. The handlers that the start-up installs,
      // such as those of crash reporting, and the builder of the widget of
      // an error go back to those of the test after that frame and before
      // any expectation, so that flutter_test reports an expectation that
      // fails first.
      final reports = <FlutterErrorDetails>[];
      final uncaught = <Object>[];
      final onError = FlutterError.onError;
      final onPlatformError = PlatformDispatcher.instance.onError;
      final errorWidgetBuilder = ErrorWidget.builder;
      Object? thrown;
      StackTrace? stackTrace;
      try {
        FlutterError.onError = reports.add;
        PlatformDispatcher.instance.onError = (error, stackTrace) {
          uncaught.add(error);
          return true;
        };
        // main() runs in real time, so a start-up that waits for a timer or
        // for input and output, as that of a module may, does not keep the
        // fake time of the test waiting forever.
        await tester.runAsync(() async {
          try {
            await app.main();
          } on Object catch (error, stack) {
            thrown = error;
            stackTrace = stack;
          }
        });
        await tester.pump();
      } finally {
        FlutterError.onError = onError;
        PlatformDispatcher.instance.onError = onPlatformError;
        ErrorWidget.builder = errorWidgetBuilder;
      }

      expect(
        thrown,
        isNull,
        reason: 'main() catches what bootstrap() throws, so the app does not '
            'stay on the splash screen of the system.\n$stackTrace',
      );
      expect(
        find.byType(FailedStartApp),
        findsOneWidget,
        reason: 'A failed start shows the screen of the failed start, and '
            'main() runs no root of the app over it.',
      );
      expect(
        find.byType(WidgetsApp),
        findsOneWidget,
        reason: 'The screen of the failed start is the only app below the '
            'root.',
      );
      expect(
        tester.widget<FailedStartApp>(find.byType(FailedStartApp)).error,
        same(fixtureStartError),
        reason: 'The screen of the failed start has the error that '
            'bootstrap() threw.',
      );
      expect(
        tester.getSemantics(find.text(_title)),
        isSemantics(label: _title, isHeader: true),
        reason: 'A screen reader reads the title as a header.',
      );
      expect(
        find.text('$fixtureStartError'),
        findsOneWidget,
        reason: 'A debug build shows the error on the screen.',
      );
      expect(
        [for (final report in reports) report.exception],
        [same(fixtureStartError)],
        reason: 'The error reaches the handler of the errors of Flutter '
            'once, through the handlers that the start-up set up before it '
            'failed.',
      );
      expect(
        uncaught,
        isEmpty,
        reason: 'main() reports the error of bootstrap() to the handler of '
            'the errors of Flutter alone, and not to the handler of the '
            'uncaught errors of the platform too, which would report it a '
            'second time.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets(
    'only a debug build shows the error and its stack trace',
    (tester) async {
      await tester.pumpWidget(
        FailedStartApp(
          error: StateError('a token 1234'),
          stackTrace: StackTrace.current,
          showsError: false,
        ),
      );

      expect(find.text(_title), findsOneWidget);
      expect(
        find.text('Close the app and open it again.'),
        findsOneWidget,
        reason: 'Any other build says what the user can do.',
      );
      expect(
        find.textContaining('1234'),
        findsNothing,
        reason: 'The message of an error may hold data of the user, so only '
            'a debug build shows it.',
      );
      expect(
        find.textContaining('failed_start_test.dart'),
        findsNothing,
        reason: 'Only a debug build shows the stack trace.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
