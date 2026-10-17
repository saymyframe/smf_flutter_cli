# smf_local_notifications

The SMF module of notifications with [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications). It provides the notifications role of SMF: the app shows a notification now or at about a time to come, asks the user for the permission, and hears of the taps on its notifications, also of the tap that launched it.

The notifications role generates `appNotifications`, through which the code of the app shows and schedules notifications and asks for the permission, and the `NotificationsService` interface. This module adds `flutter_local_notifications` and `timezone` to the app and implements the interface on `FlutterLocalNotificationsPlugin`. The app asks the user nothing when it starts. Where the system shows no question for the permission, as on Android before 13, a request opens the notification settings of the app instead. A scheduled notification uses an inexact alarm on Android, which needs no permission.

The module also sets up what the package needs in the native projects of the app: core library desugaring in the Gradle file of the Android app, the receivers that show the scheduled notifications and set them again after a restart of the device, and on iOS the delegate of the notification center in the `AppDelegate`.

## Use with the SMF CLI

`smf create` asks which module provides the notifications of the app, and offers none as well. To choose this one without the question:

```bash
smf create my_app -m local_notifications
```

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Documentation

- [The local_notifications module](https://doc.saymyframe.com/modules/local-notifications)
- [Notifications](https://doc.saymyframe.com/guides/notifications)
