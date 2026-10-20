# Generate a Flutter app that shows notifications

`local_notifications` is the module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) with which the app shows notifications through flutter_local_notifications. Choose it with `-m`:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m local_notifications --no-input
```

The notifications role remembers that the app asked for the permission, so it needs a provider of the preferences, and `smf create` adds one:

```text
Adding flutter_core: the only provider of the app entry role, which every app needs.
Adding shared_preferences: the only provider of the preferences role, which local_notifications requires.
```

The module adds flutter_local_notifications and timezone to the `pubspec.yaml` of the app, and `lib/core/notifications/local_notifications_service.dart` with the notifications service on `FlutterLocalNotificationsPlugin`. The notifications role adds `lib/core/notifications/app_notifications.dart` with `appNotifications`, which the rest of the app uses. `bootstrap()` opens the notifications before the first frame, without asking the user anything:

```dart
Future<void> bootstrap() async {
  await initPreferences();
  await initNotifications();
}
```

The code of the app asks for the permission where the user turns on something that notifies, and shows or schedules a notification:

```dart
import 'core/notifications/app_notifications.dart';

Future<void> remindTomorrow(String task) async {
  final permission = await appNotifications.request();
  if (permission != NotificationPermission.granted) return;
  await appNotifications.schedule(
    AppNotification(
      id: 1,
      title: 'Reminder',
      body: task,
      data: const {'screen': 'tasks'},
    ),
    at: DateTime.now().add(const Duration(days: 1)),
  );
}
```

A scheduled notification shows at about its time, also when the app is closed then: on Android it uses an inexact alarm, which needs no permission. A tap on a notification reaches `appNotifications.taps` with the `data` of the notification, and `appNotifications.launchTap` is the tap that launched the app.

The module also sets up the native projects: core library desugaring in `android/app/build.gradle.kts`, the receivers of the scheduled notifications in `android/app/src/main/AndroidManifest.xml`, and the delegate of the notification center in `ios/Runner/AppDelegate.swift`.

The documentation has more on [the local_notifications module](https://doc.saymyframe.com/modules/local-notifications).
