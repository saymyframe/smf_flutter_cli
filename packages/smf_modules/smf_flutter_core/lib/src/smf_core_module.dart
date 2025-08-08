import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/bundles/smf_flutter_core_bundle.dart';

class SmfCoreModule
    with EmptyModuleCodeContributor
    implements IModuleCodeContributor {
  @override
  List<BrickContribution> get brickContributions => [
    BrickContribution(name: 'flutter_core', bundle: smfFlutterCoreBundle),
  ];

  @override
  ModuleDescriptor get moduleDescriptor => ModuleDescriptor(
    name: kFlutterCoreModule,
    description: 'Core Flutter application module module',
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
