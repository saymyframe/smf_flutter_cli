# smf_firebase_messaging

The SMF module of [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging) with [firebase_messaging](https://pub.dev/packages/firebase_messaging). It provides the push role of SMF: the app gets the address of the device for its backend, receives the push messages that the backend sends there, and hears of the taps on them, also of the tap that launched it.

The push role generates `appPush`, through which the code of the app reads the address, the messages and the taps, and the `PushService` interface. This module adds `firebase_messaging` to the app and implements the interface on `FirebaseMessaging`. The address is the registration token of Firebase Cloud Messaging. The app asks the user nothing when it starts: the permission to show notifications belongs to the notifications role, which the push role requires. On iOS, the service lets a notification show while the app is in the foreground. Firebase Cloud Messaging works on the Firebase app, so the module depends on [smf_firebase_core](https://pub.dev/packages/smf_firebase_core), which comes with it and sets up Firebase.

In the Android app, the module names the channel and the small icon of the notifications of the app as those of a message that Android shows in the background. To send messages to iOS, Firebase needs a key of the Apple Push Notification service, which you upload in the Firebase console for the iOS app of each flavor that you send to: the README of the app lists that upload among the steps that you do by hand, in its section "Finish the setup", and tells how to do it and how to send the device a test message.

## Use with the SMF CLI

`smf create` asks which module provides the push messages of the app, and offers none as well. To choose this one without the question:

```bash
smf create my_app -m firebase_messaging
```

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Documentation

- [The firebase_messaging module](https://doc.saymyframe.com/modules/firebase-messaging)
- [Firebase](https://doc.saymyframe.com/guides/firebase)
