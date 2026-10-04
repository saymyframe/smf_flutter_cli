import 'package:flutter/material.dart';

/// The colour that the themes of the fixture derive their colours from,
/// which differ from those of the themes that Flutter gives an app without
/// a theme: so the colours of a screen tell whether the app shows it in a
/// theme of the fixture.
const _seedColor = Color(0xFF00695C);

/// The light theme of the fixture.
ThemeData createLightTheme() => _themeOf(Brightness.light);

/// The dark theme of the fixture.
ThemeData createDarkTheme() => _themeOf(Brightness.dark);

ThemeData _themeOf(Brightness brightness) => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: brightness,
      ),
    );
