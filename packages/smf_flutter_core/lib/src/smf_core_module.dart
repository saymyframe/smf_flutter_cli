import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/bundles/smf_flutter_core_bundle.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';

class SmfCoreModule implements IModuleCodeContributor {
  @override
  List<BrickContribution> get brickContributions => [
    BrickContribution(
      name: 'flutter_core',
      bundle: smfFlutterCoreBundle,
      vars: {},
    ),
  ];

  @override
  ModuleDescriptor get moduleDescriptor => ModuleDescriptor(
    name: kFlutterCoreModule,
    description: 'Firebase Core module',
  );

  @override
  List<SharedFileContribution> get sharedFileContributions => [];
}
