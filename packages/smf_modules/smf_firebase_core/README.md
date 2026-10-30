# smf_firebase_core

The SMF module of [Firebase](https://firebase.google.com/docs/flutter/setup) with [firebase_core](https://pub.dev/packages/firebase_core), which the other Firebase modules build on. It provides no role.

It adds `firebase_core` and a file of options for each flavor to the app, `lib/firebase_options_dev.dart`, `lib/firebase_options_staging.dart` and `lib/firebase_options_prod.dart`. `firebaseOptionsOfFlavor` of `lib/firebase_options_of_flavor.dart` picks the options by the flavor of the build, and `bootstrap()` initializes Firebase with them. A release build holds only the options of its own flavor. Each flavor may have a Firebase project of its own or share one.

`tool/configure_firebase.dart`, a script that the module adds to the app, configures one flavor with the [FlutterFire CLI](https://pub.dev/packages/flutterfire_cli):

```bash
dart tool/configure_firebase.dart staging --project=<id>
```

On macOS it runs `flutterfire configure` once for each Xcode build configuration of the flavor, and once elsewhere. Then it formats the options and runs each Dart file of `tool/firebase_configured/`, by the order of their names. A module that depends on this one puts a file there for what has to follow every run of flutterfire. An app whose modules have nothing to run there has no such directory.

Until a flavor is configured, its file is a placeholder, and a build of the flavor stops at start-up with an `UnsupportedError` that gives the command. Once one flavor is configured, a build of another one fails on Android for want of its `google-services.json`.

In Xcode, select the scheme of a flavor. It builds that flavor, whatever `ios/Flutter/Generated.xcconfig` says. The scheme `Runner` takes the flavor from that file, which has none after a fresh `flutter pub get`, so `appFlavor` is `null` there and `firebaseOptionsOfFlavor` throws. `flutter build ios --config-only --flavor <flavor>` gives the file a flavor.

Before generation, SMF checks what `flutterfire configure` needs: the Firebase CLI, a login that Google still accepts, flutterfire_cli 1.4.1 or a later 1.x, and on macOS the Ruby gem xcodeproj. In a terminal, it offers to set up what it can, asking first, and to log in again when the login has expired. After generation, it asks whether to configure the flavor `dev`, and prints the command to run later when the run cannot.

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
