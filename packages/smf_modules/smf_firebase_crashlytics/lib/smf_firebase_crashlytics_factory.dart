import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_crashlytics/src/smf_firebase_crashlytics_module.dart';

class SmfFirebaseCrashlyticsFactory implements IModuleContributorFactory {
  @override
  IModuleCodeContributor create(ModuleProfile profile) {
    return SmfFirebaseCrashlyticsModule();
  }

  @override
  bool supports(ModuleProfile profile) => true;
}
