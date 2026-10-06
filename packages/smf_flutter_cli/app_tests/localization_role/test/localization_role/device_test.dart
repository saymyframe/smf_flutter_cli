// A test that continuous integration runs in the apps with the localization
// role, whichever module provides it: while the user chose no language,
// the app is in the language that the device prefers among the languages
// of the app, and in the first of them when the device asks for none, and
// each text of the app reads in that language.
//
// It knows only the role, and sets the languages of the device of the
// test. Each expectation gives its reason, which a provider of the role
// with a known bug fails the test with (brokenProviders of the fixture
// registry).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/l10n/app_locale.dart';

import '../../integration_test/localization_role/probe.dart';
import 'app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'while the user chose no language, the app is in the language that the '
    'device prefers among its own, and in its first one when the device '
    'asks for none of them',
    (tester) async {
      // A language that no app is in, which the device prefers to each
      // language of the app.
      const unknown = Locale('zz');
      await startApp(tester, device: const [unknown]);
      expectEachLanguageSupported();
      final shown = <String, String?>{'none of them': languageOnScreen()};
      // The texts in the language that the app follows the device into.
      final texts = problemsOfTexts(appLocales.first.languageCode);

      for (final locale in appLocales.reversed) {
        tester.platformDispatcher.localesTestValue = [
          unknown,
          Locale(locale.languageCode, 'ZZ'),
        ];
        await tester.pumpAndSettle();
        shown[locale.languageCode] = languageOnScreen();
        texts.addAll(problemsOfTexts(locale.languageCode));
      }

      expect(
        shown,
        {
          'none of them': appLocales.first.languageCode,
          for (final locale in appLocales.reversed)
            locale.languageCode: locale.languageCode,
        },
        reason: 'Without a choice of the user, the app follows the languages '
            'of the device.',
      );
      expect(
        texts,
        isEmpty,
        reason: 'While the app follows the device, each text of the app '
            'reads in the language that the app is in.',
      );
    },
    timeout: timeout,
  );
}
