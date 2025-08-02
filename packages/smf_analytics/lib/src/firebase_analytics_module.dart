import 'package:smf_analytics/bundles/smf_firebase_analytics_brick_bundle.dart';
import 'package:smf_contracts/smf_contracts.dart';

class FirebaseAnalyticsModule
    with EmptyModuleCodeContributor
    implements IModuleCodeContributor {
  @override
  List<BrickContribution> get brickContributions => [
    BrickContribution(
      name: 'firebase_analytics',
      bundle: smfFirebaseAnalyticsBrickBundle,
    ),
  ];

  @override
  ModuleDescriptor get moduleDescriptor => ModuleDescriptor(
    name: kFirebaseAnalytics,
    description: 'Firebase Analytics module',
    dependsOn: {kFirebaseCore, kGetItModule},
    pubDependency: {'firebase_analytics: ^11.5.2'},
  );

  @override
  List<DiDependencyGroup> get di => [
    DiDependencyGroup(
      diDependencies: [
        DiDependency(
          abstractType: 'IAnalyticsService',
          implementation:
              'FirebaseAnalyticsService(FirebaseAnalytics.instance)',
          bindingType: DiBindingType.singleton,
        ),
      ],
      scope: DiScope.core,
      imports: [
        Import.core(
          ImportAnchor.coreService,
          'analytics/firebase/firebase_analytics_service.dart',
        ),
        Import.core(
          ImportAnchor.coreService,
          'analytics/i_analytics_service.dart',
        ),
        Import.direct(
          "import 'package:firebase_analytics/firebase_analytics.dart';",
        ),
      ],
    ),
  ];

  @override
  RouteGroup get routes => RouteGroup(
    initialRoute: '/analytics',
    routes: [
      NestedRoute(
        shellLink: RouteShellLink.toMainTabsShell(),
        children: [
          Route(
            path: '/analytics',
            screen: RouteScreen('AnalyticsScreen'),
            meta: RouteMeta(label: 'Analytics', icon: 'Icons.star'),
            imports: [Import.features('analytics/analytics_screen.dart')],
          ),
        ],
      ),
    ],
  );
}
