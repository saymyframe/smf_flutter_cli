import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/purchases/app_purchases.dart';
import 'paywall_state.dart';

// The texts of the paywall that depend on a plan. A text of the app has no
// parameters, so these put the texts of closed sets together with the
// prices that the store gives: the name and the suffix of the price for
// each term of a plan, and the length of each intro offer that the stores
// have. A term or a length outside those sets gets a text without it.

/// The name of [plan] on the paywall: the name of its term, `Lifetime` for
/// a plan paid once, or the title of its product in the store for a term
/// that the paywall has no name for.
String planNameOf(BuildContext context, Plan plan) => switch (plan.period) {
  null => {{{text_plan_lifetime}}},
  final period => termNameOf(context, period) ?? plan.title,
};

/// The name of the plan of [period], such as `Monthly`, or `null` for a
/// period that the paywall has no name for.
String? termNameOf(BuildContext context, BillingPeriod period) =>
    switch (termOf(period)) {
      PlanTerm.week => {{{text_plan_weekly}}},
      PlanTerm.month => {{{text_plan_monthly}}},
      PlanTerm.twoMonths => {{{text_plan_two_months}}},
      PlanTerm.threeMonths => {{{text_plan_three_months}}},
      PlanTerm.sixMonths => {{{text_plan_six_months}}},
      PlanTerm.year => {{{text_plan_yearly}}},
      null => null,
    };

/// What follows the price of a plan of [period], such as `/ month`, or
/// `once` for a plan paid once, or `null` for a period that the paywall has
/// no words for.
String? priceSuffixOf(BuildContext context, BillingPeriod? period) =>
    switch (period) {
      null => {{{text_once}}},
      final period => switch (termOf(period)) {
        PlanTerm.week => {{{text_per_week}}},
        PlanTerm.month => {{{text_per_month}}},
        PlanTerm.twoMonths => {{{text_per_two_months}}},
        PlanTerm.threeMonths => {{{text_per_three_months}}},
        PlanTerm.sixMonths => {{{text_per_six_months}}},
        PlanTerm.year => {{{text_per_year}}},
        null => null,
      },
    };

/// The price of [plan] with what follows it, such as `$4.99 / month`.
String priceOf(BuildContext context, Plan plan) => [
  plan.price,
  ?priceSuffixOf(context, plan.period),
].join(' ');

/// How long an intro offer of [length] lasts, such as `1 week`.
String lengthTextOf(BuildContext context, OfferLength length) =>
    switch (length) {
      OfferLength.threeDays => {{{text_three_days}}},
      OfferLength.oneWeek => {{{text_one_week}}},
      OfferLength.twoWeeks => {{{text_two_weeks}}},
      OfferLength.oneMonth => {{{text_one_month}}},
      OfferLength.twoMonths => {{{text_two_months}}},
      OfferLength.threeMonths => {{{text_three_months}}},
      OfferLength.sixMonths => {{{text_six_months}}},
      OfferLength.oneYear => {{{text_one_year}}},
    };

/// What [offer] gives, as the card of its plan shows it: `1 week free` for
/// a free trial, `$1.99 for 3 months` for a lower price, or with the
/// suffix of its period, `$0.99 / month for 3 months`, for a lower price of
/// several periods. For a length that the paywall has no words for, it is
/// `Free trial` or `Introductory price`.
String offerTextOf(BuildContext context, IntroOffer offer) {
  final length = switch (lengthOf(offer)) {
    final length? => lengthTextOf(context, length),
    null => null,
  };
  if (offer.isFree) {
    final free = {{{text_free}}};
    return length == null ? {{{text_free_trial}}} : '$length $free';
  }
  final suffix = offer.cycles > 1
      ? priceSuffixOf(context, offer.period)
      : null;
  if (length == null || (offer.cycles > 1 && suffix == null)) {
    return {{{text_intro_price}}};
  }
  return [
    offer.price,
    ?suffix,
    {{{text_for_length}}},
    length,
  ].join(' ');
}

/// What [plan] costs after its intro offer, as the paywall says right
/// below its button, such as `1 week free, then $29.99 / year`, or `null`
/// for a plan without an intro offer.
String? afterOfferTextOf(BuildContext context, Plan plan) {
  final offer = plan.introOffer;
  if (offer == null) return null;
  final then = {{{text_then}}};
  return '${offerTextOf(context, offer)}, $then ${priceOf(context, plan)}';
}

/// The label of the button that buys [plan]: `Start free trial` for a plan
/// with a free trial, `Buy` for a plan paid once, and `Subscribe` for any
/// other plan and while there is none.
String purchaseLabelOf(BuildContext context, Plan? plan) => switch (plan) {
  Plan(introOffer: IntroOffer(isFree: true)) => {{{text_start_trial}}},
  Plan(period: null) => {{{text_buy}}},
  _ => {{{text_subscribe}}},
};

/// What the user agrees to by buying [plan], below the button: that a
/// plan paid once is no subscription, or that the plan renews until the
/// user cancels it in the store of the platform, with what the user pays
/// after an intro offer.
String termsTextOf(BuildContext context, Plan plan) {
  if (plan.period == null) return {{{text_terms_lifetime}}};
  final store = switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.macOS => {{{text_terms_apple}}},
    _ => {{{text_terms_google}}},
  };
  final offer = switch (plan.introOffer) {
    null => null,
    IntroOffer(isFree: true) => {{{text_terms_trial}}},
    IntroOffer() => {{{text_terms_intro}}},
  };
  return [store, ?offer].join(' ');
}

/// The text of the app for [reason], the reason of a failure of purchases.
///
/// It has a text for every reason: a reason that the app gets later has
/// none here, and the app does not compile until it has.
String failureTextOf(BuildContext context, PurchasesFailureReason reason) =>
    switch (reason) {
      PurchasesFailureReason.network => {{{text_failure_network}}},
      PurchasesFailureReason.pending => {{{text_pending_notice}}},
      PurchasesFailureReason.alreadyOwned => {{{text_failure_owned}}},
      PurchasesFailureReason.notAllowed => {{{text_failure_not_allowed}}},
      PurchasesFailureReason.unavailable => {{{text_failure_unavailable}}},
      PurchasesFailureReason.storeProblem => {{{text_failure_store}}},
      PurchasesFailureReason.notConfigured => {{{text_failure_not_set_up}}},
      PurchasesFailureReason.unknown => {{{text_failure_unknown}}},
    };

/// The text of the app for [notice].
String noticeTextOf(BuildContext context, PaywallNotice notice) =>
    switch (notice) {
      PaywallNotice.pending => {{{text_pending_notice}}},
      PaywallNotice.nothingToRestore => {{{text_nothing_to_restore}}},
    };
