import 'package:smf_contracts/smf_contracts.dart';

class SmfContractsFactory implements IModuleContributorFactory {
  @override
  IModuleCodeContributor create(ModuleProfile profile) {
    return SmfContractsModule();
  }

  @override
  bool supports(ModuleProfile profile) {
    return true;
  }
}
