import 'package:smf_contracts/src/brick_contribution.dart';
import 'package:smf_contracts/src/module_descriptor.dart';
import 'package:smf_contracts/src/shared_file_contribution.dart';

abstract interface class IModuleCodeContributor {
  List<BrickContribution> get brickContributions;

  List<SharedFileContribution> get sharedFileContributions;

  ModuleDescriptor get moduleDescriptor;
}
