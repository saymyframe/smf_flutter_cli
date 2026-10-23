import 'package:flutter/foundation.dart';

import '../../core/purchases/app_purchases.dart';

/// A call of the paywall that is on its way.
enum PaywallAction {
  /// Buying the selected plan.
  purchase,

  /// Restoring what the store account of the user bought.
  restore,
}

/// What the paywall tells the user after a call that did not fail.
enum PaywallNotice {
  /// The payment waits for an approval, as one that a parent approves: the
  /// access comes once the store took the payment, and the router closes
  /// the paywall then.
  pending,

  /// A restore found nothing that the store account bought.
  nothingToRestore,
}

/// The state of the paywall: the plans of the current offer, or why they
/// did not load, the plan that the user selected, which call is on its way,
/// and what the last call ended with.
@immutable
final class PaywallState {
  /// Creates the state, which is loading the plans without [plans] and
  /// [loadFailure].
  const PaywallState({
    this.plans,
    this.loadFailure,
    this.selected,
    this.busy,
    this.failure,
    this.notice,
  });

  /// The plans of the current offer, in the order of the provider of
  /// purchases, or `null` while they load or when they did not.
  final List<Plan>? plans;

  /// Why the plans did not load, or `null`.
  final PurchasesFailure? loadFailure;

  /// The plan that the button of the paywall buys, or `null` while there
  /// are no plans.
  final Plan? selected;

  /// The call that is on its way, or `null` when none is. While it is, the
  /// paywall takes no other call.
  ///
  /// It stays so after a purchase or a restore that gave the user premium
  /// access, for as long as the user has it: what comes next is up to the
  /// router, which closes the paywall. The paywall neither closes itself
  /// nor navigates. When the access ends before the router took the
  /// paywall away, the paywall is idle again.
  ///
  /// While the plans load, the paywall takes no call, so that no plan comes
  /// in to be bought while a restore is on its way.
  final PaywallAction? busy;

  /// Why the last call failed, or `null` if it did not.
  final PurchasesFailure? failure;

  /// What the last call that did not fail tells the user, or `null`.
  final PaywallNotice? notice;

  /// Whether the plans are loading.
  bool get loading => plans == null && loadFailure == null;

  /// The state with [plan] selected, with nothing on its way and nothing to
  /// tell.
  PaywallState selecting(Plan plan) =>
      PaywallState(plans: plans, loadFailure: loadFailure, selected: plan);

  /// The state while [action] is on its way. The plans, or why they did not
  /// load, stay as they are.
  PaywallState busyWith(PaywallAction action) => PaywallState(
    plans: plans,
    loadFailure: loadFailure,
    selected: selected,
    busy: action,
  );

  /// The state with nothing on its way, which tells of [failure] or
  /// [notice], if any. The plans, or why they did not load, stay as they
  /// are.
  PaywallState idle({PurchasesFailure? failure, PaywallNotice? notice}) =>
      PaywallState(
        plans: plans,
        loadFailure: loadFailure,
        selected: selected,
        failure: failure,
        notice: notice,
      );

  @override
  bool operator ==(Object other) =>
      other is PaywallState &&
      other.plans == plans &&
      other.loadFailure == loadFailure &&
      other.selected == selected &&
      other.busy == busy &&
      other.failure == failure &&
      other.notice == notice;

  @override
  int get hashCode =>
      Object.hash(plans, loadFailure, selected, busy, failure, notice);
}

/// How often a plan is billed, for the periods that the paywall has words
/// for: those that the stores offer.
enum PlanTerm {
  /// Every week.
  week,

  /// Every month.
  month,

  /// Every 2 months.
  twoMonths,

  /// Every 3 months.
  threeMonths,

  /// Every 6 months.
  sixMonths,

  /// Every year.
  year,
}

/// The term of [period], or `null` for a period that the paywall has no
/// words for. Seven days are a week, and twelve months a year.
PlanTerm? termOf(BillingPeriod period) => switch ((period.unit, period.count)) {
  (BillingUnit.day, 7) || (BillingUnit.week, 1) => PlanTerm.week,
  (BillingUnit.month, 1) => PlanTerm.month,
  (BillingUnit.month, 2) => PlanTerm.twoMonths,
  (BillingUnit.month, 3) => PlanTerm.threeMonths,
  (BillingUnit.month, 6) => PlanTerm.sixMonths,
  (BillingUnit.month, 12) || (BillingUnit.year, 1) => PlanTerm.year,
  _ => null,
};

/// How long an intro offer lasts, for the lengths that the paywall has
/// words for: those of the free trials of the stores.
enum OfferLength {
  /// 3 days.
  threeDays,

  /// 1 week.
  oneWeek,

  /// 2 weeks.
  twoWeeks,

  /// 1 month.
  oneMonth,

  /// 2 months.
  twoMonths,

  /// 3 months.
  threeMonths,

  /// 6 months.
  sixMonths,

  /// 1 year.
  oneYear,
}

/// How long [offer] lasts in all, its period times its cycles, or `null`
/// for a length that the paywall has no words for. Seven days are a week,
/// fourteen days two weeks, and twelve months a year.
OfferLength? lengthOf(IntroOffer offer) =>
    switch ((offer.period.unit, offer.period.count * offer.cycles)) {
      (BillingUnit.day, 3) => OfferLength.threeDays,
      (BillingUnit.day, 7) || (BillingUnit.week, 1) => OfferLength.oneWeek,
      (BillingUnit.day, 14) || (BillingUnit.week, 2) => OfferLength.twoWeeks,
      (BillingUnit.month, 1) => OfferLength.oneMonth,
      (BillingUnit.month, 2) => OfferLength.twoMonths,
      (BillingUnit.month, 3) => OfferLength.threeMonths,
      (BillingUnit.month, 6) => OfferLength.sixMonths,
      (BillingUnit.month, 12) || (BillingUnit.year, 1) => OfferLength.oneYear,
      _ => null,
    };

/// The plan of [plans] that the paywall selects when it shows them: the
/// first that renews every year, or else the first plan.
Plan? preselectedPlan(List<Plan> plans) {
  for (final plan in plans) {
    if (_yearly(plan)) return plan;
  }
  return plans.isEmpty ? null : plans.first;
}

/// Whether [plan] is the best value of [plans]: a plan that renews every
/// year and costs less than twelve times a plan of [plans] that renews
/// every month, in the same currency.
///
/// The paywall says so on the plan, and never shows a yearly plan by what
/// it costs a month, which Google Play does not allow.
bool isBestValue(Plan plan, List<Plan> plans) {
  if (!_yearly(plan)) return false;
  for (final other in plans) {
    final monthly = switch (other.period) {
      final period? => termOf(period) == PlanTerm.month,
      null => false,
    };
    if (monthly &&
        other.currencyCode == plan.currencyCode &&
        plan.amount < other.amount * 12) {
      return true;
    }
  }
  return false;
}

/// Whether [plan] renews every year.
bool _yearly(Plan plan) => switch (plan.period) {
  final period? => termOf(period) == PlanTerm.year,
  null => false,
};
