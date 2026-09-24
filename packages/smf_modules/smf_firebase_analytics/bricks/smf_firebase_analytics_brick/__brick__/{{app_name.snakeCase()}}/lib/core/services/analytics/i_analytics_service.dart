abstract interface class IAnalyticsService {
  Future<void> logEvent(String name, {Map<String, Object>? parameters});

  Future<void> logSignIn({String? method, Map<String, Object>? parameters});

  Future<void> logSignUp({
    required String method,
    Map<String, Object>? parameters,
  });

  Future<void> setAnalyticsCollectionEnabled(bool enabled);

  Future<void> setUserId(String? userId);

  Future<void> setUserProperty({required String name, required String? value});
}
