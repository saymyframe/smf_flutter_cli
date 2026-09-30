import 'package:smf_firebase_crashlytics/src/crashlytics_phase.dart';

/// The heading of the section of the module in the README of the app.
const readmeHeading = 'Crashlytics';

/// The section of the module in the README of the app, after the section of
/// firebase_core, which tells how to configure the app with flutterfire: the
/// build phase for Crashlytics that flutterfire adds, and the command that
/// fixes it after flutterfire configured the app on macOS.
const readmeSection = '''
The app reports its errors to [Firebase Crashlytics](https://firebase.google.com/docs/crashlytics) through `firebase_crashlytics` once Firebase is configured. On macOS, `flutterfire configure` adds a build phase to the Xcode project that uploads the debug symbols of the app with the upload script of Crashlytics. The phase that flutterfire_cli 1.4.0 adds does not find the script where Flutter puts the Swift packages of the app, so with Swift Package Manager `flutter run` and `flutter build ios` fail in that phase. Configuring the app again on macOS with flutterfire_cli 1.4.1 or a later 1.x replaces the phase.

`flutter build ipa` needs one more change on macOS. The phase of flutterfire_cli 1.4.1 looks for the upload script in the build directory of Xcode, which is `build/ios` for `flutter run` and `flutter build ios` but not for the archive of `flutter build ipa`. So SMF points the phase at `build/ios/SourcePackages` right after it configures the app. `flutterfire configure` writes the phase again, so after running it yourself on macOS, run in the directory of the app:

```bash
$crashlyticsPhaseFixCommand
```
''';
