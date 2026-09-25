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
AnalyticsService createAnalyticsService() => _analyticsService;

final AnalyticsService _analyticsService =
    _AnalyticsServices(_analyticsServices);

{{{smf_analytics__implementations}}}

final class _AnalyticsServices implements AnalyticsService {
  const _AnalyticsServices(this._services);

  final List<AnalyticsService> _services;

  @override
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) =>
      _forAll((service) => service.logEvent(name, parameters: parameters));

  @override
  Future<void> logSignIn({String? method, Map<String, Object>? parameters}) =>
      _forAll(
        (service) => service.logSignIn(method: method, parameters: parameters),
      );

  @override
  Future<void> logSignUp({
    required String method,
    Map<String, Object>? parameters,
  }) =>
      _forAll(
        (service) => service.logSignUp(method: method, parameters: parameters),
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

  Future<void> _forAll(
    Future<void> Function(AnalyticsService service) call,
  ) async {
    await Future.wait(_services.map(call));
  }
}
