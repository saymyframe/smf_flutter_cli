# smf_home_flutter

The SMF module of the start screen of the app. It is a feature: a screen with its route, which the module that provides the router renders.

It generates `HomeScreen`, a screen that shows the name of the app in its app bar and nothing else, at `/home`. The app can start on it, and the main navigation of the app, when there is one, shows it as Home with the home icon. That label is a text of the module, in English and in Ukrainian: when a module provides the texts of the app, such as `gen_l10n`, the main navigation shows it in the language of the app. The screen has no state, so the module works with any module that manages state, or with none.

## Use with the SMF CLI

`smf create` asks which features the app has. To choose this one without the question:

```bash
smf create my_app -m home
```

The feature requires a router, which `smf create` adds when only one module provides it.

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Documentation

- [The home module](https://doc.saymyframe.com/modules/home)
- [Navigation](https://doc.saymyframe.com/guides/navigation)
