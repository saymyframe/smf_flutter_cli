// A test that continuous integration runs in the apps with the localization
// role and the settings screen role, whichever modules provide them: the
// setting of the language, the entry that the template of the localization
// role gives the settings screen. On the screen it shows its title and, as
// the value of its row, the choice of the user, the languages of the device
// while the user chose none. A tap opens a sheet over the main navigation
// of the app, with an option for the languages of the device and one for
// each language of the app, by its name in that language, or its code, with
// the chosen one selected and checked. A tap on an option closes the sheet:
// the app and the texts of the setting are in the language of the option,
// which is saved under the key of the role, and the option of the device
// removes what was saved. On a small phone with a large text size, the
// choice is below the title of the setting, and the sheet scrolls. There
// the texts of the setting keep their words whole and stay in its row, in
// full, in each language of the app and with each choice, and so do the
// title and the options of the sheet: each is as large as the text size
// asks, or, where its longest word would not fit, as large as that word
// allows.
//
// It knows only the two roles, and starts the app once, since the start-up
// of an app may not run twice. The matrix writes setting.dart next to it,
// from the entries of the settings screen role and the languages of the
// localization role of the app: the type of the widget of the entry, the
// key of the role, the label of each language and the texts of the setting
// in each of them. It opens the settings screen as the tests of the
// settings screen role do, which every app with that role has too. Each
// expectation gives its reason, which a provider of the localization role
// with a known bug fails the test with (brokenProviders of the fixture
// registry).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/l10n/app_locale.dart';
import 'package:{{app_name}}/core/preferences/app_preferences.dart';

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
    'the setting of the language shows the choice of the user, and its '
    'sheet chooses a language of the app or the languages of the device',
    (tester) async {
      await openSettings(tester);

      final setting = find.byType(languageSetting);
      final sheet = find.byType(BottomSheet);
      Finder inSetting(String text) =>
          find.descendant(of: setting, matching: find.text(text));
      Finder option(String label) =>
          find.descendant(of: sheet, matching: find.text(label));
      // The language that the app is in where the setting is.
      String language() =>
          Localizations.localeOf(tester.element(setting)).languageCode;
      // Whether the check of the sheet is on the row of the option.
      bool checked(String label) {
        final check = find.descendant(
          of: sheet,
          matching: find.byIcon(Icons.check_rounded),
        );
        if (check.evaluate().length != 1) return false;
        final row = tester.getRect(option(label));
        final center = tester.getCenter(check).dy;
        return row.top <= center && center <= row.bottom;
      }

      expect(
        setting,
        findsOneWidget,
        reason: 'The settings screen shows the setting of the language once.',
      );
      expect(
        appLocale.value,
        isNull,
        reason: 'An app that starts with nothing saved has no language '
            'chosen.',
      );
      final device = language();
      expect(
        inSetting(settingTitles[device]!),
        findsOneWidget,
        reason: 'The setting shows its title in the language of the app.',
      );
      expect(
        inSetting(deviceOptions[device]!),
        findsOneWidget,
        reason: 'While the user chose no language, the setting shows the '
            'option of the languages of the device.',
      );
      final title = tester.getRect(inSetting(settingTitles[device]!));
      final choice = tester.getRect(inSetting(deviceOptions[device]!));
      expect(
        choice.left >= title.right &&
            choice.top < title.bottom &&
            choice.bottom > title.top,
        isTrue,
        reason: 'The setting shows the choice of the user as the value of '
            'its row, after its title: $choice and $title.',
      );
      final arrow = find.descendant(
        of: setting,
        matching: find.byIcon(Icons.chevron_right),
      );
      expect(
        arrow,
        findsOneWidget,
        reason: 'The row of the setting has an arrow, which tells that a '
            'tap opens its options.',
      );
      expect(
        tester.getRect(arrow).left,
        greaterThanOrEqualTo(choice.right),
        reason: 'The arrow of the row is after the choice of the user.',
      );

      await tester.tap(setting);
      await tester.pumpAndSettle();
      expect(
        sheet,
        findsOneWidget,
        reason: 'A tap on the setting opens its sheet.',
      );
      expect(
        Navigator.of(tester.element(sheet)),
        same(Navigator.of(tester.element(sheet), rootNavigator: true)),
        reason: 'The sheet of the setting is on the navigator of the root '
            'of the app, so it is over the main navigation of the app too.',
      );
      expect(
        option(deviceOptions[device]!),
        findsOneWidget,
        reason: 'The sheet has the option of the languages of the device.',
      );
      for (final locale in appLocales) {
        expect(
          option(languageLabels[locale.languageCode]!),
          findsOneWidget,
          reason: 'The sheet has an option for each language of the app, by '
              'its name in that language, or its code.',
        );
      }
      expect(
        tester.getSemantics(option(deviceOptions[device]!)),
        isSemantics(isSelected: true),
        reason: 'While the user chose no language, the option of the '
            'languages of the device is the selected one.',
      );
      expect(
        checked(deviceOptions[device]!),
        isTrue,
        reason: 'The sheet has one check, on the selected option.',
      );

      // The last language of the app, as the user chooses it.
      final chosen = appLocales.last;
      final code = chosen.languageCode;
      await tester.tap(option(languageLabels[code]!));
      await tester.pumpAndSettle();
      expect(
        sheet,
        findsNothing,
        reason: 'A tap on an option closes the sheet.',
      );
      expect(
        appLocale.value,
        chosen,
        reason: 'A tap on the option of a language chooses the language.',
      );
      expect(
        language(),
        code,
        reason: 'The app is in the language that the user chose in the '
            'setting.',
      );
      expect(
        createAppPreferences().getString(savedLanguageKey),
        code,
        reason: 'A choice of the setting is saved under the key of the role, '
            'as the code of its language.',
      );
      expect(
        inSetting(languageLabels[code]!),
        findsOneWidget,
        reason: 'The setting shows the language that the user chose, by its '
            'name in that language, or its code.',
      );
      expect(
        inSetting(settingTitles[code]!),
        findsOneWidget,
        reason: 'The setting shows its texts in the language that the user '
            'chose.',
      );

      await tester.tap(setting);
      await tester.pumpAndSettle();
      expect(
        option(deviceOptions[code]!),
        findsOneWidget,
        reason: 'The sheet shows its texts in the language that the user '
            'chose.',
      );
      expect(
        tester.getSemantics(option(languageLabels[code]!)),
        isSemantics(isSelected: true),
        reason: 'The option of the language that the user chose is the '
            'selected one.',
      );
      expect(
        tester.getSemantics(option(deviceOptions[code]!)),
        isSemantics(isSelected: false),
        reason: 'Only the option of the choice of the user is selected.',
      );
      expect(
        checked(languageLabels[code]!),
        isTrue,
        reason: 'The sheet has one check, on the selected option.',
      );

      // The languages of the device again.
      await tester.tap(option(deviceOptions[code]!));
      await tester.pumpAndSettle();
      expect(
        sheet,
        findsNothing,
        reason: 'A tap on the option of the device closes the sheet.',
      );
      expect(
        appLocale.value,
        isNull,
        reason: 'The option of the languages of the device lets the app '
            'follow the device again.',
      );
      expect(
        createAppPreferences().getString(savedLanguageKey),
        isNull,
        reason: 'Following the device again removes what was saved.',
      );
      expect(
        language(),
        device,
        reason: 'The app is in the language of the device again.',
      );
      expect(
        inSetting(deviceOptions[device]!),
        findsOneWidget,
        reason: 'The setting shows the option of the languages of the '
            'device again.',
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
        reason: 'The settings screen with the setting of the language fits '
            'a small phone with a large text size.',
      );
      // The screen scrolls to the setting, which the large title may have
      // moved out of view: a list builds what is out of view too, but
      // keeps it off the stage.
      await tester.ensureVisible(
        find.byType(languageSetting, skipOffstage: false),
      );
      await tester.pumpAndSettle();
      final largeTitle = tester.getRect(inSetting(settingTitles[device]!));
      final largeChoice = tester.getRect(inSetting(deviceOptions[device]!));
      expect(
        largeChoice.top,
        greaterThanOrEqualTo(largeTitle.bottom),
        reason: 'At a large text size, the choice of the user is below the '
            'title of the setting, where it has the width of the row.',
      );
      final row = tester.getRect(setting);
      for (final text in [largeTitle, largeChoice]) {
        expect(
          text.left >= row.left && text.right <= row.right,
          isTrue,
          reason: 'The texts of the setting stay in its row on a small '
              'phone with a large text size: $text of $row.',
        );
      }

      // Each text of the row on the small phone: the title in each
      // language of the app, and as the choice the option of the languages
      // of the device, in each language that the device asks for, and the
      // name of each language of the app, which code chooses in real time,
      // so that the write of the preferences does not wait for the fake
      // time of the test.
      //
      // Under flutter test every glyph of the font of the tests is one em
      // wide, so at this size the title has about 160 pixels of room in its
      // row, and even "System", 252 pixels wide as the choice, does not fit:
      // the texts are smaller than the text size asks here. With the font
      // of the app, such as Geist of material_theme, a short word such as
      // "Мова" fits at the size that the text size asks, and a long one such
      // as "Українська" does not. So the size that this check sees is no
      // look of the app: it checks that the texts keep their words whole and
      // stay in the row, whichever size that takes.
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      Future<void> expectWholeRow(String code, String choice) async {
        await tester.ensureVisible(
          find.byType(languageSetting, skipOffstage: false),
        );
        await tester.pumpAndSettle();
        expect(
          language(),
          code,
          reason: 'The app is in the language $code, one of its languages.',
        );
        for (final text in [settingTitles[code]!, choice]) {
          _expectInPlace(
            tester,
            inSetting(text),
            setting,
            'the row of the setting',
            language: code,
          );
        }
      }

      for (final code in settingTitles.keys) {
        tester.platformDispatcher.localesTestValue = [Locale(code)];
        await tester.pumpAndSettle();
        await expectWholeRow(code, deviceOptions[code]!);
      }
      for (final locale in appLocales) {
        final code = locale.languageCode;
        await tester.runAsync(() => appLocale.choose(locale));
        await tester.pumpAndSettle();
        await expectWholeRow(code, languageLabels[code]!);
      }
      await tester.runAsync(() => appLocale.choose(null));
      await tester.pumpAndSettle();

      // The sheet on the small phone, in each language of the app, which
      // the device asks for: its title and the label of each option, each
      // option once the sheet scrolled to it. A tap outside closes it.
      for (final code in settingTitles.keys) {
        tester.platformDispatcher.localesTestValue = [Locale(code)];
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byType(languageSetting, skipOffstage: false),
        );
        await tester.pumpAndSettle();
        await tester.tap(setting);
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'The sheet of the setting fits a small phone with a large '
              'text size, in $code.',
        );
        _expectInPlace(
          tester,
          option(settingTitles[code]!),
          sheet,
          'the sheet',
          language: code,
        );
        for (final label in [
          deviceOptions[code]!,
          for (final locale in appLocales) languageLabels[locale.languageCode]!,
        ]) {
          await tester.scrollUntilVisible(
            option(label),
            100,
            scrollable:
                find.descendant(of: sheet, matching: find.byType(Scrollable)),
          );
          await tester.pumpAndSettle();
          _expectInPlace(
            tester,
            option(label),
            find.ancestor(of: option(label), matching: find.byType(ListTile)),
            'its option',
            language: code,
          );
        }
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(
          sheet,
          findsNothing,
          reason: 'A tap outside the sheet closes it, in $code.',
        );
      }
      tester.platformDispatcher.clearLocalesTestValue();
      await tester.pumpAndSettle();
      expect(
        (appLocale.value, language()),
        (null, device),
        reason: 'The app follows the device again, which asks for the '
            'language that it asked for at the start.',
      );

      await tester.ensureVisible(
        find.byType(languageSetting, skipOffstage: false),
      );
      await tester.pumpAndSettle();
      await tester.tap(setting);
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'The sheet of the setting fits a small phone with a large '
            'text size.',
      );
      // The last option of the sheet, which the sheet scrolls to where its
      // options do not fit.
      final last = option(languageLabels[appLocales.last.languageCode]!);
      await tester.scrollUntilVisible(
        last,
        100,
        scrollable:
            find.descendant(of: sheet, matching: find.byType(Scrollable)),
      );
      await tester.pumpAndSettle();
      expect(
        last.hitTestable(),
        findsOneWidget,
        reason: 'The sheet of the setting shows its last option on a small '
            'phone with a large text size, where a tap reaches it.',
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'The sheet of the setting scrolls on a small phone with a '
            'large text size.',
      );

      // Outside the sheet, as a user who chooses nothing taps.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(
        sheet,
        findsNothing,
        reason: 'A tap outside the sheet closes it.',
      );
      expect(
        appLocale.value,
        isNull,
        reason: 'A sheet that closes without a choice leaves the app '
            'following the device.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

/// Checks that [shown], a text that [place] shows in [placed], keeps its
/// words whole on the small phone in [language] and stays in [placed], in
/// full: it is laid out in the width that it has and drawn at the size of
/// its layout, and no line starts between two letters or digits, or at a
/// no-break space. The text is as large as the text size of the device, as
/// [placed] has it, asks for its style, or, where its longest word would not
/// fit the width that the text has at that size, as large as that word
/// allows: smaller, with that word on a line of its own.
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
  // The text is laid out in the width that it has and drawn at the size of
  // its layout: a FittedBox would lay it out in a width without a limit,
  // on one line, and draw it smaller.
  expect(
    paragraph.constraints.maxWidth.isFinite,
    isTrue,
    reason: '"$text" is laid out in the width that it has, in $language, '
        'and not in ${paragraph.constraints}, where it would not wrap.',
  );
  expect(
    tester.getRect(shown).width,
    closeTo(paragraph.size.width, 0.01),
    reason: '"$text" is drawn at the size of its layout, in $language, and '
        'nothing scales it.',
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
  // text, the text size as placed has it: a text that clamps the text size
  // for itself is smaller than that. And the size of the text, 14 for a
  // style that gives none, as in Flutter.
  final element = tester.element(shown);
  final largest = MediaQuery.textScalerOf(tester.element(placed))
      .scale(DefaultTextStyle.of(element).style.fontSize ?? 14);
  final size = paragraph.textScaler.scale(paragraph.text.style?.fontSize ?? 14);
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
