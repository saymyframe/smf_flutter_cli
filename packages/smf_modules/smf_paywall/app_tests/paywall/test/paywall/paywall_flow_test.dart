// A test that continuous integration runs in the apps with the paywall
// module: the ways in and out of the paywall, with the purchases of the
// provider of the purchases role and its mocks, which start as on a first
// launch, with nothing bought, and let a purchase succeed.
//
// A request for the screen of the subscription, whose route needs premium
// access, opens the paywall over the page that the user is on. A restore
// that finds nothing says so, and the close button drops the request: its
// push completes with null. Once the user has bought a plan, the router
// closes the paywall and shows the screen of the subscription, with no page
// of the paywall left; back leads to the page below. The paywall that code
// pushes itself for a user without premium access closes once the user has
// it, and for a user with premium access the router shows the screen that
// the app starts on in place of the paywall.
//
// The paywall never closes itself after a purchase: the router closes it.
// A paywall that closed itself too would close the page below it, which
// the test sees. The test starts the app once, since the start-up of an app
// may not run twice, and each expectation gives its reason.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/purchases/app_purchases.dart';
import 'package:{{app_name}}/core/router/navigation.dart';

import '../paywall_mocks.dart';
import 'paywall.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // A tap that reaches no widget fails the test where it misses.
  WidgetController.hitTestWarningShouldBeFatal = true;
  // The app starts as on its first launch, with nothing bought.
  paywallIsUnderTest = true;

  testWidgets(
    'a request for a route that needs premium access opens the paywall over '
    'the page, and the router closes it and shows the route once the user '
    'bought a plan; the close button drops the request',
    (tester) async {
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      useTallPhone(tester);
      await startApp(tester);
      expect(
        appPurchases.hasPremium.value,
        isFalse,
        reason: 'On a first launch, the user has bought nothing.',
      );

      // A request for the screen of the subscription opens the paywall.
      final first = navigatorOf(
        tester,
      ).push<Object?>(const PaywallSubscriptionLocation());
      await waitInRealTime(
        tester,
        'the plans',
        until: () => planCards.evaluate().isNotEmpty,
      );
      expect(
        (
          paywallScreen.evaluate().length,
          builtSubscription.evaluate().length,
          builtStartScreen.evaluate().length,
        ),
        (1, 0, 1),
        reason: 'A request for the screen of the subscription from a user '
            'without premium access opens the paywall over the page that '
            'the user is on, and the router builds no screen of the '
            'subscription.',
      );
      expect(
        planCards,
        findsWidgets,
        reason: 'The paywall shows the plans of the offer of the provider.',
      );

      // A restore that finds nothing says so.
      await tapInRealTime(
        tester,
        link('restore'),
        until: () => text('nothingToRestore').evaluate().isNotEmpty,
      );
      expect(
        (
          text('nothingToRestore').evaluate().length,
          paywallScreen.evaluate().length,
        ),
        (1, 1),
        reason: 'A restore that finds nothing bought says so, and the '
            'paywall stays.',
      );

      // The close button drops the request.
      await tester.tap(find.byTooltip(texts['close']!));
      await tester.pumpAndSettle();
      final closedWith = await outcomeOf(tester, first);
      expect(
        (builtPaywall.evaluate().length, startScreenShown.evaluate().length),
        (0, 1),
        reason: 'The close button closes the paywall, and the user is on '
            'the page below it again.',
      );
      expect(
        closedWith,
        isNull,
        reason: 'The request that opened the paywall is dropped: its push '
            'completes with null.',
      );

      // A purchase: the router closes the paywall and shows the route.
      final second = navigatorOf(
        tester,
      ).push<Object?>(const PaywallSubscriptionLocation());
      await waitInRealTime(
        tester,
        'the plans',
        until: () => planCards.evaluate().isNotEmpty,
      );
      expect(paywallScreen, findsOneWidget);
      await tapInRealTime(
        tester,
        purchaseButton,
        until: () => subscriptionScreen.evaluate().isNotEmpty,
      );
      expect(
        appPurchases.hasPremium.value,
        isTrue,
        reason: 'The purchase gives the user premium access.',
      );
      expect(
        (
          subscriptionScreen.evaluate().length,
          builtPaywall.evaluate().length,
          builtStartScreen.evaluate().length,
        ),
        (1, 0, 1),
        reason: 'Once the user bought a plan, the router closes the paywall '
            'and shows the screen of the subscription over the page that it '
            'was asked for on, with no page of the paywall left. A paywall '
            'that closed itself too would close that page.',
      );
      expect(await pressSystemBack(tester), isTrue);
      final shownWith = await outcomeOf(tester, second);
      expect(
        (
          builtSubscription.evaluate().length,
          startScreenShown.evaluate().length,
          shownWith,
        ),
        (0, 1, null),
        reason: 'Back leads from the screen of the subscription to the page '
            'that it was asked for on, and its push completes.',
      );

      // The paywall that code pushes itself closes once the user has
      // premium access.
      await startWithoutPremium(tester);
      expect(
        appPurchases.hasPremium.value,
        isFalse,
        reason: 'A fresh user has bought nothing.',
      );
      unawaited(
        navigatorOf(tester).push<Object?>(const PaywallPaywallLocation()),
      );
      await waitInRealTime(
        tester,
        'the plans',
        until: () => planCards.evaluate().isNotEmpty,
      );
      expect(
        paywallScreen,
        findsOneWidget,
        reason: 'Code may push the paywall for a user without premium '
            'access.',
      );
      await tapInRealTime(
        tester,
        purchaseButton,
        until: () => builtPaywall.evaluate().isEmpty,
      );
      expect(
        (builtPaywall.evaluate().length, startScreenShown.evaluate().length),
        (0, 1),
        reason: 'Once the user bought a plan, the router closes the paywall '
            'that code pushed, and the user is on the page below it.',
      );

      // For a user with premium access, the flow of the guard is over.
      unawaited(
        navigatorOf(tester).push<Object?>(const PaywallPaywallLocation()),
      );
      await tester.pumpAndSettle();
      expect(
        (builtPaywall.evaluate().length, startScreenShown.evaluate().length),
        (0, 1),
        reason: 'For a user with premium access, the router shows the '
            'screen that the app starts on in place of the paywall.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
