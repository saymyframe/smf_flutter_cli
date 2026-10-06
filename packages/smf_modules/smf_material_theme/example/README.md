# Generate a Flutter app with a light and a dark theme

`material_theme` is the module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) that gives the app a light and a dark Material 3 theme. Choose it with `-m`, here with the start screen `home`, the settings screen `settings` and the tabs of `bottom_tabs`:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m material_theme,home,settings,bottom_tabs --no-input
```

The app remembers the theme mode in its preferences, and its screens need a router, so `smf create` adds the modules that provide them:

```text
Adding flutter_core: the only provider of the app entry role, which every app needs.
Adding shared_preferences: the only provider of the preferences role, which material_theme requires.
Adding go_router: the only provider of the router role, which home requires.
```

The module writes `lib/core/theme/app_theme.dart`:

```dart
import 'package:flutter/material.dart';

/// The colour that the light and the dark theme of the app derive their
/// colours from. Change it to give the app another look.
const Color seedColor = Colors.deepPurple;

/// The light theme of the app.
///
/// The root of the app calls it each time it builds, so a change of this
/// file shows on a hot reload. [context] is the context of the root, above
/// its `MaterialApp`: it has neither the theme nor the localizations of the
/// app.
ThemeData createLightTheme(BuildContext context) => _themeOf(Brightness.light);

/// The dark theme of the app; see [createLightTheme].
ThemeData createDarkTheme(BuildContext context) => _themeOf(Brightness.dark);

/// The Material 3 theme of [brightness] in the colours of [seedColor]. What
/// both themes of the app share goes here, such as the shape of its
/// buttons.
ThemeData _themeOf(Brightness brightness) => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  ),
);
```

Change `seedColor` to give the app other colours, and `_themeOf` to change what both themes share. The root `MaterialApp` of the app takes its `theme` and its `darkTheme` from the two functions.

The app follows the device until the user selects a mode. The second tab of this app is Settings, and its entry Theme offers System, Light and Dark. The app shows the selected mode at once and starts in it the next time. Code of the app selects a mode with `appThemeMode.choose(ThemeMode.dark)`, and a widget reads the mode with `AppThemeModeScope.of(context)`. Both are in `lib/core/theme/theme_mode.dart`, which the theme role adds.

The documentation has more on [the material_theme module](https://doc.saymyframe.com/modules/material-theme).
