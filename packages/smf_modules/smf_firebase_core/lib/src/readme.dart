import 'package:smf_firebase_core/src/crashlytics_phase.dart';
import 'package:smf_firebase_core/src/preflight/flutterfire_cli.dart';

/// The heading of the section of the module in the README of the app.
const readmeHeading = 'Firebase';

/// The section of the module in the README of the app, which gives
/// [configure], the command that configures the app, and the command that
/// fixes the phase for Crashlytics after it on macOS.
String readmeSection(String configure) => '''
The app uses [Firebase](https://firebase.google.com/docs/flutter/setup) through `firebase_core`: `bootstrap()` initializes it with the options of `DefaultFirebaseOptions` in `lib/firebase_options.dart`. `flutterfire configure` of the FlutterFire CLI writes these options when it registers the app in a Firebase project, together with `android/app/google-services.json`, `firebase.json` and, on macOS, `ios/Runner/GoogleService-Info.plist`. Until then, the options are a placeholder, and the app stops at start-up with an `UnsupportedError`.

To configure the app, or to configure it again, such as for another Firebase project or on another machine, run in its directory:

```bash
dart pub global activate flutterfire_cli $flutterfireVersion
firebase login
$configure
```

`flutterfire configure` needs the [Firebase CLI](https://firebase.google.com/docs/cli), and changes the Xcode project only on macOS. The build phases that it adds to the Xcode project for some Firebase packages, such as the upload of the debug symbols of Crashlytics, run `flutterfire` from `~/.pub-cache/bin`, so every machine that builds such an app for iOS needs the FlutterFire CLI activated too.

Configure the app with flutterfire_cli $minimumFlutterfireVersion or a later 1.x; if `dart pub global list` shows one already, skip its activation above. The phase for Crashlytics that flutterfire_cli 1.4.0 adds does not find the upload script of Crashlytics where Flutter puts the Swift packages of the app, so with Swift Package Manager `flutter run` and `flutter build ios` fail in that phase; configuring the app again on macOS with $minimumFlutterfireVersion or a later 1.x replaces the phase.

With Crashlytics, `flutter build ipa` needs one more change on macOS: the phase of flutterfire_cli 1.4.1 looks for the upload script of Crashlytics in the build directory of Xcode, which is `build/ios` for `flutter run` and `flutter build ios` but not for the archive of `flutter build ipa`, so SMF points the phase at `build/ios/SourcePackages` right after it configures the app. `flutterfire configure` writes the phase again, so after running it yourself on macOS, run in the directory of the app:

```bash
$crashlyticsPhaseFixCommand
```
''';
