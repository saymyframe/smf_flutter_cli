import 'package:smf_contracts/smf_contracts.dart';

/// The heading of the section of the module in the README of the app.
const readmeHeading = 'flutter_local_notifications';

/// The path in the app of the file with the service of the module.
const serviceFile = 'lib/core/notifications/local_notifications_service.dart';

/// The version of `desugar_jdk_libs` that flutter_local_notifications
/// builds with, and so asks of the app.
const desugaringVersion = '2.1.4';

/// The receivers of flutter_local_notifications that show the scheduled
/// notifications on Android, at their time and again after a restart of the
/// device or an update of the app, as the README of the package declares
/// them in the `<application>` of the manifest of the app.
const receivers = '''
        <receiver
            android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver
            android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>''';

/// The permission with which the receiver of a restart of the device sets
/// the scheduled notifications again.
const bootPermission = 'android.permission.RECEIVE_BOOT_COMPLETED';

/// The statement of the app delegate that makes it the delegate of the
/// notification center of iOS, through which the plugin shows a
/// notification in the foreground and hears of the taps, also of the one
/// that launched the app.
const delegateStatement =
    '    UNUserNotificationCenter.current().delegate = self';

/// The section of the module in the README of the app, which also has the
/// section of the notifications role: what the module set up in the native
/// projects and why, how a notification is shown and scheduled, how the app
/// would schedule to the minute and what that costs, and what the plugin
/// can do that the app does not set up.
const String readmeSection = '''
The app shows its notifications with [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications): `$serviceFile` implements the notifications service of the app on it (see the section ${NotificationsRole.readmeHeading}).

The module set up what the package needs in the native projects:

- `${AppEntryRole.gradleAppFile}` turns on core library desugaring with `desugar_jdk_libs` $desugaringVersion, without which the Android build fails.
- `${AppEntryRole.androidManifestFile}` declares the receivers of the package that show a scheduled notification at its time and set the scheduled ones again after a restart of the device or an update of the app, and the permission `$bootPermission` for the restart.
- `${AppEntryRole.appDelegateFile}` makes the app delegate the delegate of the notification center of iOS, so that a notification shows while the app is in the foreground and a tap reaches the app, also the tap that launched it.

Every notification goes to the channel `${NotificationsRole.defaultChannel}`, with a high importance, which the service creates when the app starts. A scheduled notification uses an inexact alarm on Android, which needs no permission: Android may show it a few minutes late. To show notifications to the minute, declare `android.permission.SCHEDULE_EXACT_ALARM` in the manifest, ask for it with `requestExactAlarmsPermission()` of `AndroidFlutterLocalNotificationsPlugin`, and schedule with `AndroidScheduleMode.exactAllowWhileIdle`. Google Play allows exact alarms only for apps whose main feature needs them, such as an alarm clock or a calendar.

The app does not set up the actions of a notification, its buttons. They need the receiver `ActionBroadcastReceiver` on Android and, on iOS, a callback that registers the plugins for the isolate in which an action runs: see the README of the package.
''';
