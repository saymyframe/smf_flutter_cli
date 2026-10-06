// A test that continuous integration runs in the apps with the localization
// role, whichever module provides it: a choice of the user is saved in the
// preferences of the app under the key of the role, as the code of its
// language, and removed when the app follows the device again; and the
// next start of the app restores the language that was saved, which the
// app is then in, and leaves the choice as it is when what is saved is no
// language of the app.
//
// It knows only the role, which requires the preferences role. The matrix
// writes the key of the role next to the probe of the role
// (integration_test/localization_role/texts.dart). The next start is
// initPreferences() of the preferences role again, which opens the
// preferences anew and runs the restorer of the language: the test writes
// the key through the preferences first, while no language is chosen, so
// only that start can bring the language. It goes through the first and
// the last language of the app, each on a device that prefers the other
// one, so that the screen shows a language only once the app restored it.
// Each expectation gives its reason.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/l10n/app_locale.dart';
import 'package:{{app_name}}/core/preferences/app_preferences.dart';

import '../../integration_test/localization_role/probe.dart';
import '../../integration_test/localization_role/texts.dart';
import 'app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'a choice of the user is saved under the key of the role, removed when '
    'the app follows the device again, and restored by the next start',
    (tester) async {
      await startApp(tester);
      // The next start puts the app into the language that was saved.
      expectEachLanguageSupported();
      // The first and the last language of the app, which are one in an
      // app in one language.
      final languages = {appLocales.first, appLocales.last};
      final saved = <String, String?>{};
      final afterDevice = <String, String?>{};
      final beforeStart = <String, Locale?>{};
      final restored = <String, Locale?>{};
      final onScreen = <String, String?>{};
      Locale? afterUnknown;

      for (final locale in languages) {
        final code = locale.languageCode;
        // The device prefers the other language, so that only a choice,
        // or a start that restores one, puts the app into this one.
        final other = languages.firstWhere(
          (other) => other != locale,
          orElse: () => locale,
        );
        tester.platformDispatcher.localesTestValue = [other];
        await tester.pumpAndSettle();
        await inRealTime(tester, 'choosing $code', () async {
          await appLocale.choose(locale);
          saved[code] = createAppPreferences().getString(savedLanguageKey);
          await appLocale.choose(null);
          afterDevice[code] =
              createAppPreferences().getString(savedLanguageKey);
          beforeStart[code] = appLocale.value;
        });
        // The screen settles first, so that only the next start can change
        // what the app shows.
        await tester.pumpAndSettle();
        await inRealTime(tester, 'starting again with $code saved', () async {
          // What an earlier run of the app saved.
          await createAppPreferences().setString(savedLanguageKey, code);
          await initPreferences();
          restored[code] = appLocale.value;
        });
        await tester.pumpAndSettle();
        onScreen[code] = languageOnScreen();
      }
      await inRealTime(tester, 'starting with another code saved', () async {
        await createAppPreferences().setString(savedLanguageKey, 'zz');
        await initPreferences();
        afterUnknown = appLocale.value;
        await appLocale.choose(null);
      });

      expect(
        saved,
        {
          for (final locale in languages)
            locale.languageCode: locale.languageCode
        },
        reason: 'A choice is saved under the key of the role, as the code of '
            'its language.',
      );
      expect(
        afterDevice,
        {for (final locale in languages) locale.languageCode: null},
        reason: 'Following the device again removes what was saved.',
      );
      expect(
        beforeStart,
        {for (final locale in languages) locale.languageCode: null},
        reason: 'No language is chosen before the next start, so only that '
            'start can bring one.',
      );
      expect(
        restored,
        {for (final locale in languages) locale.languageCode: locale},
        reason: 'The next start restores the language that was saved.',
      );
      expect(
        onScreen,
        {
          for (final locale in languages)
            locale.languageCode: locale.languageCode
        },
        reason: 'The app is in the language that the next start restored.',
      );
      expect(
        afterUnknown,
        languages.last,
        reason: 'A saved code that is no language of the app leaves the '
            'choice as it is.',
      );
    },
    timeout: timeout,
  );
}
