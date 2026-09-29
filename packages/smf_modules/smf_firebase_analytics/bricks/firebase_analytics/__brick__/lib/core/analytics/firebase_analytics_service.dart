import 'package:firebase_analytics/firebase_analytics.dart';
{{#has_router}}import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show PlatformException;
{{/has_router}}
import 'analytics_service.dart';

/// Creates an analytics service that records to Firebase Analytics, which
/// needs Firebase to be initialized.
///
/// The app has one analytics service, which `createAnalyticsService()`
/// returns and which forwards every call to this one.
AnalyticsService createFirebaseAnalyticsService() =>
    FirebaseAnalyticsService(FirebaseAnalytics.instance);

/// Records what users do in the app with Firebase Analytics.
///
/// A sign-in and a sign-up are the standard `login` and `sign_up` events of
/// Firebase Analytics, with the method in their `method` parameter.
final class FirebaseAnalyticsService implements AnalyticsService {
  /// Creates the service on the given [FirebaseAnalytics].
  FirebaseAnalyticsService(this._analytics);

  final FirebaseAnalytics _analytics;

  @override
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) =>
      _analytics.logEvent(name: name, parameters: parameters);

  @override
  Future<void> logSignIn({String? method, Map<String, Object>? parameters}) =>
      _analytics.logLogin(loginMethod: method, parameters: parameters);

  @override
  Future<void> logSignUp({
    required String method,
    Map<String, Object>? parameters,
  }) =>
      _analytics.logSignUp(signUpMethod: method, parameters: parameters);

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) =>
      _analytics.setAnalyticsCollectionEnabled(enabled);

  @override
  Future<void> setUserId(String? userId) => _analytics.setUserId(id: userId);

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) =>
      _analytics.setUserProperty(name: name, value: value);
}{{#has_router}}

/// Logs a screen view to Firebase Analytics for the screen the user sees,
/// which the router of the app tells it about, named by the full name of
/// its route, such as `home.home`.
///
/// A screen that is no route of a module is the fallback start screen of
/// the app, logged as `/`, or the error screen of the router, which is not
/// logged: the location that the app cannot show may hold anything, such
/// as a token of a link.
///
/// Nothing waits for the screen view, so an error of the platform is
/// printed rather than left to the handler of the uncaught errors of the
/// app.
void logFirebaseScreenView(String? route, String location) {
  final name = route ?? (Uri.parse(location).path == '/' ? '/' : null);
  if (name == null) return;
  FirebaseAnalytics.instance.logScreenView(screenName: name).catchError(
    (Object error) => debugPrint('Firebase Analytics: $error'),
    test: (error) => error is PlatformException,
  );
}{{/has_router}}
