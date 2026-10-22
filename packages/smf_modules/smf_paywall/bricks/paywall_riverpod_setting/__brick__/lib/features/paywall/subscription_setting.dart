import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/purchases/app_purchases.dart';
import '../../core/router/navigation.dart';
import 'purchases_provider.dart';
import 'subscription_setting_row.dart';

/// The entry of the subscription on the settings screen: the
/// [SubscriptionSettingRow] with the access of the user, from
/// [premiumProvider], which leads to the screen of the subscription.
///
/// For a user without premium access, the router shows the paywall over
/// the settings screen first, and the screen of the subscription once the
/// user has the access.
class SubscriptionSetting extends ConsumerWidget {
  /// Creates the entry.
  const SubscriptionSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => SubscriptionSettingRow(
    active: ref.watch(premiumProvider) is PremiumAccess,
    onTap: () => context.nav.paywall.subscription().push<void>(),
  );
}
