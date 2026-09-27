import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/src/preflight/xcode_project_tools.dart';

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

/// The program of Ruby that points the phase at [crashlyticsScriptInApp]: in
/// the file that its argument names, it replaces every
/// [crashlyticsScriptInBuildDirectory] with it, byte for byte, whatever the
/// encoding of the file and the locale, and writes the file only when it
/// had the path. Without the file, it does nothing.
const _program = 'f = ARGV[0]; exit unless File.exist?(f); '
    's = File.binread(f); '
    't = s.gsub("$crashlyticsScriptInBuildDirectory", '
    '"$crashlyticsScriptInApp"); '
    'File.binwrite(f, t) unless t == s';

/// The command of [crashlyticsPhaseFix] as the user types it in the
/// directory of the app on macOS.
const crashlyticsPhaseFixCommand =
    "ruby -e '$_program' ${AppEntryRole.xcodeProjectFile}";

/// The step that follows `flutterfire configure` and points the build phase
/// for Crashlytics that flutterfire adds at the upload script of Crashlytics
/// in `build/ios/SourcePackages` of the app, so that `flutter build ipa`
/// finds it; see [crashlyticsScriptInBuildDirectory].
///
/// It replaces [crashlyticsScriptInBuildDirectory] with
/// [crashlyticsScriptInApp] in the Xcode project of the app, with Ruby,
/// which `flutterfire configure` needs on macOS too, and changes nothing
/// else. An app without the phase, such as one without firebase_crashlytics,
/// or with a phase of another version of flutterfire that has no such path,
/// stays as it is, and so does an app that the step fixed already.
///
/// flutterfire adds the phase only on macOS, so elsewhere the step, which
/// needs the check that the machine is a Mac, is left for later: the app is
/// configured again on a Mac, and the step follows that.
PostGenStep crashlyticsPhaseFix() => PostGenStep(
      const ToolRef('ruby'),
      const ['-e', _program, AppEntryRole.xcodeProjectFile],
      description: 'Fixing the Crashlytics phase of flutterfire for '
          'flutter build ipa',
      skippable: true,
      needs: [const XcodeProjectOnMacCheck().id],
    );
