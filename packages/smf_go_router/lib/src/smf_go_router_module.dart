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

  @override
  List<Contribution> get sharedFileContributions => [
    InsertImport(
      file: 'lib/main.dart',
      import: "import 'package:{{app_name_sc}}/core/router/app_router.dart';",
    ),

    ReplaceWidget(
      file: 'lib/main.dart',
      fromWidget: 'MaterialApp',
      toWidget: 'MaterialApp.router',
      className: 'MainApp',
      methodName: 'build',
    ),
    ModifyWidgetArguments(
      file: 'lib/main.dart',
      widgetName: 'router',
      removeArgs: ['home'],
      addArgs: {'routerConfig': 'router'},
    ),
  ];
}
