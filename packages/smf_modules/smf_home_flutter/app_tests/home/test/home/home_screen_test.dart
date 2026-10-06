// A test that continuous integration runs in the apps with the home module:
// the screen of the module welcomes the developer of the app. It names the
// app, a header for a screen reader, next to the mark of Say My Frame,
// greets by the time of the day, and has a card with the app as a cell,
// which keeps the colours of Say My Frame in a light and in a dark theme.
// Below the card it lists three steps, each with its path or address, and
// says what generated the app. Its texts are in each language of the app,
// as the device asks for it. A tap on a step copies its path and says so
// in a snack bar.
//
// The matrix writes texts.dart next to this file, the texts of the module
// in each language of the app: the languages of the localization role of
// the app, whichever module provides it, or English alone in an app without
// the role. The test starts the app once, since the start-up of an app may
// not run twice, and each expectation gives its reason.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app.dart';
import 'texts.dart';

/// The deep green of Say My Frame, the colour of the card of the screen.
const _brandGreen = Color(0xFF0F3326);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The card that tells that the app is ready: the box in the colour of
  /// Say My Frame around its title.
  Finder card() => find.ancestor(
        of: text('readyTitle'),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              (widget.decoration as BoxDecoration).color == _brandGreen,
        ),
      );

  /// The card of the step whose path or address is [code].
  Finder stepOf(String code) =>
      find.ancestor(of: shown(find.text(code)), matching: find.byType(Card));

  /// What the step whose path or address is [code] shows of [matching].
  Finder inStep(String code, Finder matching) =>
      find.descendant(of: stepOf(code), matching: matching);

  /// Checks that a screen reader announces [title] as a header, with
  /// [before] in front of it if the header has more than the title.
  void expectHeader(WidgetTester tester, String title, {String? before}) {
    final label = before == null ? title : '$before\n$title';
    expect(
      tester.getSemantics(shown(find.text(title))),
      isSemantics(label: label, isHeader: true),
      reason: 'A screen reader announces "$title" as a header.',
    );
  }

  /// The greetings that the screen shows, by their names in the module.
  List<String> greetingsShown() => [
        for (final greeting in greetings)
          if (text(greeting.name).evaluate().isNotEmpty) greeting.name,
      ];

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the screen of the module names the app, greets by the time of the day '
    'and lists the next steps with their paths, in each language of the '
    'app, and a tap on a step copies its path and says so',
    (tester) async {
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      // A phone that is tall enough for the whole screen, whose list
      // builds only what is near the part that the user sees.
      tester.view
        ..physicalSize = const Size(400, 2400)
        ..devicePixelRatio = 1;
      final copied = recordCopies(tester);
      final languages = homeTexts.keys.toList();
      await useLanguage(tester, languages.first);
      await startAtHome(tester);

      // The image of the mark, as the app bundles it.
      final assets = await tester.runAsync(
        () => AssetManifest.loadFromAssetBundle(rootBundle),
      );
      expect(
        {
          for (final variant
              in assets!.getAssetVariants(markAsset) ?? <AssetMetadata>[])
            variant.key: variant.targetDevicePixelRatio,
        },
        {
          markAsset: null,
          'lib/features/home/assets/2.0x/smf_mark.png': 2.0,
          'lib/features/home/assets/3.0x/smf_mark.png': 3.0,
        },
        reason: 'The app bundles the image of the mark of Say My Frame, '
            'with a file for each of the screens with two and with three '
            'pixels for a logical pixel.',
      );

      for (final language in languages) {
        await useLanguage(tester, language);
        expect(
          Localizations.localeOf(tester.element(home)).languageCode,
          language,
          reason: 'The screen follows the device into $language, a language '
              'of the app.',
        );

        // The name of the app, its greeting and the mark.
        expect(
          shown(find.text(appName)),
          findsOneWidget,
          reason: 'The screen names the app, in $language too.',
        );
        expect(
          greetingsShown(),
          hasLength(1),
          reason: 'The screen greets once, in $language.',
        );
        // The greeting and the name are one header.
        expectHeader(
          tester,
          appName,
          before: texts[greetingsShown().single],
        );
        expect(
          shown(find.bySemanticsLabel('Say My Frame')),
          findsOneWidget,
          reason: 'A screen reader names the mark of Say My Frame once: '
              'the small mark in the last line is left out.',
        );
        expect(
          [
            for (final image in tester.widgetList<Image>(
              shown(find.byType(Image)),
            ))
              (image.image as AssetImage).assetName,
          ],
          [markAsset, markAsset],
          reason: 'The screen shows the mark of Say My Frame next to the '
              'name of the app and in its last line, from the image of the '
              'module among the assets of the app.',
        );

        // The card, with the app as a cell.
        expect(
          card(),
          findsOneWidget,
          reason: 'The card that tells that the app is ready is in the '
              'deep green of Say My Frame, with its title in $language.',
        );
        for (final shownInCard in [
          find.text(texts['readyText']!),
          find.text(appSymbol),
          find.text(appNumber),
        ]) {
          expect(
            find.descendant(of: card(), matching: shownInCard),
            findsOneWidget,
            reason: 'The card has its text in $language, and the cell of '
                'the app with its symbol, $appSymbol, and its number, '
                '$appNumber: ${shownInCard.describeMatch(Plurality.one)}.',
          );
        }

        // The steps, in their order.
        expect(
          text('nextTitle'),
          findsOneWidget,
          reason: 'The screen has the title of its steps in $language.',
        );
        expectHeader(tester, texts['nextTitle']!);
        var above = tester.getRect(text('nextTitle')).bottom;
        for (final step in steps) {
          expect(
            stepOf(step.code),
            findsOneWidget,
            reason: 'The screen has a step with ${step.code}.',
          );
          for (final name in [step.title, step.text]) {
            expect(
              inStep(step.code, find.text(texts[name]!)),
              findsOneWidget,
              reason: 'The step with ${step.code} has its text $name in '
                  '$language.',
            );
          }
          final rect = tester.getRect(stepOf(step.code));
          expect(
            rect.top,
            greaterThanOrEqualTo(above),
            reason: 'The step with ${step.code} is below what comes before '
                'it.',
          );
          above = rect.bottom;
          final button = tester.getSemantics(
            inStep(step.code, find.byType(InkWell)),
          );
          expect(
            button,
            isSemantics(isButton: true, hasTapAction: true),
            reason: 'A screen reader announces the step with ${step.code} '
                'as a button.',
          );
          expect(
            button.label,
            stringContainsInOrder([
              texts[step.title]!,
              texts[step.text]!,
              step.code,
            ]),
            reason: 'A screen reader announces the step with ${step.code} '
                'as one button, with its title, its text and its path.',
          );
        }
        expect(
          text('footer'),
          findsOneWidget,
          reason: 'The last line of the screen is in $language.',
        );
        expect(
          tester.getRect(text('footer')).top,
          greaterThanOrEqualTo(above),
          reason: 'The last line of the screen is below its steps.',
        );

        // A tap on a step copies its path and says so.
        for (final step in steps) {
          copied.clear();
          await tester.tap(stepOf(step.code));
          await tester.pumpAndSettle();
          expect(
            copied,
            [step.code],
            reason: 'A tap on the step with ${step.code} copies it.',
          );
          expect(
            find.descendant(
              of: find.byType(SnackBar),
              matching: find.text('${texts['copied']}: ${step.code}'),
            ),
            findsOneWidget,
            reason: 'Once a tap has copied ${step.code}, a snack bar says '
                'so in $language, in place of the one of the tap before.',
          );
        }
        // The snack bar goes away by itself.
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(
          find.byType(SnackBar),
          findsNothing,
          reason: 'The snack bar of a copy goes away after a moment.',
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'The screen shows its content in $language without an '
              'error.',
        );
      }
      await useLanguage(tester, languages.first);

      // The greeting at each time of the day, on a screen that is told the
      // time: the time of the machine tells only one of them.
      for (final greeting in greetings) {
        final (first, last) = greeting.hours;
        for (final hour in {first, last}) {
          showNewHome(tester, now: () => DateTime(2026, 1, 1, hour, 30));
          await tester.pumpAndSettle();
          for (final language in languages) {
            await useLanguage(tester, language);
            expect(
              greetingsShown(),
              [greeting.name],
              reason: 'At $hour:30 the screen greets with '
                  '"${texts[greeting.name]}", in $language.',
            );
          }
          await useLanguage(tester, languages.first);
          await closeNewHome(tester);
        }
      }

      // A light and a dark theme, on a screen that is given each: an app
      // has a dark theme only if a module of it brings one.
      for (final brightness in Brightness.values) {
        showNewHome(tester, brightness: brightness);
        await tester.pumpAndSettle();
        expect(
          Theme.of(tester.element(home)).brightness,
          brightness,
          reason: 'The screen is shown in a ${brightness.name} theme.',
        );
        expect(
          card(),
          findsOneWidget,
          reason: 'The card keeps the deep green of Say My Frame in a '
              '${brightness.name} theme.',
        );
        expect(
          tester
              .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
                shown(find.byType(AnnotatedRegion<SystemUiOverlayStyle>)),
              )
              .value,
          brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          reason: 'The screen has no app bar, so it asks itself for icons '
              'of the status bar that show on a ${brightness.name} theme.',
        );
        await closeNewHome(tester);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
