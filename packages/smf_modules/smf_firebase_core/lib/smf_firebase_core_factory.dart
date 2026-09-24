import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/src/firebase_core_module.dart';

/// Creates the [FirebaseCoreModule], which is the same for every profile.
class SmfFirebaseCoreFactory implements IModuleContributorFactory {
  @override
  IModuleCodeContributor create(ModuleProfile profile) {
    return FirebaseCoreModule();
  }

  @override
  bool supports(ModuleProfile profile) {
    return true;
  }
}
