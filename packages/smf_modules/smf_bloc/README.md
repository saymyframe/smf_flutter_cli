# smf_bloc

The SMF module that manages the state of screens with [BLoC](https://bloclibrary.dev). It provides the state management role of the SMF module model with [flutter_bloc](https://pub.dev/packages/flutter_bloc) 9.

It adds `flutter_bloc` to the dependencies of the app, and nothing else: BLoC needs neither a widget around the app nor start-up code.

Modules with screens support BLoC through a variant keyed by the id of this module, `bloc`. The variant brings the Cubits or Blocs of their screens and provides them where the screens need them. It depends on `flutter_bloc` with the constraint `any`, so the version is the one of this module.

## Use with SMF CLI

`smf create` asks which module manages the state of the app, and offers none as well. To choose this one without the question, name it with `-m`:

```bash
smf create my_app -m bloc
```

An app has at most one module that manages its state.

This package is not intended to be installed directly. Use the SMF CLI to generate a new project and wire modules together.

- SMF Flutter CLI on pub.dev: https://pub.dev/packages/smf_flutter_cli

## 🌐 Links
[Repository](https://github.com/saymyframe/smf_flutter_cli/tree/main/packages/smf_modules/smf_bloc) • [Docs](https://doc.saymyframe.com) • [Issues](https://github.com/saymyframe/smf_flutter_cli/issues)

## License
See LICENSE.
