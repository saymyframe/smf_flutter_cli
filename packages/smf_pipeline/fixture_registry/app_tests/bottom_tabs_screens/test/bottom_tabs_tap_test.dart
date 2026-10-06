// A test of what only bottom_tabs does, which continuous integration runs
// in the apps of the fixture modules with bottom_tabs and both fixture
// features: the bar at the bottom shows a tab with the label of each
// destination, in the language that the app is in, and a tap on a tab,
// found by that label, selects the destination, whose branch the router
// shows. The main navigation under any layout is tested in layout_screens,
// which selects a destination through the AppShell of the layout role. It
// uses what the tests of router_screens share, and the labels of the
// destinations in each language of the app that the matrix writes for the
// tests of layout_screens, with what puts the app into a language; every
// app that it applies to has both.
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';
import 'package:{{app_name}}/features/fake_second/fixture_second_screen.dart';

import 'bottom_tabs_bar.dart';
import 'destination_labels.dart';
import 'screens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
      'a tap on a tab, which shows the label of its destination in the '
      'language of the app, selects the destination', (tester) async {
    await startApp(tester);
    expect(find.byType(FixtureHomeScreen), findsOneWidget);
    expect(heard(), [('fake_feature.home', '/fake_feature')]);

    // The destinations of the two fixture features, by their labels in
    // English, which the device of a test is in.
    final fixture = destinationLabels['en']!.indexOf('Fixture');
    final second = destinationLabels['en']!.indexOf('Second');
    expect([fixture, second], everyElement(isNonNegative));

    /// Checks the tabs of the bar of the app in [language], and taps each.
    Future<void> tapTabs(String language) async {
      final labels = destinationLabels[language]!;
      for (final label in labels) {
        expect(
          tab(tester, label),
          findsOneWidget,
          reason: 'In $language, the bar shows a tab with the label of each '
              'destination in that language.',
        );
      }

      await tester.tap(tab(tester, labels[second]));
      await tester.pumpAndSettle();
      expect(find.byType(FixtureSecondScreen), findsOneWidget);
      expect(find.byType(FixtureHomeScreen), findsNothing);
      expect(heard(), [('fake_second.second', '/fake_second')]);

      await tester.tap(tab(tester, labels[fixture]));
      await tester.pumpAndSettle();
      expect(find.byType(FixtureHomeScreen), findsOneWidget);
      expect(find.byType(FixtureSecondScreen), findsNothing);
      expect(heard(), [('fake_feature.home', '/fake_feature')]);
    }

    // In English, which the app follows the device in, and then in each
    // language of the app, the last one first, so that the app comes into
    // it from another one.
    await tapTabs('en');
    for (final language in labelLanguages.reversed) {
      // In real time, as on a device, so that a choice that the app saves
      // does not wait for the fake time of the test.
      await tester.runAsync(() => chooseLanguage(language));
      await tester.pumpAndSettle();
      await tapTabs(language);
    }

    await tester.runAsync(followDevice);
    await tester.pumpAndSettle();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
