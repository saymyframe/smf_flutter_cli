import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart' show AppNavigator, AppRouter;
import 'navigation.dart' show AppLocation;

/// Creates the router of the app: a [GoRouter] with the routes of the
/// modules of the app.
AppRouter createAppRouter() => _GoAppRouter();

/// The router of the app with go_router, which navigates between the
/// locations of the app too.
final class _GoAppRouter implements AppRouter, AppNavigator {
  /// The router, created once, on first use. Navigation goes through it
  /// rather than through the router above a context, so that any context
  /// can navigate, even one above the router.
  @override
  late final GoRouter config = GoRouter(
    initialLocation: {{{initial_location}}},
    observers: _observers(),
    routes: [
{{{routes}}}
    ],
  );

  @override
  AppNavigator navigatorOf(BuildContext context) => this;

  @override
  void go(AppLocation location) => config.go(location.path);

  @override
  Future<T?> push<T extends Object?>(AppLocation location) {
    {{#main_navigation}}_checkMainNavigation(location, 'push');
    {{/main_navigation}}return config.push<T>(location.path);
  }

  @override
  void replace(AppLocation location) {
    {{#main_navigation}}_checkMainNavigation(location, 'replace');
    {{/main_navigation}}config.pushReplacement<Object?>(location.path);
  }{{#main_navigation}}

  /// Throws a [StateError] instead of showing [location] of the main
  /// navigation on top of a page that is shown over the main navigation:
  /// go_router shows the main navigation once, so a location in it goes
  /// only on top of the main navigation itself.
  void _checkMainNavigation(AppLocation location, String method) {
    final matches = config.routerDelegate.currentConfiguration.matches;
    if (matches.isEmpty ||
        matches.last is ShellRouteMatch ||
        !matches.any((match) => match is ShellRouteMatch)) {
      return;
    }
    final target = config.configuration.findMatch(Uri.parse(location.path));
    if (target.matches.firstOrNull is! ShellRouteMatch) return;
    throw StateError(
      'Cannot $method ${location.path}: it is in the main navigation, and a '
      'page is shown over the main navigation. Use go() to show it there.',
    );
  }{{/main_navigation}}
}

/// Creates the observers of a navigator. An observer can watch only one
/// navigator, so each navigator gets instances of its own.
List<NavigatorObserver> _observers() => [
  for (final create in <NavigatorObserver Function()>[
{{{smf_router__observers}}}
  ])
    create(),
];
{{{value_checks}}}
