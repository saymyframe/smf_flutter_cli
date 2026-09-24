import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_event_bus/src/module.dart';

/// Creates the [SmfEventBusModule], which is the same for every profile.
class SmfEventBusFactory implements IModuleContributorFactory {
  @override
  IModuleCodeContributor create(ModuleProfile profile) {
    return SmfEventBusModule();
  }

  @override
  bool supports(ModuleProfile profile) {
    return true;
  }
}
