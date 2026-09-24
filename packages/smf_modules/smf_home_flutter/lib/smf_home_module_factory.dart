import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_home_flutter/src/module.dart';

class SmfHomeModuleFactory implements IModuleContributorFactory {
  @override
  IModuleCodeContributor create(ModuleProfile profile) {
    // I'm aware this breaks the SOLID OCP Principle.
    // Avoiding it would require a significantly more complex architecture
    // with many entities, so this pragmatic approach is acceptable for now.
    return switch (profile.stateManager) {
      StateManager.bloc => SmfHomeBlocModule(),
      StateManager.riverpod => SmfHomeRiverpodModule(),
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
