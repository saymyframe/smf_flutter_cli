import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'paywall_notifier.dart';
import 'paywall_view.dart';

/// The paywall: the [PaywallView] with the state of [paywallProvider].
///
/// It does not close itself after a purchase or a restore, and nothing
/// navigates to it: the router shows it in place of a route that needs
/// premium access while the user has none, and closes it once the user has
/// it.
{{{smf_router__screen_annotations__paywall__paywall_screen}}}
class PaywallScreen extends ConsumerWidget {
  /// Creates the screen.
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(paywallProvider.notifier);
    return PaywallView(
      state: ref.watch(paywallProvider),
      onSelect: notifier.select,
      onPurchase: notifier.purchase,
      onRestore: notifier.restore,
      onRetry: notifier.load,
      onOpenLink: notifier.openLink,
    );
  }
}
