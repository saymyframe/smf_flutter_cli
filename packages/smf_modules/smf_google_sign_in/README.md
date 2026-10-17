# smf_google_sign_in

The SMF module of Google sign-in with [google_sign_in](https://pub.dev/packages/google_sign_in). The users of the app sign in with their Google account on Android and iOS, next to the other ways to sign in of the app.

The module gives the auth role of SMF a way to sign in, with the label "Continue with Google" in English and Ukrainian and the "G" of Google as its icon. The auth role lists it in `appSignInMethods`, and a screen of sign-in shows its button on Android and iOS. `googleCredential()` asks Google for a credential with the sheet of Google sign-in and returns the ID token of the Google account. The app gives the credential to its provider of sign-in. A closed sheet is no failure: the function returns `null`.

Google sign-in needs the Google project to know the app: the SHA-1 of the keys that sign the Android app, an iOS client whose reversed id is a URL scheme of the app, and the web client that the ID token is issued to. The module states these needs to the provider of sign-in, which sets them up or tells how in the README of the app. google_sign_in reads the ids of the clients from the files of the app, so the module passes it none.

For the App Store, Google sign-in is a login service of a third party. An app on iOS with it also needs a way to sign in that the App Store takes as its equivalent, such as Sign in with Apple (App Store Review Guideline 4.8), and `smf create` warns of an app without one.

## Use with the SMF CLI

The module needs a provider of the authentication of the app, such as `firebase_auth`:

```bash
smf create my_app -m firebase_auth,google_sign_in,apple_sign_in
```

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Documentation

- [The google_sign_in module](https://doc.saymyframe.com/modules/google-sign-in)

## Third-party content

The image of the Google "G" logo in the brick of the module comes from the [Google Sign-In SDK for iOS](https://github.com/google/GoogleSignIn-iOS), licensed under the Apache License 2.0 (see `NOTICE`). Google and the Google "G" logo are trademarks of Google LLC.
