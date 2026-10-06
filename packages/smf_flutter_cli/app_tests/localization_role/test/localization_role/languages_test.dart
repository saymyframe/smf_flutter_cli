// A test that continuous integration runs in the apps with the localization
// role, whichever module provides it: the root of the app supports the
// languages of the app and no other, and has, for each of them, a delegate
// of each kind of localizations that supports it; once the user chose a
// language, the app is in it, and each text of the app reads in it, or in
// English when the text has no translation into it; and once the app
// follows the device again, it is in the language of the device.
//
// It knows only the role. The matrix writes the languages and the texts of
// the app next to the probe of the role
// (integration_test/localization_role/texts.dart), from the data of its
// localization role, and the probe, which the start check runs on a
// device, has the checks of this test. Each expectation gives its reason,
// which a provider of the role with a known bug fails the test with
// (brokenProviders of the fixture registry).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/l10n/app_locale.dart';

import '../../integration_test/localization_role/probe.dart';
import 'app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'once the user chose a language, the app is in it, and each text of the '
    'app reads in it, in each language of the app',
    (tester) async {
      await startApp(tester);

      expect(
        problemsOfSupportedLocales(),
        isEmpty,
        reason: 'The locales that the root supports are the languages of '
            'the app, those that the localization role chose.',
      );
      expectEachLanguageSupported();

      // The language of the device, which the app starts in.
      final device = languageOnScreen()!;

      // Through the languages in both directions, so that the app comes
      // into each from another one, whichever it started in.
      final problems = <String>[];
      for (final locale in [...appLocales.reversed, ...appLocales]) {
        await inRealTime(
          tester,
          'choosing $locale',
          () => appLocale.choose(locale),
        );
        await tester.pumpAndSettle();
        problems.addAll(problemsOfLanguage(locale));
      }

      expect(
        problems,
        isEmpty,
        reason: 'The app and its texts follow the language that the user '
            'chose: a text reads in it, or in English when it has no '
            'translation into it.',
      );

      // The device again, whose language the app started in.
      await inRealTime(
        tester,
        'following the device again',
        () => appLocale.choose(null),
      );
      await tester.pumpAndSettle();
      expect(
        [
          if (languageOnScreen() != device)
            'The app is in ${languageOnScreen()} rather than $device.',
          ...problemsOfTexts(device),
        ],
        isEmpty,
        reason: 'Once the app follows the device again, the app and its '
            'texts are in the language of the device.',
      );
    },
    timeout: timeout,
  );
}
