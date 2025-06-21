import 'package:smf_flutter_core/smf_flutter_core.dart';

class FirebaseCoreModule implements IModuleCodeContributor {
  @override
  List<BrickContribution> get brickContributions => [
    // BrickContribution(
    //   name: 'firebase_core_bootstrap',
    //   bundle: bootstrapBundle,
    //   vars: {'init_block': 'await Firebase.initializeApp();'},
    // ),
  ];

  @override
  List<SharedFileContribution> get sharedFileContributions => [];

  @override
  ModuleDescriptor get moduleDescriptor => ModuleDescriptor(
    name: kFirebaseCore,
    description: 'Firebase Core module',
    pubDependency: ['firebase_core'],
  );
}
