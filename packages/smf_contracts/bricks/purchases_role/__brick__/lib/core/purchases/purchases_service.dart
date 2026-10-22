/// What the user may use of the app: [NoAccess], or [PremiumAccess] while a
/// plan that the user bought is active.
sealed class AppAccess {
  const AppAccess();
}

/// The user has no plan that is active, or the app does not know of one.
final class NoAccess extends AppAccess {
  /// Creates the access of a user without premium access.
  const NoAccess();

  @override
  bool operator ==(Object other) => other is NoAccess;

  @override
  int get hashCode => (NoAccess).hashCode;

  @override
  String toString() => 'NoAccess()';
}

/// The user has premium access: a plan that the user bought is active.
/// Every plan of the app gives the same access.
final class PremiumAccess extends AppAccess {
  /// Creates the premium access of a plan, with what the provider knows of
  /// it.
  const PremiumAccess({
    this.expiresAt,
    this.renews = false,
    this.inTrial = false,
    this.period,
    this.manageUrl,
  });

  /// When the access ends unless the plan renews, or `null` for an access
  /// that never ends, as that of a plan paid once.
  final DateTime? expiresAt;

  /// Whether the store renews the plan when [expiresAt] comes: `false` once
  /// the user cancelled, and for a plan paid once.
  final bool renews;

  /// Whether the access is the free trial of its plan: the store charges the
  /// price of the plan once the trial ends, unless the user cancels.
  final bool inTrial;

  /// How often the plan is billed, or `null` for a plan paid once, or when
  /// the provider does not know.
  final BillingPeriod? period;

  /// The page of the store where the user manages or cancels the plan, or
  /// `null` when the store has none for it, as for a plan paid once.
  final Uri? manageUrl;

  @override
  bool operator ==(Object other) =>
      other is PremiumAccess &&
      other.expiresAt == expiresAt &&
      other.renews == renews &&
      other.inTrial == inTrial &&
      other.period == period &&
      other.manageUrl == manageUrl;

  @override
  int get hashCode =>
      Object.hash(expiresAt, renews, inTrial, period, manageUrl);

  @override
  String toString() => 'PremiumAccess(expiresAt: $expiresAt, renews: $renews, '
      'inTrial: $inTrial, period: $period, manageUrl: $manageUrl)';
}

/// The unit of a [BillingPeriod].
enum BillingUnit {
  /// A day.
  day,

  /// A week.
  week,

  /// A month.
  month,

  /// A year.
  year,
}

/// How often a plan is billed, or how long a period of an [IntroOffer]
/// lasts: [count] times the [unit], such as 3 months.
final class BillingPeriod {
  /// Creates the period of [count] times [unit].
  const BillingPeriod(this.count, this.unit);

  /// How many units the period lasts, 1 or more.
  final int count;

  /// The unit of the period.
  final BillingUnit unit;

  @override
  bool operator ==(Object other) =>
      other is BillingPeriod && other.count == count && other.unit == unit;

  @override
  int get hashCode => Object.hash(count, unit);

  @override
  String toString() => 'BillingPeriod($count ${unit.name})';
}

/// What a plan costs for a first while, for a user who may take it: a free
/// trial, or a lower price.
final class IntroOffer {
  /// Creates the offer of [cycles] periods of [period] at [price].
  const IntroOffer({
    required this.price,
    required this.amount,
    required this.period,
    this.cycles = 1,
  });

  /// The price of a [period] of the offer as the store shows it, such as
  /// `$0.99`.
  final String price;

  /// The price of a [period] of the offer as a number in the currency of
  /// its plan: 0 for a free trial.
  final num amount;

  /// How long a period of the offer lasts.
  final BillingPeriod period;

  /// How many periods the offer lasts, 1 or more.
  final int cycles;

  /// Whether the offer is a free trial.
  bool get isFree => amount == 0;
}

/// A plan of the current offer of the app, which the user can buy. Every
/// plan gives premium access.
final class Plan {
  /// Creates the plan [id].
  const Plan({
    required this.id,
    required this.title,
    required this.price,
    required this.amount,
    required this.currencyCode,
    this.period,
    this.introOffer,
  });

  /// The id that the provider gives the plan. The app does not read it.
  final String id;

  /// The name of the product of the plan in the store.
  final String title;

  /// The full price of the plan as the store shows it, in the currency of
  /// the user, such as `$4.99`: what a [period] costs, or what the plan
  /// costs once.
  final String price;

  /// The full price as a number in [currencyCode].
  final num amount;

  /// The ISO 4217 code of the currency of the price, such as `USD`.
  final String currencyCode;

  /// How often the plan renews, or `null` for a plan paid once, which gives
  /// premium access for good.
  final BillingPeriod? period;

  /// What the plan costs for a first while, if this user may take that, or
  /// `null`.
  final IntroOffer? introOffer;
}

/// Why a call of purchases failed.
enum PurchasesFailureReason {
  /// The device did not reach the store or the provider.
  network,

  /// The payment waits for an approval, as one that a parent approves, or
  /// for a payment method that takes a while. The access comes once the
  /// store took the payment, and the service tells of it then.
  pending,

  /// The store account of the user owns the plan already: a restore gives
  /// the user its access.
  alreadyOwned,

  /// The user may not pay on this device, as with parental controls or
  /// payments that are turned off.
  notAllowed,

  /// The store, or the plan, is not available on this device or for this
  /// store account, as on a device without the store.
  unavailable,

  /// The store failed on its side. Trying again later may help.
  storeProblem,

  /// Purchases are not set up, such as a key of the provider that is
  /// missing, or an offer without plans. This is a mistake in the setup of
  /// the app, which [PurchasesFailure.developerHint] explains.
  notConfigured,

  /// Anything else. [PurchasesFailure.developerHint] has the error.
  unknown,
}

/// The failure of a call of purchases: the only thing that such a call
/// throws. A user who cancels a purchase is no failure.
final class PurchasesFailure implements Exception {
  /// Creates the failure for [reason].
  const PurchasesFailure(this.reason, {this.developerHint});

  /// Why the call failed. The app shows a text of its own for each reason.
  final PurchasesFailureReason reason;

  /// What went wrong in the words of the provider, for the developer of the
  /// app, or `null`. It is no text for the user: show it in debug mode
  /// only.
  final String? developerHint;

  @override
  String toString() => developerHint == null
      ? 'PurchasesFailure: ${reason.name}'
      : 'PurchasesFailure: ${reason.name} ($developerHint)';
}

/// The purchases of the users of the app, as the provider of purchases and
/// the store keep them.
///
/// The provider implements it. The code of the app does not call it: it
/// uses `appPurchases` of `app_purchases.dart`, which calls this service and
/// does what is the same with every provider.
///
/// Every implementation keeps to this:
/// - The function that creates the service creates it without a user, asks
///   the user nothing, and never throws. It may be called again, and the
///   service that it returns then has what the store and the provider kept.
/// - [identify] comes before any other call, so a provider can set itself up
///   with the user. Each call is for the user that [identify] last gave.
/// - The purchases of each user of the app stay apart, with one exception.
///   When the user of the device, `identify(null)`, is identified as a user
///   that the provider has not seen, that user takes over the purchases of
///   the user of the device: a purchase before a sign-up stays with the new
///   account. Any other [identify] keeps the purchases of each user apart,
///   and a user gets those of another only through [restore].
/// - [access] completes from what the device keeps, without the network
///   when it keeps anything.
/// - A call fails only with a [PurchasesFailure]. Without what it needs,
///   such as a key, the service fails every call with
///   [PurchasesFailureReason.notConfigured] and a
///   [PurchasesFailure.developerHint] that names what is missing, and it
///   never stops the app.
abstract interface class PurchasesService {
  /// Makes [userId] the user whose purchases count: the id of a user of the
  /// app, or `null` for the user of this device, who has no account of the
  /// app.
  ///
  /// Identifying the user who is identified already does nothing and does
  /// not fail, `null` too.
  Future<void> identify(String? userId);

  /// The access of the user, from what the device keeps, without the
  /// network when it keeps anything.
  Future<AppAccess> access();

  /// Tells of each change of the access of the user that the provider
  /// learns of, such as a renewal, an expiry, or a grant made elsewhere: a
  /// broadcast stream. It may also tell of an access that has not changed.
  Stream<AppAccess> get accessChanges;

  /// The plans of the current offer of the app, at least one, in the order
  /// of the provider. With nothing to offer, it fails with
  /// [PurchasesFailureReason.notConfigured] and a hint.
  Future<List<Plan>> plans();

  /// Buys [plan] for the user, through the sheet of the store, and
  /// completes with the access of the user once the store took the
  /// payment: a [PremiumAccess], since every plan gives premium access.
  ///
  /// It completes with `null` when the user cancelled, which is no failure.
  /// A payment that waits for an approval fails with
  /// [PurchasesFailureReason.pending], and [accessChanges] tells of the
  /// access once the store took it. A plan that the store account owns
  /// already fails with [PurchasesFailureReason.alreadyOwned].
  Future<AppAccess?> purchase(Plan plan);

  /// Gives the user what the store account of the user bought, such as on a
  /// new device, and completes with the access of the user then.
  Future<AppAccess> restore();
}
