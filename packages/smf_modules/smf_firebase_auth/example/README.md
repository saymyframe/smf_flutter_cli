# Generate a Flutter app that signs in with Firebase Authentication

`firebase_auth` is the module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) with which the users of the app sign in through Firebase Authentication. Choose it with `-m` in a terminal:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m firebase_auth
```

It depends on `firebase_core`, which sets up Firebase, so `smf create` adds that module too:

```text
Adding firebase_core: a dependency of firebase_auth.
Adding flutter_core: the only provider of the app entry role, which every app needs.
```

The module adds firebase_auth to the `pubspec.yaml` of the app, and `lib/core/auth/firebase_auth_service.dart` with the sign-in service on `FirebaseAuth.instance`. The auth role adds `lib/core/auth/app_session.dart` with `appSession`, which the rest of the app uses. `bootstrap()` starts Firebase and then the session, so the app knows who is signed in before its first frame:

```dart
Future<void> bootstrap() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initAuth();
}
```

The code of the app signs in, up and out through `appSession`, and shows a text of its own for the reason of a failure:

```dart
import 'core/auth/app_session.dart';

Future<String?> signIn(String email, String password) async {
  try {
    await appSession.signIn(email: email, password: password);
    return null;
  } on AuthFailure catch (failure) {
    return switch (failure.reason) {
      AuthFailureReason.invalidCredentials => 'Wrong email or password.',
      AuthFailureReason.network => 'No connection. Try again.',
      _ => 'Sign-in is unavailable.',
    };
  }
}
```

`appSession.value` is a `SignedOutSession`, an `AnonymousSession` or an `AccountSession`, and a widget follows it with a `ValueListenableBuilder`.

`smf create` asks who may use the app without an account, or takes the answer from `--auth-mode`: `required`, the default, `guest` or `anonymous`. In the mode `anonymous`, the app signs in an anonymous user when it starts, and signing up gives that user the account.

The ways to sign in are enabled in the Firebase project: Email/Password, and Anonymous for the mode `anonymous`. The README of the app tells where. Until they are enabled, a call fails with the reason `notConfigured`, and its `developerHint` has the link to the project.

The documentation has more on [the firebase_auth module](https://doc.saymyframe.com/modules/firebase-auth) and on [Firebase](https://doc.saymyframe.com/guides/firebase).
