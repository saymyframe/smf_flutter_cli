// A test that continuous integration runs in the apps with the
// update_required module: the screen "Update required" in each language of
// the app and in its light and dark theme, as the device asks for them.
//
// On a small phone with insets and the text at three times its size, about
// the largest that the settings of a device have, nothing overflows, the
// title, the text, the labels of the buttons and the failure keep their words
// whole, the title and the labels grow at most by half, each text is as
// large as its longest word allows where that word would not fit, the
// screen scrolls to "Not now" below the inset at the bottom, and the
// letters and the number of the cell of the app keep their size: the cell
// is a picture that does not grow. For a screen reader, the title is a
// header that names the screen, and the failure a live region, which it
// reads as it comes. The screen comes in when it is first shown, and an app
// that asks for less motion has it in place in its first frame.
//
// The test starts the app once, since the start-up of an app may not run
// twice, gives the reviews a service of its own on which no app of the
// device opens the store page, and shows a new screen of the module over the
// app for each case. The matrix writes the texts of the module in each
// language of the app into of_app.dart next to this file.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/features/update_required/update_required_screen.dart';

import 'of_app.dart';
import 'update_required.dart';
import 'whole_words.dart';

/// The inset at the top and at the bottom of the small phone of the test,
/// such as a notch and the bar of the home gesture.
const double _inset = 40;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Shows a new screen of the module over the app, on the navigator at the
  /// root of the app, with no transition of its own: the screen comes in by
  /// itself.
  void showNewScreen(WidgetTester tester) =>
      tester.state<NavigatorState>(find.byType(Navigator).first).push<void>(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const UpdateRequiredScreen(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );

  /// Closes the screen that [showNewScreen] showed, and starts the status of
  /// the module again, as the next launch does, so that the next screen
  /// shows nothing of a visit to the store.
  Future<void> closeNewScreen(WidgetTester tester) async {
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    await startStatusAgain(tester);
  }

  /// The texts in the cell of the app, the picture at the top of the
  /// screen, which a screen reader passes over, each by what it says, with
  /// its size. The picture has the arrow of the newer version.
  Map<String, Size> cellTexts(WidgetTester tester) => {
        for (final text in tester.widgetList<Text>(
          find.descendant(
            of: find.ancestor(
              of: shown(find.byIcon(Icons.arrow_upward_rounded)),
              matching: find.byType(ExcludeSemantics),
            ),
            matching: find.byType(Text),
          ),
        ))
          text.data!: tester.getSize(find.byWidget(text)),
      };

  /// How much of the screen shows: the opacity with which it comes in.
  double shownPart(WidgetTester tester) => tester
      .widget<Opacity>(
        find
            .descendant(
              of: shown(find.byType(TweenAnimationBuilder<double>)),
              matching: find.byType(Opacity),
            )
            .first,
      )
      .opacity;

  /// The failure of the screen as a screen reader gets it: the live region
  /// around the text that the store did not open.
  Finder liveRegion() => shown(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && (widget.properties.liveRegion ?? false),
          description: 'the live region of the failure',
        ),
      );

  /// How much [text] of the screen grows with the text size of the device,
  /// as it is laid out.
  double scaleOf(WidgetTester tester, Finder text) =>
      tester
          .renderObject<RenderParagraph>(
            find.descendant(
              of: text,
              matching: find.byType(RichText),
              matchRoot: true,
            ),
          )
          .textScaler
          .scale(10) /
      10;

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the screen fits a small phone with a large text size in each language '
    'and theme, keeps its words whole and the cell of the app at its size, '
    'tells a screen reader its title and its failure, and comes in at once '
    'with less motion',
    (tester) async {
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await startApp(tester);
      await useScriptedServices(tester);
      review.opens = false;

      // The cell of the app at the usual text size, and the screen coming
      // in when it is first shown.
      showNewScreen(tester);
      await tester.pump();
      expect(
        shownPart(tester),
        0,
        reason: 'In its first frame, a screen that comes in shows nothing '
            'yet.',
      );
      final frames = await tester.pumpAndSettle();
      expect(
        shownPart(tester),
        1,
        reason: 'Once the screen has settled, it is there.',
      );
      expect(
        frames,
        lessThan(20),
        reason: 'The screen comes in within two seconds.',
      );
      final cell = cellTexts(tester);
      expect(
        cell,
        hasLength(2),
        reason: 'The cell of the app has its symbol and its number.',
      );
      await closeNewScreen(tester);

      // For a screen reader.
      final semantics = tester.ensureSemantics();
      showNewScreen(tester);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(shown(find.text(texts['title']!))),
        isSemantics(label: texts['title'], isHeader: true, namesRoute: true),
        reason: 'The title of the screen is a header that names the screen '
            'for a screen reader.',
      );
      await tester.tap(updateButton());
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(liveRegion()),
        isSemantics(isLiveRegion: true),
        reason: 'A screen reader reads that the store did not open as it '
            'comes.',
      );
      semantics.dispose();
      await closeNewScreen(tester);

      // An app that asks for less motion.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      await tester.pumpAndSettle();
      showNewScreen(tester);
      await tester.pump();
      final atOnce = tester.getRect(shown(find.text(texts['title']!)));
      expect(
        shownPart(tester),
        1,
        reason: 'In an app that asks for less motion, the screen is there in '
            'its first frame.',
      );
      await tester.pump(const Duration(seconds: 2));
      expect(
        tester.getRect(shown(find.text(texts['title']!))),
        atOnce,
        reason: 'In an app that asks for less motion, the title is in its '
            'place in the first frame, and stays there.',
      );
      expect(
        tester.binding.transientCallbackCount,
        0,
        reason: 'In an app that asks for less motion, nothing on the screen '
            'moves.',
      );
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await closeNewScreen(tester);

      // A small phone with insets and the text at three times its size, in
      // each language of the app, whose texts differ in length, and in the
      // light and the dark theme of the app.
      for (final language in updateRequiredTexts.keys) {
        final shownTexts = updateRequiredTexts[language]!;
        for (final brightness in Brightness.values) {
          final where = 'in $language, ${brightness.name}';
          tester.platformDispatcher
            ..localesTestValue = [Locale(language)]
            ..platformBrightnessTestValue = brightness
            ..textScaleFactorTestValue = largeTextScale;
          const insets = FakeViewPadding(top: _inset, bottom: _inset);
          tester.view
            ..physicalSize = const Size(320, 480)
            ..devicePixelRatio = 1
            ..padding = insets
            ..viewPadding = insets;
          await tester.pumpAndSettle();
          showNewScreen(tester);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'The screen fits a small phone with a large text size, '
                '$where.',
          );
          final context = tester.element(gate);
          final textTheme = Theme.of(context).textTheme;
          final title = shown(find.text(shownTexts['title']!));
          expectWholeWords(
            tester,
            title,
            shownTexts['title']!,
            what: 'the title',
            language: where,
            largest: textTheme.headlineSmall!.fontSize! * 1.5,
          );
          expectWholeWords(
            tester,
            shown(find.text(shownTexts['body']!)),
            shownTexts['body']!,
            what: 'the text',
            language: where,
            largest: textTheme.bodyLarge!.fontSize! * largeTextScale,
          );
          final update = updateButton(language);
          await tester.ensureVisible(update);
          await tester.pumpAndSettle();
          final updateLabel = find.descendant(
            of: update,
            matching: find.text(shownTexts['update']!),
          );
          expectWholeWords(
            tester,
            updateLabel,
            shownTexts['update']!,
            what: 'the label of "Update"',
            language: where,
            largest: DefaultTextStyle.of(tester.element(updateLabel))
                    .style
                    .fontSize! *
                1.5,
          );
          for (final (what, text) in [
            ('the title', title),
            ('the label of "Update"', updateLabel),
          ]) {
            expect(
              scaleOf(tester, text),
              lessThanOrEqualTo(1.5),
              reason: 'With a large text size, $what grows at most by half, '
                  '$where.',
            );
          }
          expect(
            cellTexts(tester),
            cell,
            reason: 'With a large text size, the letters and the number in '
                'the cell of the app keep their size, $where: they are part '
                'of the picture.',
          );

          await tester.tap(update);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'The screen with the failure and "Not now" fits a small '
                'phone with a large text size, $where.',
          );
          final failure = storeFailed(language);
          expectWholeWords(
            tester,
            failure,
            shownTexts['storeFailed']!,
            what: 'the failure',
            language: where,
            largest: textTheme.bodyMedium!.fontSize! * largeTextScale,
          );
          final later = laterButton(language);
          await tester.ensureVisible(later);
          await tester.pumpAndSettle();
          final laterLabel = find.descendant(
            of: later,
            matching: find.text(shownTexts['later']!),
          );
          expectWholeWords(
            tester,
            laterLabel,
            shownTexts['later']!,
            what: 'the label of "Not now"',
            language: where,
            largest: DefaultTextStyle.of(tester.element(laterLabel))
                    .style
                    .fontSize! *
                1.5,
          );
          expect(
            scaleOf(tester, laterLabel),
            lessThanOrEqualTo(1.5),
            reason: 'With a large text size, the label of "Not now" grows at '
                'most by half, $where.',
          );
          expect(
            later.hitTestable(),
            findsOneWidget,
            reason: '"Not now" is on the screen of a small phone with a large '
                'text size once it scrolled there, where a tap reaches it, '
                '$where.',
          );
          final height =
              tester.view.physicalSize.height / tester.view.devicePixelRatio;
          expect(
            tester.getRect(later).bottom,
            lessThanOrEqualTo(height - _inset),
            reason: '"Not now" scrolls above the inset at the bottom of the '
                'screen, such as the bar of the home gesture, $where.',
          );
          await tester.drag(
            shown(find.byType(Scrollable)).first,
            const Offset(0, 2000),
          );
          await tester.pumpAndSettle();
          expect(
            tester.getRect(title).top,
            greaterThanOrEqualTo(_inset),
            reason: 'The top of the screen is below the inset at the top, '
                'such as a notch, $where.',
          );
          tester.view.reset();
          tester.platformDispatcher
            ..clearTextScaleFactorTestValue()
            ..clearLocalesTestValue()
            ..clearPlatformBrightnessTestValue();
          await tester.pumpAndSettle();
          await closeNewScreen(tester);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
