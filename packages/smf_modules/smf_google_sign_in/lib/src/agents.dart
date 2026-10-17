import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_google_sign_in/src/readme.dart';

/// The note of the module in the guide for coding agents of the app, under
/// a heading of its own: which file asks Google and how it starts the
/// package, which errors become which reason, what the icon shows, and what
/// a test of the app replaces for the function to ask Google.
///
/// How a screen signs in with a way to sign in is for the auth role to
/// tell, in its own section of the guide.
const agentNote = '''
With `google_sign_in`:

- `googleCredential()` in `$googleSignInFile` is the function of the way to sign in with Google in `${AuthRole.appSignInMethods}`, on Android and iOS. In `lib/`, only that file imports the package. It starts the package once with `GoogleSignIn.instance.initialize()`, without ids, so that the package reads the ids of the clients of Google from the files of the app, and then calls `GoogleSignIn.instance.authenticate()`. It returns an `IdTokenCredential` with the `idToken` of the account and no `rawNonce`.
- A closed sheet, `GoogleSignInExceptionCode.canceled`, returns `null`. These fail with `notConfigured`: `clientConfigurationError`, `providerConfigurationError`, an `unknownError` whose description has `[28444]` (Credential Manager answers so when the Google project does not know the key that signed the Android app), and a `PlatformException` with the code `google_sign_in` (the plugin throws it on iOS without the iOS client or its URL scheme). Any other error fails with `unknown`.
- `GoogleSignInIcon` shows the logo of Google, `$googleLogoFile`, which `pubspec.yaml` declares among the assets of the app, at the size of the `IconTheme` around it. The branding guidelines of Google allow no other colours or shape of the logo.
- In a test, the package asks `GoogleSignInPlatform.instance` of google_sign_in_platform_interface, which the test replaces with a subclass of `GoogleSignInPlatform` that answers `init` and `authenticate`, before the first call of `googleCredential()`: the app starts the package once in a test file.
''';
