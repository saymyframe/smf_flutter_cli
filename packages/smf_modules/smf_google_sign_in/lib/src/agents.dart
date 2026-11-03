import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_google_sign_in/src/readme.dart';

/// The note of the module in the guide for coding agents of the app, under
/// a heading of its own: which file asks Google and how it starts the
/// package, which errors become which reason, how the function checks the
/// setup of the iOS app first, what the icon shows, and what a test of the
/// app replaces for the function to ask Google.
///
/// How a screen signs in with a way to sign in is for the auth role to
/// tell, in its own section of the guide.
const agentNote = '''
With `google_sign_in`:

- `googleCredential()` in `$googleSignInFile` is the function of the way to sign in with Google in `${AuthRole.appSignInMethods}`, on Android and iOS. In `lib/`, only that file imports the package. It starts the package once with `GoogleSignIn.instance.initialize()`, without ids, so that the package reads the ids of the clients of Google from the files of the app, and then calls `GoogleSignIn.instance.authenticate()`. It returns an `IdTokenCredential` with the `idToken` of the account and no `rawNonce`.
- A closed sheet, `GoogleSignInExceptionCode.canceled`, returns `null`. These fail with `notConfigured`: a `canceled` whose description has `Account reauth failed`, which Credential Manager answers on Android when Google does not know the SHA-1 of the key that signed the app or the device cannot reach Google; `clientConfigurationError`; `providerConfigurationError`; and an `unknownError` whose description has the code `28444`, which Credential Manager answers when Google does not take the server client of the app as a web client of the Google project. Any other error fails with `unknown`.
- On iOS, the Google Sign-In SDK stops an app that has no iOS client of Google, an empty one, or no URL scheme for it, and the package does not catch that. So on iOS the function first calls `readGoogleSignInIosSetup()`, which asks the handler of the method channel `google_sign_in/ios_setup` in `didInitializeImplicitFlutterEngine(_:)` of `${AppEntryRole.appDelegateFile}`. If the setup has a `problem`, the function fails with `notConfigured` without asking the SDK. It fails the same way when the app delegate does not answer.
- `GoogleSignInIcon` shows the logo of Google, `$googleLogoFile`, which `pubspec.yaml` declares among the assets of the app, at the size of the `IconTheme` around it. The branding guidelines of Google allow no other colours or shape of the logo.
- In a test, the package asks `GoogleSignInPlatform.instance` of google_sign_in_platform_interface, which the test replaces with a subclass of `GoogleSignInPlatform` that answers `init` and `authenticate`, before the first call of `googleCredential()`: the app starts the package once in a test file. On iOS the function asks the method channel `google_sign_in/ios_setup` before the package, so a test answers it with `setMockMethodCallHandler` the way the app delegate of a set-up app does: `serviceInfo`, `serviceInfoClientId` and `urlSchemes` with the reversed client id.
''';
