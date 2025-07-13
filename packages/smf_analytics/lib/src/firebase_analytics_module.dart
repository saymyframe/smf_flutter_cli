import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_sharable_bricks/smf_sharable_bricks.dart';

import '../bundles/smf_firebase_analytics_brick_bundle.dart';

class FirebaseAnalyticsModule implements IModuleCodeContributor {
  @override
  List<BrickContribution> get brickContributions => [
    BrickContribution(
      name: 'firebase_analytics',
      bundle: smfFirebaseAnalyticsBrickBundle,
    ),
  ];

  @override
  List<SharedFileContribution> get sharedFileContributions => [
    SharedFileContribution(
      bundle: smfCoreDiBrickBundle,
      slot: CoreDiSharedCodeSlots.imports,
      content: '''
      import 'package:{{app_name_sc}}/services/analytics/firebase/firebase_analytics_service.dart';
      import 'package:{{app_name_sc}}/services/analytics/i_analytics_service.dart';
      import 'package:firebase_analytics/firebase_analytics.dart';
      ''',
    ),
    SharedFileContribution(
      bundle: smfCoreDiBrickBundle,
      slot: CoreDiSharedCodeSlots.di,
      content: '''
        getIt.registerLazySingleton<IAnalyticsService>(
        () => FirebaseAnalyticsService(FirebaseAnalytics.instance),
        );
      ''',
    ),
  ];

  @override
  ModuleDescriptor get moduleDescriptor => ModuleDescriptor(
    name: kFirebaseAnalytics,
    description: 'Firebase Analytics module',
    dependsOn: {kFirebaseCore, kGetItModule},
    pubDependency: {'firebase_analytics: ^11.5.2'},
  );
}
