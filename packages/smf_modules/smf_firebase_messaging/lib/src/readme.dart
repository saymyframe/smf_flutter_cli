import 'package:smf_contracts/smf_contracts.dart';

/// The heading of the section of the module in the README of the app.
const readmeHeading = 'Firebase Cloud Messaging';

/// The path in the app of the file with the service of the module.
const serviceFile = 'lib/core/push/firebase_push_service.dart';

/// The name of the meta-data of the Android app with the channel in which
/// Android shows a message that arrives in the background.
const channelMetaData =
    'com.google.firebase.messaging.default_notification_channel_id';

/// The name of the meta-data of the Android app with the small icon of a
/// message that Android shows in the background.
const iconMetaData = 'com.google.firebase.messaging.default_notification_icon';

/// The small icon of a message that Android shows in the background: the
/// drawable of the notifications of the app.
const iconResource = '@drawable/${NotificationsRole.androidIcon}';

/// The section of the module in the README of the app, which also has the
/// section of the push role: the address of the device, the key of the
/// Apple Push Notification service that Firebase needs for iOS and how to
/// upload it, how to send a test message, what the module set up for
/// Android, why the service sets the presentation options of iOS, and how
/// the app would handle a message in the background.
const String readmeSection = '''
The app receives its push messages with [firebase_messaging](https://pub.dev/packages/firebase_messaging): `$serviceFile` implements the push service of the app on it (see the section ${PushRole.readmeHeading}). The address of this device is its registration token of Firebase Cloud Messaging.

Firebase sends messages to iOS through the Apple Push Notification service (APNs), with an APNs key of your team, which you upload by hand once for the project:

1. In your Apple Developer account, under Certificates, Identifiers & Profiles, create a key under Keys with the Apple Push Notifications service (APNs) enabled. Download its `.p8` file, and note its Key ID and your Team ID.
2. In the Firebase console, open the settings of the project, then Cloud Messaging, and upload the key under the configuration of the Apple app, with its Key ID and your Team ID.

A key sends only to the apps of its team, so register the bundle id of the app as an App ID in that team, with Push Notifications. The key matters only for sending: the iOS app gets its address without it, but Firebase cannot send to that address.

To send this device a test message, run the app in debug mode and copy the address that it prints. In the Firebase console, open Messaging, create a notification campaign, choose Send test message and paste the address. A server sends a message with the HTTP v1 API of Firebase Cloud Messaging: `POST https://fcm.googleapis.com/v1/projects/<project-id>/messages:send`, with an OAuth token of a service account of the project and the address as the `token` of the message.

`${AppEntryRole.androidManifestFile}` names the channel `${NotificationsRole.defaultChannel}` of the notifications of the app (`$channelMetaData`) and their small icon `$iconResource` (`$iconMetaData`). Android shows a message that arrives in the background with them.

On iOS, firebase_messaging answers the system for every notification that arrives while the app is in the foreground, the notifications that the app shows itself too. So the service sets its presentation options to an alert, a badge and a sound when the app starts (`setForegroundNotificationPresentationOptions()`): without them, iOS would show none of these notifications in the foreground.

The app runs no code for a message that arrives in the background. To handle one, register a top-level function with `FirebaseMessaging.onBackgroundMessage()` in `main()`. It runs in an isolate of its own, without what `bootstrap()` sets up.
''';
