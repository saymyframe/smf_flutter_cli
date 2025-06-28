import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_analytics/bundles/firebase_analytics_bundle.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';

class FirebaseAnalyticsModule implements IModuleCodeContributor {
  @override
  List<BrickContribution> get brickContributions => [
    BrickContribution(
      name: 'firebase_analytics',
      bundle: firebaseAnalyticsBundle,
      vars: {'init_block': 'await Firebase.initializeApp();'},
    ),
  ];

  @override
  List<SharedFileContribution> get sharedFileContributions => [];

  @override
  ModuleDescriptor get moduleDescriptor => ModuleDescriptor(
    name: kFirebaseAnalytics,
    description: 'Firebase Analytics module',
    dependsOn: [kFirebaseCore],
    pubDependency: ['firebase_analytics'],
  );
}
