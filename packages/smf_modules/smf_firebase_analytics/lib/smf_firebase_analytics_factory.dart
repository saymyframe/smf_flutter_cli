import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_analytics/src/module.dart';

class SmfFirebaseAnalyticsFactory implements IModuleContributorFactory {
  @override
  IModuleCodeContributor create(ModuleProfile profile) {
    return switch (profile.stateManager) {
      StateManager.bloc => FirebaseAnalyticsBlocModule(),
      StateManager.riverpod => FirebaseAnalyticsRiverpodModule(),
    };
  }

  @override
  bool supports(ModuleProfile profile) {
    return true;
  }
}
