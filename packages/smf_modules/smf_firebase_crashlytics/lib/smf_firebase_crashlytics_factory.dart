import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_crashlytics/src/smf_firebase_crashlytics_module.dart';

/// Creates the [SmfFirebaseCrashlyticsModule], which is the same for every
/// profile.
class SmfFirebaseCrashlyticsFactory implements IModuleContributorFactory {
  @override
  IModuleCodeContributor create(ModuleProfile profile) {
    return SmfFirebaseCrashlyticsModule();
  }

  @override
  bool supports(ModuleProfile profile) => true;
}
