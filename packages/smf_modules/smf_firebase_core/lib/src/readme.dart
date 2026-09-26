/// The heading of the section of the module in the README of the app.
const readmeHeading = 'Firebase';

/// The section of the module in the README of the app, which gives
/// [configure], the command that configures the app.
String readmeSection(String configure) => '''
The app uses [Firebase](https://firebase.google.com/docs/flutter/setup) through `firebase_core`: `bootstrap()` initializes it with the options of `DefaultFirebaseOptions` in `lib/firebase_options.dart`. `flutterfire configure` of the FlutterFire CLI writes these options when it registers the app in a Firebase project, together with `android/app/google-services.json`, `firebase.json` and, on macOS, `ios/Runner/GoogleService-Info.plist`. Until then, the options are a placeholder, and the app stops at start-up with an `UnsupportedError`.

To configure the app, or to configure it again, such as for another Firebase project or on another machine, run in its directory:

```bash
dart pub global activate flutterfire_cli
firebase login
$configure
```

`flutterfire configure` needs the [Firebase CLI](https://firebase.google.com/docs/cli), and changes the Xcode project only on macOS. The build phases that it adds to the Xcode project for some Firebase packages, such as the upload of the debug symbols of Crashlytics, run `flutterfire` from `~/.pub-cache/bin`, so every machine that builds such an app for iOS needs the FlutterFire CLI activated with `dart pub global activate flutterfire_cli`.
''';
