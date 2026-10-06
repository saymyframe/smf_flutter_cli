# smf_material_theme

The SMF module of the Material 3 theme of the app. It provides the theme role of SMF: the app has a light and a dark theme, and shows the one that the user selects.

The module generates `lib/core/theme/app_theme.dart`, the file that you edit to change the look of the app. Its `seedColor` is the colour that both themes derive their colours from, with `ColorScheme.fromSeed`. Its functions `createLightTheme` and `createDarkTheme` return the two themes, and the root of the app calls them each time it builds, so a change of the file shows on a hot reload. The themes are those of the material library of Flutter, so the module adds no package to the app.

The theme role adds the theme mode, whichever module provides the role. The app follows the device until the user selects the light or the dark mode. It shows the selected mode at once and saves it in its preferences, so the next launch starts in it. In an app with a settings screen, the screen has an entry in which the user selects the mode: System, Light or Dark.

Because the mode is saved in the preferences, an app with this module also has a module that provides them, such as `shared_preferences`.

## Use with the SMF CLI

`smf create` asks which module provides the theme of the app, and offers none as well. To choose this one without the question, here with a start screen, a settings screen and tabs at the bottom:

```bash
smf create my_app -m material_theme,home,settings,bottom_tabs
```

The theme requires the preferences, which `smf create` adds when only one module provides them.

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Documentation

- [The material_theme module](https://doc.saymyframe.com/modules/material-theme)
