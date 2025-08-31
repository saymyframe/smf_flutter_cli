import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_go_router/src/module.dart';

class SmfGoRouterFactory implements IModuleContributorFactory {
  @override
  IModuleCodeContributor create(ModuleProfile profile) {
    return SmfGoRouterModule();
  }

  @override
  bool supports(ModuleProfile profile) {
    return true;
  }
}
