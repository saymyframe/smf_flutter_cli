import 'package:smf_contracts/smf_contracts.dart';

/// The heading of the section of the module in the README of the app, and
/// of its note in the guide for coding agents of the app.
const readmeHeading = 'Sign in with Apple';

/// The path in the app of the file with the function of the way to sign in
/// and with its icon.
const appleSignInFile = 'lib/core/apple_sign_in/apple_sign_in.dart';

/// The entitlement of the capability Sign in with Apple, with which the iOS
/// app is signed.
const appleSignInEntitlement = 'com.apple.developer.applesignin';

/// The section of the module in the README of the app: that the way to sign
/// in works on iOS only, what its capability needs of the team that signs
/// the app and how to run the app with a free team, what Apple gives only
/// at the first sign-in, what the deletion of an account asks of Apple and
/// of the backend of the provider of sign-in, and the logo of Apple, which
/// App Review checks.
const String readmeSection = '''
The app signs in with Apple on iOS: `appleCredential()` in `$appleSignInFile` asks Apple for a credential with the sheet of Sign in with Apple, and a screen of sign-in shows the button of Apple on iOS only. On Android the app has no Sign in with Apple.

Sign in with Apple is a capability of the app. The key `$appleSignInEntitlement` in `${AppEntryRole.iosEntitlementsFile}` asks for it, and the App ID of the app needs it too: when Xcode manages the signing of the app, it adds the capability to the App ID. Signing with the capability needs a team of the paid Apple Developer Program. A free personal team cannot sign the app for an iPhone: to run the app there, remove the key from `${AppEntryRole.iosEntitlementsFile}`, and signing in with Apple then fails with the reason `notConfigured`. Without the capability, Apple answers with an unknown error, which fails with `notConfigured` too.

Apple gives the name of the user only the first time that the user signs in to the app: the credential has it then, and a later one has none. The user may also hide the email address. The account then gets an address of the private relay of Apple, which forwards messages to the user.

The App Store asks an app with Sign in with Apple to revoke the tokens that Apple gave it when the user deletes the account (App Store Review Guideline 5.1.1(v)). So `appSession.deleteAccount()` asks Apple for a new authorization first, and the provider of sign-in revokes the tokens with its code. The backend of the app needs a key of Apple to revoke them, and the documentation of the provider of sign-in tells where to set it. If the user closes the sheet of Apple, nothing is deleted.

The icon of the button, `AppleSignInIcon` in `$appleSignInFile`, is the Apple logo of the Material icons. Apple asks a custom button of Sign in with Apple to use the logo artwork of [Apple Design Resources](https://developer.apple.com/design/resources/), and App Review checks every such button. Before you submit the app, download that logo and show it in `AppleSignInIcon`.
''';
