import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_auth/src/enable_sign_in.dart';
import 'package:smf_firebase_auth/src/readme.dart';

/// The note of the module in the guide for coding agents of the app, in the
/// section of the authentication: which file is on Firebase Authentication,
/// where a code of Firebase gets its reason, and that the ways to sign in
/// are enabled in the Firebase project, by a script of the app that an
/// agent runs only when asked.
const agentNote = '''
With `firebase_auth`:

- `FirebaseAuthService` in `$serviceFile` implements `AuthService` on `FirebaseAuth.instance`. In `lib/`, only that file imports the package: other code signs in through `appSession`.
- That file gives each code of Firebase its `AuthFailureReason`, in `_failureOf()`. A code that it does not know becomes `unknown`: give it a reason there.
- The ways to sign in are enabled in the Firebase project, not in the code. A call that fails with `notConfigured` tells in its `developerHint` how, and so does the section $readmeHeading of `${AppEntryRole.readmeFile}`.
- `$enableSignInScript` enables them with the Firebase CLI. It changes the Firebase project and needs a Firebase account: run it only when asked.
''';
