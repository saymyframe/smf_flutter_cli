# The Flutter app that every SMF app starts from

`flutter_core` is part of every app that the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) generates, so you never choose it. Without `-m`, an app has this module alone:

```bash
dart pub global activate smf_flutter_cli
smf create my_app --no-input
```

`smf create` adds it by itself and says why:

```text
Adding flutter_core: the only provider of the app entry role, which every app needs.
```

The module writes the Android and iOS projects that `flutter create` writes, `pubspec.yaml`, `analysis_options.yaml`, the README of the app and this code:

```text
lib/app.dart
lib/bootstrap.dart
lib/core/app/fallback_start_screen.dart
lib/main.dart
test/core/app/fallback_start_screen_test.dart
```

`main()` runs `bootstrap()` before the first frame. Other modules put their start-up code into `bootstrap()`, such as the start of Firebase, and their wrappers around the root widget, such as the `ProviderScope` of Riverpod:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrap();
  runApp(const App());
}
```

The documentation has more on [the flutter_core module](https://doc.saymyframe.com/modules/flutter-core) and on [the files of a generated app](https://doc.saymyframe.com/getting-started/generated-app).
