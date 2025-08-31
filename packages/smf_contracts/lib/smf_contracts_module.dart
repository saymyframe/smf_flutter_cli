import 'package:smf_contracts/bundles/smf_contracts_brick_bundle.dart';
import 'package:smf_contracts/smf_contracts.dart';

class SmfContractsModule
    with EmptyModuleCodeContributor
    implements IModuleCodeContributor {
  @override
  List<BrickContribution> get brickContributions => [
        BrickContribution(
          name: 'smf_contracts',
          bundle: smfContractsBrickBundle,
        ),
      ];

  @override
  ModuleDescriptor get moduleDescriptor =>
      ModuleDescriptor(name: kContractsModule, description: 'SMF Contracts');
}
