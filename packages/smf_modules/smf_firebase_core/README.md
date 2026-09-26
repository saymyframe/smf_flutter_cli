# smf_firebase_core

The SMF module of [Firebase](https://firebase.google.com/docs/flutter/setup) for the Flutter app that SMF generates. It sets up [firebase_core](https://pub.dev/packages/firebase_core), which the other Firebase packages of an app build on.

The module:

- adds `firebase_core` to the dependencies of the app;
- adds `lib/firebase_options.dart` with `DefaultFirebaseOptions`, the options of the Firebase app of each platform;
- makes `bootstrap()`, which runs before the app starts, initialize Firebase with the options of the platform that runs the app: `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);`, among the platform services, before the services of the app;
- raises the minimum iOS version of the app to 15.0, the lowest that the Firebase SDKs support.

`flutterfire configure` of the [FlutterFire CLI](https://pub.dev/packages/flutterfire_cli) registers the app in a Firebase project and writes its options. Until it runs, `lib/firebase_options.dart` is a placeholder: the file that flutterfire_cli 1.4 writes for an app with no platform configured, where each platform throws an `UnsupportedError`, so the app compiles but stops at start-up. The FlutterFire CLI fills the placeholder in place.

## The machine

Before it generates the app, SMF checks that the machine can run `flutterfire configure`:

- the [Firebase CLI](https://firebase.google.com/docs/cli), which the FlutterFire CLI runs to reach the Firebase projects;
- a login of the Firebase CLI, which `firebase login:list --json` reports;
- the FlutterFire CLI, activated with `dart pub global activate flutterfire_cli`, in version 1.4.0 or a later 1.x;
- on macOS, the Ruby gem xcodeproj 1.23.0 or newer, with which the FlutterFire CLI sets up the iOS app in its Xcode project. It does that only on macOS: elsewhere it registers the iOS app and writes its options, but leaves the Xcode project as it is, so SMF warns to run `flutterfire configure` again on a Mac.

The app compiles without any of them, so a missing one only brings a warning with instructions. In a run with a terminal, unless it skips external setup (`--skip-external-setup`), SMF offers to install the Firebase CLI with npm, and Node.js first when it is missing, to log in with `firebase login`, and to activate flutterfire_cli 1.4.1; it asks before each. When npm fails on macOS or Linux, it offers the standalone binary of the Firebase CLI instead.

## After generation

Once the app has its packages, SMF runs `flutterfire configure --platforms=android,ios --overwrite-firebase-options` in it, through `dart pub global run flutterfire_cli:flutterfire`, with the terminal: it asks for the Firebase project and writes the options into `lib/firebase_options.dart`. It asks first, so you can leave it for later. A run without a terminal, or that skips external setup, prints the command to run later instead.

The README of the app gets a section on Firebase: how to configure the app again, such as for another Firebase project or on another machine, and that the build phases that the FlutterFire CLI adds to the Xcode project for some Firebase packages, such as the upload of the debug symbols of Crashlytics, run `flutterfire` from `~/.pub-cache/bin`.

## Use with SMF CLI

`smf create` asks which infrastructure modules the app has, and offers this one. To choose it without the question, name it with `-m`:

```bash
smf create my_app -m firebase_core
```

This package is not intended to be installed directly. Use the SMF CLI to generate a new project and wire modules together.

- SMF Flutter CLI on pub.dev: https://pub.dev/packages/smf_flutter_cli

## 🌐 Links
[Repository](https://github.com/saymyframe/smf_flutter_cli/tree/main/packages/smf_modules/smf_firebase_core) • [Docs](https://doc.saymyframe.com) • [Issues](https://github.com/saymyframe/smf_flutter_cli/issues)

## License
See LICENSE.
