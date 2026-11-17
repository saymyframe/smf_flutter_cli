// A test that continuous integration runs in the apps with the review role
// and the settings screen role, whichever modules provide them: the entry
// that opens the page of the app in its store, which the template of the
// review role gives the settings screen, over a service of the test that
// scripts what a provider answers. On Android the screen shows the entry
// once, with its title in each language of the app. A tap opens exactly the
// Google Play page of the app, for a review, and never asks for the review
// dialog, which the stores forbid from a button. When no app of the device
// opens the page, a snack bar says so in the language of the app. On iOS the
// entry shows exactly when the App Store ID of the app in .env is all
// digits, which the tests of the apps leave empty. On a small phone with a
// large text size, the title keeps its words whole and stays in the row of
// the entry, in full: it is as large as the text size asks, or, where its
// longest word would not fit, as large as that word allows.
//
// It knows only the two roles, and the env role that the review role
// requires, and starts the app once, since the start-up of an app may not
// run twice. The matrix writes setting.dart next to it, from the entries of
// the settings screen role and the languages of the localization role of
// the app: the type of the widget of the entry and its texts in each
// language. It opens the settings screen as the tests of the settings screen
// role do, and takes the service of the tests, which scripts what a provider
// answers, from the files of the test of the review role. Both of those
// tests run in every app that this one runs in. Each expectation gives its
// reason.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/env/app_env.dart';
import 'package:{{app_name}}/core/review/app_review.dart';

import '../review_role/review_role.dart' show ScriptedReview, inRealTime;
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

  testWidgets(
    'the entry that opens the page of the app in its store shows its title '
    'in the language of the app, opens the page for a review and never asks '
    'for the review dialog, shows only where the app has a store page, and '
    'keeps the words of its title whole on a small phone',
    (tester) async {
      await openSettings(tester);
      // The device asks for the first language of the app, which the app is
      // in then.
      final first = reviewTexts.keys.first;
      tester.platformDispatcher.localesTestValue = [Locale(first)];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpAndSettle();

      // A service of the test, which the app takes as it takes the service
      // of the provider at its start.
      final service = ScriptedReview();
      await inRealTime(tester, 'the start of the reviews', () async {
        await appReview.start(service);
      });
      await tester.pumpAndSettle();

      final entry = find.byType(reviewSetting);
      // The language that the app is in where the entry is.
      String language() =>
          Localizations.localeOf(tester.element(entry)).languageCode;
      // The title of the entry in [texts].
      Finder titleOf(ReviewTexts texts) =>
          find.descendant(of: entry, matching: find.text(texts.title));
      // What the snack bar of the app says, if it shows one.
      List<String> snackBar() => [
            for (final text in find
                .descendant(
                  of: find.byType(SnackBar),
                  matching: find.byType(Text),
                )
                .evaluate()
                .map((element) => element.widget as Text))
              text.data ?? text.textSpan!.toPlainText(),
          ];
      // Has the device ask for the language [code].
      Future<void> useLanguage(String code) async {
        tester.platformDispatcher.localesTestValue = [Locale(code)];
        await tester.pumpAndSettle();
        expect(
          language(),
          code,
          reason: 'The app is in the language that the device asks for, '
              '$code, one of its languages.',
        );
      }

      expect(
        entry,
        findsOneWidget,
        reason: 'On Android, where the app always has its Google Play page, '
            'the settings screen shows the entry once.',
      );
      for (final MapEntry(key: code, value: texts) in reviewTexts.entries) {
        await useLanguage(code);
        expect(
          titleOf(texts),
          findsOneWidget,
          reason: 'The entry shows its title in the language of the app, '
              '$code.',
        );
      }
      await useLanguage(first);

      // A tap opens the page for a review, which an app of the device opens.
      await tester.tap(entry);
      await tester.pumpAndSettle();
      final play = Uri.parse(
        'https://play.google.com/store/apps/details?id=$googlePlayId',
      );

      expect(
        [service.calls, service.pages],
        [
          ['openStorePage'],
          [play],
        ],
        reason: 'A tap on the entry opens exactly the Google Play page of the '
            'app once, and asks for no review dialog, which the stores '
            'forbid from a button.',
      );
      expect(
        snackBar(),
        isEmpty,
        reason: 'The page opened, so the entry shows nothing more.',
      );

      // No app of the device opens the page.
      service.opens = false;
      for (final MapEntry(key: code, value: texts) in reviewTexts.entries) {
        await useLanguage(code);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(
          snackBar(),
          [texts.failed],
          reason: 'When no app of the device opens the page, a snack bar says '
              'so in the language of the app, $code.',
        );
      }
      // The snack bar goes away once its time is over.
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(
        service.requests,
        0,
        reason: 'The entry never asks for the review dialog: the stores '
            'forbid it from a button, and point a button to the page.',
      );
      expect(
        service.pages,
        List.filled(service.pages.length, play),
        reason: 'Each tap opens the Google Play page of the app.',
      );
      expect(
        service.calls,
        List.filled(1 + reviewTexts.length, 'openStorePage'),
        reason: 'Each tap on the entry opens the page once, and does nothing '
            'else.',
      );

      // On iOS the app has its App Store page only with the App Store ID in
      // .env, all digits, which the tests of the apps leave empty.
      final id = AppEnv.reviewAppStoreId;
      final hasAppStoreId = id != null && RegExp(r'^[0-9]+$').hasMatch(id);
      await usePlatform(tester, TargetPlatform.iOS);
      expect(
        entry,
        findsNWidgets(hasAppStoreId ? 1 : 0),
        reason: 'On iOS the settings screen shows the entry only where the app '
            'has its App Store page, which takes the App Store ID in .env: '
            '"$id".',
      );
      await usePlatform(tester, null);
      expect(
        entry,
        findsOneWidget,
        reason: 'Back on Android, the settings screen shows the entry again.',
      );

      // The list of the screen that holds the entry, the nearest scrollable
      // above it on the tall surface, where the screen builds every row. On
      // the small phone below, a screen that builds its rows only as they
      // come into view may build none for the entry until this list scrolls
      // to it.
      final listOfEntry = find
          .ancestor(of: entry, matching: find.byType(Scrollable))
          .evaluate()
          .first;
      final list = find.byElementPredicate(
        (element) => element == listOfEntry,
        description: 'the list of the entry that opens the store page',
      );

      // A small phone with insets and the text at three times its size,
      // about the largest that the settings of a device have.
      tester.view
        ..physicalSize = const Size(320, 480)
        ..padding = const FakeViewPadding(top: 40, bottom: 40);
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'The settings screen with the entry fits a small phone with a '
            'large text size.',
      );
      for (final MapEntry(key: code, value: texts) in reviewTexts.entries) {
        await useLanguage(code);
        // The list scrolls until the entry is in view, as a user scrolls to
        // it: the large title and the entries above it may have moved it
        // below the end of the screen.
        await tester.scrollUntilVisible(entry, 100, scrollable: list);
        await tester.pumpAndSettle();
        final title = titleOf(texts);
        expect(title, findsOneWidget);
        final row = tester.getRect(entry);
        final box = tester.getRect(title);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: title,
            matching: find.byType(RichText),
            matchRoot: true,
          ),
        );
        expect(
          (box.left >= row.left, box.right <= row.right),
          (true, true),
          reason: 'The title of the entry stays in its row on a small phone '
              'with a large text size, in $code: it is at $box in the row at '
              '$row.',
        );
        expect(
          (
            paragraph.didExceedMaxLines,
            paragraph.size.height < paragraph.textSize.height,
          ),
          (false, false),
          reason: 'The entry shows its title "${texts.title}" in full, on as '
              'many lines as it needs, on a small phone with a large text '
              'size, in $code.',
        );
        _expectWholeWords(
          tester,
          paragraph,
          title,
          texts.title,
          language: code,
        );
      }
      expect(
        tester.takeException(),
        isNull,
        reason: 'The entry fits a small phone with a large text size in each '
            'language of the app.',
      );
    },
    // A widget test fails after ten minutes by default; a test that hangs
    // fails sooner.
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

/// Checks that [paragraph], the title [text] that [shown] shows, keeps its
/// words whole in [language]: no line starts between two letters or digits,
/// or at a no-break space. The title is as large as the text size of the
/// device asks for the style of the title in the row, or, where its longest
/// word would not fit the width that the title has at that size, as large as
/// that word allows: smaller, with that word on a line of its own.
void _expectWholeWords(
  WidgetTester tester,
  RenderParagraph paragraph,
  Finder shown,
  String text, {
  required String language,
}) {
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
      reason: 'On the small phone, the title "$text" breaks between its words '
          'and not inside "${text.substring(start, end)}", in $language: '
          'where a word would not fit, the title is as large as the word '
          'allows.',
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
  // The size that the text size of the device asks for the style of a title
  // in the row, and the size of the title.
  final element = tester.element(shown);
  final largest = MediaQuery.textScalerOf(element)
      .scale(DefaultTextStyle.of(element).style.fontSize ?? 14);
  final size = paragraph.textScaler.scale(paragraph.text.style!.fontSize!);
  final room = paragraph.constraints.maxWidth;
  expect(
    size <= largest + 0.01 &&
        (size >= largest - 0.01 || (widest <= room && widest >= room * 0.9)),
    isTrue,
    reason: 'On the small phone, the title "$text" is as large as the text '
        'size asks, $largest, or as large as its longest word allows, in '
        '$language: it is $size, and its longest word takes $widest of '
        '$room.',
  );
}
