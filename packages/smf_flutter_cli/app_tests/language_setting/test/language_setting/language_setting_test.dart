// A test that continuous integration runs in the apps with the localization
// role and the settings screen role, whichever modules provide them: the
// setting of the language, the entry that the template of the localization
// role gives the settings screen. On the screen it shows its title and the
// choice of the user, the languages of the device while the user chose
// none. A tap opens a dialog with an option for the languages of the device
// and one for each language of the app, by its name in that language, or
// its code, with the chosen one selected and checked. A tap on an option
// closes the dialog: the app and the texts of the setting are in the
// language of the option, which is saved under the key of the role, and
// the option of the device removes what was saved.
//
// It knows only the two roles, and starts the app once, since the start-up
// of an app may not run twice. The matrix writes setting.dart next to it,
// from the entries of the settings screen role and the languages of the
// localization role of the app: the type of the widget of the entry, the
// key of the role, the label of each language and the texts of the setting
// in each of them. It opens the settings screen as the tests of the
// settings screen role do, which every app with that role has too. Each
// expectation gives its reason, which a provider of the localization role
// with a known bug fails the test with (brokenProviders of the fixture
// registry).
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
    'the setting of the language shows the choice of the user, and its '
    'dialog chooses a language of the app or the languages of the device',
    (tester) async {
      await openSettings(tester);

      final setting = find.byType(languageSetting);
      final dialog = find.byType(Dialog);
      Finder inSetting(String text) =>
          find.descendant(of: setting, matching: find.text(text));
      Finder option(String label) =>
          find.descendant(of: dialog, matching: find.text(label));
      // The language that the app is in where the setting is.
      String language() =>
          Localizations.localeOf(tester.element(setting)).languageCode;
      // Whether the check of the dialog is on the row of the option.
      bool checked(String label) {
        final check = find.descendant(
          of: dialog,
          matching: find.byIcon(Icons.check),
        );
        if (check.evaluate().length != 1) return false;
        final row = tester.getRect(option(label));
        final center = tester.getCenter(check).dy;
        return row.top <= center && center <= row.bottom;
      }

      expect(
        setting,
        findsOneWidget,
        reason: 'The settings screen shows the setting of the language once.',
      );
      expect(
        appLocale.value,
        isNull,
        reason: 'An app that starts with nothing saved has no language '
            'chosen.',
      );
      final device = language();
      expect(
        inSetting(settingTitles[device]!),
        findsOneWidget,
        reason: 'The setting shows its title in the language of the app.',
      );
      expect(
        inSetting(deviceOptions[device]!),
        findsOneWidget,
        reason: 'While the user chose no language, the setting shows the '
            'option of the languages of the device.',
      );

      await tester.tap(setting);
      await tester.pumpAndSettle();
      expect(
        dialog,
        findsOneWidget,
        reason: 'A tap on the setting opens its dialog.',
      );
      expect(
        option(deviceOptions[device]!),
        findsOneWidget,
        reason: 'The dialog has the option of the languages of the device.',
      );
      for (final locale in appLocales) {
        expect(
          option(languageLabels[locale.languageCode]!),
          findsOneWidget,
          reason: 'The dialog has an option for each language of the app, '
              'by its name in that language, or its code.',
        );
      }
      expect(
        tester.getSemantics(option(deviceOptions[device]!)),
        isSemantics(isSelected: true),
        reason: 'While the user chose no language, the option of the '
            'languages of the device is the selected one.',
      );
      expect(
        checked(deviceOptions[device]!),
        isTrue,
        reason: 'The dialog has one check, on the selected option.',
      );

      // The last language of the app, as the user chooses it.
      final chosen = appLocales.last;
      final code = chosen.languageCode;
      await tester.tap(option(languageLabels[code]!));
      await tester.pumpAndSettle();
      expect(
        dialog,
        findsNothing,
        reason: 'A tap on an option closes the dialog.',
      );
      expect(
        appLocale.value,
        chosen,
        reason: 'A tap on the option of a language chooses the language.',
      );
      expect(
        language(),
        code,
        reason: 'The app is in the language that the user chose in the '
            'setting.',
      );
      expect(
        createAppPreferences().getString(savedLanguageKey),
        code,
        reason: 'A choice of the setting is saved under the key of the role, '
            'as the code of its language.',
      );
      expect(
        inSetting(languageLabels[code]!),
        findsOneWidget,
        reason: 'The setting shows the language that the user chose, by its '
            'name in that language, or its code.',
      );
      expect(
        inSetting(settingTitles[code]!),
        findsOneWidget,
        reason: 'The setting shows its texts in the language that the user '
            'chose.',
      );

      await tester.tap(setting);
      await tester.pumpAndSettle();
      expect(
        option(deviceOptions[code]!),
        findsOneWidget,
        reason: 'The dialog shows its texts in the language that the user '
            'chose.',
      );
      expect(
        tester.getSemantics(option(languageLabels[code]!)),
        isSemantics(isSelected: true),
        reason: 'The option of the language that the user chose is the '
            'selected one.',
      );
      expect(
        tester.getSemantics(option(deviceOptions[code]!)),
        isSemantics(isSelected: false),
        reason: 'Only the option of the choice of the user is selected.',
      );
      expect(
        checked(languageLabels[code]!),
        isTrue,
        reason: 'The dialog has one check, on the selected option.',
      );

      // The languages of the device again.
      await tester.tap(option(deviceOptions[code]!));
      await tester.pumpAndSettle();
      expect(
        dialog,
        findsNothing,
        reason: 'A tap on the option of the device closes the dialog.',
      );
      expect(
        appLocale.value,
        isNull,
        reason: 'The option of the languages of the device lets the app '
            'follow the device again.',
      );
      expect(
        createAppPreferences().getString(savedLanguageKey),
        isNull,
        reason: 'Following the device again removes what was saved.',
      );
      expect(
        language(),
        device,
        reason: 'The app is in the language of the device again.',
      );
      expect(
        inSetting(deviceOptions[device]!),
        findsOneWidget,
        reason: 'The setting shows the option of the languages of the '
            'device again.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
