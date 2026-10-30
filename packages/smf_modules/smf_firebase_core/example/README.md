# Generate a Flutter app with Firebase

`firebase_core` is the module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) that sets up Firebase with firebase_core. Choose it with `-m` in a terminal:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m firebase_core
```

Before it generates anything, `smf create` checks the machine for the Firebase CLI, a Firebase login and the FlutterFire CLI, and offers to set up what is missing. After generation, it offers to configure the flavor `dev` with `tool/configure_firebase.dart`, a script of the app that runs `flutterfire configure` with the ids of the flavor, and the FlutterFire CLI asks for the Firebase project.

The module adds firebase_core to the `pubspec.yaml` of the app, the options of each flavor with `lib/firebase_options_of_flavor.dart`, which picks them by the flavor of the build, that script, and the start of Firebase in `lib/bootstrap.dart`:

```dart
Future<void> bootstrap() async {
  await Firebase.initializeApp(options: firebaseOptionsOfFlavor);
}
```

Until a flavor is configured, its options are a placeholder: the app compiles but a build of that flavor stops at start-up. Each other flavor is one command away:

```bash
dart tool/configure_firebase.dart staging --project=<id>
```

A run that cannot ask or skips external setup, such as `smf create my_app -m firebase_core --no-input --skip-external-setup` in CI, leaves the command for later and prints it once the app is created:

```text
One step is left for later. Run it in the app:
  Configuring Firebase with flutterfire (the run skips external setup):
    dart tool/configure_firebase.dart dev
```

The other Firebase modules depend on this module, so it comes with them.

The documentation has more on [the firebase_core module](https://doc.saymyframe.com/modules/firebase-core) and on [Firebase in SMF](https://doc.saymyframe.com/guides/firebase).
