import 'package:smf_contracts/src/routing/routing.dart';

/// A navigation guard, implemented for each routing library it supports.
///
/// A module does not know which routing module the project uses, so a guard
/// maps every [RoutingMode] it supports to an implementation, and the
/// routing module picks the one for its mode. The go_router module fails
/// generation for a guard without a [GoRouteRedirect] under
/// [RoutingMode.goRouter].
///
/// Attach guards to routes with [BaseRoute.guards], or to the whole app with
/// [RouteGroup.coreGuards].
class RouteGuard {
  /// Creates a guard from its per-library [bindings].
  const RouteGuard({required this.bindings});

  /// Implementation of this guard for each supported routing library.
  final Map<RoutingMode, GuardImplementation> bindings;
}
