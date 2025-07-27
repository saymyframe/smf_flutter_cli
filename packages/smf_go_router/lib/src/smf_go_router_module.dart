import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_go_router/bundles/smf_go_router_bundle.dart';
import 'package:smf_go_router/src/go_router_dsl_generator.dart';

class SmfGoRouterModule
    with EmptyModuleCodeContributor, GoRouterDslGenerator
    implements IModuleCodeContributor, DslAwareCodeGenerator {
  @override
  List<BrickContribution> get brickContributions => [
    BrickContribution(name: 'go router', bundle: smfGoRouterBundle),
  ];

  @override
  ModuleDescriptor get moduleDescriptor => ModuleDescriptor(
    name: kGoRouterModule,
    description: 'SMF GoRouter Code-Aware Generator Module',
    pubDependency: {'go_router: ^16.0.0'},
  );

  RouteGroup get routes => RouteGroup(
    routes: [
      Route(
        path: '/',
        guards: [
          RouteGuard(
            bindings: {RoutingMode.goRouter: GoRouteRedirect(code: "'/home'")},
          ),
        ],
      ),
    ],
  );
}
