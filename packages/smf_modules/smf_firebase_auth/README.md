# smf_firebase_auth

The SMF module of [Firebase Authentication](https://firebase.google.com/docs/auth) with [firebase_auth](https://pub.dev/packages/firebase_auth). It provides the auth role of SMF: the users of the app sign in with an email address and a password, and the app can sign in anonymous users.

The auth role generates `appSession`, which tells who uses the app and through which the code of the app signs in, up and out, and the `AuthService` interface. This module adds `firebase_auth` to the app and implements the interface on `FirebaseAuth`. Firebase keeps the user on the device, so the app knows who is signed in before its first frame. The service gives each error code of Firebase a reason that the app shows a text for. When sign-in is not enabled in the Firebase project, the failure has a hint for the developer with the link to the page of the project where it is enabled.

Firebase Authentication works on the Firebase app, so the module depends on [smf_firebase_core](https://pub.dev/packages/smf_firebase_core), which comes with it and sets up Firebase.

The ways to sign in are enabled in the Firebase project, not in the code: Email/Password, and Anonymous for an app that signs in anonymous users. The README of the app tells where.

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
