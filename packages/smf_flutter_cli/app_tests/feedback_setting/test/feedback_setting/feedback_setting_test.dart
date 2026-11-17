// A test that continuous integration runs in the apps with the feedback
// role and the settings screen role, whichever modules provide them: the
// entry "Write to us", which the template of the feedback role gives the
// settings screen, over a service of the test that scripts what a provider
// answers. The screen shows the entry once, with its title in each
// language of the app, as one button for a screen reader. A tap opens the
// way of the service once, with a context below the root of the app, and a
// second tap while the first is on its way opens nothing more. While the
// service has not what it needs, a new settings screen leaves the entry
// out. On a small phone with a large text size, the title stays in the row
// of the entry, in full, and keeps its words whole.
//
// It knows only the two roles, and starts the app once, since the start-up
// of an app may not run twice. The matrix writes setting.dart next to it,
// from the entries of the settings screen role and the languages of the
// localization role of the app: the type of the widget of the entry and its
// title in each language. It opens the settings screen as the tests of the
// settings screen role do, and takes the service of the test from the files
// of the test of the feedback role, both of which run in every app that this
// one runs in. Each expectation gives its reason.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/feedback/app_feedback.dart';

import '../feedback_role/feedback_role.dart'
    show ScriptedFeedback, rootNavigatorOf;
import '../settings_screen_role/open_settings.dart';
import 'setting.dart';

/// A letter, a mark that belongs to one, a digit, or a no-break space, which
/// keeps the words around it together: a line that starts between two of
/// them starts inside a word.
final RegExp _joined = RegExp(
  r'[\p{L}\p{M}\p{N}\u00A0\u2007\u202F]',
  unicode: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the entry "Write to us" shows its title in the language of the app as '
    'one button, opens the way of the provider once with a context below the '
    'root, hides while the provider has not what it needs, and keeps the '
    'words of its title whole on a small phone',
    (tester) async {
      await openSettings(tester);
      final semantics = tester.ensureSemantics();
      // A service of the test, which the app takes as it takes the service
      // of the provider, and the service of the provider again at the end.
      final service = ScriptedFeedback();
      appFeedback.use(service);
      addTearDown(() => appFeedback.use(createFeedbackService()));
      await usePlatform(tester, null);

      final entry = find.byType(feedbackSetting);
      // The language that the app is in where the entry is.
      String language() =>
          Localizations.localeOf(tester.element(entry)).languageCode;
      // The title of the entry in the language [code].
      Finder titleIn(String code) => find.descendant(
            of: entry,
            matching: find.text(feedbackTitles[code]!),
          );
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

      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      expect(
        entry,
        findsOneWidget,
        reason: 'While the provider has what it needs, the settings screen '
            'shows the entry once.',
      );
      for (final code in feedbackTitles.keys) {
        await useLanguage(code);
        expect(
          titleIn(code),
          findsOneWidget,
          reason: 'The entry shows its title in the language of the app, '
              '$code.',
        );
        expect(
          tester.getSemantics(titleIn(code)),
          isSemantics(
            label: feedbackTitles[code],
            isButton: true,
            hasTapAction: true,
          ),
          reason: 'A screen reader reads the entry as one button with its '
              'title, in $code.',
        );
      }
      semantics.dispose();
      final first = feedbackTitles.keys.first;
      await useLanguage(first);

      // A tap opens the way of the service once; a second tap while the
      // first is on its way opens nothing more.
      service.hold();
      await tester.tap(entry);
      await tester.pump();
      await tester.tap(entry);
      await tester.pump();
      service.release(true);
      await tester.pumpAndSettle();
      expect(
        service.contexts,
        hasLength(1),
        reason: 'A tap on the entry opens the way of the provider once, and '
            'a second tap while the first is on its way opens nothing more.',
      );
      final reached = service.reached.single;
      expect(
        (reached.navigator, reached.locale.languageCode),
        (rootNavigatorOf(tester), first),
        reason: 'The entry gives the provider a context below the root of the '
            'app, which reaches the navigator at its root and its language.',
      );

      // While the provider has not what it needs, a new settings screen
      // leaves the entry out.
      service.canWrite = false;
      await usePlatform(tester, null);
      expect(
        entry,
        findsNothing,
        reason: 'While the provider has not what it needs, such as an '
            'address, the settings screen leaves the entry out.',
      );
      service.canWrite = true;
      await usePlatform(tester, null);
      expect(
        entry,
        findsOneWidget,
        reason: 'Once the provider has what it needs, the settings screen '
            'shows the entry again.',
      );

      // The list of the screen that holds the entry, the nearest scrollable
      // above it on the tall surface, where the screen builds every row.
      final listOfEntry = find
          .ancestor(of: entry, matching: find.byType(Scrollable))
          .evaluate()
          .first;
      final list = find.byElementPredicate(
        (element) => element == listOfEntry,
        description: 'the list of the entry "Write to us"',
      );

      // A small phone with insets and the text at three times its size,
      // about the largest that the settings of a device have.
      tester.view
        ..physicalSize = const Size(320, 480)
        ..padding = const FakeViewPadding(top: 40, bottom: 40);
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      for (final code in feedbackTitles.keys) {
        await useLanguage(code);
        await tester.scrollUntilVisible(entry, 100, scrollable: list);
        await tester.pumpAndSettle();
        final title = titleIn(code);
        final text = feedbackTitles[code]!;
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
          reason: 'The entry shows its title "$text" in full, on as many '
              'lines as it needs, on a small phone with a large text size, '
              'in $code.',
        );
        double? lineOf(int index) => paragraph
            .getBoxesForSelection(
              TextSelection(baseOffset: index, extentOffset: index + 1),
            )
            .firstOrNull
            ?.top;
        for (var index = 1; index < text.length; index++) {
          if (!_joined.hasMatch(text[index - 1]) ||
              !_joined.hasMatch(text[index])) {
            continue;
          }
          final (before, after) = (lineOf(index - 1), lineOf(index));
          if (before == null || after == null) continue;
          expect(
            after,
            closeTo(before, 0.5),
            reason: 'On the small phone, the title "$text" breaks between its '
                'words and not inside one, in $code.',
          );
        }
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
