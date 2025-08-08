import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_get_it/bundles/smf_get_it_brick_bundle.dart';
import 'package:smf_get_it/src/di_dsl_generator.dart';

class SmfGetItModule
    with EmptyModuleCodeContributor, DiDslGenerator
    implements IModuleCodeContributor, DslAwareCodeGenerator {
  @override
  List<BrickContribution> get brickContributions => [
    BrickContribution(name: 'get_it', bundle: smfGetItBrickBundle),
  ];

  @override
  ModuleDescriptor get moduleDescriptor => ModuleDescriptor(
    name: kGetItModule,
    description: 'Get it service locator',
    pubDependency: {'get_it: ^8.0.3'},
  );

  @override
  List<Contribution> get sharedFileContributions => [
    InsertImport(
      file: 'lib/main.dart',
      import: "import 'package:{{app_name_sc}}/core/di/core_di.dart';",
    ),
    InsertIntoFunction(
      file: 'lib/main.dart',
      function: 'main',
      afterStatement: 'WidgetsFlutterBinding.ensureInitialized',
      insert: "setUpCoreDI();",
    ),
  ];
}
