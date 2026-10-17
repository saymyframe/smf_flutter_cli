import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_messaging/src/readme.dart';

/// The note of the module in the guide for coding agents of the app, in the
/// section of the push messages: which file is on firebase_messaging, what
/// the address of the device is, why the service sets the presentation
/// options of iOS, which call of the package the app never makes, what the
/// manifest of Android has for the package, and what a test of the app
/// needs in place of the platform side of the package.
final String agentNote = '''
With `firebase_messaging`:

- `FirebasePushService` in `$serviceFile` implements `PushService` on `FirebaseMessaging`. In `lib/`, only that file imports the package: other code receives push messages through `appPush`.
- The address of the device is its registration token of Firebase Cloud Messaging, from `getToken()`, and a new token comes on `onTokenRefresh`. On iOS there is none until the token of the Apple Push Notification service comes.
- On iOS, `createFirebasePushService()` calls `setForegroundNotificationPresentationOptions()` with an alert, a badge and a sound. Keep it: the package answers iOS for every notification in the foreground, those of `appNotifications` too, and without these options iOS shows none of them.
- Never call `requestPermission()` of the package: the permission to show notifications belongs to `appNotifications.request()`.
- `${AppEntryRole.androidManifestFile}` names the channel and the icon with which Android shows a message that arrives in the background, those of the notifications of the app. Change them together.
- The section $readmeHeading of the README tells how to upload the key of the Apple Push Notification service and how to send this device a test message.
- The package has no platform side for tests. A test that runs `${AppEntryRole.bootstrap.name}()` answers the method channel `plugins.flutter.io/firebase_messaging` itself, with `setMockMethodCallHandler` of `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger`.
''';
