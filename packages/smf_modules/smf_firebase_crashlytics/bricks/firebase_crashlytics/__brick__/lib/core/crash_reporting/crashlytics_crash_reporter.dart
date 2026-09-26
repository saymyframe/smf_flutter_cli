import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'crash_reporter.dart';

/// Creates a crash reporter that reports to Firebase Crashlytics, which
/// needs Firebase to be initialized.
///
/// The app has one crash reporter, which `createCrashReporter()` returns and
/// which forwards every report to this one.
CrashReporter createCrashlyticsCrashReporter() =>
    CrashlyticsCrashReporter(FirebaseCrashlytics.instance);

/// Reports the errors of the app to Firebase Crashlytics.
///
/// It prints nothing. In debug mode, Crashlytics prints each report and
/// presents each error of Flutter, but the handlers that
/// `installCrashReporting()` installs already leave the errors they report
/// in the console, so each would appear twice.
final class CrashlyticsCrashReporter implements CrashReporter {
  /// Creates the reporter on the given [FirebaseCrashlytics].
  CrashlyticsCrashReporter(this._crashlytics);

  final FirebaseCrashlytics _crashlytics;

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
    String? reason,
  }) =>
      _crashlytics.recordError(
        error,
        stackTrace,
        reason: reason,
        printDetails: false,
        fatal: fatal,
      );

  /// Reports what [FirebaseCrashlytics.recordFlutterError] reports, without
  /// presenting the error as it also does.
  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) =>
      _crashlytics.recordError(
        details.exceptionAsString(),
        details.stack,
        reason: details.context
            ?.toStringDeep(minLevel: DiagnosticLevel.info)
            .trim(),
        information: details.informationCollector?.call() ?? const [],
        printDetails: false,
        fatal: fatal,
      );

  @override
  Future<void> log(String message) => _crashlytics.log(message);

  /// Sets the id of the user, or clears it with `null`, which Crashlytics
  /// does with an empty id.
  @override
  Future<void> setUserId(String? userId) =>
      _crashlytics.setUserIdentifier(userId ?? '');
}
