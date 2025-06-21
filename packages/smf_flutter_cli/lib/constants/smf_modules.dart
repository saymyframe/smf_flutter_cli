import 'package:smf_firebase_analytics/smf_firebase_analytics.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';

final smfModules = <String, IModuleCodeContributor>{
  kFirebaseCore: FirebaseCoreModule(),
  kFirebaseAnalytics: FirebaseAnalyticsModule(),
  // kFirebaseAuthModule ,
  // kFirebaseCrashlytics,
};

const smfStateManagers = <String>[
  kBlocStateManagement,
  kRiverpodStateManagement,
];
