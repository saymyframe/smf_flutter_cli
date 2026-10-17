# Generate a Flutter app that signs in with Apple

`apple_sign_in` is the module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) with which the users of the app sign in with their Apple Account on iOS. Choose it with `-m`, next to a provider of sign-in:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m firebase_auth,apple_sign_in,sign_in,bloc
```

The module adds sign_in_with_apple and crypto to the `pubspec.yaml` of the app, and `lib/core/apple_sign_in/apple_sign_in.dart` with `appleCredential()`, which asks Apple for a credential, and `AppleSignInIcon`, the icon of its button. The auth role lists the way to sign in in `appSignInMethods` of `lib/core/auth/sign_in_methods.dart`:

```dart
const List<SignInMethod> appSignInMethods = [
  SignInMethod(
    label: _appleSignInLabel,
    icon: method0.AppleSignInIcon(),
    platforms: {TargetPlatform.iOS},
    credential: method0.appleCredential,
    issuer: 'https://appleid.apple.com',
    revokesOnDeletion: true,
  ),
];
```

A screen of sign-in shows a button for each way to sign in that `isAvailable` on the platform of the app, here on iOS only. On a tap, its state asks for a credential and gives it to the session of the app:

```dart
final credential = await method.credential();
if (credential == null) return; // The user closed the sheet of Apple.
await appSession.signInWith(credential);
```

An anonymous user who signs in with Apple keeps the id. Deleting an account that signs in with Apple asks Apple again, so that the provider of sign-in can revoke the tokens of Apple.

The module signs the iOS app with the entitlement `com.apple.developer.applesignin` in `ios/Runner/Runner.entitlements`. Signing with it needs a team of the paid Apple Developer Program, and the README of the app tells how to run the app on an iPhone with a free team.

The documentation has more on [the apple_sign_in module](https://doc.saymyframe.com/modules/apple-sign-in).
