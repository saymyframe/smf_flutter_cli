import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/src/configure.dart';
import 'package:smf_firebase_core/src/preflight/flutterfire_cli.dart';

/// The heading of the section of the module in the README of the app.
const readmeHeading = 'Firebase';

/// The section of the module in the README of the app.
final String readmeSection = '''
The app uses [Firebase](https://firebase.google.com/docs/flutter/setup) through `firebase_core`: `bootstrap()` initializes it with `firebaseOptionsOfFlavor` of `lib/firebase_options_of_flavor.dart`, which takes the options of the flavor of the build from `lib/firebase_options_<flavor>.dart`. A flavor may have a Firebase project of its own or share one. Until a flavor is configured, its options are a placeholder, and a build of it stops at start-up with an `UnsupportedError` that gives the command below.

`smf create` configures `${AppEntryRole.defaultFlavor.name}`. To configure a flavor, or to configure it again, such as for another project or on another machine, run in the directory of the app:

```bash
dart pub global activate flutterfire_cli $flutterfireVersion
firebase login
dart $configureScriptPath staging --project=<id>
```

Use this script rather than `flutterfire configure`, which would write files that no flavor reads. It registers the Android and iOS apps of the flavor in the project and writes its options, `android/app/src/<flavor>/google-services.json`, `firebase.json` and, on macOS, `ios/flavors/<flavor>/GoogleService-Info.plist`. Commit them. In a terminal you may leave `--project` out, and flutterfire then asks. Other arguments, such as `--account=<email>`, go to flutterfire. The ids of each flavor are at the top of the script: if you change them in the projects, change them there too.

Once one flavor is configured, a build of a flavor that is not fails on Android, with `File google-services.json is missing`. On iOS it builds and stops at start-up, unless a build phase that flutterfire adds for a Firebase package fails the build there first.

In Xcode, select the scheme of a flavor. It builds that flavor, whatever `ios/Flutter/Generated.xcconfig` says. The scheme `Runner` takes the flavor from that file, which has none after a fresh `flutter pub get`, so `appFlavor` is `null` there and `firebaseOptionsOfFlavor` throws an `UnsupportedError`. `flutter build ios --config-only --flavor <flavor>` gives the file a flavor.

The script changes the Xcode project only on macOS, and adds a build phase that runs `flutterfire` from `~/.pub-cache/bin`. So every Mac that builds the app for iOS needs the FlutterFire CLI activated, flutterfire_cli $minimumFlutterfireVersion or a later 1.x; if `dart pub global list` shows one already, skip its activation above. flutterfire needs the [Firebase CLI](https://firebase.google.com/docs/cli).
''';
