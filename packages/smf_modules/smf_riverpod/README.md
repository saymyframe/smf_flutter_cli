# smf_riverpod

The SMF module that manages the state of screens with [Riverpod](https://riverpod.dev) 3, without code generation. It provides the state management role of the SMF module model with [flutter_riverpod](https://pub.dev/packages/flutter_riverpod).

It adds `flutter_riverpod` to the dependencies of the app and wraps the root widget in a `ProviderScope`, in `lib/main.dart`:

```dart
runApp(
  ProviderScope(child: const App()),
);
```

Modules with screens support Riverpod through a variant keyed by the id of this module, `riverpod`. The variant brings the providers of their screens. It depends on `flutter_riverpod` with the constraint `any`, so the version is the one of this module.

The `ProviderScope` has to be above every widget that reads a provider. A module with such variants requires the state management role, and SMF orders the contributions of a module after those of the providers of the roles it requires, and after those of the modules it depends on. So when a module that can use Riverpod wraps the root widget too, its wrapper goes inside the `ProviderScope`.

## Use with SMF CLI

`smf create` asks which module manages the state of the app, and offers none as well. To choose this one without the question, name it with `-m`:

```bash
smf create my_app -m riverpod
```

An app has at most one module that manages its state.

This package is not intended to be installed directly. Use the SMF CLI to generate a new project and wire modules together.

- SMF Flutter CLI on pub.dev: https://pub.dev/packages/smf_flutter_cli

## 🌐 Links
[Repository](https://github.com/saymyframe/smf_flutter_cli/tree/main/packages/smf_modules/smf_riverpod) • [Docs](https://doc.saymyframe.com) • [Issues](https://github.com/saymyframe/smf_flutter_cli/issues)

## License
See LICENSE.
