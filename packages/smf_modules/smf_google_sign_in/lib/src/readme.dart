import 'package:smf_contracts/smf_contracts.dart';

/// The heading of the section of the module in the README of the app, and
/// of its note in the guide for coding agents of the app.
const readmeHeading = 'Google sign-in';

/// The path in the app of the file with the function of the way to sign in
/// and with its icon.
const googleSignInFile = 'lib/core/google_sign_in/google_sign_in.dart';

/// The path in the app of the image of the logo of Google, which the icon
/// shows and `pubspec.yaml` of the app declares among its assets.
const googleLogoFile = 'lib/core/google_sign_in/assets/google_logo.png';

/// The branding guidelines of Sign in with Google.
const _branding = 'https://developers.google.com/identity/branding-guidelines';

/// The section of the module in the README of the app: what Google needs of
/// the Google project and of the app on Android and on iOS, where
/// google_sign_in reads the ids of the clients of Google, that the section
/// of the provider of sign-in tells what it sets up, that the SDK of Google
/// stops an iOS app that lacks its client, what the two answers of
/// Credential Manager on Android that point at the setup mean, and the logo
/// of Google, which the branding guidelines of Google keep as it is.
const String readmeSection = '''
The app signs in with Google on Android and iOS: `googleCredential()` in `$googleSignInFile` asks Google for a credential with the sheet of Google sign-in. A sign-in screen of the app, such as the one of the `sign_in` module, shows the button of Google.

Google sign-in needs the Google project of the app to know the app, and the app to know the clients of Google:

- On Android, Google knows the app by the name of its package and the SHA-1 of each key that signs it: the debug key of each machine that builds the app, the upload key, and the app signing key of Google Play.
- On iOS, the app needs the id of its iOS client of Google, and the reversed id of that client as a URL scheme in `CFBundleURLTypes` of `${AppEntryRole.infoPlistFile}`, through which the sheet of Google returns to the app.
- On both, Google issues the ID token to the web client of the Google project, the server client, against which the backend of the provider of sign-in checks the token.

`googleCredential()` starts google_sign_in with `GoogleSignIn.instance.initialize()` without ids, so google_sign_in reads them from the files of the app: on iOS `CLIENT_ID` of `GoogleService-Info.plist`, or `GIDClientID` of `${AppEntryRole.infoPlistFile}`, and on Android the string resource `default_web_client_id`. The section of the provider of sign-in in this README tells which of these it sets up. To use ids of your own, pass them to `initialize()` in `googleCredential()` of `$googleSignInFile`. Until Google sign-in is set up, signing in with Google fails with the reason `notConfigured`, and the `developerHint` of the failure tells what Google answered.

On iOS, the Google Sign-In SDK stops the app instead when the app has no iOS client of Google or not its URL scheme: google_sign_in does not catch the exception that the SDK throws then. Set both up before you try the button on iOS.

On Android, the `developerHint` has one of two answers of Credential Manager when the setup is the cause:

- `[16] Account reauth failed.`, after the user picked an account: Google does not know the SHA-1 of the key that signed this build of the app. Register the SHA-1 of that key, such as the upload key or the app signing key of Google Play for a release. A device that cannot reach Google gets the same answer.
- `[28444] Developer console is not set up correctly.`: Google does not take the server client of the app as a web client of the Google project, as when `initialize()` gets the id of the Android client as its `serverClientId`. Use the id of the web client.

The icon of the button, `GoogleSignInIcon` in `$googleSignInFile`, shows the "G" of Google from `$googleLogoFile`, the logo of the Google Sign-In SDK (Apache License 2.0). The [branding guidelines of Sign in with Google]($_branding) ask a custom button to show that logo in its own colours, on a light background, without a change: keep the image as it is.
''';
