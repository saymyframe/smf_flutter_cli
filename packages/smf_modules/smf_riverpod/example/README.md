# Generate a Flutter app with Riverpod

`riverpod` is the module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) that manages the state of screens with Riverpod 3, without code generation. Choose it with `-m`:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m home,riverpod --no-input
```

The module adds flutter_riverpod to the `pubspec.yaml` of the app, and a `ProviderScope` around the root widget in `lib/main.dart`:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrap();
  runApp(ProviderScope(child: const App()));
}
```

A feature that keeps state brings the providers of its screens in its variant for `riverpod`. The start screen `home` has no state, so this app has no providers yet.

Without `-m`, `smf create` asks which module manages the state of the app, and offers `bloc` and None as well. An app has at most one.

The documentation has more on [the riverpod module](https://doc.saymyframe.com/modules/riverpod) and on [services and state](https://doc.saymyframe.com/guides/services).
