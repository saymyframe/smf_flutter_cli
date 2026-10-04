// A test that continuous integration runs in the apps with the settings
// screen role, whichever module provides it: the settings screen shows
// every entry that the modules of the app, and the templates of roles,
// give the role (SettingsScreenRole.entriesIn), each once, one below the
// other in the order of the role, on a Material, in a list of the screen.
// The screen sets the width of each entry, the same for every entry
// between the same left and right edges, and puts no limit on its height,
// and the list scrolls to its last entry on a surface too short for the
// entries.
//
// It knows only the role, and starts the app once, since the start-up of
// an app may not run twice. Each expectation gives its reason, which a
// provider of the role with a known bug fails the test with
// (brokenProviders of the fixture registry).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'open_settings.dart';
import 'settings.dart';

/// The scrollables of [screen] above [entry], the outermost first: the
/// list of the entry is the last of them.
Finder _listsOf(Finder entry, Finder screen) => find.descendant(
      of: screen,
      matching: find.ancestor(of: entry, matching: find.byType(Scrollable)),
    );

/// Shows that the list of [last], the last entry of [screen], scrolls: on
/// a surface that ends in the middle of the entry, a drag of the list
/// brings the end of the entry into view.
Future<void> _expectScrollsTo(
  WidgetTester tester,
  Finder last,
  Finder screen,
) async {
  // What the app shows below the screen, such as the bar of its main
  // navigation, stays below it on the shorter surface.
  final surface = tester.view.physicalSize;
  final below = surface.height - tester.getRect(screen).bottom;
  tester.view.physicalSize = Size(
    surface.width,
    tester.getRect(last).center.dy + below,
  );
  await tester.pumpAndSettle();
  final hidden = tester.getRect(last).bottom - tester.getRect(screen).bottom;
  expect(
    hidden,
    greaterThan(0),
    reason: 'The last entry does not fit on a surface that ends in its '
        'middle, which the test needs to show that the list scrolls.',
  );

  // The first pixels of a drag only start it, and the list moves by the
  // rest.
  await tester.drag(
    _listsOf(last, screen).last,
    Offset(0, -(hidden + kDragSlopDefault)),
  );
  await tester.pumpAndSettle();
  expect(
    tester.getRect(last).bottom,
    lessThanOrEqualTo(tester.getRect(screen).bottom),
    reason: 'The list of the settings screen scrolls: on a surface too '
        'short for the entries, a drag brings the end of the last entry '
        'into view.',
  );
}

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
          reason: 'Each entry is below the one before it, in the order of '
              'the role.',
        );
      }

      for (final (index, entry) in entries.indexed) {
        expect(
          find.ancestor(of: entry, matching: find.byType(Material)),
          findsWidgets,
          reason: 'Every entry is on a Material.',
        );
        expect(
          _listsOf(entry, screen),
          findsWidgets,
          reason: 'Every entry is in a list of the settings screen that '
              'scrolls: a Scrollable of the screen is above it.',
        );
        // The constraints that the screen laid the entry out with.
        final constraints = tester.renderObject<RenderBox>(entry).constraints;
        expect(
          constraints.minWidth,
          constraints.maxWidth,
          reason: 'The screen sets the width of each entry: the least width '
              'that it allows the entry is the greatest one.',
        );
        expect(
          (rects[index].left, rects[index].right),
          (rects.first.left, rects.first.right),
          reason: 'Every entry has the same width, between the same left and '
              'right edges as the first entry.',
        );
        expect(
          constraints.maxHeight,
          double.infinity,
          reason: 'The screen puts no limit on the height of an entry, so '
              'the entry is as tall as it takes.',
        );
      }

      if (entries.isNotEmpty) {
        await _expectScrollsTo(tester, entries.last, screen);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
