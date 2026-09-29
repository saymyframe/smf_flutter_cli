import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../crash_reporting/crash_reporter.dart';

/// The platform side of the crash reporting of the fixture, which only the
/// mocks of its own tests answer, as only the tests of a plugin know its
/// platform side.
const fixtureCrashChannel = MethodChannel('smf.fixture/crash');

/// Creates the crash reporter of the fixture once its platform side has
/// started.
Future<CrashReporter> initFixtureCrashReporter() async {
  await fixtureCrashChannel.invokeMethod<void>('start');
  return const FixtureCrashReporter();
}

/// Crash reporting that sends every report to its platform side.
final class FixtureCrashReporter implements CrashReporter {
  /// Creates the reporter.
  const FixtureCrashReporter();

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
    String? reason,
  }) =>
      fixtureCrashChannel.invokeMethod<void>('recordError', {
        'error': '$error',
        'fatal': fatal,
        'reason': reason,
      });

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) =>
      fixtureCrashChannel.invokeMethod<void>('recordError', {
        'error': details.exceptionAsString(),
        'fatal': fatal,
      });

  @override
  Future<void> log(String message) =>
      fixtureCrashChannel.invokeMethod<void>('log', message);

  @override
  Future<void> setUserId(String? userId) =>
      fixtureCrashChannel.invokeMethod<void>('setUserId', userId);
}
