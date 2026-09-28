# smf_firebase_crashlytics

The SMF module of [Firebase Crashlytics](https://firebase.google.com/docs/crashlytics) with [firebase_crashlytics](https://pub.dev/packages/firebase_crashlytics). It provides the crash reporting role of SMF: the app reports to Crashlytics the errors that it does not handle, and those that its code reports through its `CrashReporter`.

An app can have several modules that provide crash reporting, and the reporter of the app forwards each report to all of them. Crashlytics works on the Firebase app, so the module depends on [smf_firebase_core](https://pub.dev/packages/smf_firebase_core), which comes with it and sets up Firebase.

## Use with the SMF CLI

`smf create` asks which modules provide the crash reporting of the app, and the answer may be none. To choose this one without the question:

```bash
smf create my_app -m firebase_crashlytics
```

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Documentation

- [The firebase_crashlytics module](https://doc.saymyframe.com/modules/firebase-crashlytics)
- [Firebase](https://doc.saymyframe.com/guides/firebase)
