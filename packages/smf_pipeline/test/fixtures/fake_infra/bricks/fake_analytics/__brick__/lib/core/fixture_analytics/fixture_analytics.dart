import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../analytics/analytics_service.dart';

/// The platform side of the analytics of the fixture, which only the mocks
/// of its own tests answer, as only the tests of a plugin know its
/// platform side.
const fixtureAnalyticsChannel = MethodChannel('smf.fixture/analytics');

/// Creates the analytics service of the fixture once its platform side has
/// started.
Future<AnalyticsService> initFixtureAnalytics() async {
  await fixtureAnalyticsChannel.invokeMethod<void>('start');
  return const FixtureAnalytics();
}

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

/// Whether the screen listener of the fixture throws once it noted a
/// screen, as a test that a listener of the screen that throws keeps no
/// other from hearing it sets it.
bool fixtureScreensThrow = false;

/// The screen listener of the fixture: notes the screen of [route] at
/// [location] in [fixtureScreens], and then throws if
/// [fixtureScreensThrow].
void noteFixtureScreen(String? route, String location) {
  fixtureScreens.add((route, location));
  if (fixtureScreensThrow) {
    throw StateError('The screen listener of the fixture analytics throws.');
  }
}

/// Analytics that sends what it records to its platform side.
final class FixtureAnalytics implements AnalyticsService {
  /// Creates the service.
  const FixtureAnalytics();

  @override
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) =>
      _record('logEvent', {'name': name, 'parameters': parameters});

  @override
  Future<void> logSignIn({
    String? method,
    Map<String, Object>? parameters,
  }) =>
      _record('logSignIn', {'method': method, 'parameters': parameters});

  @override
  Future<void> logSignUp({
    required String method,
    Map<String, Object>? parameters,
  }) =>
      _record('logSignUp', {'method': method, 'parameters': parameters});

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) =>
      _record('setAnalyticsCollectionEnabled', {'enabled': enabled});

  @override
  Future<void> setUserId(String? userId) =>
      _record('setUserId', {'userId': userId});

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) =>
      _record('setUserProperty', {'name': name, 'value': value});

  Future<void> _record(String method, Map<String, Object?> arguments) =>
      fixtureAnalyticsChannel.invokeMethod<void>(method, arguments);
}
