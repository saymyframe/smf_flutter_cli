# smf_firebase_auth

The SMF module of [Firebase Authentication](https://firebase.google.com/docs/auth) with [firebase_auth](https://pub.dev/packages/firebase_auth). It provides the auth role of SMF: the users of the app sign in with an email address and a password, and the app can sign in anonymous users.

The auth role generates `appSession`, which tells who uses the app and through which the code of the app signs in, up and out, and the `AuthService` interface. This module adds `firebase_auth` to the app and implements the interface on `FirebaseAuth`. Firebase keeps the user on the device, so the app knows who is signed in before its first frame. The service gives each error code of Firebase a reason that the app shows a text for. When sign-in is not enabled in the Firebase project, the failure has a hint for the developer that tells how to enable it.

The service also signs in with the credentials that the ways to sign in with Google and Apple get, which other modules give the app. An anonymous user who signs in that way keeps the id. When another user already has the identity, the app signs in to that user's account. On iOS, deleting an account that signs in with Apple asks Apple again and revokes the tokens of Apple first. The revocation needs the Services ID and the OAuth code flow configuration of the Apple sign-in method in the Firebase console. Without them the account is not deleted, and the failure tells the developer what to set.

Firebase Authentication works on the Firebase app, so the module depends on [smf_firebase_core](https://pub.dev/packages/smf_firebase_core), which comes with it and sets up Firebase.

The ways to sign in are enabled in the Firebase project, not in the code: Email/Password, Anonymous for an app that signs in anonymous users, and Google and Apple for an app with those ways to sign in. The module generates `tool/enable_firebase_sign_in.dart`, a script of the app that enables them with the [Firebase CLI](https://firebase.google.com/docs/cli) 15.34.0 or later. For Google sign-in, the script also gives Google the name of the app and the email address of your Firebase account for its consent screen, and registers the SHA-1 and SHA-256 of the Android debug key of your machine. It then downloads the Firebase files of the app again and writes the URL scheme of the iOS app into `ios/Runner/Info.plist`. Apple is enabled in the Firebase console. In a terminal, `smf create` asks to run the script right after `flutterfire configure` has configured the app. The README of the app tells how to enable the ways to sign in with the script or in the Firebase console, and what a release of the Android app needs for Google.

## Use with the SMF CLI

`smf create` asks which module provides the authentication of the app, and offers none as well. To choose this one without the question:

```bash
smf create my_app -m firebase_auth
```

`--auth-mode` says who may use the app without an account: `required`, the default, `guest` or `anonymous`.

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Documentation

- [The firebase_auth module](https://doc.saymyframe.com/modules/firebase-auth)
- [Firebase](https://doc.saymyframe.com/guides/firebase)
