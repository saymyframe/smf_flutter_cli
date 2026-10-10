import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_auth/src/enable_sign_in.dart';

/// The heading of the section of the module in the README of the app.
const readmeHeading = 'Firebase Authentication';

/// The path in the app of the file with the service of the module.
const serviceFile = 'lib/core/auth/firebase_auth_service.dart';

/// The section of the module in the README of the app, which also has the
/// section of the auth role, with the mode of the app: which ways to sign
/// in the mode needs and what the app does until they are enabled, how the
/// script of the app enables them and what it does to the Firebase project,
/// where the Firebase console enables them, where the message of a password
/// reset comes from, and what becomes of an anonymous user who signs in to
/// an account.
///
/// It names the pages of the Firebase console as the documentation of
/// Firebase does, with the links that the documentation has for them.
final String readmeSection = '''
The app signs in with [Firebase Authentication](https://firebase.google.com/docs/auth) through `firebase_auth`: `$serviceFile` implements the sign-in service of the app on it.

The ways to sign in are enabled in the Firebase project, not in the code: Email/Password in every mode of the app, and Anonymous when the mode of the app is `${AuthMode.anonymous.name}` (see the section ${AuthRole.readmeHeading}). Until they are enabled, signing in and signing up fail with the reason `notConfigured`, and the `developerHint` of the failure tells how to enable them. In the mode `${AuthMode.anonymous.name}`, the app also starts without a user.

`smf create` offers to enable them right after `flutterfire configure` configured the app. To enable them later, for another Firebase project, or after you changed the mode of the app to `${AuthMode.anonymous.name}`, run in the directory of the app:

```bash
$enableSignInCommand
```

The script reads the project from `firebase.json`, where `flutterfire configure` wrote it, and the mode from `authMode` in `${AuthRole.sessionFile}`. It enables the methods with `firebase deploy --only auth` of the [Firebase CLI](https://firebase.google.com/docs/cli) $firstFirebaseCliWithSignIn or later. It never disables a method, and it changes no file of the app. Its arguments go to the Firebase CLI, so `--project <id>` names another project. The script runs the Firebase CLI in a temporary directory, so the Firebase CLI uses its default account, even when `firebase login:use` chose another account for the directory of the app. To use another account:

```bash
$enableSignInCommand --account <email>
```

The Firebase CLI adds a web app named "Default Web App" to a project that has no web app, because it enables the methods through one (see [issue 11250 of firebase-tools](https://github.com/firebase/firebase-tools/issues/11250)). If you do not want that web app, enable the methods in the Firebase console instead: [Authentication > Sign-in method](https://console.firebase.google.com/project/_/authentication/providers) of the project that the app is configured for.

Firebase sends the message with which a user sets a new password from a template of the project: [Authentication > Templates](https://console.firebase.google.com/project/_/authentication/emails).

When an anonymous user signs in to an account that exists already, the anonymous user stays in the project, and nobody can sign in as that user again. A project that is upgraded to Firebase Authentication with Identity Platform can delete anonymous users that are older than 30 days automatically. See [Automatic clean-up](https://firebase.google.com/docs/auth/android/anonymous-auth#auto-cleanup) in the documentation of Firebase.
''';
