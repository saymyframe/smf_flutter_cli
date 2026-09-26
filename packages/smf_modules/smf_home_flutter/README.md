# smf_home_flutter

The SMF module of the start screen of the app. It is a feature of the SMF module model: a screen with its route, which the module that provides the router role renders.

It generates `lib/features/home/home_screen.dart` with `HomeScreen`, a screen that shows the name of the app in its app bar and nothing else: a neutral place for the app to start from.

- The route of the screen is `/` of the module, so its full path is `/home`, and the navigation facade offers it as `context.nav.home.home()`.
- The app can start on it. When no other route can, the app opens on `/home`, and `/` redirects there; otherwise `smf create` asks which screen the app starts on, or takes it from `--start`.
- The main navigation of the app, when a module provides it, shows the screen as Home with the home icon.

As a feature, the module requires the router role, whichever module provides it, and `smf create` adds the router itself when only one module provides it. The screen has no state, so the module works with any module that manages state, or with none.

## Use with SMF CLI

`smf create` asks which features the app has. To choose this one without the question, name it with `-m`:

```bash
smf create my_app -m home
```

This package is not intended to be installed directly. Use the SMF CLI to generate a new project and wire modules together.

- SMF Flutter CLI on pub.dev: https://pub.dev/packages/smf_flutter_cli

## 🌐 Links
[Repository](https://github.com/saymyframe/smf_flutter_cli/tree/main/packages/smf_modules/smf_home_flutter) • [Docs](https://doc.saymyframe.com) • [Issues](https://github.com/saymyframe/smf_flutter_cli/issues)

## License
See LICENSE.
