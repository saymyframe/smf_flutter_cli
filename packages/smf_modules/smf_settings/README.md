# smf_settings

The SMF module of the settings screen of the app. It is a feature: a screen with its route, which the module that provides the router renders. It provides the settings screen role of SMF.

It generates `SettingsScreen`, a list at `/settings` with a row for each setting that the modules of the app have. A module with a setting gives the settings screen role the widget of its row, and this module only shows the rows. They come in the order of the role: first the rows of the modules, in the order of the modules, then the rows that the roles of the app add themselves. The last row is About with the name of the app, which opens the about dialog of Flutter, and from there the licenses of the packages of the app. The module adds no package to the app and works with any module that manages state, or with none. In an app whose modules have no settings, the screen has the About row alone.

The title of the screen is a text of the module, in English and in Ukrainian. When a module provides the texts of the app, such as `gen_l10n`, the screen shows the title in the language of the app, or in English if that language is neither of the two. Without such a module the title is in English. The About row is a widget of Flutter, and its words follow the language of the app by themselves.

The main navigation of the app, when there is one, shows the screen as Settings with the settings icon. The label is the title of the screen, so it follows the language of the app as the title does. Without a main navigation, nothing that SMF generates opens the screen. Open it from your own code with `context.nav.settings.settings().push<void>()`, which puts the screen on top of the current one, so its back button leads back. `go()` would replace the stack with the settings screen alone, and nothing would lead back from it.

The screen is not a start screen: the app starts on it only if you name it with `--start /settings`. So an app whose only screen is this one starts on the fallback screen, even with a layout. The fallback screen is outside the main navigation, so nothing opens the settings screen there either. Add a feature with a start screen, such as `home`.

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
