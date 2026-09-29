# smf_riverpod

The SMF module that manages the state of screens with [Riverpod](https://riverpod.dev) 3, without code generation. It provides the state management role of SMF with [flutter_riverpod](https://pub.dev/packages/flutter_riverpod).

It adds `flutter_riverpod` to the app and wraps the root widget in a `ProviderScope`. A module with screens supports Riverpod through its variant for `riverpod`, which brings the providers of its screens.

## Use with the SMF CLI

`smf create` asks which module manages the state of the app, and offers none as well. To choose this one without the question:

```bash
smf create my_app -m riverpod
```

An app has at most one module that manages its state.

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Documentation

- [The riverpod module](https://doc.saymyframe.com/modules/riverpod)
- [Services and state](https://doc.saymyframe.com/guides/services)
