// The probe of the revenuecat module, which the start check runs on a
// device once the first screen of the app settled, the only place where
// the platform side is the RevenueCat SDK, and which the test of the module
// runs too (probe_test.dart): RevenueCat is configured exactly when the
// service of the app has a key, and then the access and the plans of the
// app are those that RevenueCat gives.
//
// It uses no test framework. It only reads, each read for at most 10
// seconds: it buys nothing, restores nothing and identifies no user. An
// app without a key, as on a device of CI with an empty .env, has
// RevenueCat not configured, which is no problem. A read that RevenueCat
// fails, as without a network, leaves the app nothing to show: the app
// then shows no premium access and no plans either.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:{{app_name}}/core/purchases/app_purchases.dart';
import 'package:{{app_name}}/core/purchases/purchases_service.dart';
import 'package:{{app_name}}/core/purchases/revenuecat_purchases_service.dart';

/// How long the probe waits for one read.
const _wait = Duration(seconds: 10);

/// The identifier of the entitlement that is the premium access.
const _premium = 'premium';

/// The probe of the start check: what is wrong with the purchases of the
/// app on RevenueCat as the start-up left them. It waits for no screen, so
/// it leaves [settle] out.
Future<List<String>> probeRevenueCat(Future<void> Function() settle) =>
    problemsOf(createPurchasesService());

/// What is wrong with the purchases of the app on RevenueCat with
/// [service], the service of purchases that the app started with.
Future<List<String>> problemsOf(PurchasesService service) async {
  if (service is! RevenueCatPurchasesService) {
    return ['The purchases of the app are not those of RevenueCat.'];
  }
  final configured = await Purchases.isConfigured.timeout(_wait);
  if (service.key.value == null) {
    return [
      if (configured)
        'RevenueCat is configured, though the app has no key for it: '
            '${service.key.hint}',
    ];
  }
  if (!await service.configured.timeout(_wait) || !configured) {
    return [
      'The app has the key ${service.key.name}, but RevenueCat is not '
          'configured.',
    ];
  }
  return [...await _accessProblems(), ...await _planProblems()];
}

/// Whether the access of the app is premium exactly when the entitlement
/// premium of RevenueCat is active.
Future<List<String>> _accessProblems() async {
  final shown = appPurchases.value is PremiumAccess;
  final bool active;
  try {
    final info = await Purchases.getCustomerInfo().timeout(_wait);
    active = info.entitlements.active.containsKey(_premium);
  } on PlatformException catch (error) {
    return [
      if (shown)
        'The app shows premium access, but RevenueCat fails to give the '
            'customer info: ${error.code} ${error.message}',
    ];
  }
  return [
    if (shown != active)
      'The app shows ${shown ? '' : 'no '}premium access, but the entitlement '
          '$_premium is ${active ? '' : 'not '}active in RevenueCat.',
  ];
}

/// Whether the plans of the app are the packages of the current offering
/// of RevenueCat, in its order.
Future<List<String>> _planProblems() async {
  List<String> packages;
  try {
    final offerings = await Purchases.getOfferings().timeout(_wait);
    packages = [
      for (final package in offerings.current?.availablePackages ?? const [])
        package.identifier,
    ];
  } on PlatformException {
    packages = const [];
  }
  List<String> plans;
  try {
    plans = [
      for (final plan in await appPurchases.plans().timeout(_wait)) plan.id
    ];
  } on PurchasesFailure {
    plans = const [];
  }
  return [
    if (!listEquals(plans, packages))
      'The plans of the app are $plans, but the current offering of '
          'RevenueCat has the packages $packages.',
  ];
}
