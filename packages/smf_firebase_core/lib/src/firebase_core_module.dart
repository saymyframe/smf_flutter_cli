import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/bundles/smf_firebase_core_brick_bundle.dart';
import 'package:smf_sharable_bricks/smf_sharable_bricks.dart';

class FirebaseCoreModule implements IModuleCodeContributor {
  @override
  List<BrickContribution> get brickContributions => [
    BrickContribution(
      name: 'firebase_core',
      bundle: smfFirebaseCoreBrickBundle,
    ),
  ];

  @override
  List<SharedFileContribution> get sharedFileContributions => [
    SharedFileContribution(
      bundle: smfBootstrapBrickBundle,
      slot: SharableCodeSlots.imports.slot,
      content: '''
      import 'package:firebase_core/firebase_core.dart';
        ''',
    ),
    SharedFileContribution(
      bundle: smfBootstrapBrickBundle,
      slot: SharableCodeSlots.bootstrap.slot,
      content: '''
      // Firebase Core -------------
      await Firebase.initializeApp();
      // Firebase Core END -------------
        ''',
      order: 0,
    ),
  ];

  @override
  ModuleDescriptor get moduleDescriptor => ModuleDescriptor(
    name: kFirebaseCore,
    description: 'Firebase Core module',
    pubDependency: {'firebase_core: ^3.15.1'},
  );
}
