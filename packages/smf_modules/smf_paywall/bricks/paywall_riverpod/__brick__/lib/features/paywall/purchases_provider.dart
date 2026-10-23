import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/purchases/app_purchases.dart';
import 'paywall_links.dart';

/// The purchases of the app, through which the providers of the paywall buy
/// and restore. No other file of the screens names them: a test overrides
/// this provider with an `AppPurchasesController` of its own.
final appPurchasesProvider = Provider<AppPurchasesController>(
  (ref) => appPurchases,
);

/// What opens a link of the screens of the paywall outside the app, such
/// as the terms of use or the page of the store where the user manages the
/// plan. A test overrides it to see the links that the screens open.
final paywallLinkOpenerProvider = Provider<Future<void> Function(Uri url)>(
  (ref) => openPaywallLink,
);

/// The access of the user, for the widgets of the app: the `AppAccess` of
/// the purchases of the app, `NoAccess` or `PremiumAccess`, which a widget
/// reads with `ref.watch(premiumProvider)` and which rebuilds the widget
/// when it changes.
final premiumProvider = NotifierProvider<PremiumNotifier, AppAccess>(
  PremiumNotifier.new,
);

/// Follows the access of the user.
class PremiumNotifier extends Notifier<AppAccess> {
  @override
  AppAccess build() {
    final purchases = ref.watch(appPurchasesProvider);
    void follow() => state = purchases.value;
    purchases.addListener(follow);
    ref.onDispose(() => purchases.removeListener(follow));
    return purchases.value;
  }
}
