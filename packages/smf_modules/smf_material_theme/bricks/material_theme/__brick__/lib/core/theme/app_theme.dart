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
