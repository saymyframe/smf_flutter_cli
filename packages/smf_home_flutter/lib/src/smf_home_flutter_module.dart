import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_home_flutter/bundles/smf_home_bloc_bundle.dart';

class SmfHomeFlutterModule
    with EmptyModuleCodeContributor
    implements IModuleCodeContributor {
  @override
  List<BrickContribution> get brickContributions => [
    BrickContribution(name: 'smf home module', bundle: smfHomeBlocBundle),
  ];

  @override
  ModuleDescriptor get moduleDescriptor => ModuleDescriptor(
    name: kHomeFeatureModule,
    description: 'Flutter home feature',
    pubDependency: {'flutter_bloc: ^9.1.1', 'freezed_annotation: ^3.1.0'},
    pubDevDependency: {'build_runner: ^2.5.4', 'freezed: ^3.1.0'},
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
