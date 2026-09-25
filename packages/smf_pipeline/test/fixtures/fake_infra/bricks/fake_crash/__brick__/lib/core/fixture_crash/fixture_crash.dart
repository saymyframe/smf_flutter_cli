import 'package:flutter/foundation.dart';

import '../crash_reporting/crash_reporter.dart';

/// Creates the crash reporter of the fixture once it is ready.
Future<CrashReporter> initFixtureCrashReporter() async =>
    const _FixtureCrashReporter();

final class _FixtureCrashReporter implements CrashReporter {
  const _FixtureCrashReporter();

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
    String? reason,
  }) async {}

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) async {}

  @override
  Future<void> log(String message) async {}

  @override
  Future<void> setUserId(String? userId) async {}
}
