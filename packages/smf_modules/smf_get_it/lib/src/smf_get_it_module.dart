import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_contribution_engine/smf_contribution_engine.dart';
import 'package:smf_get_it/bundles/smf_get_it_brick_bundle.dart';
import 'package:smf_get_it/src/di_dsl_generator.dart';

/// Sets the app up with get_it and registers the dependencies that modules
/// declare in their `di`.
///
/// Its brick adds the `getIt` instance and `lib/core/di/core_di.dart` with
/// `setUpCoreDI()`, which `main()` calls right after
/// `WidgetsFlutterBinding.ensureInitialized()`. [generateFromDsl] then fills
/// in the registrations. It knows no other module: whatever
/// [DiDependencyGroup]s the context carries get registered.
class SmfGetItModule
    with EmptyModuleCodeContributor, DiDslGenerator
    implements IModuleCodeContributor, DslAwareCodeGenerator {
  @override
  List<BrickContribution> get brickContributions => [
        BrickContribution(name: 'get_it', bundle: smfGetItBrickBundle),
      ];

  @override
  ModuleDescriptor get moduleDescriptor => const ModuleDescriptor(
        name: kGetItModule,
        description: 'Get it service locator',
        pubDependency: {'get_it: ^8.0.3'},
      );

  @override
  List<Contribution> get sharedFileContributions => [
        const InsertImport(
          file: 'lib/main.dart',
          import: "import 'package:{{app_name_sc}}/core/di/core_di.dart';",
        ),
        const InsertIntoFunction(
          file: 'lib/main.dart',
          function: 'main',
          afterStatement: 'WidgetsFlutterBinding.ensureInitialized',
          insert: 'setUpCoreDI();',
        ),
      ];
}
