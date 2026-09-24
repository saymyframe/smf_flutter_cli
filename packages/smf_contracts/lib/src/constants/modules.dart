import 'package:smf_contracts/smf_contracts.dart';

/// [ModuleDescriptor.name] reserved for a Firebase Authentication module.
const kFirebaseAuthModule = 'firebase_auth';

/// Identifier of the BLoC state manager, accepted by the CLI's
/// `--state-manager` option; see [StateManager.bloc].
const kBlocStateManagement = 'bloc';

/// Identifier of the Riverpod state manager, accepted by the CLI's
/// `--state-manager` option; see [StateManager.riverpod].
const kRiverpodStateManagement = 'riverpod';

/// [ModuleDescriptor.name] of the Firebase Core module.
const kFirebaseCore = 'firebase_core';

/// [ModuleDescriptor.name] of the Firebase Analytics module.
const kFirebaseAnalytics = 'firebase_analytics';

/// [ModuleDescriptor.name] of the Firebase Crashlytics module.
const kFirebaseCrashlytics = 'firebase_crashlytics';

/// [ModuleDescriptor.name] of the Flutter core module, which the CLI adds to
/// every project.
const kFlutterCoreModule = 'flutter_core';

/// [ModuleDescriptor.name] of the get_it dependency injection module.
const kGetItModule = 'get_it';

/// [ModuleDescriptor.name] of the event bus module, which lets parts of the
/// app communicate through events.
const kCommunicationModule = 'event_bus';

/// [ModuleDescriptor.name] of the go_router routing module.
const kGoRouterModule = 'go_router';

/// [ModuleDescriptor.name] of the home screen feature module.
const kHomeFeatureModule = 'home';

/// [ModuleDescriptor.name] of this contracts module, which the CLI adds to
/// every project.
const kContractsModule = 'contracts';
