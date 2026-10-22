// A test that continuous integration runs in the apps with the paywall
// module: the paywall on a phone of 320 by 480 with insets and the text at
// three times its size, in each language of the app, in the light and in
// the dark theme of the device, with a service of purchases of the test
// (ScriptedPurchases).
//
// Nothing overflows. The close button is in sight without a scroll, and the
// paywall scrolls to its links, which end above the inset at the bottom.
// The letters of the cell of the app keep their size, since the cell is a
// picture, and a price grows only by half. A screen reader reads the name
// of the app with Premium as a header, each plan as one button of a group
// of which one is selected, and a failure as a live region. In an app that
// asks for less motion, the first frame of the paywall shows every part in
// its place.
//
// The phone is that small only while the paywall is the only screen that
// the app has built, so the test shows it in place of the stack, as the
// router does for the flow of its guard, and pushes a second paywall over
// it for the close button. The test starts the app once, since the start-up
// of an app may not run twice, and each expectation gives its reason.
import 'dart:async';

import 'package:flutter/material.dart';
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
                  widget is Semantics && (widget.properties.liveRegion ?? false),
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
            pageBuilder: (context, _, _) => const PaywallScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(
        [
          for (final opacity in tester.widgetList<Opacity>(
            _inPaywall(find.byType(Opacity)),
          ))
            opacity.opacity,
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
