import 'package:smf_contracts/smf_contracts.dart';

abstract interface class IModuleContributorFactory {
  bool supports(ModuleProfile profile);

  IModuleCodeContributor create(ModuleProfile profile);
}
