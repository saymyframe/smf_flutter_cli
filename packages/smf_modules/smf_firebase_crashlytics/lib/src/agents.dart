import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_crashlytics/src/crashlytics_phase.dart';

/// The note of the module in the guide for coding agents of the app, in the
/// section of the crash reporting: why the code reports through the
/// reporter of the app, and what follows `flutterfire configure` by hand on
/// macOS.
const agentNote = '''
With `firebase_crashlytics`:

- Report through `CrashReporter`, not through `FirebaseCrashlytics.instance`.
- `${FirebaseCoreModule.configureScript}` keeps the build phase for Crashlytics working for `flutter build ipa` on macOS. After `flutterfire configure` by hand, `flutter build ipa` needs `$crashlyticsPhaseFixScript`.
''';
