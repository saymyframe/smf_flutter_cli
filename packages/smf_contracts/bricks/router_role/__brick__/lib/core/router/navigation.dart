import 'package:flutter/widgets.dart';

import 'app_router.dart';

/// A place in the app: a route with the values of its parameters.
///
/// Every route of the app has a location class, such as
/// `HomeDetailsLocation` for the route `home.details`.
sealed class AppLocation {
  /// Allows the location classes to have constant constructors.
  const AppLocation();

  /// The full name of the route, such as `home.details`.
  String get routeName;

  /// The location as a path with its query, such as `/home/details/5`.
  String get path;

  /// The location of the parent route, or `null` for a top-level route.
  AppLocation? get parent => null;

  /// The locations from the top-level route down to this one: the stack
  /// that [NavLink.go] shows.
  List<AppLocation> get chain => [...?parent?.chain, this];
}

/// A location and the context that navigates to it, as the routes of
/// `context.nav` return them.
final class NavLink {
  /// Creates the link to [location] from [context].
  const NavLink(this._context, this.location);

  final BuildContext _context;

  /// The location to navigate to.
  final AppLocation location;

  /// Shows [location] with the chain of its parents below it as the stack.
  void go() => appRouter.navigatorOf(_context).go(location);

  /// Shows [location] on top of the current stack and completes with the
  /// value the page returns when it closes.
  Future<T?> push<T extends Object?>() =>
      appRouter.navigatorOf(_context).push<T>(location);

  /// Replaces the top of the current stack with [location].
  void replace() => appRouter.navigatorOf(_context).replace(location);
}
{{{facade}}}
