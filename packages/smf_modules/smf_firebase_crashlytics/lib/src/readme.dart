import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_crashlytics/src/crashlytics_phase.dart';

/// The heading of the section of the module in the README of the app.
const readmeHeading = 'Crashlytics';

/// The section of the module in the README of the app, after the section of
/// firebase_core, which tells how to configure a flavor: the build phase for
/// Crashlytics that flutterfire adds, the script that fixes it after each
/// flavor, and what a flavor that is not configured fails with on macOS.
const readmeSection = '''
The app reports its errors to [Firebase Crashlytics](https://firebase.google.com/docs/crashlytics) through `firebase_crashlytics` once Firebase is configured. On macOS, `${FirebaseCoreModule.configureScript}` has flutterfire add a build phase to the Xcode project that uploads the debug symbols of the app with the upload script of Crashlytics. The phase that flutterfire_cli 1.4.0 adds does not find the script where Flutter puts the Swift packages of the app, so with Swift Package Manager `flutter run` and `flutter build ios` fail in that phase. Running the script again on macOS with flutterfire_cli 1.4.1 or a later 1.x replaces the phase.

`flutter build ipa` needs one more change on macOS. The phase of flutterfire_cli 1.4.1 looks for the upload script in the build directory of Xcode, which is `build/ios` for `flutter run` and `flutter build ios` but not for the archive of `flutter build ipa`. flutterfire writes the phase again in each of its runs, so `${FirebaseCoreModule.configureScript}` ends each flavor with `$crashlyticsPhaseFixScript`, which points the phase at `build/ios/SourcePackages`. After running `flutterfire configure` yourself on macOS, run that script in the directory of the app:

```bash
$crashlyticsPhaseFixCommand
```

The phase looks up the build configuration in `firebase.json`. So on macOS, once one flavor is configured, a build of a flavor that is not fails in the phase with `FirebaseJsonException: Please run "flutterfire configure"`. Run `dart ${FirebaseCoreModule.configureScript} <flavor> --project=<id>` for that flavor.
''';
