// A test that continuous integration runs in the apps with the
// notifications role and the settings screen role, whichever modules
// provide them: the entry of the notifications, which the template of the
// notifications role gives the settings screen. The screen shows it once,
// with its title and whether the app may show notifications, Off or On, as
// the value of its row, in each language of the app. On a first launch a
// tap asks for the permission through the provider, and the entry shows
// On. On a small phone with a large text size, once the list of the screen
// scrolled to the entry, the state is below the title, and the texts stay
// in the row of the entry, in full, and keep their words whole, in each
// language of the app: each is as large as the text size asks, or, where
// its longest word would not fit, as large as that word allows.
//
// It knows only the two roles, and starts the app once, since the start-up
// of an app may not run twice. The matrix writes setting.dart next to it,
// from the entries of the settings screen role and the languages of the
// localization role of the app: the type of the widget of the entry and
// its texts in each language. It opens the settings screen as the tests of
// the settings screen role do, and runs a call in real time as the test of
// the notifications role does. Both of those tests run in every app that
// this one runs in. Each expectation gives its reason.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/notifications/app_notifications.dart';

import '../notifications_role/notifications_role.dart';
import '../settings_screen_role/open_settings.dart';
import 'setting.dart';

/// A letter, a mark that belongs to one, a digit, or a no-break space, which
/// keeps the words around it together: a line that starts between two of
/// them starts inside a word.
final RegExp _joined = RegExp(
  r'[\p{L}\p{M}\p{N}\u00A0\u2007\u202F]',
  unicode: true,
);

/// A white space between two words, where a line may break: every one but a
/// no-break space.
final RegExp _space = RegExp(r'[^\S\u00A0\u2007\u202F]');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the settings screen shows the entry of the notifications, with Off or '
    'On in the language of the app, and a tap on a first launch asks for '
    'the permission',
    (tester) async {
      await openSettings(tester);

      final entry = find.byType(notificationsSetting);
      Finder inEntry(String text) =>
          find.descendant(of: entry, matching: find.text(text));
      // The language that the app is in where the entry is.
      String language() =>
          Localizations.localeOf(tester.element(entry)).languageCode;
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      // Has the device ask for each language of the app in turn, and checks
      // that the entry shows its title and the state that [state] reads,
      // which [what] tells, in each; then the device asks for the first
      // language of the app again.
      Future<void> inEachLanguage(
        String Function(SettingTexts texts) state,
        String what,
      ) async {
        for (final MapEntry(key: code, value: texts) in settingTexts.entries) {
          tester.platformDispatcher.localesTestValue = [Locale(code)];
          await tester.pumpAndSettle();
          expect(
            language(),
            code,
            reason: 'The app is in the language that the device asks for, '
                '$code, one of its languages.',
          );
          expect(
            inEntry(texts.title),
            findsOneWidget,
            reason: 'The entry shows its title in the language of the app, '
                '$code.',
          );
          expect(
            inEntry(state(texts)),
            findsOneWidget,
            reason: 'The entry shows $what in the language of the app, $code.',
          );
        }
        tester.platformDispatcher.localesTestValue = [
          Locale(settingTexts.keys.first),
        ];
        await tester.pumpAndSettle();
      }

      expect(
        entry,
        findsOneWidget,
        reason: 'The settings screen shows the entry of the notifications '
            'once.',
      );
      expect(
        appNotifications.permission.value,
        NotificationPermission.notAsked,
        reason: 'The mocks of the platform side of a provider start as on a '
            'first launch, as the notifications role says: the app may not '
            'show notifications and has not asked.',
      );
      await inEachLanguage(
        (texts) => texts.off,
        'Off, since the app may not show notifications,',
      );
      final texts = settingTexts.values.first;
      final title = tester.getRect(inEntry(texts.title));
      final state = tester.getRect(inEntry(texts.off));
      expect(
        state.left >= title.right &&
            state.top < title.bottom &&
            state.bottom > title.top,
        isTrue,
        reason: 'The entry shows whether the app may show notifications as '
            'the value of its row, after its title: $state and $title.',
      );
      final arrow = find.descendant(
        of: entry,
        matching: find.byIcon(Icons.chevron_right),
      );
      expect(
        arrow,
        findsOneWidget,
        reason: 'The row of the entry has an arrow, which tells that a tap '
            'leads on.',
      );
      expect(
        tester.getRect(arrow).left,
        greaterThanOrEqualTo(state.right),
        reason: 'The arrow of the row is after the state.',
      );

      // A tap, as a user who turns the notifications on, which the mocks of
      // the provider grant once the system asked.
      await inRealTime(tester, 'a tap on the entry', () async {
        await tester.tap(entry);
        for (var turn = 0;
            turn < 300 &&
                appNotifications.permission.value !=
                    NotificationPermission.granted;
            turn++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(
        (appNotifications.permission.value, askedSaved),
        (NotificationPermission.granted, true),
        reason: 'A tap on the entry of an app that has not asked asks for '
            'the permission, which the mocks of a provider grant when the '
            'app asks, as the role says, and the app remembers that it '
            'asked.',
      );
      await inEachLanguage(
        (texts) => texts.on,
        'On, since the app may show notifications,',
      );

      // The list of the screen that holds the entry, the nearest scrollable
      // above it on the tall surface, where the screen builds every row. On
      // the small phone below, a screen that builds its rows only as they
      // come into view may build none for the entry until this list
      // scrolls to it.
      final listOfEntry = find
          .ancestor(of: entry, matching: find.byType(Scrollable))
          .evaluate()
          .first;
      final list = find.byElementPredicate(
        (element) => element == listOfEntry,
        description: 'the list of the entry of the notifications',
      );

      // A small phone with the text at three times its size, about the
      // largest that the settings of a device have.
      tester.view.physicalSize = const Size(320, 480);
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'The settings screen with the entry of the notifications '
            'fits a small phone with a large text size.',
      );
      // The list scrolls until the entry is in view, as a user scrolls to
      // it: the large title and the entries above it may have moved it
      // below the end of the screen.
      await tester.scrollUntilVisible(entry, 100, scrollable: list);
      await tester.pumpAndSettle();
      final largeTitle = tester.getRect(inEntry(texts.title));
      final largeState = tester.getRect(inEntry(texts.on));
      expect(
        largeState.top,
        greaterThanOrEqualTo(largeTitle.bottom),
        reason: 'At a large text size, the state is below the title of the '
            'entry, where it has the width of the row.',
      );
      final row = tester.getRect(entry);
      for (final text in [largeTitle, largeState]) {
        expect(
          text.left >= row.left && text.right <= row.right,
          isTrue,
          reason: 'The texts of the entry stay in its row on a small phone '
              'with a large text size: $text of $row.',
        );
      }
      expect(
        arrow,
        findsOneWidget,
        reason: 'The row of the entry keeps its arrow at a large text size.',
      );

      // The texts of the row on the small phone, in each language of the
      // app.
      //
      // Under flutter test every glyph of the font of the tests is one em
      // wide, so at this size the title has about 160 pixels of room in its
      // row, and even "On", 84 pixels wide below it, fits while
      // "Notifications" does not: the title is smaller than the text size
      // asks here. With the font of the app, such as Geist of
      // material_theme, a shorter word fits at the size that the text size
      // asks. So the size that this check sees is no look of the app: it
      // checks that the texts keep their words whole and stay in the row,
      // whichever size that takes.
      for (final MapEntry(key: code, value: texts) in settingTexts.entries) {
        tester.platformDispatcher.localesTestValue = [Locale(code)];
        await tester.pumpAndSettle();
        expect(
          language(),
          code,
          reason: 'The app is in the language that the device asks for, '
              '$code, one of its languages.',
        );
        await tester.scrollUntilVisible(entry, 100, scrollable: list);
        await tester.pumpAndSettle();
        for (final text in [texts.title, texts.on]) {
          _expectInPlace(
            tester,
            inEntry(text),
            entry,
            'the row of the entry',
            language: code,
          );
        }
      }
      tester.platformDispatcher.localesTestValue = [
        Locale(settingTexts.keys.first),
      ];
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'The entry of the notifications fits a small phone with a '
            'large text size in each language of the app.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

/// Checks that [shown], a text that [place] shows in [placed], keeps its
/// words whole on the small phone in [language] and stays in [placed], in
/// full: no line starts between two letters or digits, or at a no-break
/// space. The text is as large as the text size of the device asks for its
/// style, or, where its longest word would not fit the width that the text
/// has at that size, as large as that word allows: smaller, with that word
/// on a line of its own.
void _expectInPlace(
  WidgetTester tester,
  Finder shown,
  Finder placed,
  String place, {
  required String language,
}) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(
        of: shown, matching: find.byType(RichText), matchRoot: true),
  );
  final text = paragraph.text.toPlainText();
  final box = tester.getRect(shown);
  final bounds = tester.getRect(placed);
  expect(
    (box.left >= bounds.left, box.right <= bounds.right),
    (true, true),
    reason: '"$text" stays in $place on a small phone with a large text '
        'size, in $language: it is at $box in $place at $bounds.',
  );
  expect(
    (
      paragraph.didExceedMaxLines,
      paragraph.size.height < paragraph.textSize.height,
    ),
    (false, false),
    reason: '"$text" shows in full in $place, on as many lines as it needs, '
        'on a small phone with a large text size, in $language.',
  );
  // The boxes of the characters from [start] to [end].
  List<TextBox> boxesOf(int start, int end) => paragraph.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: end),
      );
  // The top of the line of the character at [index], or `null` for one that
  // the paragraph draws no box for.
  double? lineOf(int index) => boxesOf(index, index + 1).firstOrNull?.top;
  for (var index = 1; index < text.length; index++) {
    if (!_joined.hasMatch(text[index - 1]) || !_joined.hasMatch(text[index])) {
      continue;
    }
    final (before, after) = (lineOf(index - 1), lineOf(index));
    if (before == null || after == null) continue;
    final start = text.lastIndexOf(_space, index) + 1;
    final end = switch (text.indexOf(_space, index)) {
      -1 => text.length,
      final space => space,
    };
    expect(
      after,
      closeTo(before, 0.5),
      reason: 'On the small phone, "$text" breaks between its words and not '
          'inside "${text.substring(start, end)}", in $language: where a '
          'word would not fit, the text is as large as the word allows.',
    );
  }
  // The width of the longest word: that of all its boxes.
  var widest = 0.0;
  var from = 0;
  for (final word in text.split(_space)) {
    if (word.isEmpty) continue;
    final start = text.indexOf(word, from);
    from = start + word.length;
    final width = boxesOf(start, from).fold(
      0.0,
      (width, box) => width + box.right - box.left,
    );
    if (width > widest) widest = width;
  }
  // The size that the text size of the device asks for the style of the
  // text, and the size of the text.
  final element = tester.element(shown);
  final largest = MediaQuery.textScalerOf(element)
      .scale(DefaultTextStyle.of(element).style.fontSize ?? 14);
  final size = paragraph.textScaler.scale(paragraph.text.style!.fontSize!);
  final room = paragraph.constraints.maxWidth;
  expect(
    size <= largest + 0.01 &&
        (size >= largest - 0.01 || (widest <= room && widest >= room * 0.9)),
    isTrue,
    reason: 'On the small phone, "$text" is as large as the text size asks, '
        '$largest, or as large as its longest word allows, in $language: it '
        'is $size, and its longest word takes $widest of $room.',
  );
}
