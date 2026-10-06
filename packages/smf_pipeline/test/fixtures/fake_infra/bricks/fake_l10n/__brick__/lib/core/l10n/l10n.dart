import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app_locale.dart';

/// The texts of the app in the language of a context: `context.l10n`.
extension AppTexts on BuildContext {
  /// The texts of the app in the language of this context, which is below
  /// the root of the app.
  FixtureTexts get l10n => Localizations.of<FixtureTexts>(this, FixtureTexts)!;
}

/// The texts of the app in one language, each written out in this file: no
/// tool generates them.
class FixtureTexts {
  /// Creates the texts in the language of the code [language].
  const FixtureTexts(this.language);

  /// The delegate that loads the texts for the root of the app, in each
  /// language of the app.
  static const LocalizationsDelegate<FixtureTexts> delegate =
      _FixtureTextsDelegate();

  /// The code of the language of the texts, such as `uk`.
  final String language;

{{{getters}}}
}

class _FixtureTextsDelegate extends LocalizationsDelegate<FixtureTexts> {
  const _FixtureTextsDelegate();

  @override
  bool isSupported(Locale locale) => appLocales.any(
        (supported) => supported.languageCode == locale.languageCode,
      );

  @override
  Future<FixtureTexts> load(Locale locale) =>
      SynchronousFuture(FixtureTexts(locale.languageCode));

  @override
  bool shouldReload(_FixtureTextsDelegate old) => false;
}
