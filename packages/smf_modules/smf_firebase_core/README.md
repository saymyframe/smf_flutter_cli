# smf_firebase_core

The SMF module of [Firebase](https://firebase.google.com/docs/flutter/setup) for the Flutter app that SMF generates. It sets up [firebase_core](https://pub.dev/packages/firebase_core), which the other Firebase packages of an app build on.

The module:

- adds `firebase_core` to the dependencies of the app;
- adds `lib/firebase_options.dart` with `DefaultFirebaseOptions`, the options of the Firebase app of each platform;
- makes `bootstrap()`, which runs before the app starts, initialize Firebase with the options of the platform that runs the app: `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);`, among the platform services, before the services of the app;
- raises the minimum iOS version of the app to 15.0, the lowest that the Firebase SDKs support.

`flutterfire configure` of the [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup) registers the app in a Firebase project and writes its options. Until it runs, `lib/firebase_options.dart` is a placeholder in the form that the FlutterFire CLI writes for the platforms it has not configured: each platform throws an `UnsupportedError`, so the app compiles but stops at start-up. The FlutterFire CLI fills the placeholder in place.

## Use with SMF CLI

This package is not intended to be installed directly. Use the SMF CLI to generate a new project and wire modules together.

- SMF Flutter CLI on pub.dev: https://pub.dev/packages/smf_flutter_cli

## 🌐 Links
[Repository](https://github.com/saymyframe/smf_flutter_cli/tree/main/packages/smf_modules/smf_firebase_core) • [Docs](https://doc.saymyframe.com) • [Issues](https://github.com/saymyframe/smf_flutter_cli/issues)

## License
See LICENSE.
