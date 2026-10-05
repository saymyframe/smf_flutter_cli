import 'package:flutter/material.dart';

/// The colour that the themes of the fixture derive their colours from: one
/// of its own at first, so that its themes differ from those that Flutter
/// gives an app without a theme. A test changes it, and the root of the
/// app, which reads it through [FixtureSeedScope], rebuilds in the new
/// colours.
final fixtureSeed = ValueNotifier<Color>(const Color(0xFF00695C));

/// Gives the root of the app the colour of the seed of the fixture, and
/// rebuilds the root when the colour changes. The fixture puts it around
/// the root.
class FixtureSeedScope extends InheritedNotifier<ValueNotifier<Color>> {
  /// Creates the scope of [notifier] around [child].
  const FixtureSeedScope({
    required ValueNotifier<Color> super.notifier,
    required super.child,
    super.key,
  });

  /// The colour of the scope around [context]; the widget of [context]
  /// rebuilds when the colour changes.
  static Color of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<FixtureSeedScope>()!
      .notifier!
      .value;
}

/// The light theme of the fixture, in the colours of the seed around
/// [context], the context of the root of the app.
ThemeData createLightTheme(BuildContext context) =>
    _themeOf(context, Brightness.light);

/// The dark theme of the fixture, in the colours of the seed around
/// [context], the context of the root of the app.
ThemeData createDarkTheme(BuildContext context) =>
    _themeOf(context, Brightness.dark);

ThemeData _themeOf(BuildContext context, Brightness brightness) => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: FixtureSeedScope.of(context),
        brightness: brightness,
      ),
    );
