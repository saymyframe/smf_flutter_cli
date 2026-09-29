# Generate a Flutter app with get_it

`get_it` is the module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) that provides dependency injection with get_it. Choose it with `-m`, here together with `event_bus`, whose service it registers:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m get_it,event_bus --no-input
```

The modules of the app declare their services, and this module registers them in `lib/core/di/dependencies.dart`:

```dart
Future<void> registerDependencies() async {
  final getIt = GetIt.instance;
  getIt.registerLazySingleton<di0.CommunicationService>(
    () => di0.createCommunicationService(),
  );
}
```

`bootstrap()` awaits `registerDependencies()` before the first frame. Only the composition file of a feature takes services, with `resolve<T>()` of the `ServiceLocator` of the dependency injection role, which does not name get_it. The rest of the app gets its services as parameters.

Without `-m`, `smf create` asks which module provides dependency injection. When a module you chose needs it and `get_it` is the only module that provides it, `smf create` adds `get_it` by itself.

The documentation has more on [the get_it module](https://doc.saymyframe.com/modules/get-it) and on [services and state](https://doc.saymyframe.com/guides/services).
