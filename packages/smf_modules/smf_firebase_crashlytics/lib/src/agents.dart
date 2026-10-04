import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_crashlytics/src/readme.dart';

/// The note of the module in the guide for coding agents of the app, in the
/// section of the crash reporting: why the code reports through the
/// reporter of the app, and the step that follows `flutterfire configure`
/// on macOS.
const agentNote = '''
With `firebase_crashlytics`:

- Report through `CrashReporter`, not through `FirebaseCrashlytics.instance`.
- After `flutterfire configure` runs on macOS, `flutter build ipa` needs the fix of the section $readmeHeading of `${AppEntryRole.readmeFile}`.
''';
