import 'package:smf_analytics/smf_analytics.dart';
import 'package:smf_communication/smf_communication.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_get_it/smf_get_it.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_home_flutter/smf_home_flutter.dart';

final smfModules = <String, IModuleCodeContributor>{
  kFirebaseCore: FirebaseCoreModule(),
  kFirebaseAnalytics: FirebaseAnalyticsModule(),
  kFlutterCoreModule: SmfCoreModule(),
  kGetItModule: SmfGetItModule(),
  kCommunicationModule: SmfCommunicationModule(),
  kGoRouterModule: SmfGoRouterModule(),
  kHomeFeatureModule: SmfHomeFlutterModule(),
  // kFirebaseCrashlytics,
};

const smfStateManagers = <String>[
  kBlocStateManagement,
  kRiverpodStateManagement,
];
