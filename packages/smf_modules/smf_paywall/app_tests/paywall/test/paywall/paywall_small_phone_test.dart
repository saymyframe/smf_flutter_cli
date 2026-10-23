// A test that continuous integration runs in the apps with the paywall
// module: the paywall on a phone of 320 by 480 with insets and the text at
// three times its size, in each language of the app, in the light and in
// the dark theme of the device, with a service of purchases of the test
// (ScriptedPurchases).
//
// Nothing overflows. The close button is in sight without a scroll and once
// the paywall scrolled to its links, which end above the inset at the
// bottom. The letters of the cell of the app keep their size, since the cell
// is a picture, a price grows only by half and is the largest text of its
// plan, and a price stays on one line with what follows it. A screen reader
// reads the name of the app with Premium as a header, each plan as one
// button of a group of which one is selected, with its name, its price, its
// intro offer and its badge, and a failure as a live region. In an app that
// asks for less motion, the first frames of the paywall show every part in
// its place, the plans too.
//
// The phone is that small only while the paywall is the only screen that
// the app has built, so the test shows it in place of the stack, as the
// router does for the flow of its guard, and pushes a second paywall over
// it for the close button. The test starts the app once, since the start-up
// of an app may not run twice, and each expectation gives its reason.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/purchases/app_purchases.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/paywall/paywall_card.dart';
import 'package:{{app_name}}/features/paywall/paywall_screen.dart';

import '../paywall_mocks.dart';
import 'of_app.dart';
import 'paywall.dart';

/// The insets of the small phone, in logical pixels.
const _top = 24.0;
const _bottom = 20.0;

/// Gives the app the small phone with the text at three times its size.
void _useSmallPhone(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(320, 480)
    ..devicePixelRatio = 1
    ..padding = const FakeViewPadding(top: _top, bottom: _bottom);
  tester.platformDispatcher.textScaleFactorTestValue = 3;
}

/// The texts of the paywall on top, the last one that the app built.
Finder _inPaywall(Finder matching) =>
    find.descendant(of: find.byType(PaywallScreen).last, matching: matching);

/// The largest size at which [paragraph] draws a text, with the text size of
/// the device.
double _largestSizeOf(RenderParagraph paragraph) {
  var largest = 0.0;
  void visit(InlineSpan span, double? inherited) {
    if (span is! TextSpan) return;
    final size = span.style?.fontSize ?? inherited;
    if (span.text != null && size != null) {
      final shown = paragraph.textScaler.scale(size);
      if (shown > largest) largest = shown;
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      visit(child, size);
    }
  }

  visit(paragraph.text, null);
  return largest;
}

/// Checks that [shown], a text of the paywall on top with the text [text],
/// keeps its words whole on the small phone: each word is on one line.
void _expectWholeWords(
  WidgetTester tester,
  Finder shown,
  String text, {
  required String when,
}) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(
        of: shown, matching: find.byType(RichText), matchRoot: true),
  );
  var start = 0;
  for (final word in text.split(' ')) {
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: start + word.length),
    );
    expect(
      {for (final box in boxes) box.top},
      hasLength(1),
      reason: '$when, "$text" breaks between its words and not inside '
          '"$word": where a word would not fit, the text is as large as the '
          'word allows.',
    );
    start += word.length + 1;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  paywallIsUnderTest = true;

  testWidgets(
    'the paywall fits a small phone with a large text size in each language '
    'and theme, scrolls to its links, keeps the letters of its cell, and '
    'tells a screen reader its header, its plans and a failure',
    (tester) async {
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      useTallPhone(tester);
      final languages = paywallTexts.keys.toList();
      await useLanguage(tester, languages.first);
      await startApp(tester);
      final semantics = tester.ensureSemantics();
      final service = ScriptedPurchases();
      await startPurchases(tester, service);
      // The paywall alone, as the router shows the flow of its guard.
      navigatorOf(tester).go(const PaywallPaywallLocation());
      await tester.pumpAndSettle();
      // A second paywall over it, which has the close button.
      final root = tester.state<NavigatorState>(find.byType(Navigator).first);
      unawaited(
        root.push<void>(
          MaterialPageRoute(builder: (context) => const PaywallScreen()),
        ),
      );
      await tester.pumpAndSettle();
      _useSmallPhone(tester);
      await tester.pumpAndSettle();

      for (final brightness in Brightness.values) {
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        for (final language in languages) {
          await useLanguage(tester, language);
          final when = 'On a small phone, in $language, ${brightness.name}';
          final scrollable = _inPaywall(find.byType(Scrollable)).first;
          await tester.drag(scrollable, const Offset(0, 2000));
          await tester.pumpAndSettle();
          expect(
            _inPaywall(find.byTooltip(texts['close']!)).hitTestable(),
            findsOneWidget,
            reason: '$when, the close button is in sight without a scroll.',
          );
          await tester.scrollUntilVisible(
            _inPaywall(link('restore')),
            200,
            scrollable: scrollable,
          );
          await tester.drag(scrollable, const Offset(0, -2000));
          await tester.pumpAndSettle();
          final restore = tester.getRect(_inPaywall(link('restore')));
          expect(
            restore.bottom,
            lessThanOrEqualTo(480 - _bottom),
            reason: '$when, the paywall scrolls to its links, which end '
                'above the inset at the bottom.',
          );
          expect(
            _inPaywall(find.byTooltip(texts['close']!)).hitTestable(),
            findsOneWidget,
            reason: '$when, the close button stays in sight once the paywall '
                'scrolled to its end.',
          );
          // The price and what follows it stay on one line.
          final afterOffer =
              '${texts['oneWeek']} ${texts['free']}, ${texts['then']} '
              r'$29.99'
              '\u00A0${texts['perYear']!.replaceAll(' ', '\u00A0')}';
          await tester.scrollUntilVisible(
            _inPaywall(find.text(afterOffer)),
            100,
            scrollable: scrollable,
          );
          for (final text in [
            afterOffer,
            texts['startTrial']!,
            texts['planYearly']!,
            texts['benefitNew']!,
          ]) {
            _expectWholeWords(
              tester,
              _inPaywall(find.text(text)).first,
              text,
              when: when,
            );
          }
          await tester.scrollUntilVisible(
            _inPaywall(planCards).first,
            100,
            scrollable: scrollable,
          );
          final card = _inPaywall(planCards).first;
          final nameText = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.descendant(
                of: card,
                matching: find.text(texts['planYearly']!),
              ),
              matching: find.byType(RichText),
              matchRoot: true,
            ),
          );
          expect(
            nameText.textScaler.scale(10),
            lessThanOrEqualTo(15),
            reason: '$when, the name of a plan grows only by half, as its '
                'price does, so that it is never larger than the price.',
          );
          final name = _largestSizeOf(nameText);
          final price = _largestSizeOf(
            tester.renderObject<RenderParagraph>(
              find
                  .descendant(
                    of: card,
                    matching: find.textContaining(
                      r'$29.99',
                      findRichText: true,
                    ),
                  )
                  .first,
            ),
          );
          expect(
            name,
            lessThanOrEqualTo(price),
            reason: '$when, the price of a plan is its largest text: the name '
                'is $name, the price $price.',
          );
          final scale = MediaQuery.textScalerOf(
            tester.element(
              _inPaywall(
                find.textContaining(r'$29.99', findRichText: true),
              ).first,
            ),
          ).scale(10);
          expect(
            scale,
            lessThanOrEqualTo(15),
            reason: '$when, a price grows only by half.',
          );
        }
      }

      // The letters of the cell keep their size.
      final cell = find.descendant(
        of: _inPaywall(find.byType(PremiumCard)),
        matching: find.byWidgetPredicate(
          (widget) => widget is Text && (widget.style?.fontSize ?? 0) > 30,
        ),
      );
      expect(cell, findsOneWidget);
      expect(
        MediaQuery.textScalerOf(tester.element(cell)),
        TextScaler.noScaling,
        reason: 'The letters of the cell of the app are a picture, and keep '
            'their size at a large text size.',
      );

      // What a screen reader reads.
      final scrollable = _inPaywall(find.byType(Scrollable)).first;
      await tester.drag(scrollable, const Offset(0, 2000));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(
          _inPaywall(
            find.bySemanticsLabel(RegExp(RegExp.escape(texts['premium']!))),
          ).first,
        ),
        isSemantics(isHeader: true),
        reason: 'A screen reader reads the name of the app with Premium as '
            'a header.',
      );
      await tester.scrollUntilVisible(
        _inPaywall(planCards).first,
        100,
        scrollable: scrollable,
      );
      expect(
        tester.getSemantics(_inPaywall(planCards).first),
        isSemantics(
          label: '${texts['planYearly']}, '
              r'$29.99'
              ' ${texts['perYear']}, ${texts['oneWeek']} ${texts['free']}, '
              '${texts['bestValue']}',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
        ),
        reason: 'A screen reader reads a plan as one button of a group of '
            'which one is selected.',
      );
      service.failure = const PurchasesFailure(PurchasesFailureReason.network);
      await tester.scrollUntilVisible(
        _inPaywall(purchaseButton),
        100,
        scrollable: scrollable,
      );
      await tester.tap(_inPaywall(purchaseButton));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(
          _inPaywall(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  (widget.properties.liveRegion ?? false),
              description: 'the live region of the message',
            ),
          ),
        ),
        isSemantics(isLiveRegion: true),
        reason: 'A screen reader announces a failure when it appears.',
      );
      service.failure = null;
      semantics.dispose();

      // Less motion: the first frame has every part in its place.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      unawaited(
        root.push<void>(
          PageRouteBuilder<void>(
            transitionDuration: Duration.zero,
            pageBuilder: (context, _, _) => const PaywallScreen(),
          ),
        ),
      );
      // The first frames, in which the plans come in.
      for (var frame = 0; frame < 3; frame++) {
        await tester.pump();
      }
      expect(_inPaywall(planCards), findsNWidgets(3));
      expect(
        [
          for (final opacity in tester.widgetList<Opacity>(
            _inPaywall(find.byType(Opacity)),
          ))
            opacity.opacity,
          for (final fade in tester.widgetList<FadeTransition>(
            _inPaywall(find.byType(FadeTransition)),
          ))
            fade.opacity.value,
        ].where((opacity) => opacity < 1),
        isEmpty,
        reason: 'In an app that asks for less motion, the first frame of the '
            'paywall shows every part in its place.',
      );
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await tester.pumpAndSettle();
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
