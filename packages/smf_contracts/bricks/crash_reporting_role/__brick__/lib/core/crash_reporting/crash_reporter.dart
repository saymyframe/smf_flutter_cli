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
///
/// It calls each of them on its own, and its future completes once all of
/// them are done. A crash reporter that throws, or whose future fails,
/// keeps no other from the call, and its failure reaches neither the code
/// that called nor the handlers of [installCrashReporting], which would
/// report it to the same crash reporter again, without end. In debug mode
/// the failure is printed, so that a crash reporter that does not work,
/// such as one that is not set up, shows in the console.
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
/// Each report reaches every crash reporter, and the failure of a crash
/// reporter comes back to neither handler; see [createCrashReporter].
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

  /// Calls [call] with each crash reporter on its own, and completes once
  /// all of them are done, whatever each does; see [createCrashReporter].
  Future<void> _forAll(
    Future<void> Function(CrashReporter reporter) call,
  ) async {
    await Future.wait([
      for (final reporter in _reporters) _callAlone(reporter, call),
    ]);
  }

  /// Calls [call] with [reporter], and keeps what it throws, or the error of
  /// its future, from the caller: in debug mode it prints it.
  static Future<void> _callAlone(
    CrashReporter reporter,
    Future<void> Function(CrashReporter reporter) call,
  ) async {
    try {
      await call(reporter);
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('The crash reporter ${reporter.runtimeType} failed: $error');
      }
    }
  }
}
