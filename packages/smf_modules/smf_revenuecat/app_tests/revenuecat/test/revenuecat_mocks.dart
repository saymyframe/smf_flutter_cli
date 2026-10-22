// The platform side of RevenueCat for the tests that continuous integration
// runs in the apps with the revenuecat module: RevenueCat, its backend and
// the store account of the device in memory, in place of the RevenueCat SDK
// of a device and of the servers behind it. It starts as an app finds the
// device on its first launch: nothing is bought, and the current offering
// has a plan of a month with a free week, a plan of a year and a plan paid
// once, each of a product that the entitlement premium has. The matrix sets
// it up before the tests of every module of such an app
// (MatrixAppTest.mocks), so that any of them may run the start-up of the
// app, which starts the purchases on it.
//
// purchases_flutter has no mocks for tests and no platform interface:
// Purchases is a class of static methods over the method channel
// purchases_flutter. So this answers the messages of the plugin to the
// platform on that channel, in the standard codec, and tells the plugin of
// a change of the customer info there, as the SDK does. A version of the
// package that changes them breaks these tests. The listeners of Purchases
// and the last customer info that it received are static, so they last for
// a whole test file, also when a test takes a device of its own.
//
// It answers at once, without a timer, so a call completes in a widget test
// too. It keeps to RevenueCat where the app relies on it, and to the
// convention of the mocks of the purchases role:
// - it keeps the user of the device from one configuration to the next, as
//   the SDK keeps the last user between launches: an anonymous user
//   ($RCAnonymousID:<n>) on a first launch;
// - logIn of a user that no logIn named before, while the user of the
//   device is anonymous, gives that user the purchases of the anonymous
//   user, who no longer has them; any other logIn switches to the user,
//   whose purchases stay its own; logIn of the current user changes
//   nothing; logOut starts a new anonymous user, with nothing bought, and
//   fails with the code 22 for an anonymous user;
// - a purchase completes at once and succeeds, in the free trial of its
//   product while the store account never took it; its customer info, and
//   that of a restore, is the one that getCustomerInfo gives right after
//   it; a restore gives the current user what the store account bought;
// - getCustomerInfo answers from the cache of the customer info, which a
//   configuration, a logIn, a logOut, a purchase and a restore fill, so a
//   grant made on the backend shows only once invalidateCustomerInfoCache
//   empties the cache, or once the SDK refreshes it itself;
// - it tells the plugin of the customer info when it fills the cache with
//   one that changed, before it answers the call;
// - Google Play appends the name of the app to the title of a product, and
//   a product of a subscription there is the subscription and its base
//   plan; on Android a product has its intro offer only while the store
//   account may take it, and on iOS the app asks whether it may;
// - before the first configuration, every call but isConfigured fails as
//   the Android SDK does, with a code that is no number: iOS stops the app
//   there instead. On Android a configuration with an empty key fails so
//   too, and on iOS it succeeds, and every later call fails with the code
//   11 of a key that RevenueCat does not know.
//
// It differs from RevenueCat in this: it checks no key but an empty one,
// shows no sheet of a store, sends nothing to a server and needs no
// network; nothing expires, renews or is refunded while a test runs; a
// purchase of a product that the user has already is a new purchase; and a
// restore never takes purchases from another user.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// The method channel of the plugin, on which the app calls RevenueCat and
/// RevenueCat tells the app of the customer info.
const _channel = MethodChannel('purchases_flutter');

/// The identifier of the entitlement of the premium access.
const _premium = 'premium';

/// The name of the app that Google Play appends to the title of a product.
const appNameOfStore = 'SMF Tests';

/// A product of the stores of the mocks: [id] on iOS, and [androidId] on
/// Android, `<subscription>:<base plan>` for a subscription.
final class MockProduct {
  /// Creates the product.
  const MockProduct({
    required this.id,
    required this.androidId,
    required this.title,
    required this.price,
    this.period,
    this.trial,
  });

  /// The id of the product in the App Store.
  final String id;

  /// The id of the product in Google Play.
  final String androidId;

  /// The title of the product, without the name of the app.
  final String title;

  /// The price in US dollars.
  final double price;

  /// How often the subscription renews in ISO 8601, such as `P1M`, or
  /// `null` for a product that the user pays for once.
  final String? period;

  /// How long the free trial of the subscription lasts in ISO 8601, or
  /// `null` without one.
  final String? trial;

  /// The id of the product on the platform that the app runs on.
  String get storeId =>
      defaultTargetPlatform == TargetPlatform.android ? androidId : id;
}

/// A package of the current offering: its [identifier] and [type], as
/// RevenueCat names them, and its [product].
typedef MockPackage = ({String identifier, String type, MockProduct product});

/// The packages of the current offering that the mocks start with.
const List<MockPackage> packagesOfTests = [
  (
    identifier: r'$rc_monthly',
    type: 'MONTHLY',
    product: MockProduct(
      id: 'smf_premium_monthly',
      androidId: 'smf_premium:monthly',
      title: 'Premium Monthly',
      price: 4.99,
      period: 'P1M',
      trial: 'P1W',
    ),
  ),
  (
    identifier: r'$rc_annual',
    type: 'ANNUAL',
    product: MockProduct(
      id: 'smf_premium_annual',
      androidId: 'smf_premium:annual',
      title: 'Premium Annual',
      price: 39.99,
      period: 'P1Y',
    ),
  ),
  (
    identifier: r'$rc_lifetime',
    type: 'LIFETIME',
    product: MockProduct(
      id: 'smf_premium_lifetime',
      androidId: 'smf_premium_lifetime',
      title: 'Premium Lifetime',
      price: 99.99,
    ),
  ),
];

/// A purchase of the product [product], the id of the product in its store,
/// at [at], in the free trial of the product or not.
typedef _Purchase = ({
  MockProduct product,
  String storeId,
  DateTime at,
  bool inTrial
});

/// The platform side of RevenueCat in memory; see [mockRevenueCat].
final class MockRevenueCat {
  MockRevenueCat._();

  /// The packages of the current offering, in its order, or `null` for no
  /// current offering.
  List<MockPackage>? packages = packagesOfTests;

  /// The identifiers of the packages whose products the entitlement premium
  /// does not have, as in a project that is not set up yet.
  final Set<String> unattached = {};

  /// What iOS answers when the app asks whether the store account may take
  /// an intro offer, or `null` for the answer of the store account: it may
  /// until it took the free trial of the product.
  IntroEligibilityStatus? eligibility;

  /// The key of the last configuration, or `null` before the first one.
  String? apiKey;

  /// The user of the device, which RevenueCat keeps between launches, or
  /// `null` before the first configuration.
  String? appUserId;

  /// The calls that reached the platform side, in their order.
  final List<MethodCall> calls = [];

  /// The names of the methods of [calls], in their order.
  List<String> get methods => [for (final call in calls) call.method];

  /// What each user bought, by the id of the user and of the product in its
  /// store: what the backend of RevenueCat keeps.
  final Map<String, Map<String, _Purchase>> _bought = {};

  /// What the store account of the device bought, by the id of the product
  /// in its store.
  final Map<String, _Purchase> _storeAccount = {};

  /// The products whose free trial the store account took.
  final Set<MockProduct> _trialsTaken = {};

  /// The access that the backend granted each user until a time, by the
  /// id of the user.
  final Map<String, DateTime> _grants = {};

  /// The users that a logIn named.
  final Set<String> _named = {};

  int _anonymousUsers = 0;
  bool _configured = false;
  bool _keyRefused = false;

  /// The customer info in the cache of the device, and the user it is of,
  /// or `null` once the cache is emptied.
  ({String user, Map<String, Object?> info})? _cache;

  /// The customer info that the plugin was last told of, without the time
  /// of its request.
  String? _told;

  final Map<String, PlatformException> _failures = {};
  final Map<String, Completer<void>> _held = {};

  /// Answers the next call of [method], such as `purchasePackage`, with the
  /// error [code] of RevenueCat and [message], as the platform sends it:
  /// the code as a text, which is no number for an error of the plugin
  /// itself, and the details of RevenueCat, with [underlying] as the
  /// message of the error below it and [userCancelled].
  void failNext(
    String method,
    String code, {
    String message = 'The mocks of RevenueCat failed the call.',
    String? underlying,
    bool? userCancelled,
  }) {
    final number = int.tryParse(code);
    final details = <String, Object?>{
      'code': number,
      'message': message,
      'readableErrorCode':
          number != null && number < PurchasesErrorCode.values.length
              ? PurchasesErrorCode.values[number].name
              : 'UNKNOWN',
    };
    if (underlying != null) details['underlyingErrorMessage'] = underlying;
    if (userCancelled != null) details['userCancelled'] = userCancelled;
    _failures[method] = PlatformException(
      code: code,
      message: message,
      details: number == null ? null : details,
    );
  }

  /// Answers the next call of [method] only once the completer that it
  /// returns completes, as a platform that takes a while.
  Completer<void> holdNext(String method) => _held[method] = Completer<void>();

  /// Grants [user] premium access until [until] on the backend, as the
  /// dashboard or the API of RevenueCat does. The device sees it once it
  /// reads the customer info anew.
  void grant(String user, {required DateTime until}) =>
      _grants[user] = until.toUtc();

  /// Has the SDK read the customer info of the user anew and tell the app,
  /// as it does on its own now and then, such as when the app comes back.
  Future<void> refresh() async {
    _cache = null;
    final user = appUserId;
    if (user != null) await _fetch(user);
  }

  /// Answers the messages of the plugin to the platform.
  void _install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      if (_held.remove(call.method) case final held?) await held.future;
      if (_failures.remove(call.method) case final failure?) throw failure;
      return _answer(call);
    });
  }

  Future<Object?> _answer(MethodCall call) async {
    final arguments = (call.arguments as Map<Object?, Object?>?) ?? const {};
    if (call.method == 'isConfigured') return _configured;
    if (call.method == 'setupPurchases') return _setUp(arguments);
    if (!_configured) {
      throw PlatformException(
        code: 'error',
        message: 'There is no singleton instance. Make sure you configure '
            'Purchases before trying to get the default instance.',
      );
    }
    if (_keyRefused) {
      throw PlatformException(
        code: '11',
        message: 'There was a credentials issue. Check the underlying error '
            'for more details.',
        details: const {
          'code': 11,
          'message': 'There was a credentials issue.',
          'readableErrorCode': 'INVALID_CREDENTIALS',
          'underlyingErrorMessage': 'Invalid API Key.',
        },
      );
    }
    final user = appUserId!;
    switch (call.method) {
      case 'getAppUserID':
        return user;
      case 'isAnonymous':
        return _isAnonymous(user);
      case 'logIn':
        return _logIn(user, arguments['appUserID']! as String);
      case 'logOut':
        return _logOut(user);
      case 'getCustomerInfo':
        return _cachedInfo(user);
      case 'invalidateCustomerInfoCache':
        _cache = null;
        return null;
      case 'getOfferings':
        return _offerings();
      case 'checkTrialOrIntroductoryPriceEligibility':
        return _eligibilityOf(arguments['productIdentifiers']! as List);
      case 'purchasePackage':
        return _purchase(user, arguments['packageIdentifier']! as String);
      case 'restorePurchases':
        return _restore(user);
    }
    throw MissingPluginException('No answer for ${call.method}');
  }

  Future<Object?> _setUp(Map<Object?, Object?> arguments) async {
    final key = arguments['apiKey']! as String;
    if (key.isEmpty && defaultTargetPlatform == TargetPlatform.android) {
      throw PlatformException(
        code: 'error',
        message: 'API key must be set. Get this from the RevenueCat web app',
      );
    }
    apiKey = key;
    _configured = true;
    _keyRefused = key.isEmpty;
    final user =
        appUserId ??= arguments['appUserId'] as String? ?? _newAnonymousUser();
    if (!_keyRefused) await _fetch(user);
    return null;
  }

  String _newAnonymousUser() => '\$RCAnonymousID:${++_anonymousUsers}';

  bool _isAnonymous(String user) => user.startsWith(r'$RCAnonymousID:');

  Future<Object?> _logIn(String user, String to) async {
    if (to == user) {
      return {'customerInfo': await _cachedInfo(user), 'created': false};
    }
    final created = !_named.contains(to) && !_bought.containsKey(to);
    if (_isAnonymous(user) && created) {
      _bought[to] = _bought.remove(user) ?? {};
    }
    _named.add(to);
    appUserId = to;
    return {'customerInfo': await _fetch(to), 'created': created};
  }

  Future<Object?> _logOut(String user) async {
    if (_isAnonymous(user)) {
      const message = 'Called logOut but the current user is anonymous.';
      throw PlatformException(
        code: '22',
        message: message,
        details: const {
          'code': 22,
          'message': message,
          'readableErrorCode': 'LOGOUT_CALLED_WITH_ANONYMOUS_USER',
        },
      );
    }
    final anonymous = appUserId = _newAnonymousUser();
    return _fetch(anonymous);
  }

  Future<Object?> _purchase(String user, String identifier) async {
    final package =
        packages?.where((package) => package.identifier == identifier);
    if (package == null || package.isEmpty) {
      throw PlatformException(
        code: '5',
        message: 'The product is not available for purchase.',
        details: const {
          'code': 5,
          'message': 'The product is not available for purchase.',
        },
      );
    }
    final product = package.single.product;
    final purchase = (
      product: product,
      storeId: product.storeId,
      at: DateTime.now().toUtc(),
      inTrial: product.trial != null && !_trialsTaken.contains(product),
    );
    if (purchase.inTrial) _trialsTaken.add(product);
    (_bought[user] ??= {})[purchase.storeId] = purchase;
    _storeAccount[purchase.storeId] = purchase;
    return {
      'customerInfo': await _fetch(user),
      'transaction': {
        'transactionIdentifier':
            'transaction-${purchase.at.microsecondsSinceEpoch}',
        'productIdentifier': purchase.storeId,
        'purchaseDate': _iso(purchase.at),
      },
    };
  }

  Future<Object?> _restore(String user) async {
    final bought = _bought[user] ??= {};
    for (final MapEntry(key: id, value: purchase) in _storeAccount.entries) {
      final kept = bought[id];
      if (kept == null || purchase.at.isAfter(kept.at)) bought[id] = purchase;
    }
    return _fetch(user);
  }

  /// The customer info of [user] from the cache, or from the backend when
  /// the cache has none of the user.
  Future<Map<String, Object?>> _cachedInfo(String user) async {
    final cache = _cache;
    if (cache != null && cache.user == user) return cache.info;
    return _fetch(user);
  }

  /// Reads the customer info of [user] from the backend into the cache, and
  /// tells the plugin of it when it changed.
  Future<Map<String, Object?>> _fetch(String user) async {
    final info = _infoOf(user);
    _cache = (user: user, info: info);
    final told = jsonEncode({...info, 'requestDate': null});
    if (told != _told) {
      _told = told;
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        _channel.name,
        _channel.codec.encodeMethodCall(
          MethodCall('Purchases-CustomerInfoUpdated', info),
        ),
        (_) {},
      );
    }
    return info;
  }

  /// The products that the entitlement premium has.
  bool _attached(MockProduct product) => !unattached.any(
        (identifier) =>
            packages?.any(
              (package) =>
                  package.identifier == identifier &&
                  package.product == product,
            ) ??
            false,
      );

  /// The customer info of [user] as the backend has it now.
  Map<String, Object?> _infoOf(String user) {
    final now = DateTime.now().toUtc();
    final bought = (_bought[user] ?? const {}).values.toList();
    final entitlements = <Map<String, Object?>>[
      for (final purchase in bought)
        if (_attached(purchase.product)) _entitlementOf(purchase),
      if (_grants[user] case final until?) _grantOf(until),
    ];
    Map<String, Object?>? premium;
    for (final entitlement in entitlements) {
      if (!_isActive(entitlement, now)) continue;
      if (premium == null || _endsLater(entitlement, premium)) {
        premium = entitlement;
      }
    }
    final subscriptions = [
      for (final purchase in bought)
        if (purchase.product.period != null &&
            _expirationOf(purchase)!.isAfter(now))
          purchase.storeId,
    ];
    final android = defaultTargetPlatform == TargetPlatform.android;
    return {
      'entitlements': {
        'all': premium == null ? const {} : {_premium: premium},
        'active': premium == null ? const {} : {_premium: premium},
        'verification': 'NOT_REQUESTED',
      },
      'allPurchaseDates': {
        for (final purchase in bought) purchase.storeId: _iso(purchase.at),
      },
      'activeSubscriptions': subscriptions,
      'allPurchasedProductIdentifiers': [
        for (final purchase in bought) purchase.storeId,
      ],
      'nonSubscriptionTransactions': [
        for (final purchase in bought)
          if (purchase.product.period == null)
            {
              'transactionIdentifier':
                  'transaction-${purchase.at.microsecondsSinceEpoch}',
              'productIdentifier': purchase.storeId,
              'purchaseDate': _iso(purchase.at),
            },
      ],
      'firstSeen': _iso(DateTime.utc(2026)),
      'originalAppUserId': user,
      'allExpirationDates': {
        for (final purchase in bought)
          purchase.storeId: _isoOrNull(_expirationOf(purchase)),
      },
      'requestDate': _iso(now),
      'latestExpirationDate': null,
      'originalPurchaseDate': null,
      'originalApplicationVersion': null,
      'managementURL': subscriptions.isEmpty
          ? null
          : android
              ? 'https://play.google.com/store/account/subscriptions'
              : 'https://apps.apple.com/account/subscriptions',
    };
  }

  /// The entitlement premium that [purchase] gives.
  Map<String, Object?> _entitlementOf(_Purchase purchase) {
    final android = defaultTargetPlatform == TargetPlatform.android;
    final [product, ...basePlan] = purchase.storeId.split(':');
    return {
      'identifier': _premium,
      'isActive': true,
      'willRenew': purchase.product.period != null,
      'latestPurchaseDate': _iso(purchase.at),
      'originalPurchaseDate': _iso(purchase.at),
      'productIdentifier': product,
      'productPlanIdentifier': basePlan.isEmpty ? null : basePlan.single,
      'isSandbox': true,
      'ownershipType': 'PURCHASED',
      'store': android ? 'PLAY_STORE' : 'APP_STORE',
      'periodType': purchase.inTrial ? 'TRIAL' : 'NORMAL',
      'expirationDate': _isoOrNull(_expirationOf(purchase)),
      'unsubscribeDetectedAt': null,
      'billingIssueDetectedAt': null,
      'verification': 'NOT_REQUESTED',
    };
  }

  /// The entitlement premium that a grant until [until] gives.
  Map<String, Object?> _grantOf(DateTime until) => {
        'identifier': _premium,
        'isActive': true,
        'willRenew': false,
        'latestPurchaseDate': _iso(DateTime.utc(2026)),
        'originalPurchaseDate': _iso(DateTime.utc(2026)),
        'productIdentifier': 'rc_promo_premium_custom',
        'productPlanIdentifier': null,
        'isSandbox': true,
        'ownershipType': 'PURCHASED',
        'store': 'PROMOTIONAL',
        'periodType': 'NORMAL',
        'expirationDate': _iso(until),
        'unsubscribeDetectedAt': null,
        'billingIssueDetectedAt': null,
        'verification': 'NOT_REQUESTED',
      };

  Map<String, Object?> _offerings() {
    final packages = this.packages;
    if (packages == null) return {'all': <String, Object?>{}, 'current': null};
    const context = {
      'offeringIdentifier': 'default',
      'placementIdentifier': null,
      'targetingContext': null,
    };
    final json = [
      for (final package in packages)
        {
          'identifier': package.identifier,
          'packageType': package.type,
          'product': _productOf(package.product, context),
          'presentedOfferingContext': context,
        },
    ];
    final current = {
      'identifier': 'default',
      'serverDescription': 'The offering of the tests',
      'metadata': <String, Object?>{},
      'availablePackages': json,
      for (final (index, package) in packages.indexed)
        if (_shortcuts.containsKey(package.type))
          _shortcuts[package.type]!: json[index],
    };
    return {
      'all': {'default': current},
      'current': current,
    };
  }

  Map<String, Object?> _productOf(
    MockProduct product,
    Map<String, Object?> context,
  ) {
    final android = defaultTargetPlatform == TargetPlatform.android;
    final trial = product.trial;
    final intro =
        trial != null && (!android || !_trialsTaken.contains(product));
    return {
      'identifier': product.storeId,
      'description': 'Premium access for the tests',
      'title': android ? '${product.title} ($appNameOfStore)' : product.title,
      'price': product.price,
      'priceString': '\$${product.price.toStringAsFixed(2)}',
      'currencyCode': 'USD',
      'introPrice': intro
          ? {
              'price': 0.0,
              'priceString': r'$0.00',
              'period': trial,
              'cycles': 1,
              'periodUnit': _units[trial.substring(trial.length - 1)],
              'periodNumberOfUnits':
                  int.parse(trial.substring(1, trial.length - 1)),
            }
          : null,
      'discounts': null,
      'productCategory':
          product.period == null ? 'NON_SUBSCRIPTION' : 'SUBSCRIPTION',
      'defaultOption': null,
      'subscriptionOptions': null,
      'presentedOfferingContext': context,
      'subscriptionPeriod': product.period,
    };
  }

  Map<String, Object?> _eligibilityOf(List<Object?> ids) => {
        for (final id in ids.cast<String>())
          id: {
            'status': (eligibility ??
                    (packages?.any(
                              (package) =>
                                  package.product.storeId == id &&
                                  _trialsTaken.contains(package.product),
                            ) ??
                            false
                        ? IntroEligibilityStatus
                            .introEligibilityStatusIneligible
                        : IntroEligibilityStatus
                            .introEligibilityStatusEligible))
                .index,
            'description': 'The answer of the mocks',
          },
      };
}

/// The names of the shortcuts of an offering, by the type of a package.
const _shortcuts = {
  'LIFETIME': 'lifetime',
  'ANNUAL': 'annual',
  'MONTHLY': 'monthly',
  'WEEKLY': 'weekly',
};

/// The units of ISO 8601 as RevenueCat names them.
const _units = {'D': 'DAY', 'W': 'WEEK', 'M': 'MONTH', 'Y': 'YEAR'};

/// When [purchase] ends: at the end of its trial or of its period, or never
/// for a product that the user pays for once.
DateTime? _expirationOf(_Purchase purchase) {
  final period =
      purchase.inTrial ? purchase.product.trial : purchase.product.period;
  if (period == null) return null;
  final count = int.parse(period.substring(1, period.length - 1));
  final at = purchase.at;
  return switch (period.substring(period.length - 1)) {
    'D' => at.add(Duration(days: count)),
    'W' => at.add(Duration(days: 7 * count)),
    'M' => DateTime.utc(at.year, at.month + count, at.day, at.hour, at.minute,
        at.second, at.millisecond),
    _ => DateTime.utc(at.year + count, at.month, at.day, at.hour, at.minute,
        at.second, at.millisecond),
  };
}

/// Whether [entitlement] is active at [now].
bool _isActive(Map<String, Object?> entitlement, DateTime now) {
  final expiration = entitlement['expirationDate'] as String?;
  return expiration == null || DateTime.parse(expiration).isAfter(now);
}

/// Whether [entitlement] ends after [other]: one that never ends ends last.
bool _endsLater(Map<String, Object?> entitlement, Map<String, Object?> other) {
  final ends = entitlement['expirationDate'] as String?;
  final otherEnds = other['expirationDate'] as String?;
  if (otherEnds == null) return false;
  return ends == null ||
      DateTime.parse(ends).isAfter(DateTime.parse(otherEnds));
}

String _iso(DateTime time) => time.toUtc().toIso8601String();

String? _isoOrNull(DateTime? time) => time == null ? null : _iso(time);

/// Answers the platform side of RevenueCat with RevenueCat, its backend and
/// the store account of a device in memory, as a first launch finds them,
/// and returns it: a test reads there what reached the platform side, and
/// scripts what RevenueCat answers and tells.
///
/// The binding of the tests must be initialized first. A test file that
/// calls it for a device of its own does so before the app configures
/// RevenueCat, and one for iOS sets debugDefaultTargetPlatformOverride too.
MockRevenueCat mockRevenueCat() => MockRevenueCat._().._install();
