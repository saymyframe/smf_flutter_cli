// A test that continuous integration runs in the apps of the fixture
// modules with a router and a layout, whichever modules provide them: the
// label of each destination of the main navigation is in the language that
// the app is in, as the layout role generates it (LayoutRole.destination),
// and the layout shows no label in a language that the app is no longer in
// (LayoutRole.appShell). In an app with the localization role, the label of
// a module that gave that role its text reads in each language of the app,
// or in English where it has no translation, and the label of a module
// that does not list that role is in English in every language. In an app
// without that role, every label is in English.
//
// It knows only the roles. The matrix writes the labels of the app for it,
// in each of its languages, into destination_labels.dart, from the data of
// the layout role and of the localization role, with what puts the app
// into a language. It reads the label of a destination as the layout does,
// with label() of the Destination for a context below the root of the app,
// and looks for the texts of the labels in what the AppShell shows, so it
// depends neither on the router nor on how the layout shows a destination.
// It uses what the tests of router_screens share, which every app that it
// applies to has. Each expectation gives its reason, which a provider of a
// role with a known bug fails the test with (brokenProviders of the fixture
// registry).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/layout/app_shell.dart';

import 'destination_labels.dart';
import 'screens.dart';

/// The main navigation that the user sees.
Finder _shell() => find.byType(AppShell);

/// The labels of the destinations of the main navigation, in their order,
/// as each returns it for the context of the main navigation.
List<String> _labels(WidgetTester tester) {
  final context = tester.element(_shell());
  return [
    for (final destination in tester.widget<AppShell>(_shell()).destinations)
      destination.label(context),
  ];
}

/// The labels that the main navigation shows though the app is in
/// [language]: those of the destinations in another language of the app
/// that are no label in [language], each with the code of its language.
List<String> _labelsOfAnotherLanguage(WidgetTester tester, String language) {
  final current = destinationLabels[language]!;
  return [
    for (final other in labelLanguages)
      if (other != language)
        for (final label in destinationLabels[other]!)
          if (!current.contains(label) &&
              find
                  .descendant(of: _shell(), matching: find.text(label))
                  .evaluate()
                  .isNotEmpty)
            '$label ($other)',
  ];
}

/// Puts the app into what [choose] chooses, in real time, as on a device,
/// so that a choice that the app saves does not wait for the fake time of
/// the test, and waits for the app to build in it. An error of [choose]
/// fails the test, which tester.runAsync would only report to the handler
/// of the errors of Flutter.
Future<void> _choose(
  WidgetTester tester,
  Future<void> Function() choose,
) async {
  Object? error;
  await tester.runAsync(() async {
    try {
      await choose();
    } on Object catch (thrown) {
      error = thrown;
    }
  });
  if (error != null) fail('The choice of the language threw $error');
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets('the labels of the destinations follow the language of the app',
      (tester) async {
    // The device of a test is in English, a language of every app.
    await startApp(tester);
    expect(
      {'device': _labels(tester)},
      {'device': destinationLabels['en']},
      reason: 'While the app follows a device in English, each destination '
          'gives its label in English.',
    );

    // Through the languages in both directions, so that the app comes into
    // each from another one.
    for (final language in [...labelLanguages.reversed, ...labelLanguages]) {
      await _choose(tester, () => chooseLanguage(language));
      expect(
        {language: _labels(tester)},
        {language: destinationLabels[language]},
        reason: 'Each destination gives its label in the language of the app.',
      );
      expect(
        {language: _labelsOfAnotherLanguage(tester, language)},
        {language: isEmpty},
        reason: 'The layout shows no label of a destination in a language '
            'that the app is not in.',
      );
    }

    await _choose(tester, followDevice);
    expect(
      {'device': _labels(tester)},
      {'device': destinationLabels['en']},
      reason: 'Once the app follows the device again, each destination gives '
          'its label in the language of the device.',
    );
    expect(
      {'device': _labelsOfAnotherLanguage(tester, 'en')},
      {'device': isEmpty},
      reason: 'Once the app follows the device again, the layout shows no '
          'label of a destination in a language that the app is not in.',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
