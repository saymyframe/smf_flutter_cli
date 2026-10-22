import 'dart:async';

import '../purchases/purchases_service.dart';

/// A purchase of a plan: when the user bought it, and whether its first
/// period was the free trial of the plan.
typedef _Purchase = ({DateTime at, bool inTrial});

/// The id of the plan that renews each month, with a free week for a user
/// who never bought it.
const _monthlyId = 'fixture.monthly';

/// The id of the plan that renews each year.
const _annualId = 'fixture.annual';

/// The id of the plan that the user pays for once, for good.
const _lifetimeId = 'fixture.lifetime';

/// The free week of the plan of [_monthlyId].
const _freeWeek = IntroOffer(
  price: r'$0.00',
  amount: 0,
  period: BillingPeriod(1, BillingUnit.week),
);

/// The plans of the offer of the fixture, in its order, without the free
/// week that only some users may take.
const _plans = [
  Plan(
    id: _monthlyId,
    title: 'Monthly (fixture)',
    price: r'$4.99',
    amount: 4.99,
    currencyCode: 'USD',
    period: BillingPeriod(1, BillingUnit.month),
  ),
  Plan(
    id: _annualId,
    title: 'Annual (fixture)',
    price: r'$39.99',
    amount: 39.99,
    currencyCode: 'USD',
    period: BillingPeriod(1, BillingUnit.year),
  ),
  Plan(
    id: _lifetimeId,
    title: 'Lifetime (fixture)',
    price: r'$99.99',
    amount: 99.99,
    currencyCode: 'USD',
  ),
];

/// The page of the store of the fixture where a user manages a plan that
/// renews.
final Uri _manageUrl = Uri.parse('https://store.fixture.example/manage');

/// What each user bought: the purchase of each plan by its id, by the key
/// of the user, which is the id of a user of the app or that of a user of
/// this device ([_deviceUser]). It stands for the backend of a provider,
/// which every start of the app finds as the last one left it.
final Map<String, Map<String, _Purchase>> _bought = {};

/// The purchases that were made on this device, by the id of their plans:
/// what the store account of the device bought, which a restore gives the
/// user.
final Map<String, _Purchase> _boughtOnDevice = {};

/// The ids of users of the app that an identification named, on any
/// device: the fixture has one.
final Set<String> _named = {};

/// The key of the user whom this device has, the user whose purchases
/// count: the one that was identified last, also in an earlier start of the
/// app, or `null` before the first identification.
String? _onDevice;

/// How many users of this device the fixture started.
int _deviceUsers = 0;

/// The start of the key of a user of this device, which no id of a user of
/// the app has.
const _devicePrefix = r'$fixture-device:';

/// The key of the [number]th user of this device.
String _deviceUser(int number) => '$_devicePrefix$number';

/// Waits for the answer of the store or of the backend, which takes a
/// moment, as with a provider that asks them: a turn of the event loop. So
/// a test makes the calls of purchases in real time, as it runs the
/// start-up of the app.
Future<void> _answer() => Future<void>.delayed(Duration.zero);

/// The time now, in UTC.
DateTime _now() => DateTime.now().toUtc();

/// Opens the purchases of the fixture, as a start of the app does: it asks
/// the store for what it keeps, which takes a moment, and returns the
/// service, without a user. It asks the user nothing.
///
/// A start keeps what each user bought and the user whom the device has.
/// Nothing outlives the process of the app, so each run of the tests of a
/// file starts as on a first install.
Future<PurchasesService> openFixturePurchases() async {
  await _answer();
  return FixturePurchases._();
}

/// Purchases in memory, with an offer of three plans: one that renews each
/// month, with a free week for a user who never bought it, one that renews
/// each year, and one that the user pays for once. A purchase completes at
/// once, with no sheet of a store, and nothing expires while a test runs.
///
/// It keeps the purchases of each user of the app as the purchases role
/// says: `identify(null)` after another user starts a new user of this
/// device with nothing bought; a user that no identification named before,
/// identified while the user of this device is identified, takes over the
/// purchases of the user of this device; and a restore gives the user who
/// is identified each purchase made on this device, which the other users
/// keep too. No server grants an access, so the service tells of a change
/// only when a purchase or a restore made one.
final class FixturePurchases implements PurchasesService {
  FixturePurchases._();

  final StreamController<AppAccess> _changes =
      StreamController<AppAccess>.broadcast();

  /// Whether [identify] was called, which the role asks before any other
  /// call.
  bool _identified = false;

  /// What [user] bought: the purchase of each plan by its id.
  Map<String, _Purchase> _of(String user) =>
      _bought.putIfAbsent(user, () => {});

  /// The key of the user whose purchases count. Throws a [StateError] before
  /// [identify], as the role asks every provider to be identified first.
  String _user() {
    if (!_identified) {
      throw StateError('The purchases of the fixture were not identified.');
    }
    return _onDevice!;
  }

  @override
  Future<void> identify(String? userId) async {
    await _answer();
    _identified = true;
    final onDevice = _onDevice;
    final ofDevice = onDevice != null && onDevice.startsWith(_devicePrefix);
    if (userId == null) {
      // The user of this device stays, also from an earlier start; after a
      // user of the app, a new one starts, with nothing bought.
      if (!ofDevice) _onDevice = _deviceUser(++_deviceUsers);
    } else if (userId != onDevice) {
      // A user that no identification named before takes over the
      // purchases of the user of this device, who no longer has them.
      if (ofDevice && !_named.contains(userId)) {
        _bought[userId] = _bought.remove(onDevice) ?? {};
      }
      _named.add(userId);
      _onDevice = userId;
    }
  }

  @override
  Future<AppAccess> access() async {
    await _answer();
    return _accessOf(_of(_user()));
  }

  @override
  Stream<AppAccess> get accessChanges => _changes.stream;

  @override
  Future<List<Plan>> plans() async {
    await _answer();
    final purchases = _of(_user());
    return [for (final plan in _plans) _offered(plan, purchases)];
  }

  @override
  Future<AppAccess?> purchase(Plan plan) async {
    await _answer();
    final purchases = _of(_user());
    final offered = _plans.where((other) => other.id == plan.id).firstOrNull;
    if (offered == null) {
      throw PurchasesFailure(
        PurchasesFailureReason.unavailable,
        developerHint: 'The fixture has no plan ${plan.id}.',
      );
    }
    if (_isActive(offered, purchases[offered.id])) {
      throw const PurchasesFailure(PurchasesFailureReason.alreadyOwned);
    }
    final purchase = (
      at: _now(),
      inTrial: _offered(offered, purchases).introOffer?.isFree ?? false,
    );
    purchases[offered.id] = purchase;
    _boughtOnDevice[offered.id] = purchase;
    return _told(purchases);
  }

  @override
  Future<AppAccess> restore() async {
    await _answer();
    final purchases = _of(_user());
    for (final MapEntry(key: id, value: purchase) in _boughtOnDevice.entries) {
      final kept = purchases[id];
      if (kept == null || purchase.at.isAfter(kept.at)) {
        purchases[id] = purchase;
      }
    }
    return _told(purchases);
  }

  /// The access of [purchases], which the service tells of.
  AppAccess _told(Map<String, _Purchase> purchases) {
    final access = _accessOf(purchases);
    _changes.add(access);
    return access;
  }
}

/// [plan] as the user with [purchases] gets it: the plan of [_monthlyId]
/// with its free week for a user who never bought it.
Plan _offered(Plan plan, Map<String, _Purchase> purchases) =>
    plan.id == _monthlyId && !purchases.containsKey(_monthlyId)
        ? Plan(
            id: plan.id,
            title: plan.title,
            price: plan.price,
            amount: plan.amount,
            currencyCode: plan.currencyCode,
            period: plan.period,
            introOffer: _freeWeek,
          )
        : plan;

/// Whether [purchase] of [plan] gives access now: that of a plan paid
/// once does for good.
bool _isActive(Plan plan, _Purchase? purchase) {
  if (purchase == null) return false;
  final ends = _endOf(plan, purchase);
  return ends == null || ends.isAfter(_now());
}

/// When the access of [purchase] of [plan] ends, or `null` for a plan that
/// the user pays for once, which never ends.
DateTime? _endOf(Plan plan, _Purchase purchase) {
  final at = purchase.at;
  if (purchase.inTrial) return at.add(const Duration(days: 7));
  return switch (plan.period) {
    null => null,
    BillingPeriod(:final count, unit: BillingUnit.day) =>
      at.add(Duration(days: count)),
    BillingPeriod(:final count, unit: BillingUnit.week) =>
      at.add(Duration(days: 7 * count)),
    BillingPeriod(:final count, unit: BillingUnit.month) => DateTime.utc(
        at.year,
        at.month + count,
        at.day,
        at.hour,
        at.minute,
        at.second,
        at.millisecond,
        at.microsecond,
      ),
    BillingPeriod(:final count, unit: BillingUnit.year) => DateTime.utc(
        at.year + count,
        at.month,
        at.day,
        at.hour,
        at.minute,
        at.second,
        at.millisecond,
        at.microsecond,
      ),
  };
}

/// The access that [purchases] give: premium access for good with the plan
/// paid once, and otherwise that of the plan whose access ends last, while
/// it has not ended.
AppAccess _accessOf(Map<String, _Purchase> purchases) {
  if (purchases.containsKey(_lifetimeId)) return const PremiumAccess();
  PremiumAccess? access;
  for (final plan in _plans) {
    final purchase = purchases[plan.id];
    if (purchase == null || !_isActive(plan, purchase)) continue;
    final ends = _endOf(plan, purchase)!;
    if (access == null || ends.isAfter(access.expiresAt!)) {
      access = PremiumAccess(
        expiresAt: ends,
        renews: true,
        inTrial: purchase.inTrial,
        period: plan.period,
        manageUrl: _manageUrl,
      );
    }
  }
  return access ?? const NoAccess();
}
