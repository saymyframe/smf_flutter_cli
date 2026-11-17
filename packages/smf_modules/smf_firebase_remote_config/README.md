# smf_firebase_remote_config

The SMF module of [Firebase Remote Config](https://firebase.google.com/docs/remote-config) with [firebase_remote_config](https://pub.dev/packages/firebase_remote_config). It provides the remote config role of SMF: the app reads values that its Firebase project changes without a new version of the app. Each value has a default, which the app uses while the project gives none.

The remote config role generates `appRemoteConfig`, through which the code of the app reads the values; `RemoteValues`, with a getter for each parameter of the app; and the `RemoteConfigService` interface. This module adds `firebase_remote_config` to the app and implements the interface on `FirebaseRemoteConfig` with the real-time updates of Firebase: a value that you publish in the Firebase console reaches a running app, which makes it active at once. The start of the app never waits for a fetch: it makes active what the device kept from the last one. Firebase Remote Config works on the Firebase app, so the module depends on [smf_firebase_core](https://pub.dev/packages/smf_firebase_core), which comes with it and sets up Firebase.

An app without parameters asks Firebase nothing. Once a module of the app reads a parameter, such as the minimum version of the app, you create that parameter in Remote Config of the Firebase project of each flavor. The README of the app lists this among the steps that you do by hand, in its section "Finish the setup". It also tells which APIs of Google the project needs, what fetches cost and what each fetch sends.

## Use with the SMF CLI

`smf create` asks which module provides the remote config of the app, and offers none as well. To choose this one without the question:

```bash
smf create my_app -m firebase_remote_config
```

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Documentation

- [The firebase_remote_config module](https://doc.saymyframe.com/modules/firebase-remote-config)
- [Firebase](https://doc.saymyframe.com/guides/firebase)
