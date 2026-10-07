// A test that continuous integration runs in the apps with the settings
// module: what the settings screen shows below its title.
//
// In an app whose modules have settings, it shows their entries in one
// group: a card, with a line between each two entries.
//
// In an app whose modules have none, it shows a note for the developer of
// the app in place of the group. The note says that the app has no
// settings yet and names the file of the screen, where a setting goes. A
// tap on the path copies it, and the screen says so. On a small phone with
// a large text size the screen scrolls, and the path is shown in full: it
// wraps, at a text size that grows only by half, so that it breaks after a
// slash wherever the name that follows fits a line. The note is in English
// in every app.
//
// The matrix writes settings_of_app.dart next to this file, from the
// settings screen role of the app: how many entries the screen has.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/features/settings/settings_screen.dart';

import 'settings_app.dart';
import 'settings_of_app.dart';

/// The path of the file of the screen in the app, which the note names.
const _path = 'lib/features/settings/settings_screen.dart';

/// The texts of the note.
const _noSettings = 'No settings yet';
const _hint = 'A module with a setting adds its entry here. You can add your '
    'own in this file.';

/// The settings screen.
final Finder _screen = find.byType(SettingsScreen);

/// The widget on the settings screen that shows [text].
Finder _onScreen(String text) =>
    find.descendant(of: _screen, matching: find.text(text));

/// The lines that [paragraph], which shows [_path], breaks the path into:
/// the letters of a line have one top edge.
List<String> _linesOf(RenderParagraph paragraph) {
  final lines = <String>[];
  double? top;
  for (var index = 0; index < _path.length; index++) {
    final letter = paragraph
        .getBoxesForSelection(
          TextSelection(baseOffset: index, extentOffset: index + 1),
        )
        .single;
    if (letter.top != top) lines.add('');
    top = letter.top;
    lines.last += _path[index];
  }
  return lines;
}

/// Checks the group of the entries of the screen of an app with settings.
void _expectGroup(WidgetTester tester) {
  final group = find.descendant(of: _screen, matching: find.byType(Card));
  expect(
    group,
    findsOneWidget,
    reason: 'The screen shows the entries of the app in one group, a card.',
  );
  // What the group has one below the other: the first column of the card.
  final rows = tester
      .widget<Column>(
        find.descendant(of: group, matching: find.byType(Column)).first,
      )
      .children;
  expect(
    [
      for (final (index, row) in rows.indexed)
        if (index.isOdd) row.runtimeType,
    ],
    List.filled(settingsEntryCount - 1, Divider),
    reason: 'The group has a line between each two entries.',
  );
  expect(
    [
      for (final (index, row) in rows.indexed)
        if (index.isEven) row is Divider,
    ],
    List.filled(settingsEntryCount, false),
    reason: 'The group has each entry of the app, and no line before the '
        'first entry or after the last one.',
  );
  expect(
    _onScreen(_noSettings),
    findsNothing,
    reason: 'The screen of an app with settings has no note of an app '
        'without them.',
  );
}

/// Checks the note of the screen of an app without settings.
Future<void> _expectNote(WidgetTester tester) async {
  final path = _onScreen(_path);

  expect(
    find.descendant(of: _screen, matching: find.byType(Card)),
    findsNothing,
    reason: 'The screen of an app without settings has no group of entries.',
  );
  expect(
    titleOfSettings(settingsTitles['en']!),
    findsOneWidget,
    reason: 'The screen of an app without settings has its title.',
  );
  expect(
    _onScreen(_noSettings),
    findsOneWidget,
    reason: 'The screen says that the app has no settings yet.',
  );
  expect(
    _onScreen(_hint),
    findsOneWidget,
    reason: 'The screen tells the developer of the app where a setting goes.',
  );
  expect(
    path,
    findsOneWidget,
    reason: 'The screen names its file by its path in the app.',
  );
  expect(
    tester.getSemantics(path),
    isSemantics(isButton: true, hasTapAction: true, label: _path),
    reason: 'The path is a button for a screen reader, which a tap reaches.',
  );
  expect(
    MediaQuery.textScalerOf(tester.element(path)).scale(10),
    MediaQuery.textScalerOf(tester.element(_screen)).scale(10),
    reason: 'At the text size of the device of the tests, the path has the '
        'text size of the screen.',
  );

  // What the app copies, in place of the clipboard of a device.
  final copied = <Object?>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map<Object?, Object?>)['text']);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  await tester.tap(path);
  await tester.pumpAndSettle();
  expect(copied, [_path], reason: 'A tap on the path copies it.');
  expect(
    find.descendant(
      of: find.byType(SnackBar),
      matching: find.text('Copied: $_path'),
    ),
    findsOneWidget,
    reason: 'The screen says that it copied the path.',
  );
  // The message goes away after a while, which the test waits for, so that
  // no timer of it is left when the test ends.
  await tester.pump(const Duration(seconds: 10));
  await tester.pumpAndSettle();
  expect(
    find.byType(SnackBar),
    findsNothing,
    reason: 'The message that the path was copied goes away.',
  );

  // A small phone with insets and the text at three times its size, about
  // the largest that the settings of a device have.
  const insets = FakeViewPadding(top: 40, bottom: 40);
  tester.view
    ..physicalSize = const Size(320, 480)
    ..devicePixelRatio = 1
    ..padding = insets
    ..viewPadding = insets;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = 3;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpAndSettle();
  expect(
    tester.takeException(),
    isNull,
    reason: 'The screen of an app without settings fits a small phone with '
        'a large text size.',
  );

  await tester.scrollUntilVisible(
    path,
    100,
    scrollable:
        find.descendant(of: _screen, matching: find.byType(Scrollable)).first,
  );
  await tester.pumpAndSettle();
  expect(
    tester.takeException(),
    isNull,
    reason: 'The screen of an app without settings scrolls to its path on a '
        'small phone with a large text size.',
  );
  expect(
    path.hitTestable(),
    findsOneWidget,
    reason: 'The path is on the screen of a small phone with a large text '
        'size once the screen scrolled to it, where a tap reaches it.',
  );
  expect(
    MediaQuery.textScalerOf(tester.element(_screen)).scale(10),
    30,
    reason: 'The screen has the text size of the device, three times the '
        'usual one.',
  );
  expect(
    MediaQuery.textScalerOf(tester.element(path)).scale(10),
    15,
    reason: 'At a large text size, the path grows only by half.',
  );

  final paragraph = tester.renderObject<RenderParagraph>(path);
  final shown = tester.widget<Text>(path);
  expect(
    (shown.maxLines, shown.overflow, paragraph.didExceedMaxLines),
    (null, null, false),
    reason: 'The path is shown in full: nothing limits its lines or cuts '
        'it.',
  );
  final width = tester.view.physicalSize.width;
  final rect = tester.getRect(path);
  expect(
    rect.left >= 0 && rect.right <= width,
    isTrue,
    reason: 'The path is within the width of the screen: $rect of $width.',
  );
  final lines = _linesOf(paragraph);
  expect(
    lines.length,
    greaterThan(1),
    reason: 'The path wraps on a small phone with a large text size.',
  );
  // The width of a letter of the path, whose letters all have one width,
  // and so how many of them fit a line.
  final letter = paragraph
      .getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: 1))
      .single
      .toRect()
      .width;
  final fits = (paragraph.constraints.maxWidth / letter).floor();
  var end = 0;
  for (final line in lines.take(lines.length - 1)) {
    end += line.length;
    // The name that the line break is in, with the slash after it.
    final from = _path.lastIndexOf('/', end - 1) + 1;
    final next = _path.indexOf('/', end);
    final name = _path.substring(from, next < 0 ? _path.length : next + 1);
    expect(
      line.endsWith('/') || name.length > fits,
      isTrue,
      reason: 'The path breaks after a slash, and inside a name only when '
          'the name is too long for a line: "$line" ends inside "$name", '
          'and a line has room for $fits letters.',
    );
  }
}

/// On a narrow phone with a large text size, the title of the screen gets
/// smaller rather than break inside a word: it stays on one line, within
/// the screen.
Future<void> _expectTitleOnOneLine(WidgetTester tester) async {
  const width = 320.0;
  tester.view
    ..physicalSize = const Size(width, 480)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = 3;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpAndSettle();
  // A check before this one may have scrolled the screen down, and a list
  // builds only what is in view: back to its top, where the title is.
  tester
      .state<ScrollableState>(
        find.descendant(of: _screen, matching: find.byType(Scrollable)).first,
      )
      .position
      .jumpTo(0);
  await tester.pumpAndSettle();

  final title = find.descendant(
    of: find
        .descendant(
          of: _screen,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && (widget.properties.header ?? false),
          ),
        )
        .first,
    matching: find.byType(Text),
  );
  final style = tester.widget<Text>(title).style!;
  // The height of a line of the title at this text size.
  final line =
      MediaQuery.textScalerOf(tester.element(title)).scale(style.fontSize!) *
          (style.height ?? 1);
  expect(
    tester.getSize(title).height,
    lessThan(1.5 * line),
    reason: 'The title is on one line, also when its line is too short for '
        'it at this text size.',
  );
  final shown = tester.getRect(title);
  expect(
    (shown.left >= 0, shown.right <= width),
    (true, true),
    reason: 'The title is within the screen: it is at $shown.',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the settings screen shows the entries of the app in one group, or, in '
    'an app without settings, a note for its developer with the path of the '
    'file of the screen',
    (tester) async {
      await startApp(tester);
      await goToSettings(tester);

      if (settingsEntryCount > 0) {
        _expectGroup(tester);
      } else {
        await _expectNote(tester);
      }
      await _expectTitleOnOneLine(tester);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
