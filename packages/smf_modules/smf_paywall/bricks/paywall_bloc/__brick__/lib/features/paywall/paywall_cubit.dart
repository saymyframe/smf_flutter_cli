import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/purchases/app_purchases.dart';
import 'paywall_state.dart';

/// The state of the paywall: it loads the plans of the current offer, buys
/// the selected plan and restores purchases through the purchases of the
/// app, and tells which call is on its way and what the last one ended
/// with.
class PaywallCubit extends Cubit<PaywallState> {
  /// Creates the cubit that buys through [_purchases] and opens a link with
  /// [_openLink], and loads the plans.
  PaywallCubit(this._purchases, this._openLink) : super(const PaywallState()) {
    _purchases.hasPremium.addListener(_follow);
    unawaited(load());
  }

  final AppPurchasesController _purchases;
  final Future<void> Function(Uri url) _openLink;

  /// Whether a purchase or a restore of this cubit is on its way.
  var _calling = false;

  /// Loads the plans of the current offer, and selects the plan that the
  /// paywall selects first.
  Future<void> load() async {
    if (state.busy != null) return;
    emit(const PaywallState());
    try {
      final plans = await _purchases.plans();
      if (!isClosed) {
        emit(PaywallState(plans: plans, selected: preselectedPlan(plans)));
      }
    } on PurchasesFailure catch (failure) {
      if (!isClosed) emit(PaywallState(loadFailure: failure));
    }
  }

  /// Selects [plan], unless a call is on its way.
  void select(Plan plan) {
    if (state.busy != null) return;
    emit(state.selecting(plan));
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
    await _run(PaywallAction.purchase, () => _purchases.purchase(plan));
  }

  /// Restores what the store account of the user bought.
  ///
  /// Once the user has premium access, the router closes the paywall, so
  /// the state stays busy for as long as the user has it. A restore that
  /// finds nothing tells the user so.
  Future<void> restore() => _run(
    PaywallAction.restore,
    () async => await _purchases.restore() is PremiumAccess,
    otherwise: PaywallNotice.nothingToRestore,
  );

  /// Opens [url], a link of the paywall.
  Future<void> openLink(Uri url) => _openLink(url);

  /// Makes [call], the call of [action], unless a call is on its way.
  /// [call] returns whether the user has premium access then, and the state
  /// stays busy if so. Otherwise it is idle again, with the notice
  /// [otherwise], if any.
  Future<void> _run(
    PaywallAction action,
    Future<bool> Function() call, {
    PaywallNotice? otherwise,
  }) async {
    if (state.busy != null) return;
    _calling = true;
    emit(state.busyWith(action));
    final bool premium;
    try {
      premium = await call();
    } on PurchasesFailure catch (failure) {
      _calling = false;
      // The user may have left the paywall while the call was on its way.
      if (isClosed) return;
      emit(
        failure.reason == PurchasesFailureReason.pending
            ? state.idle(notice: PaywallNotice.pending)
            : state.idle(failure: failure),
      );
      return;
    }
    _calling = false;
    if (isClosed) return;
    if (premium) {
      _follow();
    } else {
      emit(state.idle(notice: otherwise));
    }
  }

  /// Ends the busy state that a call left once the user has no premium
  /// access: the access ended again before the router took the paywall
  /// away, and the paywall is back.
  void _follow() {
    if (_calling || isClosed || state.busy == null) return;
    if (!_purchases.hasPremium.value) emit(state.idle());
  }

  @override
  Future<void> close() {
    _purchases.hasPremium.removeListener(_follow);
    return super.close();
  }
}
