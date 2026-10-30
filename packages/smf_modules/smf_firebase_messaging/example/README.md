# Generate a Flutter app that receives push messages

`firebase_messaging` is the module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) with which the app receives push messages through Firebase Cloud Messaging. Choose it with `-m`:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m firebase_messaging --no-input
```

The push role shows a message that arrives in the foreground as a notification of the app, so it needs a provider of the notifications, which in turn needs one of the preferences. Firebase Cloud Messaging works on the Firebase app. `smf create` adds all three:

```text
Adding firebase_core: a dependency of firebase_messaging.
Adding flutter_core: the only provider of the app entry role, which every app needs.
Adding local_notifications: the only provider of the notifications role, which firebase_messaging requires.
Adding shared_preferences: the only provider of the preferences role, which local_notifications requires.
```

The module adds firebase_messaging to the `pubspec.yaml` of the app, and `lib/core/push/firebase_push_service.dart` with the push service on `FirebaseMessaging`. The push role adds `lib/core/push/app_push.dart` with `appPush`, which the rest of the app uses. `bootstrap()` starts the push messages before the first frame, once Firebase and the notifications started, without asking the user anything:

```dart
Future<void> bootstrap() async {
  await Firebase.initializeApp(options: firebaseOptionsOfFlavor);
  await initPreferences();
  await initNotifications();
  await initPush();
}
```

The code of the app sends the address of the device to its backend, and opens the screen that a tapped message names:

```dart
import 'core/push/app_push.dart';

void listenToPushMessages(void Function(String screen) open) {
  void sendAddress() {
    final address = appPush.address.value;
    if (address != null) backend.registerDevice(address);
  }

  // The address may be there already, or come later.
  sendAddress();
  appPush.address.addListener(sendAddress);
  appPush.taps.listen((message) {
    if (message.data['screen'] case final screen?) open(screen);
  });
  if (appPush.launchMessage?.data['screen'] case final screen?) open(screen);
}
```

The address is the registration token of Firebase Cloud Messaging. On iOS it comes once the device has a token of the Apple Push Notification service, and Firebase sends to iOS only with a key of that service, which you upload in the Firebase console. The README of the app tells how, and how to send the device a test message.

The documentation has more on [the firebase_messaging module](https://doc.saymyframe.com/modules/firebase-messaging).
