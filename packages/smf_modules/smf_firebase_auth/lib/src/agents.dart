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

/// The note of the module for an app with ways to sign in with an identity
/// provider, [methods] by [firebaseMethodsOf], in the same section after
/// [agentNote], or `null` for an app without them: what else the script of
/// the app does for them, and what the developer of the app does by hand.
String? methodsAgentNote(Map<String, Set<SignInNeed>> methods) {
  const google = '- For Google sign-in, `$enableSignInScript` also registers '
      'the SHA of the Android debug key of the machine in the Firebase '
      'project, downloads the Firebase files of the app again and writes the '
      'URL scheme of the iOS app into `ios/Runner/Info.plist`. After '
      '`flutterfire configure` for another project, it has to run again: run '
      'it only when asked.';
  const apple = '- Apple is enabled in the Firebase console by hand, with the '
      'private key of Apple that deleting an account needs. That key is a '
      'secret: never put it into the app or its repository.';
  final lines = [
    if (methods.values.any((needs) => needs.isNotEmpty)) google,
    if (methods.containsKey('apple.com')) apple,
  ];
  return lines.isEmpty ? null : '${lines.join('\n')}\n';
}
