import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/src/module.dart';

class SmfFlutterCoreFactory implements IModuleContributorFactory {
  @override
  IModuleCodeContributor create(ModuleProfile profile) {
    return switch (profile.stateManager) {
      StateManager.bloc => SmfCoreModule(),
      StateManager.riverpod => SmfCoreModuleRiverpod(),
    };
  }

  @override
  bool supports(ModuleProfile profile) {
    return switch (profile.stateManager) {
      StateManager.bloc => true,
      StateManager.riverpod => true,
    };
  }
}
