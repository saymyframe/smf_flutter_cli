import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'purchases_service.dart';

/// The identifier of the entitlement in RevenueCat that every plan of the
/// app unlocks: the premium access of the app.
const _entitlement = '{{entitlement}}';

/// The names of the keys of RevenueCat in `.env`.
const _appleKey = 'REVENUECAT_APPLE_KEY';
const _googleKey = 'REVENUECAT_GOOGLE_KEY';
const _testKey = 'REVENUECAT_TEST_KEY';

/// Returns the purchases of the app on RevenueCat, with the key of `.env`
/// that [revenueCatKey] chooses for this platform and build. It asks the
/// user nothing and never throws: without a key, every call fails with
/// [PurchasesFailureReason.notConfigured].
PurchasesService createRevenueCatPurchasesService() =>
    RevenueCatPurchasesService(
      revenueCatKey(
        platform: defaultTargetPlatform,
        debug: kDebugMode,
        apple: {{{env_revenuecat_apple_key}}},
        google: {{{env_revenuecat_google_key}}},
        test: {{{env_revenuecat_test_key}}},
      ),
    );

/// The key with which the app configures RevenueCat, or why it has none.
final class RevenueCatKey {
  /// The key [value], which `.env` has under [name].
  const RevenueCatKey(String this.name, String this.value) : hint = null;

  /// No key, for the reason that [hint] tells the developer of the app.
  const RevenueCatKey.none(String this.hint)
      : name = null,
        value = null;

  /// The name of the key in `.env`, or `null` without a key.
  final String? name;

  /// The public API key of RevenueCat, or `null` without a key.
  final String? value;

  /// Why the app has no key, for the developer of the app, or `null` with a
  /// key.
  final String? hint;
}

/// The key with which the app configures RevenueCat on [platform], in a
/// debug build when [debug], from the values of `.env`: [apple], [google]
/// and [test], each `null` while it is empty.
///
/// A debug build takes the key of the Test Store, [test], when `.env` has
/// one, so that a purchase works with nothing but a RevenueCat account. A
/// profile or release build never takes it: RevenueCat stops such a build
/// that is configured with a key of the Test Store, on purpose. Otherwise
/// the app takes the key of the store of the platform: [apple] on iOS and
/// [google] on Android.
///
/// It takes no key when that key has no value in the build, when it is a
/// secret key of RevenueCat (`sk_`), which never goes into an app, and in a
/// profile or release build when it is a key of the Test Store (`test_`).
/// The hint of [RevenueCatKey.none] then names the key and tells what to
/// do.
RevenueCatKey revenueCatKey({
  required TargetPlatform platform,
  required bool debug,
  required String? apple,
  required String? google,
  required String? test,
}) {
  final (String, String?, String)? chosen = debug && test != null
      ? (_testKey, test, 'the Test Store')
      : switch (platform) {
          TargetPlatform.iOS => (_appleKey, apple, 'the App Store app'),
          TargetPlatform.android => (_googleKey, google, 'the Play Store app'),
          _ => null,
        };
  if (chosen == null) {
    return RevenueCatKey.none(
      'The app sells through RevenueCat on Android and iOS only, and runs '
      'on ${platform.name} here.',
    );
  }
  final (name, value, app) = chosen;
  if (value == null) {
    return RevenueCatKey.none(
      '$name has no value in this build. In .env, give it the public API key '
      'of $app in RevenueCat${debug ? ', or give $_testKey the public API key '
          'of the Test Store' : ''}. Then build the app as the section '
      '"{{values_heading}}" of its README says.',
    );
  }
  if (value.startsWith('sk_')) {
    return RevenueCatKey.none(
      '$name in .env is a secret key of RevenueCat, which never goes into an '
      'app: use the public API key of $app.',
    );
  }
  if (!debug && value.startsWith('test_')) {
    return RevenueCatKey.none(
      '$name in .env is a key of the Test Store, which RevenueCat refuses in '
      'a profile or release build: use the public API key of $app.',
    );
  }
  return RevenueCatKey(name, value);
}

/// The infos of the customer that RevenueCat tells of, for every service:
/// the listeners of `Purchases` are static, so the services of the app share
/// one.
final StreamController<CustomerInfo> _customerInfos =
    StreamController<CustomerInfo>.broadcast();

/// Whether the listener of [_customerInfos] is added to `Purchases`.
bool _listening = false;

/// How often each product of the offerings that RevenueCat gave is billed,
/// by the id of the product in the store, and whether the app read the
/// offerings once: they tell the period of the plan of an access, which the
/// info of the customer does not.
final Map<String, BillingPeriod> _periods = {};
bool _periodsRead = false;

/// How long an access waits for the offerings. RevenueCat gives them from
/// what the device keeps at once, and the wait ends a read that would wait
/// for the network, so that the access comes well within the time that the
/// start of the purchases waits for it.
const _offeringsWait = Duration(seconds: 1);

/// The purchases of the app on [RevenueCat](https://www.revenuecat.com),
/// with purchases_flutter.
///
/// The code of the app does not use it: it buys and restores through
/// `appPurchases` of `app_purchases.dart`.
///
/// The service configures RevenueCat when it is created, with the key of
/// [RevenueCatKey], and every call waits for that: RevenueCat stops an iOS
/// app that calls it before it is configured. Without a key it never calls
/// RevenueCat, and every call fails with
/// [PurchasesFailureReason.notConfigured] and the hint of the key.
///
/// The premium access of the app is the entitlement `{{entitlement}}` in
/// RevenueCat, which every product of the current offering unlocks. The id
/// of a [Plan] is the identifier of its package in that offering.
final class RevenueCatPurchasesService implements PurchasesService {
  /// Creates the service, which configures RevenueCat with [key], if it has
  /// a value.
  RevenueCatPurchasesService(this.key) {
    final value = key.value;
    _configured = value == null ? Future.value(false) : _configure(value);
  }

  /// The key that the service configures RevenueCat with, or why it has
  /// none.
  final RevenueCatKey key;

  /// Completes with whether RevenueCat is configured, once it is or failed.
  late final Future<bool> _configured;

  /// Completes with whether the service configured RevenueCat, once it did
  /// or failed: `false` without a key, or when RevenueCat refused the key.
  Future<bool> get configured => _configured;

  /// Why configuring RevenueCat failed, or `null`.
  String? _configureHint;

  /// The packages of the current offering that [plans] gave, by their
  /// identifiers, which a purchase needs.
  final Map<String, Package> _packages = {};

  /// Configures RevenueCat with [value], and completes with whether it did.
  /// It never fails, since nothing may wait for it.
  Future<bool> _configure(String value) async {
    try {
      await Purchases.configure(PurchasesConfiguration(value));
    } on PlatformException catch (error) {
      _configureHint =
          'RevenueCat refused to start with ${key.name}: ${error.message}';
      return false;
    } on MissingPluginException catch (error) {
      _configureHint = 'RevenueCat did not start with ${key.name}: the app '
          'has no platform side of purchases_flutter, as in a test without '
          'mocks of the method channel purchases_flutter (${error.message}).';
      return false;
    } on Object catch (error) {
      _configureHint = 'RevenueCat did not start with ${key.name}: $error';
      return false;
    }
    if (!_listening) {
      _listening = true;
      Purchases.addCustomerInfoUpdateListener(_customerInfos.add);
    }
    return true;
  }

  /// Runs [call] once RevenueCat is configured, and turns what it fails
  /// with into a [PurchasesFailure]: an error of RevenueCat into the reason
  /// of its code, and any other error into the reason
  /// [PurchasesFailureReason.unknown].
  Future<T> _call<T>(Future<T> Function() call) async {
    if (!await _configured) {
      throw PurchasesFailure(
        PurchasesFailureReason.notConfigured,
        developerHint: key.hint ?? _configureHint,
      );
    }
    try {
      return await call();
    } on PurchasesFailure {
      rethrow;
    } on PlatformException catch (error, stackTrace) {
      Error.throwWithStackTrace(_failureOf(error, key.name), stackTrace);
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PurchasesFailure(
          PurchasesFailureReason.unknown,
          developerHint: '$error',
        ),
        stackTrace,
      );
    }
  }

  @override
  Future<void> identify(String? userId) => _call(() async {
        if (userId != null) {
          await Purchases.logIn(userId);
        } else if (!await Purchases.isAnonymous) {
          try {
            await Purchases.logOut();
          } on PlatformException catch (error) {
            // RevenueCat has an anonymous user already, as after another
            // call that logged out meanwhile: that is the user of this
            // device.
            if (_codeOf(error) !=
                PurchasesErrorCode.logOutWithAnonymousUserError) {
              rethrow;
            }
          }
        }
      });

  @override
  Future<AppAccess> access() =>
      _call(() async => _accessAfter(await Purchases.getCustomerInfo()));

  @override
  Stream<AppAccess> get accessChanges => key.value == null
      ? const Stream<AppAccess>.empty()
      : _customerInfos.stream.map(_accessOf);

  @override
  Future<List<Plan>> plans() => _call(() async {
        final offerings = await Purchases.getOfferings();
        _read(offerings);
        final current = offerings.current;
        final packages = current?.availablePackages ?? const <Package>[];
        if (current == null || packages.isEmpty) {
          throw PurchasesFailure(
            PurchasesFailureReason.notConfigured,
            developerHint: current == null
                ? 'RevenueCat has no current offering: make the offering with '
                    'the packages of the app current in RevenueCat.'
                : 'The current offering ${current.identifier} of RevenueCat '
                    'has no packages: add the packages of the app to it.',
          );
        }
        _packages
          ..clear()
          ..addEntries([
            for (final package in packages)
              MapEntry(package.identifier, package),
          ]);
        final withIntro = await _withIntro(packages);
        return [for (final package in packages) _planOf(package, withIntro)];
      });

  @override
  Future<AppAccess?> purchase(Plan plan) => _call(() async {
        final package = _packages[plan.id] ?? await _packageAgain(plan.id);
        final CustomerInfo info;
        try {
          info = (await Purchases.purchase(PurchaseParams.package(package)))
              .customerInfo;
        } on PlatformException catch (error) {
          if (_cancelled(error)) return null;
          rethrow;
        }
        final access = await _accessAfter(info);
        if (access is! PremiumAccess) {
          throw PurchasesFailure(
            PurchasesFailureReason.notConfigured,
            developerHint: 'The user bought '
                '${package.storeProduct.identifier}, but RevenueCat gives no '
                'active entitlement $_entitlement for it: attach the product '
                'to the entitlement $_entitlement in RevenueCat, and a '
                'restore gives the access.',
          );
        }
        return access;
      });

  @override
  Future<AppAccess> restore() =>
      _call(() async => _accessAfter(await Purchases.restorePurchases()));

  /// The package [id] of the current offering, which RevenueCat gives again.
  /// Fails with [PurchasesFailureReason.unavailable] when the offering has
  /// none of that id.
  Future<Package> _packageAgain(String id) async {
    final offerings = await Purchases.getOfferings();
    _read(offerings);
    final package = offerings.current?.getPackage(id);
    if (package == null) {
      throw PurchasesFailure(
        PurchasesFailureReason.unavailable,
        developerHint: 'The current offering of RevenueCat has no package '
            '$id.',
      );
    }
    return _packages[id] = package;
  }

  /// The access of [info], once the app read the offerings that tell the
  /// period of a plan that renews, if it has not yet. It waits for them at
  /// most [_offeringsWait]: the access then has no period, and the periods
  /// come with offerings that RevenueCat gives later.
  Future<AppAccess> _accessAfter(CustomerInfo info) async {
    final premium = info.entitlements.active[_entitlement];
    if (premium?.expirationDate != null && !_periodsRead) {
      final read = Purchases.getOfferings().then(_read);
      try {
        await read.timeout(_offeringsWait);
      } on Object {
        // The access then has no period, as when the offerings do not have
        // its product. A read that ends later keeps the periods, or fails
        // with nobody to tell.
        unawaited(read.then((_) {}, onError: (Object _) {}));
      }
    }
    return _accessOf(info);
  }
}

/// Keeps the periods of the products of [offerings].
void _read(Offerings offerings) {
  for (final offering in offerings.all.values) {
    for (final package in offering.availablePackages) {
      final product = package.storeProduct;
      final period = _periodIn(product.subscriptionPeriod);
      if (period != null) _periods[product.identifier] = period;
    }
  }
  _periodsRead = true;
}

/// The access of the customer of [info]: premium while the entitlement
/// [_entitlement] is active.
AppAccess _accessOf(CustomerInfo info) {
  final premium = info.entitlements.active[_entitlement];
  if (premium == null || !premium.isActive) return const NoAccess();
  final expiration = premium.expirationDate;
  final manageUrl = info.managementURL;
  return PremiumAccess(
    expiresAt: expiration == null ? null : DateTime.tryParse(expiration),
    renews: premium.willRenew,
    inTrial: premium.periodType == PeriodType.trial,
    period: expiration == null ? null : _periodOf(premium),
    manageUrl: manageUrl == null ? null : Uri.tryParse(manageUrl),
  );
}

/// How often the product of [premium] is billed, if the offerings have
/// it. On Android the product of a plan in the store is the subscription
/// and its base plan.
BillingPeriod? _periodOf(EntitlementInfo premium) {
  final product = premium.productIdentifier;
  final basePlan = premium.productPlanIdentifier;
  return (basePlan == null ? null : _periods['$product:$basePlan']) ??
      _periods[product];
}

/// The ids of the products of [packages] whose intro offer the user may
/// take. Android gives a product only the offers that the user may take,
/// and on iOS the app asks: it shows an offer only when iOS says the user
/// may take it, so that it promises no trial that the store does not give.
Future<Set<String>> _withIntro(List<Package> packages) async {
  final ids = [
    for (final package in packages)
      if (package.storeProduct.introductoryPrice != null)
        package.storeProduct.identifier,
  ];
  if (ids.isEmpty || defaultTargetPlatform != TargetPlatform.iOS) {
    return ids.toSet();
  }
  try {
    final eligibility =
        await Purchases.checkTrialOrIntroductoryPriceEligibility(ids);
    return {
      for (final MapEntry(key: id, value: of) in eligibility.entries)
        if (of.status == IntroEligibilityStatus.introEligibilityStatusEligible)
          id,
    };
  } on PlatformException {
    return const {};
  }
}

/// [package] as a plan of the app, with its intro offer if its product is
/// among [withIntro].
Plan _planOf(Package package, Set<String> withIntro) {
  final product = package.storeProduct;
  final intro = product.introductoryPrice;
  return Plan(
    id: package.identifier,
    title: _titleOf(product),
    price: product.priceString,
    amount: product.price,
    currencyCode: product.currencyCode,
    period: _periodIn(product.subscriptionPeriod),
    introOffer: intro == null || !withIntro.contains(product.identifier)
        ? null
        : _introOf(intro),
  );
}

/// The title of [product]. Google Play appends the name of the app in
/// parentheses to the title of a product, which the app leaves out.
String _titleOf(StoreProduct product) {
  if (defaultTargetPlatform != TargetPlatform.android) return product.title;
  final title = product.title.replaceFirst(RegExp(r'\s*\([^()]*\)$'), '');
  return title.isEmpty ? product.title : title;
}

/// [intro] as an intro offer of a plan, or `null` when RevenueCat gives it
/// no period that the app knows.
IntroOffer? _introOf(IntroductoryPrice intro) {
  final unit = _units[intro.periodUnit];
  if (unit == null || intro.periodNumberOfUnits < 1 || intro.cycles < 1) {
    return null;
  }
  return IntroOffer(
    price: intro.priceString,
    amount: intro.price,
    period: BillingPeriod(intro.periodNumberOfUnits, unit),
    cycles: intro.cycles,
  );
}

/// The units of the periods of RevenueCat.
const _units = {
  PeriodUnit.day: BillingUnit.day,
  PeriodUnit.week: BillingUnit.week,
  PeriodUnit.month: BillingUnit.month,
  PeriodUnit.year: BillingUnit.year,
};

/// The period of a subscription in ISO 8601, such as `P1M`, or `null` for a
/// product that the user pays for once.
BillingPeriod? _periodIn(String? iso) {
  final match = RegExp(r'^P(\d+)([DWMY])$').firstMatch(iso ?? '');
  if (match == null) return null;
  final count = int.parse(match[1]!);
  if (count < 1) return null;
  return BillingPeriod(count, switch (match[2]!) {
    'D' => BillingUnit.day,
    'W' => BillingUnit.week,
    'M' => BillingUnit.month,
    _ => BillingUnit.year,
  });
}

/// The code of RevenueCat in [error], or `null` when it is no code of
/// RevenueCat, as for an error of the plugin itself, whose code is no
/// number.
PurchasesErrorCode? _codeOf(PlatformException error) {
  final number = int.tryParse(error.code);
  if (number == null ||
      number < 0 ||
      number >= PurchasesErrorCode.values.length) {
    return null;
  }
  return PurchasesErrorCode.values[number];
}

/// Whether [error] tells that the user cancelled a purchase.
bool _cancelled(PlatformException error) {
  final details = error.details;
  return _codeOf(error) == PurchasesErrorCode.purchaseCancelledError ||
      (details is Map && details['userCancelled'] == true);
}

/// [error] of RevenueCat, configured with the key [keyName] of `.env`, as a
/// failure of the purchases of the app.
PurchasesFailure _failureOf(PlatformException error, String? keyName) {
  final code = _codeOf(error);
  final reason = switch (code) {
    PurchasesErrorCode.paymentPendingError => PurchasesFailureReason.pending,
    PurchasesErrorCode.networkError ||
    PurchasesErrorCode.offlineConnectionError ||
    PurchasesErrorCode.productRequestTimeout ||
    PurchasesErrorCode.apiEndpointBlocked =>
      PurchasesFailureReason.network,
    PurchasesErrorCode.productAlreadyPurchasedError ||
    PurchasesErrorCode.receiptAlreadyInUseError ||
    PurchasesErrorCode.receiptInUseByOtherSubscriberError ||
    PurchasesErrorCode.purchaseBelongsToOtherUser =>
      PurchasesFailureReason.alreadyOwned,
    PurchasesErrorCode.purchaseNotAllowedError =>
      PurchasesFailureReason.notAllowed,
    PurchasesErrorCode.productNotAvailableForPurchaseError ||
    PurchasesErrorCode.purchaseInvalidError ||
    PurchasesErrorCode.ineligibleError =>
      PurchasesFailureReason.unavailable,
    PurchasesErrorCode.configurationError ||
    PurchasesErrorCode.invalidCredentialsError ||
    PurchasesErrorCode.invalidAppleSubscriptionKeyError ||
    PurchasesErrorCode.insufficientPermissionsError =>
      PurchasesFailureReason.notConfigured,
    PurchasesErrorCode.storeProblemError ||
    PurchasesErrorCode.invalidReceiptError ||
    PurchasesErrorCode.missingReceiptFileError ||
    PurchasesErrorCode.unexpectedBackendResponseError ||
    PurchasesErrorCode.unknownBackendError ||
    PurchasesErrorCode.customerInfoError ||
    PurchasesErrorCode.systemInfoError ||
    PurchasesErrorCode.signatureVerificationFailed ||
    PurchasesErrorCode.testStoreSimulatedPurchaseError =>
      PurchasesFailureReason.storeProblem,
    _ => PurchasesFailureReason.unknown,
  };
  return PurchasesFailure(reason, developerHint: _hintOf(error, code, keyName));
}

/// What [error] with [code] tells the developer of the app, whose app
/// configured RevenueCat with the key [keyName] of `.env`.
String _hintOf(
  PlatformException error,
  PurchasesErrorCode? code,
  String? keyName,
) {
  final details = error.details;
  final underlying = details is Map ? details['underlyingErrorMessage'] : null;
  final said = [
    '${code?.name ?? 'code ${error.code}'}: ${error.message}',
    if (underlying is String && underlying.isNotEmpty) underlying,
  ].join(' ');
  return switch (code) {
    PurchasesErrorCode.invalidCredentialsError =>
      'RevenueCat refused $keyName of .env ($said): copy the public API key '
          'of the app in RevenueCat into .env.',
    PurchasesErrorCode.productAlreadyPurchasedError ||
    PurchasesErrorCode.receiptAlreadyInUseError ||
    PurchasesErrorCode.receiptInUseByOtherSubscriberError ||
    PurchasesErrorCode.purchaseBelongsToOtherUser =>
      'The store account owns the product already ($said).',
    PurchasesErrorCode.testStoreSimulatedPurchaseError =>
      'The Test Store of RevenueCat failed the purchase, as its dialog was '
          'told to ($said).',
    _ => said,
  };
}
