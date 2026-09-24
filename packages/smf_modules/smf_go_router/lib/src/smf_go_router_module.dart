import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_contribution_engine/smf_contribution_engine.dart';
import 'package:smf_go_router/bundles/smf_go_router_bundle.dart';
import 'package:smf_go_router/src/go_router_dsl_generator.dart';

/// The go_router module: ships the router and tabs shell templates, switches
/// `MainApp` in `lib/main.dart` to `MaterialApp.router` with the generated
/// router, and renders the routes that modules declare with the routing DSL
/// (see [GoRouterDslGenerator]).
class SmfGoRouterModule
    with EmptyModuleCodeContributor, GoRouterDslGenerator
    implements IModuleCodeContributor, DslAwareCodeGenerator {
  @override
  List<BrickContribution> get brickContributions => [
        BrickContribution(name: 'go router', bundle: smfGoRouterBundle),
      ];

  @override
  ModuleDescriptor get moduleDescriptor => const ModuleDescriptor(
        name: kGoRouterModule,
        description: 'SMF GoRouter Code-Aware Generator Module',
        pubDependency: {'go_router: ^16.0.0'},
      );

  @override
  List<Contribution> get sharedFileContributions => [
        const InsertImport(
          file: 'lib/main.dart',
          import:
              "import 'package:{{app_name_sc}}/core/router/app_router.dart';",
        ),
        const ReplaceWidget(
          file: 'lib/main.dart',
          fromWidget: 'MaterialApp',
          toWidget: 'MaterialApp.router',
          className: 'MainApp',
          methodName: 'build',
        ),
        const ModifyWidgetArguments(
          file: 'lib/main.dart',
          widgetName: 'router',
          removeArgs: ['home'],
          addArgs: {'routerConfig': 'router'},
        ),
      ];
}
