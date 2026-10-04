import 'package:flutter/material.dart';

/// The theme mode of the fixture, which the fixture puts around the root of
/// the app: the root reads it from its context.
class FixtureThemeMode extends InheritedWidget {
  /// Gives [mode] to the widgets below.
  const FixtureThemeMode({
    required this.mode,
    required super.child,
    super.key,
  });

  /// The theme mode.
  final ThemeMode mode;

  /// The theme mode of the fixture around [context], which rebuilds when
  /// the mode changes.
  static ThemeMode of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FixtureThemeMode>()!.mode;

  @override
  bool updateShouldNotify(FixtureThemeMode oldWidget) =>
      mode != oldWidget.mode;
}
