import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

/// Reports the errors of the app.
abstract interface class CrashReporter {
  /// Reports [error] with its [stackTrace]; a [fatal] error ended the app.
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
    String? reason,
  });

  /// Reports an error that Flutter caught, described by [details].
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  });

  /// Adds [message] to the log sent with the next report.
  Future<void> log(String message);

  /// Sets the id of the signed-in user for the next reports.
  Future<void> setUserId(String userId);
}

/// Returns the crash reporter of the app, which forwards every call to the
/// crash reporters of all modules.
CrashReporter createCrashReporter() => _crashReporter;

/// Reports the errors that Flutter, the platform dispatcher and the current
/// isolate do not handle.
///
/// `bootstrap()` calls it once the crash reporting services are ready.
void installCrashReporting() {
  final reporter = createCrashReporter();
  final presentError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (kDebugMode) {
      presentError?.call(details);
    }
    unawaited(reporter.recordFlutterError(details, fatal: true));
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(reporter.recordError(error, stackTrace, fatal: true));
    return true;
  };
  Isolate.current.addErrorListener(
    RawReceivePort((Object? message) {
      if (message case [final Object error, final String? stackTrace]) {
        unawaited(
          reporter.recordError(
            error,
            stackTrace == null ? null : StackTrace.fromString(stackTrace),
            fatal: true,
          ),
        );
      }
    }).sendPort,
  );
}

final CrashReporter _crashReporter = _CrashReporters(_crashReporters);

{{{smf_crash_reporting__implementations}}}

final class _CrashReporters implements CrashReporter {
  const _CrashReporters(this._reporters);

  final List<CrashReporter> _reporters;

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
    String? reason,
  }) =>
      _forAll(
        (reporter) => reporter.recordError(
          error,
          stackTrace,
          fatal: fatal,
          reason: reason,
        ),
      );

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) =>
      _forAll(
        (reporter) => reporter.recordFlutterError(details, fatal: fatal),
      );

  @override
  Future<void> log(String message) =>
      _forAll((reporter) => reporter.log(message));

  @override
  Future<void> setUserId(String userId) =>
      _forAll((reporter) => reporter.setUserId(userId));

  Future<void> _forAll(
    Future<void> Function(CrashReporter reporter) call,
  ) async {
    await Future.wait(_reporters.map(call));
  }
}
