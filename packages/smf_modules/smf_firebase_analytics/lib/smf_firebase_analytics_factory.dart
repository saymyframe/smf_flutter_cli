import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_analytics/src/module.dart';

class SmfFirebaseAnalyticsFactory implements IModuleContributorFactory {
  @override
  IModuleCodeContributor create(ModuleProfile profile) {
    return FirebaseAnalyticsModule();
  }

  @override
  bool supports(ModuleProfile profile) {
    return true;
  }
}
