# smf_bloc

The SMF module that manages the state of screens with [BLoC](https://bloclibrary.dev). It provides the state management role of SMF with [flutter_bloc](https://pub.dev/packages/flutter_bloc) 9.

It adds `flutter_bloc` to the app and nothing else: BLoC needs neither a widget around the app nor start-up code. A module with screens supports BLoC through its variant for `bloc`, which brings the Cubits or Blocs of its screens.

## Use with the SMF CLI

`smf create` asks which module manages the state of the app, and offers none as well. To choose this one without the question:

```bash
smf create my_app -m bloc
```

An app has at most one module that manages its state.

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS and Linux; Windows is not tested yet.

## Documentation

- [The bloc module](https://doc.saymyframe.com/modules/bloc)
- [Services and state](https://doc.saymyframe.com/guides/services)
