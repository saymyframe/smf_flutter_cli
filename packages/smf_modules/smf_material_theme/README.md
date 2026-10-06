# smf_material_theme

The SMF module of the Material 3 theme of the app. It provides the theme role of SMF: the app has a light and a dark theme, and shows the one that the user selects.

The module generates `lib/core/theme/app_theme.dart`, the file that you edit to change the look of the app. One function there builds both themes, so they differ only in their colours. `_schemeOf` has the colours: a deep green and a cream as the primary pair, a green accent, and neutral surfaces with hairlines for borders. `_textThemeOf` has the text styles, and `_themeOf` the look of the components, such as cards and buttons. The functions `createLightTheme` and `createDarkTheme` return the two themes, and the root of the app calls them each time it builds, so a change of the file shows on a hot reload.

The font of the themes is [Geist](https://github.com/vercel/geist-font), which has Latin and Cyrillic letters. Its files are part of the app: they are in `assets/fonts/geist/` in the weights 400, 500 and 600, next to their licence, the SIL Open Font License, and `pubspec.yaml` declares the family. The app loads no font from the network, and the module adds no package to it. For another font, add its files, declare its family in `pubspec.yaml` and name it in `_fontFamily` of the file of the themes.

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
