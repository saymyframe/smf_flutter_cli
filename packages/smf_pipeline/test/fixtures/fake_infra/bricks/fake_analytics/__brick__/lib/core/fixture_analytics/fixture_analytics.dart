import 'package:flutter/widgets.dart';

import '../analytics/analytics_service.dart';

/// Creates the analytics service of the fixture, which logs nothing.
AnalyticsService createFixtureAnalytics() => const _FixtureAnalytics();

/// A navigator observer that the fixture adds to every navigator.
final class FixtureObserver extends NavigatorObserver {}

final class _FixtureAnalytics implements AnalyticsService {
  const _FixtureAnalytics();

  @override
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {}

  @override
  Future<void> logSignIn({
    String? method,
    Map<String, Object>? parameters,
  }) async {}

  @override
  Future<void> logSignUp({
    required String method,
    Map<String, Object>? parameters,
  }) async {}

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {}

  @override
  Future<void> setUserId(String? userId) async {}

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {}
}
