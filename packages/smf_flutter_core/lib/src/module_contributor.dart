import 'package:smf_flutter_core/src/brick_contribution.dart';
import 'package:smf_flutter_core/src/module_descriptor.dart';
import 'package:smf_flutter_core/src/shared_file_contribution.dart';

abstract interface class IModuleCodeContributor {
  List<BrickContribution> get brickContributions;

  List<SharedFileContribution> get sharedFileContributions;

  ModuleDescriptor get moduleDescriptor;
}
