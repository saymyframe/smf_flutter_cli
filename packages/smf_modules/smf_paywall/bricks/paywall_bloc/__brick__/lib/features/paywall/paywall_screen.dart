import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'paywall_composition.dart';
import 'paywall_cubit.dart';
import 'paywall_state.dart';
import 'paywall_view.dart';

/// The paywall: the [PaywallView] with the state of a [PaywallCubit].
///
/// It does not close itself after a purchase or a restore, and nothing
/// navigates to it: the router shows it in place of a route that needs
/// premium access while the user has none, and closes it once the user has
/// it.
{{{smf_router__screen_annotations__paywall__paywall_screen}}}
class PaywallScreen extends StatelessWidget {
  /// Creates the screen.
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => createPaywallCubit(),
    child: BlocBuilder<PaywallCubit, PaywallState>(
      builder: (context, state) => PaywallView(
        state: state,
        onSelect: context.read<PaywallCubit>().select,
        onPurchase: context.read<PaywallCubit>().purchase,
        onRestore: context.read<PaywallCubit>().restore,
        onRetry: context.read<PaywallCubit>().load,
        onOpenLink: context.read<PaywallCubit>().openLink,
      ),
    ),
  );
}
