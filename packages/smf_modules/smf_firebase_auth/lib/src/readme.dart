import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_auth/src/enable_sign_in.dart';

/// The heading of the section of the module in the README of the app.
const readmeHeading = 'Firebase Authentication';

/// The path in the app of the file with the service of the module.
const serviceFile = 'lib/core/auth/firebase_auth_service.dart';

/// The page of the Firebase console with the sign-in methods of the project
/// that the user picks there, as the documentation of Firebase links it.
const _signInMethods =
    'https://console.firebase.google.com/project/_/authentication/providers';

/// The section of the module in the README of the app, which also has the
/// section of the auth role, with the mode of the app: which ways to sign
/// in the mode needs and what the app does until they are enabled, how the
/// script of the app enables them and what it does to the Firebase project,
/// where the Firebase console enables them, where the message of a password
/// reset comes from, and what becomes of an anonymous user who signs in to
/// an account.
///
/// In an app with ways to sign in with an identity provider, [methods] by
/// [firebaseMethodsOf], it also tells what the script sets up in the
/// project and in the app for each, by what they need (see
/// [enableSignInScript]), what it leaves to the developer of the app, such
/// as the SHA of the key of a release, and how Apple is enabled, each with
/// a word on the section of the steps by hand, which lists them.
///
/// It names the pages of the Firebase console as the documentation of
/// Firebase does, with the links that the documentation has for them.
String readmeSectionOf(Map<String, Set<SignInNeed>> methods) {
  final google = methods.containsKey('google.com');
  final apple = methods.containsKey('apple.com');
  final needs = {for (final needs in methods.values) ...needs};
  final providers = [if (google) 'Google', if (apple) 'Apple'];
  final changesFiles = needs.contains(SignInNeed.serverClient) ||
      needs.contains(SignInNeed.iosClient);
  return '''
The app signs in with [Firebase Authentication](https://firebase.google.com/docs/auth) through `firebase_auth`: `$serviceFile` implements the sign-in service of the app on it.

The ways to sign in are enabled in the Firebase project, not in the code: Email/Password in every mode of the app, ${providers.isEmpty ? 'and ' : ''}Anonymous when the mode of the app is `${AuthMode.anonymous.name}` (see the section ${AuthRole.readmeHeading})${providers.isEmpty ? '' : ', and ${providers.join(' and ')} for the ways to sign in of the app'}. Until they are enabled, signing in and signing up fail with the reason `notConfigured`, and the `developerHint` of the failure tells how to enable them. In the mode `${AuthMode.anonymous.name}`, the app also starts without a user.

`smf create` asks to enable them right after `flutterfire configure` has configured the app. To enable them later, for another Firebase project, or after you changed the mode of the app to `${AuthMode.anonymous.name}`, run in the directory of the app:

```bash
$enableSignInCommand
```

The script reads the project from `firebase.json`, where `flutterfire configure` wrote it, and the mode from `authMode` in `${AuthRole.sessionFile}`, and says which project and which mode it enables them for. It enables the methods with `firebase deploy --only auth` of the [Firebase CLI](https://firebase.google.com/docs/cli) $firstFirebaseCliWithSignIn or later. It never disables a method, and it changes no file of the app${changesFiles ? ' but those that Google needs, as told below' : ''}. `--project <id>` names another project, and the other arguments go to the Firebase CLI as they are. The script runs the Firebase CLI in a temporary directory, where an account that `firebase login:use` chose for the directory of the app does not apply. To name the account:

```bash
$enableSignInCommand --account <email>
```
${google || needs.isNotEmpty ? _googleOf(google, needs) : ''}${apple ? _apple : ''}
You can also enable the methods in the Firebase console, under [Authentication > Sign-in method]($_signInMethods) in the project that the app is configured for.

Firebase sends the message with which a user sets a new password from a template of the project: [Authentication > Templates](https://console.firebase.google.com/project/_/authentication/emails).

`appSession.userToken()` is a Firebase ID token. A server of the app verifies it with the [Firebase Admin SDK](https://firebase.google.com/docs/auth/admin/verify-id-tokens). The Admin SDK takes only a token of its own Firebase project, so a token of another project fails there.

When an anonymous user signs in to an account that exists already, the anonymous user stays in the project, and nobody can sign in as that user again. A project that is upgraded to Firebase Authentication with Identity Platform can delete anonymous users that are older than 30 days automatically. See [Automatic clean-up](https://firebase.google.com/docs/auth/android/anonymous-auth#auto-cleanup) in the documentation of Firebase.
''';
}

/// What the README tells of the way to sign in of Google, if [google], and
/// of what the script sets up in the project and in the app for [needs],
/// which it does only for the project that `firebase.json` names, and of
/// the keys of a release for the certificate of the Android app, which the
/// section of the steps by hand lists (see
/// `FirebaseAuthModule.googleReleaseShaStep`).
String _googleOf(bool google, Set<SignInNeed> needs) {
  const brand = '''

For Google sign-in, the script also gives Google the name of the app and the email address of the account of the Firebase CLI for the consent screen that users see when they sign in. The address is the support email there. When the Firebase CLI runs as no user account, as with a service account, the script leaves Google out and says so: run it with `--account <email>`, or enable Google in the Firebase console.
''';
  const debugKey = 'It registers the SHA-1 and SHA-256 of the Android debug '
      'key of the machine that runs it, which Google uses to recognize the '
      'Android app. When the machine has no debug key yet, the script creates '
      'it, as the first debug build would. Every machine has a debug key of '
      'its own, so run the script on each machine that builds the app for '
      'debugging, or add the SHA of its key in the Firebase console, in the '
      'settings of the Android app.';
  const files = 'It downloads the Firebase files of the app again, such as '
      '`android/app/google-services.json` and '
      '`ios/Runner/GoogleService-Info.plist`, once they have the clients of '
      'Google, and writes them where `flutterfire configure` wrote them.';
  const scheme = 'It writes the URL scheme of the iOS app, '
      '`REVERSED_CLIENT_ID` of `ios/Runner/GoogleService-Info.plist`, into '
      '`CFBundleURLTypes` of `ios/Runner/Info.plist`. It adds the scheme and '
      'removes none: after a change of the project, remove the scheme of the '
      'former project there by hand.';
  final steps = [
    if (needs.contains(SignInNeed.androidCertificate)) debugKey,
    if (needs.contains(SignInNeed.serverClient) ||
        needs.contains(SignInNeed.iosClient))
      files,
    if (needs.contains(SignInNeed.iosClient)) scheme,
  ];
  final setup = steps.isEmpty
      ? ''
      : '''

The script sets up the rest of what Google needs only for the project that `firebase.json` names, not for one that `--project` names:

${[for (final step in steps) '- $step'].join('\n')}

Run the script again after `flutterfire configure` for another project.
''';
  const release = '''

A release of the Android app is signed with another key, whose SHA-1 and SHA-256 Google needs too: those of the upload key, and of the app signing key of Google Play, under Test and release > App integrity in the Play Console. Add each with the Firebase CLI, with the id of the Android app from `firebase.json`:

```bash
firebase apps:android:sha:create <appId> <sha>
```

The section ${AppEntryRole.setupHeading} lists this among the steps that you do by hand.
''';
  return [
    if (google) brand,
    setup,
    if (needs.contains(SignInNeed.androidCertificate)) release,
  ].join();
}

/// What the README tells of the way to sign in of Apple, which no command
/// of the Firebase CLI enables, and of the key with which Firebase revokes
/// the tokens of Apple; the section of the steps by hand lists both (see
/// `FirebaseAuthModule.appleProviderStep` and
/// `FirebaseAuthModule.appleRevocationStep`).
const _apple = '''

Apple is enabled in the Firebase console, which the Firebase CLI cannot do: add Apple under [Authentication > Sign-in method]($_signInMethods). Deleting an account that signs in with Apple revokes the tokens that Apple gave the app, as the App Store asks of an app with Sign in with Apple (App Store Review Guideline 5.1.1(v)). Firebase does that with the Services ID and the OAuth code flow configuration, which you enter in the settings of the Apple provider there: your Apple team ID, and the Key ID and the private key of a key for Sign in with Apple. The private key is a secret: enter it in the console yourself, and never put it into the app or its repository. Until they are set, deleting an account that signs in with Apple fails with `notConfigured`, and the account stays. The section ${AppEntryRole.setupHeading} lists both, adding Apple and entering the key, among the steps that you do by hand.
''';
