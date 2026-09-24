import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_get_it/src/module.dart';

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
