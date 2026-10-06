// A test that continuous integration runs in the apps with the home module:
// the screen of the module fits a small phone with insets and the text at
// three times its size, about the largest that the settings of a device
// have, in each language of the app. The list of the screen scrolls to
// each step and to the last line, which ends above the inset at the bottom
// of the screen. The cell of the app in the card is a picture, so its
// symbol and its number keep their size, and the card draws next to it
// only the cells that have room there. The path of a step is no larger
// than one and a half times its size, takes as many lines as it needs and
// is not cut, and a tap on the step still copies it and says so in a snack
// bar that fits the phone.
//
// The phone is that small only while a screen of the module covers it:
// whether what is around the screen of its route, such as the main
// navigation of the app, or another screen of the app fits such a phone is
// a matter for the tests of its own module. The test starts the app once,
// since the start-up of an app may not run twice, and each expectation
// gives its reason.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app.dart';
import 'texts.dart';

/// The size of the small phone of the test, and the inset at its top and
/// at its bottom, such as a notch and the bar of the home gesture.
const Size _phone = Size(320, 480);
const double _inset = 40;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The list of the screen.
  Finder list() => shown(find.byType(Scrollable)).first;

  /// Scrolls the list of the screen as far as [where] says, its start or
  /// its end.
  Future<void> scrollTo(
    WidgetTester tester,
    double Function(ScrollPosition position) where,
  ) async {
    final position = tester.state<ScrollableState>(list()).position;
    position.jumpTo(where(position));
    await tester.pumpAndSettle();
  }

  /// Scrolls the list of the screen until it shows [part].
  Future<void> scrollToShow(WidgetTester tester, Finder part) async {
    await tester.scrollUntilVisible(part, 100, scrollable: list());
    await tester.pumpAndSettle();
  }

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the screen of the module fits a small phone with a large text size '
    'and insets, in each language of the app',
    (tester) async {
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final copied = recordCopies(tester);
      final languages = homeTexts.keys.toList();
      await useLanguage(tester, languages.first);
      await startAtHome(tester);
      // A screen of the module over the whole phone: what is around the
      // screen of its route, such as the main navigation of the app, is
      // for the tests of its own module.
      showNewHome(tester);
      await tester.pumpAndSettle();

      const insets = FakeViewPadding(top: _inset, bottom: _inset);
      tester.view
        ..physicalSize = _phone
        ..devicePixelRatio = 1
        ..padding = insets
        ..viewPadding = insets;
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      await tester.pumpAndSettle();

      for (final language in languages) {
        await useLanguage(tester, language);
        await scrollTo(tester, (position) => position.minScrollExtent);
        expect(
          tester.takeException(),
          isNull,
          reason: 'The top of the screen fits a small phone with a large '
              'text size, in $language.',
        );
        expect(
          MediaQuery.textScalerOf(tester.element(home)).scale(10),
          30,
          reason: 'The screen is shown with the text at three times its '
              'size.',
        );
        expect(
          tester.getRect(list()).top,
          greaterThanOrEqualTo(_inset),
          reason: 'The screen starts below the inset at the top of the '
              'phone, such as a notch.',
        );

        // The cell of the app is a picture: its symbol and its number keep
        // their size and stay inside it.
        await scrollToShow(tester, shown(find.text(appSymbol)));
        final cell = tester.getRect(
          find
              .ancestor(
                of: shown(find.text(appSymbol)),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(
          cell.size,
          const Size(88, 88),
          reason: 'The cell of the app has its size, whatever the size of '
              'the text.',
        );
        for (final inCell in [appSymbol, appNumber]) {
          final shownInCell = shown(find.text(inCell));
          expect(
            MediaQuery.textScalerOf(tester.element(shownInCell)),
            TextScaler.noScaling,
            reason: 'The cell of the app is a picture, so "$inCell" in it '
                'keeps its size when the text of the device is larger.',
          );
          final rect = tester.getRect(shownInCell);
          expect(
            cell.contains(rect.topLeft) && cell.contains(rect.bottomRight),
            isTrue,
            reason: '"$inCell" is inside the cell of the app: $rect in '
                '$cell.',
          );
        }
        expect(
          tester.getSize(shown(find.text(appSymbol))).height,
          lessThan(2 * 42),
          reason: 'The symbol of the app is on one line of its cell.',
        );

        expect(
          cells(
            find.ancestor(
              of: text('readyTitle'),
              matching: find.byType(ClipRRect),
            ),
          ),
          paintsExactlyCountTimes(#drawRect, 9),
          reason: 'On a narrow phone, the card draws only the two columns '
              'of cells that have room next to the cell of the app, and '
              'lights up the three of the five cells that are in them.',
        );

        // Each step, with its path, which a tap still copies.
        for (final step in steps) {
          final path = shown(find.text(step.code));
          await scrollToShow(tester, path);
          expect(
            tester.takeException(),
            isNull,
            reason: 'The step with ${step.code} fits a small phone with a '
                'large text size, in $language.',
          );
          expect(
            MediaQuery.textScalerOf(tester.element(path)).scale(10),
            15,
            reason: 'The path of a step is at most one and a half times '
                'its size, so that it breaks at its slashes: ${step.code}.',
          );
          final shownPath = tester.widget<Text>(path);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: path, matching: find.byType(RichText)),
          );
          expect(
            (shownPath.maxLines, shownPath.overflow, paragraph.softWrap),
            (null, null, true),
            reason: 'The path of a step takes as many lines as it needs, '
                'and none of it is cut: ${step.code}.',
          );
          final chip = tester.getRect(
            find.ancestor(of: path, matching: find.byType(Container)).first,
          );
          final rect = tester.getRect(path);
          expect(
            chip.contains(rect.topLeft) && chip.contains(rect.bottomRight),
            isTrue,
            reason: 'The path of the step is inside its box: $rect in '
                '$chip.',
          );
          // The longest path does not fit one line of such a phone.
          if (step == steps.first) {
            expect(
              rect.height,
              greaterThan(2 * 12.5 * 1.5),
              reason: 'A path that is too long for a line takes more lines: '
                  '${step.code}.',
            );
          }
          expect(
            path.hitTestable(),
            findsOneWidget,
            reason: 'The path of the step is on the screen, where a tap '
                'reaches it: ${step.code}.',
          );
          copied.clear();
          await tester.tap(path);
          await tester.pumpAndSettle();
          expect(
            copied,
            [step.code],
            reason: 'A tap on the step copies ${step.code} on a small '
                'phone too.',
          );
          expect(
            tester.takeException(),
            isNull,
            reason: 'The snack bar of a copy fits a small phone with a '
                'large text size, in $language.',
          );
          final said = find.descendant(
            of: find.byType(SnackBar),
            matching: find.text('${texts['copied']}: ${step.code}'),
          );
          expect(
            MediaQuery.textScalerOf(tester.element(said)).scale(10),
            15,
            reason: 'The snack bar of a copy names the path in a text that '
                'is at most one and a half times its size, as the step '
                'does: ${step.code}.',
          );
          expect(
            tester.getRect(find.byType(SnackBar)).top,
            greaterThanOrEqualTo(_inset),
            reason: 'The snack bar of a copy is on the screen of a small '
                'phone, below the inset at its top: ${step.code}.',
          );
          // The snack bar goes away by itself, and covers no step then.
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
        }

        // The end of the list.
        await scrollTo(tester, (position) => position.maxScrollExtent);
        expect(
          tester.takeException(),
          isNull,
          reason: 'The end of the screen fits a small phone with a large '
              'text size, in $language.',
        );
        expect(
          text('footer').hitTestable(),
          findsOneWidget,
          reason: 'The list of the screen scrolls to its last line.',
        );
        expect(
          tester.getRect(text('footer')).bottom,
          lessThanOrEqualTo(_phone.height - _inset),
          reason: 'The last line of the screen ends above the inset at '
              'the bottom of the phone, such as the bar of the home '
              'gesture.',
        );
      }

      // The phone and the language of the test again, before the app
      // shows what is below the screen.
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await useLanguage(tester, languages.first);
      await closeNewHome(tester);
      expect(
        tester.takeException(),
        isNull,
        reason: 'The screen is back on the phone of the test without an '
            'error.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
