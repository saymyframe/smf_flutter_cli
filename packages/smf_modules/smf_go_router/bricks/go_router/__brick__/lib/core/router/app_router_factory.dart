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
    // An observer can watch only one navigator, so the navigator gets
    // instances of its own.
    observers: [
      for (final create in <NavigatorObserver Function()>[
{{{smf_router__observers}}}
      ])
        create(),
    ],
    routes: [
{{{routes}}}
    ],
  );

  @override
  AppNavigator navigatorOf(BuildContext context) => this;

  @override
  void go(AppLocation location) => config.go(location.path);

  @override
  Future<T?> push<T extends Object?>(AppLocation location) =>
      config.push<T>(location.path);

  @override
  void replace(AppLocation location) =>
      config.pushReplacement<Object?>(location.path);
}
{{{value_checks}}}
