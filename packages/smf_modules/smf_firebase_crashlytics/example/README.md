# Generate a Flutter app with Firebase Crashlytics

`firebase_crashlytics` is the module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) that reports errors to Firebase Crashlytics. Choose it with `-m` in a terminal:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m firebase_crashlytics
```

It depends on `firebase_core`, which sets up Firebase, so `smf create` adds that module too:

```text
Adding firebase_core: a dependency of firebase_crashlytics.
Adding flutter_core: the only provider of the app entry role, which every app needs.
```

The module adds firebase_crashlytics to the `pubspec.yaml` of the app, and `lib/core/crash_reporting/crashlytics_crash_reporter.dart` with the reporter on `FirebaseCrashlytics.instance`. The crash reporting role adds `lib/core/crash_reporting/crash_reporter.dart` with the `CrashReporter` interface, `createCrashReporter()` and `installCrashReporting()`. `bootstrap()` starts Firebase and then installs the reporting:

```dart
Future<void> bootstrap() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  installCrashReporting();
}
```

From then on, the errors that the app does not handle go to Crashlytics. The code of the app reports other errors with `createCrashReporter().recordError(error, stackTrace)`.

After `flutterfire configure`, SMF on macOS fixes the Crashlytics build phase that the FlutterFire CLI adds, so that `flutter build ipa` works when the app uses Swift Package Manager.

The documentation has more on [the firebase_crashlytics module](https://doc.saymyframe.com/modules/firebase-crashlytics) and on [Crashlytics and flutter build ipa](https://doc.saymyframe.com/guides/firebase#crashlytics-and-flutter-build-ipa).
