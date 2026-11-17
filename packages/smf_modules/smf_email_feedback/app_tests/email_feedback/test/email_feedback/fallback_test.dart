// A test that continuous integration runs in the apps with the
// email_feedback module: what the user sees where no mail app opens the
// mail, on the real url_launcher, whose platform side is the device of
// email_feedback_mocks.dart, scripted to have no mail app. Whether iOS
// answers that nothing opened or Android throws that no app takes the link,
// the open completes with false, nothing reaches the handlers of the errors,
// and a sheet on the navigator at the root of the app shows a header, the
// text and the address, in each language of the app and in the colours of a
// light and of a dark theme. Its button copies exactly the address and says
// so to a screen reader, and back closes it. A context that left the screen
// during the open shows nothing. On a small phone with a large text size,
// the sheet scrolls to its button above the inset at the bottom, shows the
// address in full on one line, keeps the words of its title and of its text
// whole, and the label of the button grows at most by half. In an app that
// asks for less motion, the first frame has the sheet in place.
//
// It uses the service of the module and starts the app once, since the
// start-up of an app may not run twice. Each expectation gives its reason.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/env/app_env.dart';
import 'package:{{app_name}}/core/feedback/email_feedback_service.dart';

import '../email_feedback_mocks.dart';
import 'email_feedback.dart';
import 'of_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'where no mail app opens the mail, a sheet on the root of the app shows '
    'the address in the language and the theme of the app, copies it, '
    'closes with back, and fits a small phone with a large text size',
    (tester) async {
      await startApp(tester);
      final device = mockEmailFeedback();
      final address = AppEnv.emailFeedbackAddress!.trim();
      final service = createEmailFeedbackService();

      /// Opens a mail from a page of the test with [theme] that no mail app
      /// opens, as [answer] says, and returns what the open completed with.
      Future<bool?> openWithout(MailAnswer answer, {ThemeData? theme}) async {
        final context = await contextBelowRoot(tester, theme: theme);
        device.next = answer;
        ({bool? answer, Object? error})? result;
        final errors = await errorsWhile(() async {
          result = await answerWithin(tester, service.open(context));
          await tester.pumpAndSettle();
        });
        expect(
          result!.error,
          isNull,
          reason: 'A mail that no app opens is no error: the service throws '
              'nothing.',
        );
        expect(
          [...errors.flutter, ...errors.platform],
          isEmpty,
          reason: 'A mail that no app opens is no error: nothing reaches the '
              'handlers of the errors.',
        );
        return result!.answer;
      }

      /// Closes the sheet and the page of the test below it.
      Future<void> closeSheetAndPage() async {
        rootNavigatorOf(tester).pop();
        await tester.pumpAndSettle();
        await closeTestPage(tester);
      }

      final themes = {
        'light': ThemeData(),
        'dark': ThemeData(brightness: Brightness.dark),
      };
      for (final code in emailFeedbackTexts.keys) {
        await useLanguage(tester, code);
        final texts = textsIn(code);
        for (final (answer, platform) in [
          (MailAnswer.nothingOpens, 'iOS'),
          (MailAnswer.noActivity, 'Android'),
        ]) {
          for (final MapEntry(key: name, value: theme) in themes.entries) {
            final where = 'in $code and the $name theme, as $platform answers';
            final opened = await openWithout(answer, theme: theme);

            expect(
              opened,
              isFalse,
              reason: 'The open completes with false where no mail app opens '
                  'the mail, $where.',
            );
            expect(sheet, findsOneWidget, reason: 'The sheet shows, $where.');
            expect(
              find.descendant(
                of: find.byType(Navigator).first,
                matching: sheet,
              ),
              findsOneWidget,
              reason: 'The sheet is on the navigator at the root of the app, '
                  'so it shows over the main navigation too, $where.',
            );
            expect(
              [
                inSheet(texts['noMailTitle']!),
                inSheet(texts['noMailText']!),
                inSheet(address),
                inSheet(texts['copy']!),
              ].map((finder) => finder.evaluate().length),
              [1, 1, 1, 1],
              reason: 'The sheet shows its title, its text, the address of '
                  '.env and its button, $where.',
            );
            expect(
              find.ancestor(
                of: inSheet(texts['noMailTitle']!),
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Semantics &&
                      (widget.properties.header ?? false),
                ),
              ),
              findsOneWidget,
              reason: 'A screen reader reads the title of the sheet as a '
                  'header, $where.',
            );
            expect(
              find.descendant(
                of: sheet,
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is DecoratedBox &&
                      widget.decoration is BoxDecoration &&
                      (widget.decoration as BoxDecoration).color ==
                          theme.colorScheme.surfaceContainer,
                ),
              ),
              findsOneWidget,
              reason: 'The sheet takes its colours from the theme of the '
                  'screen that opened it, $where.',
            );
            await closeSheetAndPage();
          }
        }
      }

      // The button copies exactly the address, and says so.
      final first = emailFeedbackTexts.keys.first;
      await useLanguage(tester, first);
      final copied = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') copied.add(call.arguments);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await openWithout(MailAnswer.nothingOpens);
      await tester.tap(inSheet(textsIn(first)['copy']!));
      await tester.pumpAndSettle();
      expect(
        copied,
        [
          {'text': address},
        ],
        reason: 'The button puts exactly the address on the clipboard.',
      );
      expect(
        find.ancestor(
          of: inSheet(textsIn(first)['copied']!),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && (widget.properties.liveRegion ?? false),
          ),
        ),
        findsOneWidget,
        reason: 'Once the address is copied, the button says so in a live '
            'region, which a screen reader reads as it comes.',
      );

      // Back closes the sheet.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(sheet, findsNothing, reason: 'Back closes the sheet.');
      await closeTestPage(tester);

      // A context that left the screen while the open waited shows nothing.
      final context = await contextBelowRoot(tester);
      device
        ..hold()
        ..next = MailAnswer.nothingOpens;
      ({bool? answer, Object? error})? left;
      final errors = await errorsWhile(() async {
        final open = service.open(context);
        await tester.pump();
        await closeTestPage(tester);
        device.release();
        left = await answerWithin(tester, open);
        await tester.pumpAndSettle();
      });
      expect(
        (
          left!.answer,
          left!.error,
          sheet.evaluate().length,
          [...errors.flutter, ...errors.platform].length,
        ),
        (false, null, 0, 0),
        reason: 'When the screen that opened the mail left before the mail '
            'app answered, the open completes with false, shows no sheet and '
            'throws nothing.',
      );

      // A small phone with insets and the text at three times its size.
      tester.view
        ..physicalSize = const Size(320, 480)
        ..devicePixelRatio = 1
        ..padding = const FakeViewPadding(top: 40, bottom: 40);
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      for (final code in emailFeedbackTexts.keys) {
        await useLanguage(tester, code);
        final texts = textsIn(code);
        await openWithout(MailAnswer.nothingOpens);
        expect(
          tester.takeException(),
          isNull,
          reason: 'The sheet fits a small phone with a large text size, in '
              '$code.',
        );
        for (final name in ['noMailTitle', 'noMailText']) {
          expectWholeWords(
            paragraphOf(tester, inSheet(texts[name]!)),
            texts[name]!,
            language: code,
          );
        }
        final shown = paragraphOf(tester, inSheet(address));
        final lines = {
          for (final box in shown.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: address.length),
          ))
            box.top.round(),
        };
        expect(
          (shown.didExceedMaxLines, lines.length),
          (false, 1),
          reason: 'The sheet shows the address in full on one line on a small '
              'phone with a large text size, in $code.',
        );
        final label = paragraphOf(tester, inSheet(texts['copy']!));
        expect(
          label.textScaler.scale(10),
          lessThanOrEqualTo(15),
          reason: 'The label of the button grows at most by half, in $code.',
        );
        final button = find.descendant(
          of: sheet,
          matching: find.byType(FilledButton),
        );
        await tester.scrollUntilVisible(
          button,
          100,
          scrollable: find.descendant(
            of: sheet,
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getRect(button).bottom,
          lessThanOrEqualTo(480 - 40),
          reason: 'The sheet scrolls to its button above the inset at the '
              'bottom of the phone, in $code.',
        );
        await closeSheetAndPage();
      }
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.pumpAndSettle();

      // An app that asks for less motion has the sheet in place in its first
      // frame.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();
      final still = await contextBelowRoot(tester);
      device.next = MailAnswer.nothingOpens;
      final open = service.open(still);
      var done = false;
      open.whenComplete(() => done = true).ignore();
      for (var turn = 0; turn < 20 && !done; turn++) {
        await tester.pump(Duration.zero);
      }
      await tester.pump();
      final firstFrame = tester.getRect(sheet);
      await tester.pumpAndSettle();
      expect(
        firstFrame,
        tester.getRect(sheet),
        reason: 'In an app that asks for less motion, the first frame of the '
            'sheet has it in place.',
      );
      await closeSheetAndPage();
    },
    timeout: timeout,
  );
}
