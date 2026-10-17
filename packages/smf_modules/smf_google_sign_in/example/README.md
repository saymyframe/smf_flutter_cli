# Generate a Flutter app that signs in with Google

`google_sign_in` is the module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) with which the users of the app sign in with their Google account on Android and iOS. Choose it with `-m`, next to a provider of sign-in:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m firebase_auth,google_sign_in,apple_sign_in,sign_in,bloc
```

The module adds google_sign_in to the `pubspec.yaml` of the app, with the logo of Google among its assets, and `lib/core/google_sign_in/google_sign_in.dart` with `googleCredential()`, which asks Google for a credential, and `GoogleSignInIcon`, the icon of its button. The auth role lists the way to sign in in `appSignInMethods` of `lib/core/auth/sign_in_methods.dart`:

```dart
const List<SignInMethod> appSignInMethods = [
  SignInMethod(
    label: _googleSignInLabel,
    icon: method0.GoogleSignInIcon(),
    platforms: {TargetPlatform.android, TargetPlatform.iOS},
    credential: method0.googleCredential,
    issuer: 'https://accounts.google.com',
  ),
];
```

A screen of sign-in shows a button for each way to sign in that `isAvailable` on the platform of the app. On a tap, its state asks for a credential and gives it to the session of the app:

```dart
final credential = await method.credential();
if (credential == null) return; // The user closed the sheet of Google.
await appSession.signInWith(credential);
```

An anonymous user who signs in with Google keeps the id. Google sign-in needs the Google project to know the app, and the README of the app tells what that takes and what the provider of sign-in sets up of it.

The documentation has more on [the google_sign_in module](https://doc.saymyframe.com/modules/google-sign-in).
