import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

/// The texts of the app in the language of a context: `context.l10n`.
extension AppTexts on BuildContext {
  /// The texts of the app in the language of this context, which is below
  /// the root of the app.
  ///
  /// gen-l10n of Flutter generates [AppLocalizations] from the ARB files in
  /// `lib/l10n`. `flutter pub get` runs it when one of those files changed,
  /// and `flutter gen-l10n` runs it for a new file too.
  AppLocalizations get l10n => AppLocalizations.of(this);
}
