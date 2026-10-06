import 'package:flutter/widgets.dart';

import '../preferences/app_preferences.dart';

/// The languages of the app. The app shows its texts in the language that
/// the device prefers among them, and in the first of the list when the
/// device asks for none of them.
///
/// A language has one locale here. The app tells its languages apart by
/// their codes alone, so of two locales of one language, such as
/// `Locale('pt', 'BR')` and `Locale('pt', 'PT')`, `appLocale.choose()`
/// takes the first, whichever of them it is given.
const appLocales = <Locale>[{{{locales}}}];

/// The key of the preferences of the app under which the app saves the
/// language that the user chose, as the code of the language, such as `uk`.
/// Nothing is saved under it while the app follows the languages of the
/// device.
const _key = {{{locale_key}}};

/// The language that the user chose for the app, which the app remembers
/// between its launches.
///
/// The root of the app reads it through [AppLocaleScope], and rebuilds in
/// the new language when the choice changes.
final appLocale = AppLocaleController._();

/// Keeps the language that the user chose for the app, and saves each
/// choice in the preferences of the app.
final class AppLocaleController extends ChangeNotifier {
  AppLocaleController._();

  Locale? _locale;

  /// The preferences of the app, once it opened them.
  AppPreferences? _preferences;

  /// The language that the user chose, one of [appLocales], or `null` while
  /// the app follows the languages of the device.
  Locale? get value => _locale;

  /// Chooses the language of [locale] as the language of the app, or with
  /// `null` lets the app follow the languages of the device again.
  ///
  /// The choice is the one of [appLocales] with the language of [locale],
  /// so `Locale('uk', 'UA')` chooses `Locale('uk')`. A locale of a language
  /// that the app is not in is refused: the future completes with an
  /// [ArgumentError], and nothing changes.
  ///
  /// The language of the app changes at once, and the choice is then saved
  /// in the preferences once the app opened them: before that, it changes
  /// only memory. When saving fails, the future completes with the error of
  /// the preferences. The app stays in the new language while it runs, and
  /// its next launch starts with what was saved before; choosing the
  /// language again saves it again.
  Future<void> choose(Locale? locale) async {
    final chosen = locale == null ? null : _ofApp(locale.languageCode);
    if (locale != null && chosen == null) {
      throw ArgumentError.value(
        '$locale',
        'locale',
        'The app is not in the language of this locale',
      );
    }
    _set(chosen);
    final preferences = _preferences;
    if (preferences == null) return;
    if (chosen == null) {
      await preferences.remove(_key);
    } else {
      await preferences.setString(_key, chosen.languageCode);
    }
  }

  void _set(Locale? locale) {
    if (locale == _locale) return;
    _locale = locale;
    notifyListeners();
  }
}

/// The one of [appLocales] with the language of the code [code], or `null`.
Locale? _ofApp(String? code) {
  for (final locale in appLocales) {
    if (locale.languageCode == code) return locale;
  }
  return null;
}

/// Restores the language that the user chose from [preferences], which the
/// app opened, and keeps them for the choices to come: a restorer of the
/// preferences, which the app calls before its first frame.
///
/// When nothing is saved, or what is saved is not the code of one of
/// [appLocales], the choice stays as it is.
void restoreAppLocale(AppPreferences preferences) {
  appLocale._preferences = preferences;
  final saved = _ofApp(preferences.getString(_key));
  if (saved != null) appLocale._set(saved);
}

/// Gives the root of the app the language that the user chose, and rebuilds
/// the root when the choice changes.
class AppLocaleScope extends InheritedNotifier<AppLocaleController> {
  /// Creates the scope of [notifier] around [child].
  const AppLocaleScope({
    required AppLocaleController super.notifier,
    required super.child,
    super.key,
  });

  /// The language that the user chose, or `null` to follow the device; the
  /// widget of [context] rebuilds when the choice changes.
  static Locale? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AppLocaleScope>()!
      .notifier!
      .value;
}
