import 'package:smf_contracts/smf_contracts.dart';

/// The routes a module adds to the app, returned from
/// [IModuleCodeContributor.routes].
///
/// The routing module merges the groups of all selected modules into one
/// router, so a module declares only its own routes.
class RouteGroup {
  /// Creates a group of [routes], optionally suggesting an [initialRoute].
  const RouteGroup({
    required this.routes,
    this.initialRoute,
    this.coreGuards = const [],
  });

  /// A group without routes, for modules that add no navigation.
  factory RouteGroup.empty() => const RouteGroup(routes: []);

  /// Path this module suggests as the app's start location, such as
  /// `'/home'`.
  ///
  /// When several selected modules suggest one, the CLI asks the user to
  /// pick; its `--route` option overrides all suggestions. The result is
  /// [DslContext.initialRoute].
  final String? initialRoute;

  /// The routes of this module: [Route]s and [NestedRoute]s.
  final List<BaseRoute> routes;

  /// Guards that apply to every route of the app, not only to this module's.
  ///
  /// They are combined into the router-wide redirect. Use [BaseRoute.guards]
  /// to guard only this module's routes.
  final List<RouteGuard> coreGuards;
}
