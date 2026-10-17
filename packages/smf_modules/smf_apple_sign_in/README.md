# smf_apple_sign_in

The SMF module of [Sign in with Apple](https://developer.apple.com/sign-in-with-apple/) with [sign_in_with_apple](https://pub.dev/packages/sign_in_with_apple). The users of the app sign in with their Apple Account on iOS, next to the other ways to sign in of the app.

The module gives the auth role of SMF a way to sign in, with the label "Continue with Apple" in English and Ukrainian and the Apple logo as its icon. The auth role lists it in `appSignInMethods`, and a screen of sign-in shows its button on iOS only. `appleCredential()` asks Apple for a credential with the sheet of Sign in with Apple, with the SHA-256 hash of a new random nonce, and returns the ID token of Apple with the nonce, the authorization code and the name of the user. Apple gives the name only the first time that a user signs in to the app. The app gives the credential to its provider of sign-in. A closed sheet is no failure: the function returns `null`.

The App Store takes Sign in with Apple as the equivalent of a login service of a third party, such as Google, which an app on iOS with such a service needs (App Store Review Guideline 4.8). Deleting an account that signs in with Apple asks Apple again first, so that the provider of sign-in can revoke the tokens of Apple, as Guideline 5.1.1(v) asks. The backend of the provider needs a key of Apple for that.

The module signs the iOS app with the entitlement of the capability, `com.apple.developer.applesignin`. Signing with it needs a team of the paid Apple Developer Program. The README of the app tells how to run the app on an iPhone with a free team, and that Apple asks for its own logo artwork in the button, which App Review checks.

## Use with the SMF CLI

The module needs a provider of the authentication of the app, such as `firebase_auth`:

```bash
smf create my_app -m firebase_auth,apple_sign_in
```

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Documentation

- [The apple_sign_in module](https://doc.saymyframe.com/modules/apple-sign-in)
