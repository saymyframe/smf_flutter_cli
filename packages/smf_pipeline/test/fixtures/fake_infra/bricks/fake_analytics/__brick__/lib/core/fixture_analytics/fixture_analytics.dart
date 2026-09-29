import 'package:flutter/widgets.dart';

import '../analytics/analytics_service.dart';

/// Creates the analytics service of the fixture, which logs nothing.
AnalyticsService createFixtureAnalytics() => const FixtureAnalytics();

/// A navigator observer that the fixture adds to every navigator, which
/// notes the routes that come on its navigator.
final class FixtureObserver extends NavigatorObserver {
  /// Creates the observer, which [fixtureObservers] notes.
  FixtureObserver() {
    fixtureObservers.add(this);
  }

  /// The names of the routes pushed on the navigator of the observer, in
  /// order: for a page of the router, the full name of its route.
  final List<String?> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushed.add(route.settings.name);
}

/// The navigator observers of the fixture, in the order the router created
/// them: one for each navigator.
final List<FixtureObserver> fixtureObservers = [];

/// The screens the user saw, as the screen listener of the fixture heard of
/// them: the full name of the route of each, or `null`, and its location.
final List<(String?, String)> fixtureScreens = [];

/// Analytics that logs nothing.
final class FixtureAnalytics implements AnalyticsService {
  /// Creates the service.
  const FixtureAnalytics();

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
