import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

/// The texts of the app in the language of a context: `context.l10n`.
extension AppTexts on BuildContext {
  /// The texts of the app in the language of this context, which is below
  /// the root of the app.
  ///
  /// gen-l10n of Flutter generates [AppLocalizations] from the ARB files in
  /// `lib/l10n`: run `flutter gen-l10n` after every change of those files.
  AppLocalizations get l10n => AppLocalizations.of(this);
}
