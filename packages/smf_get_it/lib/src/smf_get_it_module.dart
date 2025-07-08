import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_get_it/bundles/smf_get_it_brick_bundle.dart';
import 'package:smf_sharable_bricks/smf_sharable_bricks.dart';

class SmfGetItModule implements IModuleCodeContributor {
  @override
  List<BrickContribution> get brickContributions => [
    BrickContribution(name: 'get_it', bundle: smfGetItBrickBundle),
  ];

  @override
  ModuleDescriptor get moduleDescriptor => ModuleDescriptor(
    name: kGetItModule,
    description: 'Get it service locator',
    pubDependency: {'get_it: ^8.0.3'},
  );

  @override
  List<SharedFileContribution> get sharedFileContributions => [
    SharedFileContribution(
      bundle: smfBootstrapBrickBundle,
      slot: SharableCodeSlots.imports.slot,
      content: '''
      import 'package:{{app_name_sc}}/core/di/core_di.dart';
      ''',
    ),
    SharedFileContribution(
      bundle: smfBootstrapBrickBundle,
      slot: SharableCodeSlots.bootstrap.slot,
      order: 1,
      content: '''
      setUpCoreDI();
      ''',
    ),
  ];
}
