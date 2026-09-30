import 'package:flutter/foundation.dart';

import '../analytics/analytics_service.dart';
import '../crash_reporting/crash_reporter.dart';

/// How the services of the log fail once they noted a call, which a test
/// sets.
enum ServiceLogFailure {
  /// They do not fail.
  none,

  /// They throw as they are called, before they return a future.
  throwing,

  /// They return a future that fails.
  failing,
}

/// How each call of the services of the log fails from now on, until a
/// test sets it back to [ServiceLogFailure.none], as each call of a service
/// fails whose platform side is broken.
ServiceLogFailure serviceLogFailure = ServiceLogFailure.none;

/// The calls that reached the analytics service of the log, in their order:
/// each as the name of its method followed by its arguments.
final List<List<Object?>> loggedAnalyticsCalls = [];

/// The calls that reached the crash reporter of the log, in their order:
/// each as the name of its method followed by its arguments, with the error
/// or the details of the error of Flutter that it got.
final List<List<Object?>> loggedCrashReporterCalls = [];

/// Creates the analytics service of the log.
AnalyticsService createServiceLogAnalytics() => const ServiceLogAnalytics();

/// Creates the crash reporter of the log.
CrashReporter createServiceLogCrashReporter() =>
    const ServiceLogCrashReporter();

/// Analytics that notes each call in [loggedAnalyticsCalls], and then fails
/// as [serviceLogFailure] says.
final class ServiceLogAnalytics implements AnalyticsService {
  /// Creates the service.
  const ServiceLogAnalytics();

  @override
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) =>
      _note(loggedAnalyticsCalls, ['logEvent', name, parameters]);

  @override
  Future<void> logSignIn({String? method, Map<String, Object>? parameters}) =>
      _note(loggedAnalyticsCalls, ['logSignIn', method, parameters]);

  @override
  Future<void> logSignUp({
    required String method,
    Map<String, Object>? parameters,
  }) =>
      _note(loggedAnalyticsCalls, ['logSignUp', method, parameters]);

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) => _note(
        loggedAnalyticsCalls,
        ['setAnalyticsCollectionEnabled', enabled],
      );

  @override
  Future<void> setUserId(String? userId) =>
      _note(loggedAnalyticsCalls, ['setUserId', userId]);

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) =>
      _note(loggedAnalyticsCalls, ['setUserProperty', name, value]);
}

/// Crash reporting that notes each call in [loggedCrashReporterCalls], and
/// then fails as [serviceLogFailure] says.
final class ServiceLogCrashReporter implements CrashReporter {
  /// Creates the reporter.
  const ServiceLogCrashReporter();

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
    String? reason,
  }) =>
      _note(loggedCrashReporterCalls, ['recordError', error, fatal, reason]);

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) =>
      _note(loggedCrashReporterCalls, ['recordFlutterError', details, fatal]);

  @override
  Future<void> log(String message) =>
      _note(loggedCrashReporterCalls, ['log', message]);

  @override
  Future<void> setUserId(String? userId) =>
      _note(loggedCrashReporterCalls, ['setUserId', userId]);
}

/// Notes [call] in [calls], and then fails as [serviceLogFailure] says.
Future<void> _note(List<List<Object?>> calls, List<Object?> call) {
  calls.add(call);
  final failure = StateError('The service log failed on ${call.first}.');
  return switch (serviceLogFailure) {
    ServiceLogFailure.none => Future<void>.value(),
    ServiceLogFailure.throwing => throw failure,
    ServiceLogFailure.failing => Future<void>.error(failure),
  };
}
