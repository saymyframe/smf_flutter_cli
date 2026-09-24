import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/bundles/smf_flutter_core_bundle.dart';
import 'package:smf_flutter_core/bundles/smf_flutter_riverpod_bundle.dart';

class SmfCoreModuleRiverpod
    with EmptyModuleCodeContributor
    implements IModuleCodeContributor {
  @override
  List<BrickContribution> get brickContributions => [
        BrickContribution(
          name: 'flutter_core',
          bundle: smfFlutterCoreBundle,
        ),
        BrickContribution(
          name: 'smf flutter core riverpod',
          bundle: smfFlutterRiverpodBundle,
        ),
      ];

  @override
  ModuleDescriptor get moduleDescriptor => ModuleDescriptor(
        name: kFlutterCoreModule,
        description: 'Core Flutter application module module with riverpod',
        pubDependency: {'flutter_riverpod: ^2.5.1'},
      );

  @override
  RouteGroup get routes => RouteGroup(
        initialRoute: '/noModules',
        routes: [
          Route(
            path: '/noModules',
            screen: RouteScreen('NoModulesScreen'),
            imports: [
              Import.core(ImportAnchor.coreWidgets, 'no_modules_screen.dart'),
            ],
          ),
        ],
      );
}
