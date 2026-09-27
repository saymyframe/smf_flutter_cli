import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart' show AppNavigator, AppRouter;
import 'navigation.dart' show AppLocation;

/// Creates the router of the app: a [GoRouter] with the routes of the
/// modules of the app.
AppRouter createAppRouter() => _GoAppRouter();

/// The router of the app with go_router, which navigates between the
/// locations of the app too, and tells the listeners of the screen the user
/// sees when it changes.
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
  )..routerDelegate.addListener(_showScreen);

  /// The key of the page on top and its location, as the listeners of the
  /// screen last heard of them.
  (LocalKey?, String)? _screen;

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
  }

  /// Tells the listeners of the screen about the page on top when another
  /// page comes on top, or the page on top shows another location.
  ///
  /// The delegate of go_router notifies its listeners once for each change
  /// of its configuration, a switch of branches included, and may do so
  /// again without a change of the page on top, which the listeners of the
  /// screen do not hear of twice. The location of a pushed page is its own,
  /// as that of the configuration leaves pushed pages out; the error screen
  /// of go_router has no page.
  void _showScreen() {
    final configuration = config.routerDelegate.currentConfiguration;
    final top = configuration.lastOrNull;
    final location = switch (top) {
      ImperativeRouteMatch(:final matches) => matches.uri.toString(),
      _ => configuration.uri.toString(),
    };
    final screen = (top?.pageKey, location);
    if (screen == _screen) return;
    _screen = screen;
    for (final listener in _screenListeners) {
      listener(top?.route.name, location);
    }
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

/// The listeners of the screen the user sees, which get the full name of
/// the route of the screen, or `null` for a screen that is not a route of a
/// module, and its location.
final List<void Function(String? route, String location)> _screenListeners = [
{{{smf_router__screen_listeners}}}
];
{{{value_checks}}}
