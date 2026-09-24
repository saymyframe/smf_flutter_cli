import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_analytics/bundles/smf_firebase_analytics_bloc_bundle.dart';
import 'package:smf_firebase_analytics/bundles/smf_firebase_analytics_brick_bundle.dart';
import 'package:smf_firebase_analytics/bundles/smf_firebase_analytics_riverpod_bundle.dart';

/// Firebase Analytics: the analytics service plus a demo screen built with
/// the chosen state manager, so the UI only talks to that layer.
abstract class FirebaseAnalyticsModule
    with EmptyModuleCodeContributor
    implements IModuleCodeContributor {
  /// Demo feature brick for the chosen state manager.
  BrickContribution get featureBrick;

  /// Pub dependency of the chosen state manager.
  String get stateManagerDependency;

  @override
  List<BrickContribution> get brickContributions => [
        BrickContribution(
          name: 'firebase_analytics',
          bundle: smfFirebaseAnalyticsBrickBundle,
        ),
        featureBrick,
      ];

  @override
  ModuleDescriptor get moduleDescriptor => ModuleDescriptor(
        name: kFirebaseAnalytics,
        description: 'Firebase Analytics module',
        dependsOn: {kFirebaseCore, kGetItModule, kGoRouterModule},
        pubDependency: {'firebase_analytics: ^12.0.1', stateManagerDependency},
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

class FirebaseAnalyticsBlocModule extends FirebaseAnalyticsModule {
  @override
  BrickContribution get featureBrick => BrickContribution(
        name: 'firebase_analytics bloc',
        bundle: smfFirebaseAnalyticsBlocBundle,
      );

  @override
  String get stateManagerDependency => 'flutter_bloc: ^9.1.1';
}

class FirebaseAnalyticsRiverpodModule extends FirebaseAnalyticsModule {
  @override
  BrickContribution get featureBrick => BrickContribution(
        name: 'firebase_analytics riverpod',
        bundle: smfFirebaseAnalyticsRiverpodBundle,
      );

  @override
  String get stateManagerDependency => 'flutter_riverpod: ^2.5.1';
}
