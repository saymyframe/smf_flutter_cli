# smf_settings

The SMF module of the settings screen of the app. It is a feature: a screen with its route, which the module that provides the router renders. It provides the settings screen role of SMF.

It generates `SettingsScreen`, a list at `/settings` with a row for each setting that the modules of the app have. A module with a setting gives the settings screen role the widget of its row, and this module only shows the rows, in the order of the role: those of the modules in the order of the modules, then those that the roles of the app add themselves. The last row is About with the name of the app, which opens the about dialog of Flutter, and from there the licenses of the packages of the app. The module adds no package to the app and works with any module that manages state, or with none. In an app whose modules have no settings, the screen has the About row alone.

The main navigation of the app, when there is one, shows the screen as Settings with the settings icon. Without a main navigation, nothing that SMF generates opens the screen: go there from your own code with `context.nav.settings.settings().go()`. The app does not start on the screen.

## Use with the SMF CLI

`smf create` asks which module provides the settings screen, and offers none as well. To choose this one without the question, here with a start screen and tabs at the bottom:

```bash
smf create my_app -m home,settings,bottom_tabs
```

The feature requires a router, which `smf create` adds when only one module provides it.

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Documentation

- [The settings module](https://doc.saymyframe.com/modules/settings)
- [Navigation](https://doc.saymyframe.com/guides/navigation)
