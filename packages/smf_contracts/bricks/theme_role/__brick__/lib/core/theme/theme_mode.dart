import 'package:flutter/material.dart';

import '../preferences/app_preferences.dart';

/// The theme mode that the user selected for the app, which the app
/// remembers between its launches: whether the app is light, dark, or
/// follows the device.
///
/// The root of the app reads it through [AppThemeModeScope], and rebuilds
/// in the new mode when the choice changes.
final appThemeMode = AppThemeModeController._();

/// Keeps the theme mode that the user selected for the app, tells its
/// listeners when the mode changes, and saves each choice in the
/// preferences of the app. The app has one, [appThemeMode].
final class AppThemeModeController extends ChangeNotifier {
  AppThemeModeController._();

  /// The key of the mode in the preferences, which keep it by its name.
  static const _key = {{{mode_key}}};

  /// The preferences that remember the mode, once the app opened them.
  AppPreferences? _preferences;

  ThemeMode _mode = ThemeMode.system;

  /// The mode of the app: [ThemeMode.system], which follows the device,
  /// unless the user selected another.
  ThemeMode get value => _mode;

  /// Chooses [mode] as the mode of the app, at once, and saves the choice:
  /// the future completes once the mode is saved. Until the app opened its
  /// preferences for the first time, it changes only memory; from then on
  /// it saves through the preferences that the app opened last.
  ///
  /// If the preferences fail to save the mode, the future completes with
  /// their error. The app is in [mode] by then and stays in it while it
  /// runs, but its next launch has the mode that was saved before. The
  /// same choice again saves it.
  Future<void> choose(ThemeMode mode) async {
    if (mode != _mode) {
      _mode = mode;
      notifyListeners();
    }
    await _preferences?.setString(_key, mode.name);
  }

  /// Takes the mode that [preferences] have saved, and keeps the current
  /// one when they have none, or one that the app does not know. It keeps
  /// [preferences] for the choices to come.
  void _restore(AppPreferences preferences) {
    _preferences = preferences;
    final saved = ThemeMode.values.asNameMap()[preferences.getString(_key)];
    if (saved == null || saved == _mode) return;
    _mode = saved;
    notifyListeners();
  }
}

/// Restores the theme mode that the user selected from [preferences], which
/// the app opened, and keeps them for the choices to come: a restorer of
/// the preferences, which the app calls before its first frame.
void restoreAppThemeMode(AppPreferences preferences) =>
    appThemeMode._restore(preferences);

/// Gives the root of the app the theme mode that the user selected, and
/// rebuilds the root, and any other widget below that reads the mode, when
/// the choice changes.
class AppThemeModeScope extends InheritedNotifier<AppThemeModeController> {
  /// Creates the scope of [notifier] around [child].
  const AppThemeModeScope({
    required AppThemeModeController super.notifier,
    required super.child,
    super.key,
  });

  /// The theme mode that the user selected; the widget of [context]
  /// rebuilds when the choice changes.
  static ThemeMode of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AppThemeModeScope>()!
      .notifier!
      .value;
}
