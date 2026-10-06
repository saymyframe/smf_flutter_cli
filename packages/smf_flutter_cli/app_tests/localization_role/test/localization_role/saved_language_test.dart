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
// only that start can bring the language. Each expectation gives its
// reason.
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
      final locale = appLocales.last;
      String? saved;
      String? afterDevice;
      Locale? beforeStart;
      Locale? restored;
      Locale? afterUnknown;

      await inRealTime(tester, 'choosing a language', () async {
        await appLocale.choose(locale);
        saved = createAppPreferences().getString(savedLanguageKey);
        await appLocale.choose(null);
        afterDevice = createAppPreferences().getString(savedLanguageKey);
        beforeStart = appLocale.value;
      });
      // The screen settles first, so that only the next start can change
      // what the app shows.
      await tester.pumpAndSettle();
      await inRealTime(tester, 'starting again', () async {
        // What an earlier run of the app saved.
        await createAppPreferences().setString(
          savedLanguageKey,
          locale.languageCode,
        );
        await initPreferences();
        restored = appLocale.value;
      });
      await tester.pumpAndSettle();
      final onScreen = languageOnScreen();
      await inRealTime(tester, 'starting with another code saved', () async {
        await createAppPreferences().setString(savedLanguageKey, 'zz');
        await initPreferences();
        afterUnknown = appLocale.value;
        await appLocale.choose(null);
      });

      expect(
        saved,
        locale.languageCode,
        reason: 'A choice is saved under the key of the role, as the code of '
            'its language.',
      );
      expect(
        afterDevice,
        isNull,
        reason: 'Following the device again removes what was saved.',
      );
      expect(
        beforeStart,
        isNull,
        reason: 'No language is chosen before the next start, so only that '
            'start can bring one.',
      );
      expect(
        restored,
        locale,
        reason: 'The next start restores the language that was saved.',
      );
      expect(
        onScreen,
        locale.languageCode,
        reason: 'The app is in the language that the next start restored.',
      );
      expect(
        afterUnknown,
        locale,
        reason: 'A saved code that is no language of the app leaves the '
            'choice as it is.',
      );
    },
    timeout: timeout,
  );
}
