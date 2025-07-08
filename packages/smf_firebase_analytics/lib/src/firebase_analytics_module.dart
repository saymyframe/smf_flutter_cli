import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_analytics/bundles/smf_firebase_analytics_brick_bundle.dart';
import 'package:smf_sharable_bricks/smf_sharable_bricks.dart';

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
      bundle: smfBootstrapBrickBundle,
      slot: SharableCodeSlots.imports.slot,
      content: '''
      import 'package:firebase_analytics/firebase_analytics.dart';
      import 'package:package_info_plus/package_info_plus.dart';
      ''',
    ),
    SharedFileContribution(
      bundle: smfBootstrapBrickBundle,
      slot: SharableCodeSlots.bootstrap.slot,
      content: '''
      // Firebase Analytics -------------
      final analytics = FirebaseAnalytics.instance;
          // TODO: refactor to a separate service
    final info = await PackageInfo.fromPlatform();
    await analytics.setDefaultEventParameters({
      'app_version': info.version,
      'build_number': info.buildNumber,
      'platform': Platform.operatingSystem,
    });
    // Firebase Analytics EMD -------------
      ''',
    ),

    SharedFileContribution(
      bundle: smfCoreDiBrickBundle,
      slot: SharableCodeSlots.imports.slot,
      content: '''
      import 'package:{{app_name_sc}}/services/analytics/firebase/firebase_analytics_service.dart';
      import 'package:{{app_name_sc}}/services/analytics/i_analytics_service.dart';
      ''',
    ),
    SharedFileContribution(
      bundle: smfCoreDiBrickBundle,
      slot: SharableCodeSlots.di.slot,
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
