import 'package:flutter/material.dart';

import '../../core/purchases/app_purchases.dart';
import 'paywall_screen.dart';

/// Whether the onboarding shows its step that offers premium access: while
/// the user has none.
bool paywallStepShows() => !appPurchases.hasPremium.value;

/// Shows the paywall over the onboarding: the action of the step that
/// offers premium access. It completes once the paywall is closed, with its
/// close button, with back, or once the user has premium access, and the
/// onboarding then goes on. For a user who has the access already, it shows
/// nothing.
///
/// While the onboarding is on, a guard of the routes may keep the router
/// from showing the route of the paywall, so the paywall is a route of its
/// own on the navigator at the root of the app, over the onboarding.
///
/// Elsewhere the paywall never closes itself after a purchase or a restore:
/// it is a page of the router, which closes it once the guard of premium
/// access allows. This route has no page, so the router does not own it: it
/// leaves the routes without a page over its pages as they are when a guard
/// notifies, and nothing else would close the paywall. So the route closes
/// here once the user has premium access, also from below a route over it,
/// such as a dialog, which stays, and the onboarding goes on. Only
/// if the navigator itself is disposed with the route on it, as when the
/// root of the app is replaced, does the listener stay, and from then on it
/// does nothing.
Future<void> showPaywall(BuildContext context) async {
  if (appPurchases.hasPremium.value) return;
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (context) => const PaywallScreen(),
  );
  void closeOnPremium() {
    if (!appPurchases.hasPremium.value) return;
    if (route.isCurrent) {
      navigator.pop();
    } else if (route.isActive) {
      navigator.removeRoute(route);
    }
  }

  appPurchases.hasPremium.addListener(closeOnPremium);
  try {
    await navigator.push(route);
  } finally {
    appPurchases.hasPremium.removeListener(closeOnPremium);
  }
}
