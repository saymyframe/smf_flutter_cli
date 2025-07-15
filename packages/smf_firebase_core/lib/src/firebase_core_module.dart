import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/bundles/smf_firebase_core_brick_bundle.dart';

class FirebaseCoreModule
    with EmptyModuleCodeContributor
    implements IModuleCodeContributor {
  @override
  List<BrickContribution> get brickContributions => [
    BrickContribution(
      name: 'firebase_core',
      bundle: smfFirebaseCoreBrickBundle,
    ),
  ];

  @override
  List<Contribution> get sharedFileContributions => [
    InsertImport(
      file: 'lib/main.dart',
      import: "import 'package:firebase_core/firebase_core.dart';",
    ),
    InsertIntoFunction(
      file: 'lib/main.dart',
      function: 'main',
      afterStatement: 'WidgetsFlutterBinding.ensureInitialized',
      insert: '''
      // Firebase Core -------------
      await Firebase.initializeApp();
      // Firebase Core END -------------
      ''',
    ),
  ];

  @override
  ModuleDescriptor get moduleDescriptor => ModuleDescriptor(
    name: kFirebaseCore,
    description: 'Firebase Core module',
    pubDependency: {'firebase_core: ^3.15.1'},
  );
}
