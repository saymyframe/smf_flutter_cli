import 'package:smf_contracts/lego.dart';
import 'package:smf_go_router/bundles/go_router_bundle.dart';
import 'package:smf_go_router/src/go_routes.dart';

/// The module that routes the app with go_router, and so provides the
/// router role.
///
/// It adds `go_router` to the dependencies of the app and generates
/// `createAppRouter()` in `lib/core/router/app_router_factory.dart`, which
/// creates the router of the app once, on first use: a `GoRouter` with the
/// routes that the modules of the app declare, each under the namespace of
/// its module, named by its full name, such as `home.details`, and with its
/// screen imported with a prefix of its own. The path `/` redirects to the
/// route the app starts on, or shows the fallback screen of the app entry
/// when no route can start the app, so an app without features shows that
/// screen through the router. The app opens on the start route.
///
/// Screens get the values of their parameters from the location, parsed
/// with `tryParse`: an optional value that the location does not have, or
/// not of its type, is `null`, and a location without a valid required
/// value shows the error screen of the router.
///
/// The navigation facade goes through the same router whatever the context
/// it navigates from: `go()` goes to the path of a location, which makes
/// the chain of its parents the stack, `push()` pushes it, and `replace()`
/// replaces the top of the stack with it, as `pushReplacement` of go_router
/// does. The root navigator creates its navigator observers from the
/// factories of the router role once.
final class GoRouterModule extends SmfModule {
  /// Creates the module.
  const GoRouterModule();

  /// The id of the module.
  static const id = ModuleId('go_router');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Routes and navigation with go_router',
        kind: ModuleKinds.infrastructure,
        providers: [_GoRouterProvider()],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(goRouterBundle),
        const PubspecContribution.hosted('go_router', '^17.5.0'),
      ];
}

/// Renders the routes of the app into the brick of the module.
final class _GoRouterProvider extends RoleProvider<RoutesData> {
  const _GoRouterProvider();

  @override
  Role<RoutesData> get role => routerRole;

  @override
  RoleOutput render(RoleHookInput<RoutesData> input) {
    final routes = GoRoutes.of(
      routerRole.facadeOf(input),
      start: routerRole.startIn(input),
    );
    return RoleOutput(
      vars: {
        'initial_location': routes.initialLocation,
        'routes': routes.routes,
        'value_checks': routes.valueChecks,
      },
    );
  }
}
