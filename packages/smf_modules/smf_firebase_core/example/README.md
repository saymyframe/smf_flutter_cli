# Generate a Flutter app with Firebase

`firebase_core` is the module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) that sets up Firebase with firebase_core. Choose it with `-m` in a terminal:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m firebase_core
```

Before it generates anything, `smf create` checks the machine for the Firebase CLI, a Firebase login and the FlutterFire CLI, and offers to set up what is missing. After generation, it offers to run `flutterfire configure` with the ids of the app, and the FlutterFire CLI asks for the Firebase project.

The module adds firebase_core to the `pubspec.yaml` of the app, `lib/firebase_options.dart`, and the start of Firebase in `lib/bootstrap.dart`:

```dart
Future<void> bootstrap() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}
```

Until `flutterfire configure` runs, `lib/firebase_options.dart` is a placeholder: the app compiles but stops at start-up. A run that cannot ask or skips external setup, such as `smf create my_app -m firebase_core --no-input --skip-external-setup` in CI, prints the command to run in the app later instead:

```text
[WARN] Configuring Firebase with flutterfire is not done, because the run skips external setup. Run it in the app: dart pub global run flutterfire_cli:flutterfire configure --platforms=android,ios --overwrite-firebase-options --ios-bundle-id=com.example.my-app --android-package-name=com.example.my_app
```

`firebase_crashlytics` and `firebase_analytics` depend on this module, so it comes with them.

The documentation has more on [the firebase_core module](https://doc.saymyframe.com/modules/firebase-core) and on [Firebase in SMF](https://doc.saymyframe.com/guides/firebase).
