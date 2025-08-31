import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_home_flutter/bundles/smf_home_riverpod_bundle.dart';

class SmfHomeRiverpodModule
    with EmptyModuleCodeContributor
    implements IModuleCodeContributor {
  @override
  List<BrickContribution> get brickContributions => [
        BrickContribution(
            name: 'smf home riverpod', bundle: smfHomeRiverpodBundle),
      ];

  @override
  ModuleDescriptor get moduleDescriptor => ModuleDescriptor(
        name: kHomeFeatureModule,
        description: 'Flutter home feature',
        dependsOn: {kGoRouterModule},
        pubDependency: {'flutter_riverpod: ^2.5.1'},
      );

  @override
  RouteGroup get routes => RouteGroup(
        initialRoute: '/home',
        routes: [
          NestedRoute(
            shellLink: RouteShellLink.toMainTabsShell(),
            children: [
              Route(
                path: '/home',
                name: 'homeScreen',
                screen: RouteScreen('HomeScreen'),
                meta: RouteMeta(label: 'Home', icon: 'Icons.home', order: 0),
                imports: [Import.features('home/home_screen.dart')],
              ),
            ],
          ),
        ],
      );
}
