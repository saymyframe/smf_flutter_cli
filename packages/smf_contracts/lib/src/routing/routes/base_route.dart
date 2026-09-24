import 'package:smf_contracts/smf_contracts.dart';

/// Fields shared by the route types, [Route] and [NestedRoute].
///
/// Routing modules generate code only for these two types.
abstract class BaseRoute {
  /// Initializes the fields shared by all routes.
  const BaseRoute({
    this.screen,
    this.name,
    this.guards = const [],
    this.imports = const [],
  });

  /// Name of the route for named navigation, for example `'homeScreen'`;
  /// only a [Route] has one.
  ///
  /// The routing module also generates a constant named after it (for
  /// go_router, in the `AppRoutes` class), so it must be a valid Dart
  /// identifier and unique in the app.
  final String? name;

  /// The widget the route builds; only a [Route] has one.
  final RouteScreen? screen;

  /// Guards checked before navigating to this route.
  ///
  /// The guards of a [NestedRoute] apply to each of its own children, not to
  /// the shell, so they never guard routes of other modules.
  final List<RouteGuard> guards;

  /// Imports that the generated router needs for this route, such as the
  /// file of its screen.
  final List<Import> imports;
}
