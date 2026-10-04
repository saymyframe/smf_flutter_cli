// A test that continuous integration runs in the apps with the settings
// screen role, whichever module provides it: the settings screen shows
// every entry that the modules of the app, and the templates of roles,
// give the role (SettingsScreenRole.entriesIn), each once, one below the
// other in the order of the role, on a Material, in a list that scrolls,
// and as wide as the others.
//
// It knows only the role, and starts the app once, since the start-up of
// an app may not run twice. Each expectation gives its reason, which a
// provider of the role with a known bug fails the test with
// (brokenProviders of the fixture registry).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'open_settings.dart';
import 'settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the settings screen shows every entry of the modules once, one below '
    'the other in the order of the role',
    (tester) async {
      await openSettings(tester);

      final screen = find.byType(settingsScreen);
      final entries = [
        for (final entry in settingsEntries)
          find.descendant(of: screen, matching: find.byType(entry)),
      ];
      for (final entry in entries) {
        expect(
          entry,
          findsOneWidget,
          reason: 'Every entry of the modules is on the settings screen once.',
        );
      }

      final rects = [for (final entry in entries) tester.getRect(entry)];
      for (var index = 1; index < rects.length; index++) {
        expect(
          rects[index].top,
          greaterThanOrEqualTo(rects[index - 1].bottom),
          reason: 'The entries are one below the other, in the order of the '
              'role.',
        );
        expect(
          (rects[index].left, rects[index].right),
          (rects.first.left, rects.first.right),
          reason: 'The entries are as wide as each other, the width of '
              'their list.',
        );
      }
      for (final entry in entries) {
        expect(
          find.ancestor(of: entry, matching: find.byType(Material)),
          findsWidgets,
          reason: 'Every entry is on a Material.',
        );
        expect(
          find.descendant(
            of: screen,
            matching: find.ancestor(
              of: entry,
              matching: find.byType(Scrollable),
            ),
          ),
          findsWidgets,
          reason: 'The entries are in a list of the screen that scrolls.',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
