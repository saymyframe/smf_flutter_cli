// A test that continuous integration runs in the apps with the settings
// module: the title of the settings screen is in the language of the app.
// The title is a text of the module, which the screen reads from the texts
// of the app, and it is the header of the screen for a screen reader.
//
// The matrix writes settings_languages.dart next to this file, from the
// localization role of the app: the languages of the app, and how to choose
// one of them as the user does. An app without the role is in English, with
// nothing to choose, and the test checks that language alone. The
// expectation of the title gives its reason, which a provider of the
// localization role with a known bug fails the test with (brokenProviders
// of the fixture registry).
import 'package:flutter_test/flutter_test.dart';

import 'settings_app.dart';
import 'settings_languages.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the title of the settings screen is in the language of the app',
    (tester) async {
      await startApp(tester);
      // Every app is in English, and in any other language only if one of
      // its modules has a text in it.
      final languages = [
        for (final language in appLanguages)
          if (settingsTitles.containsKey(language)) language,
      ];
      expect(languages, contains('en'), reason: 'Every app is in English.');

      for (final language in languages) {
        // In real time: the app saves the choice in its preferences.
        await inRealTime(
          tester,
          'choosing $language',
          () => chooseLanguage(language),
        );
        await tester.pumpAndSettle();
        await goToSettings(tester);

        final title = titleOfSettings(settingsTitles[language]!);
        expect(
          title,
          findsOneWidget,
          reason: 'The title of the screen is in the language of the app, '
              '$language.',
        );
        expect(
          tester.getSemantics(title),
          isSemantics(isHeader: true),
          reason: 'The title is the header of the screen for a screen '
              'reader, in $language.',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
