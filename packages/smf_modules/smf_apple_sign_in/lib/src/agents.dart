import 'package:smf_apple_sign_in/src/readme.dart';
import 'package:smf_contracts/smf_contracts.dart';

/// The note of the module in the guide for coding agents of the app, under
/// a heading of its own: which file asks Apple and what it returns, what
/// Apple gives only at the first sign-in, which errors become which reason,
/// the entitlement of the capability, and what a test of the app sets for
/// the function to ask Apple.
///
/// How a screen signs in with a way to sign in, and what the deletion of an
/// account asks of it, is for the auth role to tell, in its own section of
/// the guide.
const agentNote = '''
With `sign_in_with_apple`:

- `appleCredential()` in `$appleSignInFile` is the function of the way to sign in with Apple in `${AuthRole.appSignInMethods}`, which works on iOS only. In `lib/`, only that file imports the package. It asks `SignInWithApple.getAppleIDCredential()` with the SHA-256 hash of a nonce of `generateNonce()`, and returns an `IdTokenCredential` with that nonce as its `rawNonce` and the `authorizationCode` of the request.
- Apple gives `givenName` and `familyName` only the first time that a user signs in to the app. A later credential has none, so do not expect the name there.
- A closed sheet, `AuthorizationErrorCode.canceled`, returns `null`. `AuthorizationErrorCode.unknown`, which Apple answers when the app is signed without the entitlement `$appleSignInEntitlement` of `${AppEntryRole.iosEntitlementsFile}`, fails with `notConfigured`, and any other error with `unknown`.
- In a test, `appleCredential()` asks Apple only while `debugDefaultTargetPlatformOverride` is `TargetPlatform.iOS`. The package asks the platform on the method channel `com.aboutyou.dart_packages.sign_in_with_apple`, whose method `performAuthorizationRequest` a test answers with a map whose `type` is `appleid`, with `identityToken`, `authorizationCode`, `givenName` and `familyName`.
''';
