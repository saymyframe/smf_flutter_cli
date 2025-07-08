import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_analytics/smf_firebase_analytics.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_get_it/smf_get_it.dart';

final smfModules = <String, IModuleCodeContributor>{
  kFirebaseCore: FirebaseCoreModule(),
  kFirebaseAnalytics: FirebaseAnalyticsModule(),
  kFlutterCoreModule: SmfCoreModule(),
  kGetItModule: SmfGetItModule(),
  // kFirebaseCrashlytics,
};

const smfStateManagers = <String>[
  kBlocStateManagement,
  kRiverpodStateManagement,
];
