import 'package:flutter/widgets.dart';

/// The languages of the app. The app shows its texts in the language that
/// the device prefers among them, and in the first of the list when the
/// device asks for none of them.
const appLocales = <Locale>[{{{locales}}}];

/// The language that the user chose for the app, or `null` while the app
/// follows the languages of the device.
///
/// Set its value to one of [appLocales], or to `null`, to change the
/// language: the root of the app, which reads it through [AppLocaleScope],
/// rebuilds in the new language.
final appLocale = ValueNotifier<Locale?>(null);

/// Gives the root of the app the language that the user chose, and rebuilds
/// the root when the choice changes.
class AppLocaleScope extends InheritedNotifier<ValueNotifier<Locale?>> {
  /// Creates the scope of [notifier] around [child].
  const AppLocaleScope({
    required ValueNotifier<Locale?> super.notifier,
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
