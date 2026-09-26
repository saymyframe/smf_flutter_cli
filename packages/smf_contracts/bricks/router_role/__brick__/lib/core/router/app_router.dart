import 'package:flutter/widgets.dart';

import 'app_router_factory.dart';
import 'navigation.dart';

/// The router of the app, created on first use.
final AppRouter appRouter = createAppRouter();

/// The router of the app: its configuration for `MaterialApp.router` and the
/// navigation that screens use through `context.nav`.
abstract interface class AppRouter {
  /// The configuration that `MaterialApp.router` takes as `routerConfig`.
  RouterConfig<Object> get config;

  /// The navigator that [context] navigates with.
  AppNavigator navigatorOf(BuildContext context);
}

/// Moves between the locations of the app.
abstract interface class AppNavigator {
  /// Shows [location] with the chain of its parents below it as the stack.
  ///
  /// In the main navigation, it selects the branch of [location] and makes
  /// the chain its stack; for a location outside the main navigation, the
  /// chain replaces the whole stack, main navigation included.
  void go(AppLocation location);

  /// Shows [location] on top of the current stack and completes with the
  /// value the page returns when it closes.
  ///
  /// In the main navigation, the current stack is that of the selected
  /// branch, whichever branch [location] belongs to, and the selected
  /// destination stays; a location outside the main navigation is shown
  /// over it. A location in the main navigation goes only on top of the
  /// main navigation itself: from a page shown over it, this throws a
  /// [StateError] and leaves the stack as it is, so [go] to the location
  /// instead. From a page with no main navigation below it, the main
  /// navigation comes on top with the location.
  Future<T?> push<T extends Object?>(AppLocation location);

  /// Replaces the top of the current stack with [location].
  ///
  /// As with [push], a location in the main navigation cannot replace a
  /// page shown over the main navigation: this throws a [StateError] and
  /// leaves the stack as it is, so [go] to the location instead.
  void replace(AppLocation location);
}
