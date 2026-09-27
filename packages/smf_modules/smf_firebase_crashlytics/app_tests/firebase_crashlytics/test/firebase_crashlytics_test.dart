// A test that continuous integration runs in the apps with Firebase
// Crashlytics, on the real Firebase packages, whose platform side answers
// as their packages for tests let it: the start-up of the app installs the
// handlers of the errors that nothing catches, which report them to
// Crashlytics, and the crash reporter of the app reaches it.
import 'dart:async';

import 'package:firebase_crashlytics_platform_interface/test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/bootstrap.dart';
import 'package:{{app_name}}/core/crash_reporting/crash_reporter.dart';

import 'firebase_core_mocks.dart';

/// Records what reaches the platform side of Firebase Crashlytics.
final class _Crashlytics implements TestFirebaseCrashlyticsHostApi {
  final List<RecordErrorRequest> errors = [];
  final List<String> logs = [];
  final List<String> users = [];

  void clear() {
    errors.clear();
    logs.clear();
    users.clear();
  }

  @override
  Future<void> recordError(RecordErrorRequest request) async =>
      errors.add(request);

  @override
  Future<void> log(String message) async => logs.add(message);

  @override
  Future<void> setUserIdentifier(String identifier) async =>
      users.add(identifier);

  @override
  Future<bool> checkForUnsentReports() async => false;

  @override
  Future<void> crash() async {}

  @override
  Future<void> deleteUnsentReports() async {}

  @override
  Future<bool> didCrashOnPreviousExecution() async => false;

  @override
  Future<void> sendUnsentReports() async {}

  @override
  Future<bool> setCrashlyticsCollectionEnabled(bool enabled) async => enabled;

  @override
  Future<void> setCustomKey(String key, String value) async {}
}

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
  final crashlytics = _Crashlytics();
  final onErrorBefore = FlutterError.onError;

  setUpAll(() async {
    mockFirebaseCore(
      pluginConstants: {
        'plugins.flutter.io/firebase_crashlytics': {
          'isCrashlyticsCollectionEnabled': true,
        },
      },
    );
    TestFirebaseCrashlyticsHostApi.setUp(crashlytics);
    // As by default, the handler of the errors of Flutter presents them.
    FlutterError.onError = (details) => FlutterError.presentError(details);
    await bootstrap();
  });

  tearDownAll(() => FlutterError.onError = onErrorBefore);

  setUp(crashlytics.clear);

  test(
      'an error that Flutter catches is presented once and reaches '
      'Crashlytics as fatal', () async {
    expect(kDebugMode, isTrue);
    final details = FlutterErrorDetails(
      exception: StateError('broken in a build'),
      stack: StackTrace.current,
      library: 'the test',
      context: ErrorDescription('while building the test'),
    );

    late List<String> printed;
    final presented = await _presented(() async {
      printed = await _printed(() async {
        FlutterError.onError!(details);
        await pumpEventQueue();
      });
    });

    expect(presented, [same(details)]);
    expect(printed, isEmpty);
    final request = crashlytics.errors.single;
    expect(request.exception, 'Bad state: broken in a build');
    expect(request.reason, 'while building the test');
    expect(request.fatal, isTrue);
    expect(request.stackTraceElements, isNotEmpty);
  });

  test(
      'an error that nothing catches reaches Crashlytics as fatal, and is '
      'left to the engine in debug mode', () async {
    final printed = await _printed(() async {
      expect(
        PlatformDispatcher.instance.onError!(
          StateError('broken later'),
          StackTrace.current,
        ),
        isFalse,
      );
      await pumpEventQueue();
    });

    expect(printed, isEmpty);
    expect(crashlytics.errors.single.exception, 'Bad state: broken later');
    expect(crashlytics.errors.single.fatal, isTrue);
  });

  test('the crash reporter of the app reaches Crashlytics', () async {
    final reporter = createCrashReporter();

    final printed = await _printed(() async {
      await reporter.recordError(
        ArgumentError('caught'),
        StackTrace.current,
        reason: 'while saving',
      );
      await reporter.log('saved');
      await reporter.setUserId('user-1');
      await reporter.setUserId(null);
    });

    expect(printed, isEmpty);
    final request = crashlytics.errors.single;
    expect(request.exception, 'Invalid argument(s): caught');
    expect(request.reason, 'while saving');
    expect(request.fatal, isFalse);
    expect(crashlytics.logs, ['saved']);
    expect(crashlytics.users, ['user-1', '']);
  });
}
