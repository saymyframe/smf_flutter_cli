import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'purchases_provider.dart';
import 'subscription_view.dart';

/// The screen of the subscription: the [SubscriptionView] with the access
/// of [premiumProvider], which opens the page of the store with
/// [paywallLinkOpenerProvider].
///
/// It neither closes itself nor navigates once the access ends: the router
/// closes it then.
{{{smf_router__screen_annotations__paywall__subscription_screen}}}
class SubscriptionScreen extends ConsumerWidget {
  /// Creates the screen.
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => SubscriptionView(
    access: ref.watch(premiumProvider),
    onManage: ref.read(paywallLinkOpenerProvider),
  );
}
