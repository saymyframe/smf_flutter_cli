/// The module that sets up Firebase in the app: `FirebaseCoreModule`, which
/// initializes Firebase at start-up with the options that the FlutterFire
/// CLI writes.
///
/// For the modules that depend on it, it has `FirebaseCliVersionCheck`, a
/// check of the machine for a Firebase CLI in the version that their
/// commands need.
library;

export 'src/firebase_core_module.dart';
export 'src/preflight/firebase_cli_version.dart' show FirebaseCliVersionCheck;
