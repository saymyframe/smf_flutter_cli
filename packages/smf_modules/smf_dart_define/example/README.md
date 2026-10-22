# Generate a Flutter app that reads the values of .env

`dart_define` is the module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) that gives an app the values of its `.env` file through `--dart-define-from-file`, an option of the `flutter` tool. Choose it with `-m`:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m dart_define --no-input
```

The modules of an app declare the values that a developer fills in, as keys of the env role. The role writes `.env` with one line for each key, such as `SHOP_API_KEY=`, and `.env.example`, which has the same keys and stays in git while `.env` does not. This module adds `lib/core/env/app_env.dart`, with a static getter of `AppEnv` for each key:

```dart
abstract final class AppEnv {
  /// The public API key of the shop.
  static String? get shopApiKey {
    const value = String.fromEnvironment('SHOP_API_KEY');
    return value.isEmpty ? null : value;
  }
}
```

A getter is `null` while its value in `.env` is empty or missing, so the app builds and starts before you fill anything in. Fill in `.env` and run the app with the argument that reads it:

```bash
flutter run --dart-define-from-file=.env
```

`flutter test` and `flutter build` take the same argument. In VS Code, `.vscode/launch.json` passes it to Run and Debug, to the links above `main()` and to the tests. In Android Studio, `.run/main.run.xml` passes it to the run configuration named after the app, but not to tests. The `flutter` tool reads `.env` only when a command starts, so after you edit it, stop `flutter run` and start it again: hot reload and hot restart keep the old values.

Every value ends up in the app, where anyone who has the app can read it. Never put a secret into `.env`.

The documentation has more on [the dart_define module](https://doc.saymyframe.com/modules/dart-define).
