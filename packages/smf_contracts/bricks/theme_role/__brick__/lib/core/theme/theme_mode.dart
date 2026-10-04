import 'package:flutter/material.dart';

import '../preferences/app_preferences.dart';

/// The theme mode of the app: whether it is light, dark, or follows the
/// device, as the user selected. The root of the app reads it through
/// [ThemeModeScope], and the preferences of the app remember it.
final themeModeController = ThemeModeController._();

/// Keeps the theme mode that the user selected for the app, tells its
/// listeners when the mode changes, and saves it in the preferences of the
/// app. The app has one, [themeModeController].
final class ThemeModeController extends ChangeNotifier {
  ThemeModeController._();

  /// The key of the mode in the preferences, which keep it by its name.
  static const _key = {{{mode_key}}};

  /// The preferences that remember the mode, once the app opened them.
  AppPreferences? _preferences;

  ThemeMode _mode = ThemeMode.system;

  /// The mode of the app: [ThemeMode.system], which follows the device,
  /// unless the user selected another.
  ThemeMode get mode => _mode;

  /// Makes [mode] the mode of the app at once, and saves it: the future
  /// completes once the mode is saved. Before the app opened its
  /// preferences, it changes only memory.
  ///
  /// If the preferences fail to save the mode, the future completes with
  /// their error. The app is in [mode] by then and stays in it while it
  /// runs, but its next launch has the mode that was saved before. The
  /// same choice again saves it.
  Future<void> select(ThemeMode mode) async {
    if (mode != _mode) {
      _mode = mode;
      notifyListeners();
    }
    await _preferences?.setString(_key, mode.name);
  }

  /// Takes the mode that [preferences] have saved, and keeps the current
  /// one when they have none, or one that the app does not know. It keeps
  /// [preferences] for the writes of the mode.
  void _restore(AppPreferences preferences) {
    _preferences = preferences;
    final saved = ThemeMode.values.asNameMap()[preferences.getString(_key)];
    if (saved == null || saved == _mode) return;
    _mode = saved;
    notifyListeners();
  }
}

/// Restores the theme mode of the app from [preferences]: the preferences
/// call it once they are open, before the first frame.
void restoreThemeMode(AppPreferences preferences) =>
    themeModeController._restore(preferences);

/// Gives the widgets below it the [ThemeModeController] of the app, and
/// rebuilds those that read it when the mode changes. It is around the
/// root of the app, which takes its theme mode from it.
class ThemeModeScope extends InheritedNotifier<ThemeModeController> {
  /// Creates the scope of [notifier] around [child].
  const ThemeModeScope({
    required ThemeModeController super.notifier,
    required super.child,
    super.key,
  });

  /// The controller of the theme mode of the app; the widget of [context]
  /// rebuilds when the mode changes.
  static ThemeModeController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeModeScope>()!.notifier!;
}
