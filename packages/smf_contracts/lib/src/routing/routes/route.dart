import 'package:smf_contracts/src/routing/routing.dart';

/// A route with a path and, usually, a screen it builds.
class Route extends BaseRoute {
  /// Creates a route for [path].
  const Route({
    required this.path,
    super.screen,
    this.parameters = const [],
    this.meta,
    super.name,
    super.guards,
    super.imports,
  });

  /// Location pattern of the route, for example `'/users/:id'`.
  ///
  /// Declare every `:name` segment in [parameters]. The routing module also
  /// generates a constant with this path.
  final String path;

  /// Parameters that the route reads from its location, which
  /// [RouteScreen.screenArguments] pass to the screen.
  final List<RouteParameter> parameters;

  /// How the route appears as an entry of a navigation shell; required for
  /// the children of a [NestedRoute] in a tab-bar shell.
  final RouteMeta? meta;
}
