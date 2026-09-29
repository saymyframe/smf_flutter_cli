# Generate a Flutter app with BLoC

`bloc` is the module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) that manages the state of screens with BLoC. Choose it with `-m`:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m home,bloc --no-input
```

The module adds flutter_bloc to the `pubspec.yaml` of the app:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_bloc: "^9.1.1"
  go_router: "^17.5.0"
```

`go_router` is there for the start screen. BLoC needs no widget around the app and no start-up code, so `flutter_bloc` is all the module adds. A feature that keeps state brings the Cubits or Blocs of its screens in its variant for `bloc`. The start screen `home` has no state, which is why this app gets only the package.

Without `-m`, `smf create` asks which module manages the state of the app, and offers `riverpod` and None as well. An app has at most one.

The documentation has more on [the bloc module](https://doc.saymyframe.com/modules/bloc) and on [services and state](https://doc.saymyframe.com/guides/services).
