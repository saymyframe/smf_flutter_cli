import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_local_notifications/src/readme.dart';

/// The note of the module in the guide for coding agents of the app, in the
/// section of the notifications: which file is on flutter_local_notifications
/// and how it shows a notification, how to add a channel, what the native
/// projects have for the package, and what a test of the app needs in place
/// of the platform side of the package.
final String agentNote = '''
With `flutter_local_notifications`:

- `LocalNotificationsService` in `$serviceFile` implements `NotificationsService` on `FlutterLocalNotificationsPlugin`. In `lib/`, only that file imports the package: other code shows notifications through `appNotifications`.
- Every notification goes to the channel `notificationChannelId` with the details in `_details` of that file. For another channel, such as one with another sound, create it with `createNotificationChannel()` of `AndroidFlutterLocalNotificationsPlugin` in `openLocalNotifications()`, and show a notification in it with details of its own.
- A scheduled notification uses an inexact alarm (`AndroidScheduleMode.inexactAllowWhileIdle`). Exact alarms need the permission `SCHEDULE_EXACT_ALARM`, which Google Play allows only for an app whose main feature needs them: change the mode only when asked.
- `${AppEntryRole.androidManifestFile}` declares the receivers of the package, `${AppEntryRole.gradleAppFile}` turns on core library desugaring, and `${AppEntryRole.appDelegateFile}` sets the delegate of the notification center. Keep them: scheduled notifications, the Android build and the taps on iOS need them.
- The package has no platform side for tests. A test that runs `${AppEntryRole.bootstrap.name}()` answers the method channel `dexterous.com/flutter/local_notifications` itself, with `setMockMethodCallHandler` of `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger`, after `AndroidFlutterLocalNotificationsPlugin.registerWith()`.
''';
