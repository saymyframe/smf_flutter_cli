# Generate a Flutter app that reads Firebase Remote Config

`firebase_remote_config` is the module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) with which the app reads values of remote config from Firebase Remote Config. Choose it with `-m`:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m firebase_remote_config --no-input
```

Firebase Remote Config works on the Firebase app, so `smf create` adds the module that sets up Firebase:

```text
Adding firebase_core: a dependency of firebase_remote_config.
Adding flutter_core: the only provider of the app entry role, which every app needs.
```

The module adds firebase_remote_config to the `pubspec.yaml` of the app, and `lib/core/remote_config/firebase_remote_config_service.dart` with the remote config service on `FirebaseRemoteConfig`. The remote config role adds `lib/core/remote_config/app_remote_config.dart` with `appRemoteConfig`, which the rest of the app uses, and `lib/core/remote_config/remote_values.dart` with `RemoteValues`. `bootstrap()` starts remote config before the first frame, once Firebase started, and waits at most a second for the values that the device kept:

```dart
Future<void> bootstrap() async {
  await Firebase.initializeApp(options: firebaseOptionsOfFlavor);
  await initRemoteConfig();
}
```

A parameter has a default in `RemoteValues.defaults` and a getter, which the modules of the app give the role. To add one of your own, such as a text of a banner, put it into `lib/core/remote_config/remote_values.dart`:

```dart
static const Map<String, Object> defaults = {'banner_text': ''};

/// The text of the banner of the home screen; empty for none.
String get bannerText => _values['banner_text']! as String;
```

Then create `banner_text` as a String in Remote Config of the Firebase project of each flavor. A widget follows the value, which changes once you publish a new one:

```dart
ValueListenableBuilder<RemoteValues>(
  valueListenable: appRemoteConfig,
  builder: (context, values, _) => values.bannerText.isEmpty
      ? const SizedBox.shrink()
      : Text(values.bannerText),
);
```

The documentation has more on [the firebase_remote_config module](https://doc.saymyframe.com/modules/firebase-remote-config).
