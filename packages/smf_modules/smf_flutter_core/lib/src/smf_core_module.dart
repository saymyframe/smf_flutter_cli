import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/bundles/smf_flutter_core_bundle.dart';

/// The Flutter app that every project starts from, as used with bloc: the
/// platform folders, `lib/main.dart` and a `/noModules` screen for a project
/// without feature modules.
class SmfCoreModule
    with EmptyModuleCodeContributor
    implements IModuleCodeContributor {
  @override
  List<BrickContribution> get brickContributions => [
        BrickContribution(name: 'flutter_core', bundle: smfFlutterCoreBundle),
      ];

  @override
  ModuleDescriptor get moduleDescriptor => const ModuleDescriptor(
        name: kFlutterCoreModule,
        description: 'Core Flutter application module module',
      );

  @override
  RouteGroup get routes => const RouteGroup(
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
