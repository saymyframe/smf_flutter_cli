import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:{{app_name.snakeCase()}}/core/services/analytics/i_analytics_service.dart';

class FirebaseAnalyticsService implements IAnalyticsService {
  const FirebaseAnalyticsService(this._analytics);

  final FirebaseAnalytics _analytics;

  @override
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    return _analytics.logEvent(name: name, parameters: parameters);
  }

  @override
  Future<void> logSignIn({
    String? method,
    Map<String, Object>? parameters,
  }) async {
    return _analytics.logLogin(loginMethod: method);
  }

  @override
  Future<void> logSignUp({
    required String method,
    Map<String, Object>? parameters,
  }) async {
    return _analytics.logSignUp(signUpMethod: method, parameters: parameters);
  }

  @override
  Future<void> setUserId(String? userId) async {
    return _analytics.setUserId(id: userId);
  }

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    return _analytics.setUserProperty(name: name, value: value);
  }

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    return _analytics.setAnalyticsCollectionEnabled(enabled);
  }
}
