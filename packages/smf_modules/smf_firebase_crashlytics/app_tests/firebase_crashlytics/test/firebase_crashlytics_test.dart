// A test that continuous integration runs in the apps with Firebase
// Crashlytics, on the real Firebase packages, whose platform side answers
// as their packages for tests let it: the crash reporter of the module,
// which createCrashlyticsCrashReporter() creates, reports to Crashlytics,
// and neither presents nor prints what it reports, which the handlers of
// the crash reporting role leave to Flutter and to the engine.
//
// The app may have other crash reporters, whose platform side only the
// tests of their own modules know, so the test uses the reporter of the
// module rather than createCrashReporter(), which reports to all of them.
// It initializes Firebase as the start-up of the app does, and runs none
// of the rest of the start-up; firebase_crashlytics_uncaught_errors_test.dart
// checks the handlers of the errors that the start-up installs. The
// options of Firebase come with the tests of firebase_core, which every
// app with Crashlytics has.
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/crash_reporting/crashlytics_crash_reporter.dart';
import 'package:{{app_name}}/firebase_options.dart';

import 'firebase_crashlytics_mocks.dart';

/// Runs [body] and returns what it printed, with print or debugPrint.
Future<List<String>> _printed(FutureOr<void> Function() body) async {
  final lines = <String>[];
  final debugPrintBefore = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) =>
      lines.addAll((message ?? '').split('\n'));
  try {
    await runZoned(
      () async => body(),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => lines.addAll(line.split('\n')),
      ),
    );
  } finally {
    debugPrint = debugPrintBefore;
  }
  return lines;
}

/// Runs [body] and returns the errors that Flutter presented meanwhile.
Future<List<FlutterErrorDetails>> _presented(
  FutureOr<void> Function() body,
) async {
  final presented = <FlutterErrorDetails>[];
  final presentErrorBefore = FlutterError.presentError;
  FlutterError.presentError = presented.add;
  try {
    await body();
  } finally {
    FlutterError.presentError = presentErrorBefore;
  }
  return presented;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockCrashlytics crashlytics;

  setUpAll(() async {
    crashlytics = mockFirebaseCrashlytics();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  });

  setUp(() => crashlytics.clear());

  test(
      'the reporter reports an error of Flutter to Crashlytics, and neither '
      'presents nor prints it', () async {
    expect(kDebugMode, isTrue);
    final reporter = createCrashlyticsCrashReporter();
    final details = FlutterErrorDetails(
      exception: StateError('broken in a build'),
      stack: StackTrace.current,
      library: 'the test',
      context: ErrorDescription('while building the test'),
    );

    late List<String> printed;
    final presented = await _presented(() async {
      printed = await _printed(
        () => reporter.recordFlutterError(details, fatal: true),
      );
    });

    expect(presented, isEmpty);
    expect(printed, isEmpty);
    final request = crashlytics.errors.single;
    expect(request.exception, 'Bad state: broken in a build');
    expect(request.reason, 'while building the test');
    expect(request.fatal, isTrue);
    expect(request.stackTraceElements, isNotEmpty);
  });

  test(
      'the reporter reports errors, the log and the user to Crashlytics, and '
      'prints nothing', () async {
    final reporter = createCrashlyticsCrashReporter();

    final printed = await _printed(() async {
      await reporter.recordError(
        ArgumentError('caught'),
        StackTrace.current,
        reason: 'while saving',
      );
      await reporter.recordError(
        StateError('broken later'),
        StackTrace.current,
        fatal: true,
      );
      await reporter.log('saved');
      await reporter.setUserId('user-1');
      await reporter.setUserId(null);
    });

    expect(printed, isEmpty);
    final [caught, fatal] = crashlytics.errors;
    expect(caught.exception, 'Invalid argument(s): caught');
    expect(caught.reason, 'while saving');
    expect(caught.fatal, isFalse);
    expect(caught.stackTraceElements, isNotEmpty);
    expect(fatal.exception, 'Bad state: broken later');
    expect(fatal.fatal, isTrue);
    expect(crashlytics.logs, ['saved']);
    expect(crashlytics.users, ['user-1', '']);
  });
}
