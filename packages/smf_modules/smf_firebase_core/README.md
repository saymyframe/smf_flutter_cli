# smf_firebase_core

The SMF module of [Firebase](https://firebase.google.com/docs/flutter/setup) with [firebase_core](https://pub.dev/packages/firebase_core), which the other Firebase modules build on. It provides no role.

It adds `firebase_core` and `lib/firebase_options.dart` to the app, and `bootstrap()` initializes Firebase with these options. Until `flutterfire configure` of the [FlutterFire CLI](https://pub.dev/packages/flutterfire_cli) writes the options, the file is a placeholder, and the app stops at start-up.

Before generation, SMF checks what `flutterfire configure` needs: the Firebase CLI, a login that Google still accepts, flutterfire_cli 1.4.1 or a later 1.x, and on macOS the Ruby gem xcodeproj. In a terminal, it offers to set up what it can, asking first, and to log in again when the login has expired. After generation, it asks whether to run `flutterfire configure`, and prints the command to run later when the run cannot.

For the modules that depend on it, the package has the check `FirebaseCliVersionCheck`. A module whose command exists only in newer versions of the Firebase CLI puts the check among its own checks of the machine, with the lowest version that has the command. The check reads `firebase --version` and tells how to update an older Firebase CLI. SMF does not update the Firebase CLI itself. On a machine without the Firebase CLI, the check of `firebase_core` runs first and offers the installation. The check of the version then reads the version that was installed.

## Use with the SMF CLI

`smf create` asks which infrastructure modules the app has, and offers this one. It also comes with the other Firebase modules. To choose it without the question:

```bash
smf create my_app -m firebase_core
```

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Documentation

- [The firebase_core module](https://doc.saymyframe.com/modules/firebase-core)
- [Firebase](https://doc.saymyframe.com/guides/firebase)
