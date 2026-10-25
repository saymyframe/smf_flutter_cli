import 'package:smf_contracts/smf_contracts.dart';

/// The note of the module in the guide for coding agents of an app with a
/// router, in the section of the analytics: the function of its file that
/// logs the screen views, and the native files that turn off those that
/// Firebase Analytics logs itself.
const screenViewsAgentNote = '''
With `firebase_analytics`:

- Screen views need no code: the router calls `logFirebaseScreenView()` with each screen that the user sees, and it logs the screen under the name of its route.
- `${AppEntryRole.androidManifestFile}` and `${AppEntryRole.infoPlistFile}` turn off the screen views that Firebase Analytics logs itself, which would name the one activity or view controller of Flutter rather than a screen.
''';
