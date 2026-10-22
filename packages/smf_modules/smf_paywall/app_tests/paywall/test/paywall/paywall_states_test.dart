// A test that continuous integration runs in the apps with the paywall
// module: what the paywall shows, with a service of purchases of the test
// that scripts what a provider answers (ScriptedPurchases).
//
// While the plans load, the paywall shows grey cards that do not move, and
// the screen settles. Then it shows a card for each plan, in the order of
// the provider, with the name of its period, the price that the store gives
// with what follows it, and what its intro offer gives; the yearly plan is
// selected and is the best value. The button and the lines below it follow
// the selected plan: Start free trial with what the plan costs after its
// trial, Subscribe, or Buy for a plan paid once, with the terms of the store.
// The texts are in each language of the app.
//
// A failed purchase shows the text of its reason, with the hint of the
// provider in debug mode, and a payment that waits for an approval says so.
// While a purchase is on its way, the button spins, or is disabled with its
// label in an app that asks for less motion, and nothing else takes a tap.
// Plans that do not load show that they are not available, with Try again
// and a note for the developer with the hint of the provider, also after a
// restore there. The link to the terms of use opens its address of .env
// outside the app; the privacy policy, whose key the matrix leaves empty, has
// no link, and the note names its key.
//
// The test starts the app once, since the start-up of an app may not run
// twice, and each expectation gives its reason.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/env/app_env.dart';
import 'package:{{app_name}}/core/purchases/app_purchases.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/paywall/paywall_widgets.dart';

import '../paywall_mocks.dart';
import 'of_app.dart';
import 'paywall.dart';

/// The name of the plan of [index], in the order of the service of the
/// tests.
const _planNames = ['planYearly', 'planMonthly', 'planLifetime'];

/// The text of the card of the plan of [index] that matches [matching].
Finder _onCard(int index, Finder matching) =>
    find.descendant(of: planCards.at(index), matching: matching);

/// Whether the card of the plan of [index] is the selected one.
bool _selected(WidgetTester tester, int index) =>
    tester.widget<PlanCard>(planCards.at(index)).selected;

/// The label that the button of the paywall shows.
String _label(WidgetTester tester) => tester
    .widget<WholeWords>(
      find.descendant(of: purchaseButton, matching: find.byType(WholeWords)),
    )
    .text;

/// Whether the button of the paywall spins.
bool _spins() => find
    .descendant(
      of: purchaseButton,
      matching: find.byType(CircularProgressIndicator),
    )
    .evaluate()
    .isNotEmpty;

/// Whether the link of the paywall that restores purchases takes a tap.
bool _restoreTakesTap(WidgetTester tester) =>
    tester
        .widget<TextButton>(
          find.descendant(
              of: link('restore'), matching: find.byType(TextButton)),
        )
        .onPressed !=
    null;

/// Whether the button of the paywall takes a tap.
bool _takesTap(WidgetTester tester) =>
    tester
        .widget<FilledButton>(
          find.descendant(
              of: purchaseButton, matching: find.byType(FilledButton)),
        )
        .onPressed !=
    null;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  paywallIsUnderTest = true;

  testWidgets(
    'the paywall shows grey cards while the plans load, then the plans with '
    'their prices and offers, the button and the terms of the selected plan, '
    'the failures and the plans that are not available, in each language',
    (tester) async {
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      useTallPhone(tester);
      final languages = paywallTexts.keys.toList();
      await useLanguage(tester, languages.first);
      await startApp(tester);
      final links = recordLinks();

      // While the plans load.
      final service = ScriptedPurchases();
      final plans = service.hold('plans');
      await startPurchases(tester, service);
      unawaited(
        navigatorOf(tester).push<Object?>(const PaywallPaywallLocation()),
      );
      // The screen settles while the plans load: nothing moves forever.
      await tester.pumpAndSettle();
      expect(
        (
          find.byType(PlanSkeleton).evaluate().length,
          planCards.evaluate().length,
        ),
        (2, 0),
        reason: 'While the plans load, the paywall shows grey cards in their '
            'place.',
      );
      expect(
        (_takesTap(tester), _restoreTakesTap(tester)),
        (false, false),
        reason: 'While the plans load, there is nothing to buy, and nothing '
            'to restore, so that no plan comes in to be bought while a '
            'restore is on its way.',
      );
      await inRealTime(tester, 'the plans', () async => plans.complete());
      await tester.pumpAndSettle();

      // The plans, in each language.
      for (final language in languages) {
        await useLanguage(tester, language);
        final when = 'In $language';
        expect(
          planCards,
          findsNWidgets(3),
          reason: '$when, the paywall shows a card for each plan.',
        );
        for (final (index, name) in _planNames.indexed) {
          expect(
            _onCard(index, text(name)),
            findsOneWidget,
            reason: '$when, the card of a plan names its period.',
          );
        }
        expect(
          [
            for (final (index, price)
                in [r'$29.99', r'$4.99', r'$79.99'].indexed)
              _onCard(
                index,
                find.textContaining(price, findRichText: true),
              ).evaluate().length,
          ],
          [1, 1, 1],
          reason: '$when, each card shows the price that the store gives.',
        );
        expect(
          (
            _onCard(0, text('bestValue')).evaluate().length,
            _onCard(1, text('bestValue')).evaluate().length,
            _onCard(
              0,
              find.text('${texts['oneWeek']} ${texts['free']}'),
            ).evaluate().length,
          ),
          (1, 0, 1),
          reason: '$when, the yearly plan, which costs less than twelve '
              'months, is the best value, and its card tells of its free '
              'week.',
        );
        expect(
          [
            for (final index in [0, 1, 2]) _selected(tester, index)
          ],
          [true, false, false],
          reason: '$when, the yearly plan is selected.',
        );
        expect(_label(tester), texts['startTrial'], reason: when);
        expect(
          find.text(
            '${texts['oneWeek']} ${texts['free']}, ${texts['then']} '
            r'$29.99'
            '\u00A0${texts['perYear']!.replaceAll(' ', '\u00A0')}',
          ),
          findsOneWidget,
          reason: '$when, below the button the paywall tells what the plan '
              'costs after its free trial.',
        );
        expect(
          find.text('${texts['termsGoogle']} ${texts['termsTrial']}'),
          findsOneWidget,
          reason: '$when, the paywall tells the terms of the store, and that '
              'the price is charged after the trial.',
        );
      }

      // Another plan.
      await tester.tap(planCards.at(1));
      await tester.pumpAndSettle();
      expect(
        (_selected(tester, 1), _label(tester)),
        (true, texts['subscribe']),
        reason: 'A tap selects a plan, and the button subscribes to it.',
      );
      expect(find.text(texts['termsGoogle']!), findsOneWidget);
      await tester.tap(planCards.at(2));
      await tester.pumpAndSettle();
      expect(
        (_label(tester), find.text(texts['termsLifetime']!).evaluate().length),
        (texts['buy'], 1),
        reason: 'A plan paid once is bought, and is no subscription.',
      );

      // The link to the terms of use opens its address of .env outside the
      // app. The privacy policy has no address there, so the paywall has no
      // link to it, and the note for the developer names its key.
      final terms = AppEnv.paywallTermsUrl;
      expect(
        (terms != null, AppEnv.paywallPrivacyUrl),
        (true, null),
        reason: 'The matrix gives the terms of use an address of the tests, '
            'and the privacy policy none.',
      );
      await tester.tap(link('terms'));
      await tester.pumpAndSettle();
      expect(
        links.opened.last,
        '$terms externalApplication',
        reason: 'The link to the terms of use opens its address of .env '
            'outside the app.',
      );
      expect(
        link('privacy'),
        findsNothing,
        reason: 'A link whose address is empty in .env is left out.',
      );
      expect(
        [
          for (final key in ['PAYWALL_TERMS_URL', 'PAYWALL_PRIVACY_URL'])
            find
                .descendant(
                  of: find.byType(DeveloperNote),
                  matching: find.text(key),
                )
                .evaluate()
                .length,
        ],
        [0, 1],
        reason: 'In debug mode, the note for the developer names the key of '
            '.env that is empty, and no other.',
      );

      // A failed purchase.
      await tester.tap(planCards.at(0));
      await tester.pumpAndSettle();
      for (final reason in PurchasesFailureReason.values) {
        service.failure = PurchasesFailure(
          reason,
          developerHint: 'the hint of ${reason.name}',
        );
        await tester.tap(purchaseButton);
        await tester.pumpAndSettle();
        expect(
          text(failureTextOf(reason)),
          findsOneWidget,
          reason: 'A purchase that fails with ${reason.name} shows its text.',
        );
        expect(
          find.text('the hint of ${reason.name}'),
          reason == PurchasesFailureReason.pending
              ? findsNothing
              : findsOneWidget,
          reason: 'In debug mode, a failure also shows the hint of the '
              'provider, and a payment that waits is no failure.',
        );
      }
      service.failure = null;

      // A purchase on its way.
      final purchase = service.hold('purchase');
      await tester.tap(purchaseButton);
      await tester.pump();
      expect(
        _spins(),
        isTrue,
        reason: 'While a purchase is on its way, the button spins.',
      );
      await tester.tap(planCards.at(1), warnIfMissed: false);
      await tester.pump();
      expect(
        (
          _selected(tester, 0),
          tester
              .widget<TextButton>(
                find.descendant(
                  of: link('restore'),
                  matching: find.byType(TextButton),
                ),
              )
              .onPressed,
        ),
        (true, null),
        reason: 'While a purchase is on its way, no plan is selected and '
            'nothing is restored.',
      );
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      await tester.pump();
      expect(
        (_spins(), _takesTap(tester)),
        (false, false),
        reason: 'In an app that asks for less motion, the button of a '
            'purchase on its way is disabled with its label.',
      );
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await inRealTime(tester, 'the purchase', () async => purchase.complete());
      await tester.pumpAndSettle();
      expect(
        builtPaywall,
        findsNothing,
        reason: 'Once the user bought a plan, the router closes the paywall '
            'that code pushed.',
      );

      // Plans that do not load.
      final unset = ScriptedPurchases()
        ..plansFailure = const PurchasesFailure(
          PurchasesFailureReason.notConfigured,
          developerHint: 'A key of the provider is missing.',
        );
      await startPurchases(tester, unset);
      unawaited(
        navigatorOf(tester).push<Object?>(const PaywallPaywallLocation()),
      );
      await tester.pumpAndSettle();
      expect(
        (
          text('plansUnavailable').evaluate().length,
          text('tryAgain').evaluate().length,
          purchaseButton.evaluate().length,
        ),
        (1, 1, 0),
        reason: 'Plans that do not load are not available, with a way to '
            'try again, and there is nothing to buy.',
      );
      expect(
        (
          find.text('For the developer').evaluate().length,
          find.text('A key of the provider is missing.').evaluate().length,
        ),
        (1, 1),
        reason: 'In debug mode, a note for the developer shows the hint of '
            'the provider.',
      );

      // A restore there still tells why the plans did not load.
      await tester.tap(link('restore'));
      await tester.pumpAndSettle();
      expect(
        (
          text('nothingToRestore').evaluate().length,
          text('plansUnavailable').evaluate().length,
          text('tryAgain').evaluate().length,
          find.byType(PlanSkeleton).evaluate().length,
          find.text('A key of the provider is missing.').evaluate().length,
        ),
        (1, 1, 1, 0, 1),
        reason: 'A restore that finds nothing while the plans are not '
            'available says so, and the paywall still shows that the plans '
            'are not available, with Try again and the hint of the provider, '
            'rather than grey cards as while the plans load.',
      );
      unset.plansFailure = null;
      await tester.tap(text('tryAgain'));
      await tester.pumpAndSettle();
      expect(
        planCards,
        findsNWidgets(3),
        reason: 'Try again loads the plans.',
      );
      await tester.tap(find.byTooltip(texts['close']!));
      await tester.pumpAndSettle();
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
