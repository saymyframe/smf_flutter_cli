// A test that continuous integration runs in the apps with the paywall
// module: the screen of the subscription, with a service of purchases of
// the test that scripts the access of the user (ScriptedPurchases).
//
// For a plan that renews, one that ends, one in its free trial and one paid
// once, the screen names the plan and tells when it renews, when it ends,
// when the trial ends, with the date in the language of the app, or that
// the access is for good. Its button opens the page of the store where the
// user manages the plan, outside the app, and a plan paid once, which has
// no such page, has no button. When the access ends, the router closes the
// screen. In an app with a settings screen, the entry of the subscription
// tells whether the user has premium access, and its tap leads through the
// paywall and a purchase to the screen of the subscription over the
// settings screen.
//
// The matrix writes of_app.dart next to this file, with the settings screen
// of the app and the entry of the module, if the app has one. The test
// starts the app once, since the start-up of an app may not run twice, and
// each expectation gives its reason.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/purchases/app_purchases.dart';
import 'package:{{app_name}}/core/router/navigation.dart';

import '../paywall_mocks.dart';
import 'of_app.dart';
import 'paywall.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  paywallIsUnderTest = true;

  testWidgets(
    'the screen of the subscription tells the plan and when it renews or '
    'ends, opens the page of the store, closes once the access ends, and '
    'its entry on the settings screen leads there through the paywall',
    (tester) async {
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      useTallPhone(tester);
      final languages = paywallTexts.keys.toList();
      await useLanguage(tester, languages.first);
      await startApp(tester);
      final links = recordLinks();
      final manage = Uri.parse('https://example.com/manage');
      final ends = DateTime.utc(2031, 3, 4, 12);

      for (final (name, access, row) in [
        (
          'a plan that renews',
          PremiumAccess(
            expiresAt: ends,
            renews: true,
            period: const BillingPeriod(1, BillingUnit.year),
            manageUrl: manage,
          ),
          'renewsOn',
        ),
        (
          'a plan that ends',
          PremiumAccess(
            expiresAt: ends,
            period: const BillingPeriod(1, BillingUnit.month),
            manageUrl: manage,
          ),
          'endsOn',
        ),
        (
          'a plan in its free trial',
          PremiumAccess(
            expiresAt: ends,
            renews: true,
            inTrial: true,
            period: const BillingPeriod(1, BillingUnit.year),
            manageUrl: manage,
          ),
          'trialEndsOn',
        ),
        ('a plan paid once', const PremiumAccess(), 'lifetimeAccess'),
      ]) {
        await startPurchases(tester, ScriptedPurchases()..access_ = access);
        final page = navigatorOf(
          tester,
        ).push<Object?>(const PaywallSubscriptionLocation());
        await tester.pumpAndSettle();
        expect(
          (
            subscriptionScreen.evaluate().length,
            builtPaywall.evaluate().length
          ),
          (1, 0),
          reason: 'With $name, the user has premium access, and the router '
              'shows the screen of the subscription.',
        );
        for (final language in languages) {
          await useLanguage(tester, language);
          final when = 'With $name, in $language';
          expect(
            (
              text('subscriptionTitle').evaluate().length,
              text(row).evaluate().length,
            ),
            (1, 1),
            reason: '$when, the screen tells when the plan renews or ends, '
                'or that the access is for good.',
          );
          final plan = switch (access.period) {
            BillingPeriod(unit: BillingUnit.year) => 'planYearly',
            BillingPeriod() => 'planMonthly',
            null => null,
          };
          if (plan != null) {
            expect(
              (
                text('planLabel').evaluate().length,
                text(plan).evaluate().length
              ),
              (1, 1),
              reason: '$when, the screen names the plan.',
            );
          } else {
            expect(
              text('planLabel'),
              findsNothing,
              reason: '$when, a plan of no period has no row of its plan.',
            );
          }
          if (access.expiresAt case final expiresAt?) {
            final date = MaterialLocalizations.of(
              tester.element(subscriptionScreen),
            ).formatShortDate(expiresAt.toLocal());
            expect(
              find.text(date),
              findsOneWidget,
              reason: '$when, the screen shows the date in the language of '
                  'the app.',
            );
          }
        }
        if (access.manageUrl != null) {
          await tester.tap(text('manage'));
          await tester.pumpAndSettle();
          expect(
            links.opened.last,
            '$manage externalApplication',
            reason: 'With $name, the button opens the page of the store '
                'where the user manages the plan, outside the app.',
          );
        } else {
          expect(
            text('manage'),
            findsNothing,
            reason: 'A plan paid once has no page to manage in the store.',
          );
        }
        expect(await pressSystemBack(tester), isTrue);
        await page;
      }

      // The access ends while the screen is shown.
      final service = ScriptedPurchases()
        ..access_ = PremiumAccess(expiresAt: ends, renews: true);
      await startPurchases(tester, service);
      unawaited(
        navigatorOf(tester).push<Object?>(const PaywallSubscriptionLocation()),
      );
      await tester.pumpAndSettle();
      expect(subscriptionScreen, findsOneWidget);
      service.tell(const NoAccess());
      await tester.pump();
      await tester.pumpAndSettle();
      expect(
        (
          builtSubscription.evaluate().length,
          startScreenShown.evaluate().length
        ),
        (0, 1),
        reason: 'When the access ends, the router closes the screen of the '
            'subscription, and the user is on the page below it.',
      );

      // The entry of the settings screen.
      final settings = settingsLocation;
      final entry = subscriptionEntry;
      if (settings == null || entry == null) return;
      final row = find.byType(entry);
      if (settingsInMainNavigation) {
        navigatorOf(tester).go(settings);
      } else {
        unawaited(navigatorOf(tester).push<void>(settings));
      }
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        row,
        100,
        scrollable: find.byType(Scrollable).last,
      );
      for (final language in languages) {
        await useLanguage(tester, language);
        expect(
          [
            for (final name in ['settingTitle', 'settingInactive'])
              find.descendant(of: row, matching: text(name)).evaluate().length,
          ],
          [1, 1],
          reason: 'In $language, the entry has its title and tells that the '
              'user has no premium access.',
        );
      }
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        (paywallScreen.evaluate().length, builtSubscription.evaluate().length),
        (1, 0),
        reason: 'For a user without premium access, the entry opens the '
            'paywall over the settings screen.',
      );
      await tester.tap(purchaseButton);
      await tester.pumpAndSettle();
      expect(
        (
          subscriptionScreen.evaluate().length,
          builtPaywall.evaluate().length,
          find.byType(settingsScreen!, skipOffstage: false).evaluate().length,
        ),
        (1, 0, 1),
        reason: 'Once the user bought a plan, the router closes the paywall '
            'and shows the screen of the subscription over the settings '
            'screen.',
      );
      expect(await pressSystemBack(tester), isTrue);
      expect(
        find.descendant(of: row, matching: text('settingActive')),
        findsOneWidget,
        reason: 'Once the user has premium access, the entry says so.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
