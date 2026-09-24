import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_get_it/src/module.dart';

/// Creates the [SmfGetItModule], which is the same for every profile: the
/// get_it setup doesn't depend on the state manager.
class SmfGetItFactory implements IModuleContributorFactory {
  @override
  IModuleCodeContributor create(ModuleProfile profile) {
    return SmfGetItModule();
  }

  @override
  bool supports(ModuleProfile profile) {
    return true;
  }
}
