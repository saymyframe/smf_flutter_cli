# smf_home_flutter

The SMF module of the start screen of the app. It is a feature: a screen with its route, which the module that provides the router renders.

It generates `HomeScreen` at `/home`, a welcome to the developer of the app. The screen greets by the time of the day and names the app, next to the mark of Say My Frame. A card in the colours of Say My Frame shows the app as a cell of the periodic table, with a symbol and a number that the module makes from the name of the app. Below the card are three next steps, each with the path or the address that it is about, which a tap copies. The parts of the screen come in one after another, once, and at once on a device that asks for less motion. You replace the content of the screen with the first screen of your app.

The app can start on the screen, and the main navigation of the app, when there is one, shows it as Home with the home icon. The texts of the screen and that label are texts of the module, in English and in Ukrainian: when a module provides the texts of the app, such as `gen_l10n`, the app shows them in its language.

The module adds no package to the app. The screen takes the styles of its texts from the theme of the app, whichever module provides it, and shows a path in the monospaced font of the device. The mark is an image that the module writes into `lib/features/home/assets/` and declares in `pubspec.yaml`. What moves on the screen is the state of the screen itself, so the module works with any module that manages state, or with none.

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
