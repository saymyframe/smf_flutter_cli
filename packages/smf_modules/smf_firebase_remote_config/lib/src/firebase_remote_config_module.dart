import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_remote_config/bundles/firebase_remote_config_bundle.dart';
import 'package:smf_firebase_remote_config/src/agents.dart';
import 'package:smf_firebase_remote_config/src/readme.dart';

/// The module that reads the values of remote config of the app from
/// Firebase Remote Config with the firebase_remote_config package, and so
/// provides the remote config role: values that the Firebase project
/// changes without a new version of the app, each with the default of the
/// app.
///
/// The template of the role generates `RemoteConfigService`, the interface
/// of the service of a provider, `RemoteValues`, the values that the code of
/// the app reads, and `appRemoteConfig`, which keeps them up to date with
/// the service. This module adds `firebase_remote_config` to the
/// dependencies of the app and implements the service in
/// `lib/core/remote_config/firebase_remote_config_service.dart` on
/// `FirebaseRemoteConfig`:
/// - `open` takes what the device kept and gives Firebase the fetch
///   interval and the timeout of the role and the defaults of the
///   parameters of the app;
/// - `values` has the active values that the project gave, and leaves out
///   the defaults, which Firebase has among its values too;
/// - `updates` tells of each real-time update of Firebase, once Firebase
///   fetched what the project published, and the controller of the role
///   activates it.
///
/// Firebase Remote Config works on the Firebase app, so the module depends
/// on [FirebaseCoreModule], which initializes Firebase in `bootstrap()`
/// before remote config starts. The service is created without waiting and
/// asks Firebase nothing until the controller opens it.
///
/// The parameters of the app are created by hand in the Firebase project of
/// each flavor, since no command adds a parameter to a template without
/// replacing what the developer set in the console. So an app with
/// parameters lists the step by hand [parametersStep], which the provider
/// of the module gives in its `manualSteps` hook; an app without parameters
/// has nothing to create.
///
/// The README of the app tells where the parameters go, which APIs of
/// Google the project needs, what fetches cost, and what each fetch sends.
/// Its guide for coding agents tells which file is on the package, which
/// values of Firebase the service takes, and what a test needs in place of
/// the platform side of the package.
final class FirebaseRemoteConfigModule extends SmfModule {
  /// Creates the module.
  const FirebaseRemoteConfigModule();

  /// The id of the module.
  static const id = ModuleId('firebase_remote_config');

  /// The step by hand in which the developer creates the parameters of the
  /// app in Firebase Remote Config of the project of each flavor. Only an
  /// app with parameters lists it.
  static const parametersStep = ManualStep(
    ManualStepId(id, 'parameters'),
    'Create the parameters of the app in Firebase Remote Config',
  );

  static const _file = ImportRef.app(
    'core/remote_config/firebase_remote_config_service.dart',
  );

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Firebase Remote Config with firebase_remote_config',
        kind: ModuleKinds.infrastructure,
        dependsOn: {FirebaseCoreModule.id},
        providers: [_FirebaseRemoteConfigProvider()],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(firebaseRemoteConfigBundle),
        // 6.7 is the last version on firebase_core 4, which the Firebase
        // modules share.
        const PubspecContribution.hosted('firebase_remote_config', '^6.7.1'),
        remoteConfigRole.data(
          const RemoteConfigImplementation(
            type: TypeRef('FirebaseRemoteConfigService', import: _file),
            create: FactoryRef(
              'createFirebaseRemoteConfigService',
              import: _file,
            ),
          ),
        ),
        AppEntryRole.readmeSections.entry(readmeHeading, readmeSection),
        AppEntryRole.agentSections.entry(
          remoteConfigRole.description,
          AgentNote(agentNote),
        ),
      ];
}

/// The provider of the remote config role of [FirebaseRemoteConfigModule]:
/// its brick implements the role, and its `manualSteps` hook lists
/// [FirebaseRemoteConfigModule.parametersStep] in an app with parameters.
final class _FirebaseRemoteConfigProvider
    extends RoleProvider<RemoteConfigData> {
  const _FirebaseRemoteConfigProvider();

  @override
  Role<RemoteConfigData> get role => remoteConfigRole;

  /// The step in which the developer creates the parameters of the app in
  /// Firebase, in an app whose modules or templates of roles give the role
  /// a parameter; none in an app without parameters.
  @override
  List<ManualStep> manualSteps(RoleHookInput<RemoteConfigData> input) => [
        if (remoteConfigRole.keysIn(input).isNotEmpty)
          FirebaseRemoteConfigModule.parametersStep,
      ];
}
