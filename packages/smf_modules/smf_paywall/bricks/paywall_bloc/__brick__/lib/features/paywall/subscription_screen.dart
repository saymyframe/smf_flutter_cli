import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/purchases/app_purchases.dart';
import 'paywall_composition.dart';
import 'subscription_cubit.dart';
import 'subscription_view.dart';

/// The screen of the subscription: the [SubscriptionView] with the access
/// of a [SubscriptionCubit].
///
/// It neither closes itself nor navigates once the access ends: the router
/// closes it then.
{{{smf_router__screen_annotations__paywall__subscription_screen}}}
class SubscriptionScreen extends StatelessWidget {
  /// Creates the screen.
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => createSubscriptionCubit(),
    child: BlocBuilder<SubscriptionCubit, AppAccess>(
      builder: (context, access) => SubscriptionView(
        access: access,
        onManage: context.read<SubscriptionCubit>().manage,
      ),
    ),
  );
}
