import 'package:smf_firebase_core/smf_firebase_core.dart';

/// Where the build phase for Crashlytics that `flutterfire configure` of
/// flutterfire_cli 1.4.1 adds to the Xcode project looks for the upload
/// script of Crashlytics among the Swift packages of the app: in the build
/// directory of Xcode.
///
/// On macOS, flutterfire adds the phase, named
/// `FlutterFire: "flutterfire upload-crashlytics-symbols"`, to an app that
/// depends on firebase_crashlytics
/// (`lib/src/firebase/firebase_apple_writes.dart` of flutterfire_cli 1.4.1),
/// and the path is twice in its script. Flutter puts the Swift packages of
/// the app into `build/ios/SourcePackages`, and `flutter run` and
/// `flutter build ios` set the build directory to `build/ios`, so the phase
/// finds the script there. `flutter build ipa` archives the app without
/// setting it, since Xcode would not copy the debug symbols into the archive
/// then (`lib/src/ios/mac.dart` of the tools of Flutter 3.44), so the phase
/// misses the script, and the archive fails.
const crashlyticsScriptInBuildDirectory =
    r'$BUILD_DIR/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run';

/// Where the upload script of Crashlytics is, in `build/ios/SourcePackages`
/// of the app, for the build phase of flutterfire: `$SRCROOT` is the
/// directory of the Xcode project, `ios`.
///
/// For `flutter run` and `flutter build ios` it is the path that
/// [crashlyticsScriptInBuildDirectory] gives, and `flutter build ipa` finds
/// the script there too. With another build directory of Flutter than
/// `build`, as `flutter config --build-dir` sets it, the phase finds the
/// script for those builds by its search of the build directory of Xcode,
/// and `flutter build ipa` does not, with this path or without it.
const crashlyticsScriptInApp = r'$SRCROOT/../build/ios/SourcePackages/'
    'checkouts/firebase-ios-sdk/Crashlytics/run';

/// The script of the app that points the build phase for Crashlytics at
/// [crashlyticsScriptInApp]: in the Xcode project, it replaces every
/// [crashlyticsScriptInBuildDirectory] with it, and changes nothing else. An
/// app with a phase of another version of flutterfire that has no such path
/// stays as it is, and so does an app that the script fixed already; its
/// output says so.
///
/// flutterfire writes the phase again in each of its runs, so a fix once after
/// generation would break `flutter build ipa` with the next flavor that the
/// developer configures. The script is in
/// [FirebaseCoreModule.configuredHooksDirectory], whose files the script that
/// configures a flavor runs after flutterfire. flutterfire changes the Xcode
/// project only on macOS, so elsewhere the script does nothing.
const crashlyticsPhaseFixScript =
    '${FirebaseCoreModule.configuredHooksDirectory}/fix_crashlytics_phase.dart';

/// The command of [crashlyticsPhaseFixScript] as the developer types it in the
/// directory of the app, after `flutterfire configure` by hand.
const crashlyticsPhaseFixCommand = 'dart $crashlyticsPhaseFixScript';
