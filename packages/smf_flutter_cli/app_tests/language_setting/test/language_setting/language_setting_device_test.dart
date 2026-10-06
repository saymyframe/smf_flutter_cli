// A test that continuous integration runs in the apps with the localization
// role and the settings screen role, whichever modules provide them: the
// setting of the language on a device that prefers the last language of
// the app, while language_setting_test.dart runs on the English device of
// the tests. While the user chose no language, the app and the texts of the
// setting are in the language of the device. A choice of that same
// language, which code makes, leaves the app in the language it is in, and
// the setting names it. The next start of the app restores the language
// that was saved, which the app and the setting then show. The dialog has
// an option for the languages of the device, one for each language of the
// app, and no other.
//
// It knows only the two roles, and starts the app once, since the start-up
// of an app may not run twice: so it is a file of its own. The matrix
// writes setting.dart next to it (see language_setting_test.dart). The next
// start is initPreferences() of the preferences role again, which opens the
// preferences anew and runs the restorer of the language: the test writes
// the key through the preferences first, while no language is chosen, so
// only that start can bring the language. Each expectation gives its
// reason, which a provider of the localization role with a known bug fails
// the test with (brokenProviders of the fixture registry).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/l10n/app_locale.dart';
import 'package:{{app_name}}/core/preferences/app_preferences.dart';

import '../settings_screen_role/open_settings.dart';
import 'setting.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'on a device in the last language of the app, the setting of the '
    'language follows the device, names a choice that code makes, shows the '
    'language that the next start restores, and has no option but those of '
    'the app and of the device',
    (tester) async {
      final ofDevice = appLocales.last;
      final code = ofDevice.languageCode;
      tester.platformDispatcher.localesTestValue = [ofDevice];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await openSettings(tester);

      final setting = find.byType(languageSetting);
      final dialog = find.byType(Dialog);
      Finder inSetting(String text) =>
          find.descendant(of: setting, matching: find.text(text));
      // The language that the app is in where the setting is.
      String language() =>
          Localizations.localeOf(tester.element(setting)).languageCode;

      expect(
        appLocale.value,
        isNull,
        reason: 'An app that starts with nothing saved has no language '
            'chosen.',
      );
      expect(
        language(),
        code,
        reason: 'While the user chose no language, the app is in the '
            'language of the device.',
      );
      expect(
        inSetting(settingTitles[code]!),
        findsOneWidget,
        reason: 'While the app follows the device, the setting shows its '
            'texts in the language of the device.',
      );
      expect(
        inSetting(deviceOptions[code]!),
        findsOneWidget,
        reason: 'While the app follows the device, the setting shows the '
            'option of the languages of the device, in the language of the '
            'device.',
      );

      // The language of the device, as code chooses it, in real time, so
      // that the write of the preferences does not wait for the fake time
      // of the test.
      await tester.runAsync(() => appLocale.choose(ofDevice));
      await tester.pumpAndSettle();
      expect(
        language(),
        code,
        reason: 'A choice of the language of the device leaves the app in '
            'that language.',
      );
      expect(
        inSetting(languageLabels[code]!),
        findsOneWidget,
        reason: 'The setting shows a choice that leaves the app in the '
            'language it is in.',
      );

      // The next start, with the first language of the app saved by an
      // earlier run.
      await tester.runAsync(() => appLocale.choose(null));
      await tester.pumpAndSettle();
      expect(
        appLocale.value,
        isNull,
        reason: 'No language is chosen before the next start, so only that '
            'start can bring one.',
      );
      final saved = appLocales.first;
      await tester.runAsync(() async {
        await createAppPreferences().setString(
          savedLanguageKey,
          saved.languageCode,
        );
        await initPreferences();
      });
      await tester.pumpAndSettle();
      expect(
        appLocale.value,
        saved,
        reason: 'The next start restores the language that was saved.',
      );
      expect(
        language(),
        saved.languageCode,
        reason: 'The app is in the language that the next start restored.',
      );
      expect(
        inSetting(languageLabels[saved.languageCode]!),
        findsOneWidget,
        reason: 'The setting shows the language that the next start '
            'restored.',
      );

      await tester.tap(setting);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: dialog, matching: find.byType(ListTile)),
        findsNWidgets(appLocales.length + 1),
        reason: 'The dialog has the option of the languages of the device, '
            'one for each language of the app, and no other.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
