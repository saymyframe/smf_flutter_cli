import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_analytics/src/module.dart';

/// Creates the Firebase Analytics module for the profile's state manager:
/// [FirebaseAnalyticsBlocModule] or [FirebaseAnalyticsRiverpodModule].
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
