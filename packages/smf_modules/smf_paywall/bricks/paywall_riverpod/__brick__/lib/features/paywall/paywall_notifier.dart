import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/purchases/app_purchases.dart';
import 'paywall_state.dart';
import 'purchases_provider.dart';

/// The state of the paywall, which lasts as long as the paywall does.
///
/// A provider is one for the app, where a cubit would be one for each page:
/// two pages of the paywall that are open at once, as a leaving one and a
/// new one during a transition, show the same state.
final paywallProvider =
    NotifierProvider.autoDispose<PaywallNotifier, PaywallState>(
      PaywallNotifier.new,
    );

/// Loads the plans of the current offer, buys the selected plan and
/// restores purchases through the purchases of the app, and tells which
/// call is on its way and what the last one ended with.
class PaywallNotifier extends Notifier<PaywallState> {
  /// Whether a purchase or a restore of this notifier is on its way.
  var _calling = false;

  @override
  PaywallState build() {
    final purchases = ref.watch(appPurchasesProvider);
    // Ends the busy state that a call left once the user has no premium
    // access: the access ended again before the router took the paywall
    // away, and the paywall is back.
    void follow() {
      if (_calling || state.busy == null) return;
      if (!purchases.hasPremium.value) state = state.idle();
    }

    purchases.hasPremium.addListener(follow);
    ref.onDispose(() => purchases.hasPremium.removeListener(follow));
    // The plans load once the provider has its first state.
    scheduleMicrotask(() {
      if (ref.mounted) unawaited(load());
    });
    return const PaywallState();
  }

  /// Loads the plans of the current offer, and selects the plan that the
  /// paywall selects first.
  Future<void> load() async {
    if (state.busy != null) return;
    final purchases = ref.read(appPurchasesProvider);
    state = const PaywallState();
    try {
      final plans = await purchases.plans();
      if (ref.mounted) {
        state = PaywallState(plans: plans, selected: preselectedPlan(plans));
      }
    } on PurchasesFailure catch (failure) {
      if (ref.mounted) state = PaywallState(loadFailure: failure);
    }
  }

  /// Selects [plan], unless a call is on its way.
  void select(Plan plan) {
    if (state.busy != null) return;
    state = state.selecting(plan);
  }

  /// Buys the selected plan.
  ///
  /// Once the user has premium access, the router closes the paywall, so
  /// the state stays busy for as long as the user has it. When the user
  /// cancels, the state is again as it was, and a payment that waits for an
  /// approval tells the user so.
  Future<void> purchase() async {
    final plan = state.selected;
    if (plan == null) return;
    await _run(
      PaywallAction.purchase,
      (purchases) => purchases.purchase(plan),
    );
  }

  /// Restores what the store account of the user bought.
  ///
  /// Once the user has premium access, the router closes the paywall, so
  /// the state stays busy for as long as the user has it. A restore that
  /// finds nothing tells the user so.
  Future<void> restore() => _run(
    PaywallAction.restore,
    (purchases) async => await purchases.restore() is PremiumAccess,
    otherwise: PaywallNotice.nothingToRestore,
  );

  /// Opens [url], a link of the paywall.
  Future<void> openLink(Uri url) => ref.read(paywallLinkOpenerProvider)(url);

  /// Makes [call], the call of [action], unless a call is on its way or the
  /// plans load. [call] returns whether the user has premium access then,
  /// and the state stays busy if so. Otherwise it is idle again, with the
  /// notice [otherwise], if any.
  Future<void> _run(
    PaywallAction action,
    Future<bool> Function(AppPurchasesController purchases) call, {
    PaywallNotice? otherwise,
  }) async {
    if (state.busy != null || state.loading) return;
    final purchases = ref.read(appPurchasesProvider);
    _calling = true;
    state = state.busyWith(action);
    final bool premium;
    try {
      premium = await call(purchases);
    } on PurchasesFailure catch (failure) {
      _calling = false;
      // The user may have left the paywall while the call was on its way.
      if (!ref.mounted) return;
      state = failure.reason == PurchasesFailureReason.pending
          ? state.idle(notice: PaywallNotice.pending)
          : state.idle(failure: failure);
      return;
    }
    _calling = false;
    if (!ref.mounted) return;
    // The access may have ended again already.
    if (!premium) {
      state = state.idle(notice: otherwise);
    } else if (!purchases.hasPremium.value) {
      state = state.idle();
    }
  }
}
