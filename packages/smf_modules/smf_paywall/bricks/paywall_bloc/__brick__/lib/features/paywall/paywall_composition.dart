import '../../core/purchases/app_purchases.dart';
import 'paywall_cubit.dart';
import 'paywall_links.dart';
import 'premium_cubit.dart';
import 'subscription_cubit.dart';

/// Creates the cubit of the paywall, which loads the plans at once.
///
/// The cubits of the paywall get the purchases of the app here, and no
/// other file of the screens names them: a test creates a cubit with an
/// `AppPurchasesController` of its own.
PaywallCubit createPaywallCubit() =>
    PaywallCubit(appPurchases, openLink: openPaywallLink);

/// Creates the cubit of the screen of the subscription.
SubscriptionCubit createSubscriptionCubit() =>
    SubscriptionCubit(appPurchases, openLink: openPaywallLink);

/// Creates the cubit with the access of the user, which the root of the
/// app provides to every widget.
PremiumCubit createPremiumCubit() => PremiumCubit(appPurchases);
