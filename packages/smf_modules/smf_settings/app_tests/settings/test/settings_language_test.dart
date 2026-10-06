// A test that continuous integration runs in the apps with the settings
// module: the title of the settings screen and its last row, which tells
// what the app is, are in the language of the app. The title is a text of
// the module, which the screen reads from the texts of the app. The row is
// a widget of Flutter, whose words follow the language of the app by
// themselves.
//
// The matrix writes settings_languages.dart next to this file, from the
// localization role of the app: the languages of the app, and how to choose
// one of them as the user does. An app without the role is in English, with
// nothing to choose, and the test checks that language alone.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/features/settings/settings_screen.dart';

import 'settings_app.dart';
import 'settings_languages.dart';

/// The title of the screen in each language that the module has it in.
const _titles = {'en': 'Settings', 'uk': 'Налаштування'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the title of the settings screen and its last row are in the language '
    'of the app',
    (tester) async {
      await startApp(tester);
      // Every app is in English, and in any other language only if one of
      // its modules has a text in it.
      final languages = [
        for (final language in appLanguages)
          if (_titles.containsKey(language)) language,
      ];
      expect(languages, contains('en'), reason: 'Every app is in English.');
      final english =
          const DefaultMaterialLocalizations().aboutListTileTitle(appName);

      for (final language in languages) {
        // In real time: the app saves the choice in its preferences.
        await inRealTime(
          tester,
          'choosing $language',
          () => chooseLanguage(language),
        );
        await tester.pumpAndSettle();
        await goToSettings(tester);

        expect(
          find.descendant(
            of: find.descendant(
              of: find.byType(SettingsScreen),
              matching: find.byType(AppBar),
            ),
            matching: find.text(_titles[language]!),
          ),
          findsOneWidget,
          reason: 'The title of the screen is in the language of the app, '
              '$language.',
        );

        final about = await showAboutRow(tester);
        final label = MaterialLocalizations.of(
          tester.element(about),
        ).aboutListTileTitle(appName);
        expect(
          find.descendant(of: about, matching: find.text(label)),
          findsOneWidget,
          reason: 'The row tells what the app is in the words of Flutter '
              'for the language of the app, $language.',
        );
        expect(
          label == english,
          language == 'en',
          reason: 'The words of Flutter for the row are the English ones in '
              'English only: the language is $language.',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
