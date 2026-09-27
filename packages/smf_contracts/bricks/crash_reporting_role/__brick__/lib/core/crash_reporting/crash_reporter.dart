import 'dart:async';

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

  /// Sets the id of the signed-in user for the next reports, or clears it
  /// with `null`.
  Future<void> setUserId(String? userId);
}

/// Returns the crash reporter of the app, which forwards every call to the
/// crash reporters of all modules.
CrashReporter createCrashReporter() => _crashReporter;

/// Reports the errors of the main isolate that nothing handles, each once.
///
/// `bootstrap()` calls it once the crash reporting services are ready. Two
/// handlers cover the main isolate:
/// - `FlutterError.onError` gets the errors that Flutter catches, such as in
///   a build or a layout, and still presents them as Flutter does by
///   default;
/// - `PlatformDispatcher.instance.onError` gets every other uncaught error,
///   such as in a `Future`, a `Timer` or the handler of a port, with its
///   type. In debug mode it leaves the error unhandled, so the engine prints
///   it.
///
/// `compute()` and `Isolate.run()` throw the error of their isolate to the
/// code that awaits them, so it reaches the platform dispatcher unless that
/// code catches it. The uncaught errors of an isolate that the app spawns
/// itself go only to the error listener of that isolate, such as the
/// `onError` port of `Isolate.spawn`, so the app reports them there to its
/// crash reporter.
void installCrashReporting() {
  final reporter = createCrashReporter();
  final presentError = FlutterError.onError;
  FlutterError.onError = (details) {
    presentError?.call(details);
    unawaited(reporter.recordFlutterError(details, fatal: true));
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(reporter.recordError(error, stackTrace, fatal: true));
    return !kDebugMode;
  };
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
  Future<void> setUserId(String? userId) =>
      _forAll((reporter) => reporter.setUserId(userId));

  Future<void> _forAll(
    Future<void> Function(CrashReporter reporter) call,
  ) async {
    await Future.wait(_reporters.map(call));
  }
}
