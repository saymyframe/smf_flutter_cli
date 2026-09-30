import 'package:flutter/foundation.dart';

/// Records what users do in the app.
abstract interface class AnalyticsService {
  /// Logs the event [name] with [parameters].
  Future<void> logEvent(String name, {Map<String, Object>? parameters});

  /// Logs that the user signed in, with the sign-in [method].
  Future<void> logSignIn({String? method, Map<String, Object>? parameters});

  /// Logs that the user signed up, with the sign-up [method].
  Future<void> logSignUp({
    required String method,
    Map<String, Object>? parameters,
  });

  /// Turns the collection of analytics data on or off.
  Future<void> setAnalyticsCollectionEnabled(bool enabled);

  /// Sets the id of the signed-in user, or clears it with `null`.
  Future<void> setUserId(String? userId);

  /// Sets the user property [name] to [value], or clears it with `null`.
  Future<void> setUserProperty({required String name, required String? value});
}

/// Returns the analytics service of the app, which forwards every call to
/// the analytics services of all modules.
///
/// It calls each of them on its own, and its future completes once all of
/// them are done. An analytics service that throws, or whose future fails,
/// keeps no other from the call, and its failure does not reach the code
/// that called: that code may not await the call, and then nothing would
/// catch the failure. In debug mode the failure is printed, so that an
/// analytics service that does not work, such as one that is not set up,
/// shows in the console. Each analytics service gets a copy of its own of
/// the map of parameters, so that one that changes the map changes nothing
/// that the caller or another analytics service has. An analytics service
/// whose factory throws, or that fails to start, is left out, and in debug
/// mode its error is printed.
AnalyticsService createAnalyticsService() => _analyticsService;

final AnalyticsService _analyticsService =
    _AnalyticsServices(_analyticsServices);

{{{smf_analytics__implementations}}}

final class _AnalyticsServices implements AnalyticsService {
  const _AnalyticsServices(this._services);

  final List<AnalyticsService> _services;

  @override
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) =>
      _forAll(
        (service) => service.logEvent(name, parameters: _copyOf(parameters)),
      );

  @override
  Future<void> logSignIn({String? method, Map<String, Object>? parameters}) =>
      _forAll(
        (service) => service.logSignIn(
          method: method,
          parameters: _copyOf(parameters),
        ),
      );

  @override
  Future<void> logSignUp({
    required String method,
    Map<String, Object>? parameters,
  }) =>
      _forAll(
        (service) => service.logSignUp(
          method: method,
          parameters: _copyOf(parameters),
        ),
      );

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) =>
      _forAll((service) => service.setAnalyticsCollectionEnabled(enabled));

  @override
  Future<void> setUserId(String? userId) =>
      _forAll((service) => service.setUserId(userId));

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) =>
      _forAll((service) => service.setUserProperty(name: name, value: value));

  /// Calls [call] with each analytics service on its own, and completes
  /// once all of them are done, whatever each does; see
  /// [createAnalyticsService].
  Future<void> _forAll(
    Future<void> Function(AnalyticsService service) call,
  ) async {
    await Future.wait([
      for (final service in _services) _callAlone(service, call),
    ]);
  }

  /// A copy of [parameters] for one analytics service; see
  /// [createAnalyticsService].
  static Map<String, Object>? _copyOf(Map<String, Object>? parameters) =>
      parameters == null ? null : Map.of(parameters);

  /// Calls [call] with [service], and keeps what it throws, or the error of
  /// its future, from the caller: in debug mode it prints it.
  static Future<void> _callAlone(
    AnalyticsService service,
    Future<void> Function(AnalyticsService service) call,
  ) async {
    try {
      await call(service);
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('The analytics service ${service.runtimeType} failed: $error');
      }
    }
  }
}
