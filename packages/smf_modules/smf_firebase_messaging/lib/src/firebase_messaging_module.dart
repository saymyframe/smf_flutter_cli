import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_messaging/bundles/firebase_messaging_bundle.dart';
import 'package:smf_firebase_messaging/src/agents.dart';
import 'package:smf_firebase_messaging/src/readme.dart';

/// The module that receives the push messages of the app with Firebase
/// Cloud Messaging and the firebase_messaging package, and so provides the
/// push role: the address of the device, the messages that arrive and the
/// taps of the user on them.
///
/// The template of the role generates `PushService`, the interface of the
/// service of a provider, `appPush`, through which the code of the app
/// receives push messages, and `initPush()`, which `bootstrap()` awaits
/// before the first frame. This module adds `firebase_messaging` to the
/// dependencies of the app and implements the service in
/// `lib/core/push/firebase_push_service.dart` on `FirebaseMessaging`. The
/// address of the device is the registration token of Firebase Cloud
/// Messaging.
///
/// Firebase Cloud Messaging works on the Firebase app, so the module depends
/// on [FirebaseCoreModule], which initializes Firebase in `bootstrap()`, and
/// the push messages start after that. The service is created without
/// waiting: it asks the user nothing and never asks for the permission to
/// show notifications, which belongs to the notifications role.
///
/// The service keeps what the role promises and the package does not:
/// - the address and the message that launched the app are `null` where
///   the package fails, as it does on iOS before the token of the Apple
///   Push Notification service comes;
/// - a value of the data of a message that is no string, which iOS may
///   give, is its JSON;
/// - on iOS it sets the presentation options of a notification in the
///   foreground to an alert, a badge and a sound when it is created: the
///   package answers iOS for every notification in the foreground, the
///   local notifications of the app too, with those options, and with
///   none of them by default.
///
/// The template of the push role gives the iOS app the entitlement and the
/// background mode that push messages need. In the manifest of the Android
/// app, the module names the channel and the small icon of the
/// notifications role as those of a message that Android shows in the
/// background.
///
/// The README of the app tells how to upload the key of the Apple Push
/// Notification service to Firebase, how to send a test message, and why
/// the service sets the presentation options. Its guide for coding agents
/// tells which file is on the package, which call of the package the app
/// never makes, and what a test needs in place of the platform side of the
/// package.
final class FirebaseMessagingModule extends SmfModule {
  /// Creates the module.
  const FirebaseMessagingModule();

  /// The id of the module.
  static const id = ModuleId('firebase_messaging');

  static const _file = ImportRef.app('core/push/firebase_push_service.dart');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Firebase Cloud Messaging with firebase_messaging',
        kind: ModuleKinds.infrastructure,
        dependsOn: {FirebaseCoreModule.id},
        providers: [RoleProvider.plain(pushRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(firebaseMessagingBundle),
        // 16.7 is the last version on firebase_core 4, which the Firebase
        // modules share; 17 needs firebase_core 5.
        const PubspecContribution.hosted('firebase_messaging', '^16.7.0'),
        pushRole.data(
          const RoleImplementation(
            type: TypeRef('FirebasePushService', import: _file),
            create: FactoryRef('createFirebasePushService', import: _file),
          ),
        ),
        AppEntryRole.androidManifestApplicationMeta.entry(
          channelMetaData,
          const AndroidMetaData.value(NotificationsRole.defaultChannel),
        ),
        AppEntryRole.androidManifestApplicationMeta.entry(
          iconMetaData,
          const AndroidMetaData.resource(iconResource),
        ),
        AppEntryRole.readmeSections.entry(readmeHeading, readmeSection),
        AppEntryRole.agentSections.entry(
          pushRole.description,
          AgentNote(agentNote),
        ),
      ];
}
