// The probe of the revenuecat module, which the start check runs on a
// device once the first screen of the app settled, the only place where
// the platform side is the RevenueCat SDK, and which the tests of the module
// run too (probe_test.dart and access_check_test.dart): RevenueCat is
// configured exactly when the service of the app has a key, and then the
// access and the plans of the app are those that RevenueCat gives, each plan
// with the price of its package and a period exactly when its product
// renews.
//
// It uses no test framework. It only reads, each read for at most 10
// seconds: it buys nothing and restores nothing, and the only user that it
// identifies is the user of the app, as appPurchases.plans() does. An
// app without a key, as on a device of CI with an empty .env, has
// RevenueCat not configured, which is no problem. A read that RevenueCat
// fails, as without a network, leaves the app nothing to show: the app
// then shows no premium access and no plans either.
//
// The probe also starts a check that outlives it and the start check, once
// in a run of the app: whether premium access that a server grants the user
// of the app in RevenueCat reaches appPurchases (checkAccess). Only a
// server with a secret key of the project can grant it, so the check asks
// the script of CI that started the app, .github/scripts/start_app.sh of
// the repository of SMF, to answer once the start check passed. It writes a
// request, smf_start_request_revenuecat, into the temporary directory of
// the app: the app user id of the device in RevenueCat, the entitlement
// premium and the end of the access, an hour from now in whole seconds. The
// script copies the request, runs the command that it was given for
// revenuecat, a test of the module that grants the entitlement with the
// REST API v2 of RevenueCat, and then waits for the verdict that the check
// writes into smf_start_report_revenuecat there: `passed`, or `failed: `
// and the problem. The check reads the customer info anew every few
// seconds, past the cache of the SDK, until the app shows that access. It
// writes its verdict without a request when RevenueCat is not configured,
// as in a release build, which never takes the key of the Test Store, or
// when the app shows premium access already. Each file is written next to
// its place and renamed, so that it is there only whole. Neither file has
// the key of RevenueCat. Where nothing answers, as in a start without the
// answer, the check writes its verdict once its time is up, and nothing
// reads it.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:{{app_name}}/core/purchases/app_purchases.dart';
import 'package:{{app_name}}/core/purchases/purchases_service.dart';
import 'package:{{app_name}}/core/purchases/revenuecat_purchases_service.dart';

/// How long the probe waits for one read.
const _wait = Duration(seconds: 10);

/// The identifier of the entitlement that is the premium access.
const _premium = 'premium';

/// The name of the exchange of the check of the access with start_app.sh,
/// in the names of its files and of the answer that the script is given.
const String exchangeName = 'revenuecat';

/// How long the access that the check asks for lasts: RevenueCat ends it on
/// its own, so nothing has to take it back once the check is done.
const Duration grantDuration = Duration(hours: 1);

/// How long the check waits for the access once it asked for it: longer
/// than start_app.sh waits for the answer and the verdict, so that the
/// script tells what it waited for when nothing comes.
const Duration accessTimeout = Duration(minutes: 10);

/// How often the check reads the customer info anew while it waits.
const Duration readInterval = Duration(seconds: 5);

/// How far the end of the access that the app shows may be from the end
/// that the check asked for.
const Duration expiryTolerance = Duration(minutes: 1);

/// The check of the access that the probe started, if it started one.
Future<String>? _access;

/// The probe of the start check: what is wrong with the purchases of the
/// app on RevenueCat as the start-up left them. It also starts
/// [checkAccess] the first time, without waiting for it, with the same
/// service, so that RevenueCat is configured once more and no more. It
/// waits for no screen, so it leaves [settle] out.
Future<List<String>> probeRevenueCat(Future<void> Function() settle) {
  final service = createPurchasesService();
  _access ??= checkAccess(service: service);
  return problemsOf(service);
}

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
  final bool active;
  try {
    final info = await Purchases.getCustomerInfo().timeout(_wait);
    active = info.entitlements.active.containsKey(_premium);
  } on PlatformException catch (error) {
    return [
      if (appPurchases.value is PremiumAccess)
        'The app shows premium access, but RevenueCat fails to give the '
            'customer info: ${error.code} ${error.message}',
    ];
  }
  // The access of the app once RevenueCat has told it of the info that it
  // read, as a read that fetched the info does, also of an access that came
  // while the probe waited for the read.
  await Future<void>.delayed(const Duration(milliseconds: 100));
  final shown = appPurchases.value is PremiumAccess;
  return [
    if (shown != active)
      'The app shows ${shown ? '' : 'no '}premium access, but the entitlement '
          '$_premium is ${active ? '' : 'not '}active in RevenueCat.',
  ];
}

/// Whether the plans of the app are the packages of the current offering
/// of RevenueCat, in its order, each with the price of its package and a
/// period exactly when its product renews.
Future<List<String>> _planProblems() async {
  List<Package> packages;
  try {
    final offerings = await Purchases.getOfferings().timeout(_wait);
    packages = offerings.current?.availablePackages ?? const [];
  } on PlatformException {
    packages = const [];
  }
  List<Plan> plans;
  try {
    plans = await appPurchases.plans().timeout(_wait);
  } on PurchasesFailure {
    plans = const [];
  }
  final ids = [for (final plan in plans) plan.id];
  final identifiers = [for (final package in packages) package.identifier];
  if (!listEquals(ids, identifiers)) {
    return [
      'The plans of the app are $ids, but the current offering of '
          'RevenueCat has the packages $identifiers.',
    ];
  }
  return [
    for (final (index, plan) in plans.indexed)
      ..._differencesOf(plan, packages[index].storeProduct),
  ];
}

/// What differs between [plan] and [product], the product of its package
/// in RevenueCat: the price, and whether the plan renews.
List<String> _differencesOf(Plan plan, StoreProduct product) {
  final period = product.subscriptionPeriod;
  final hasPeriod = plan.period == null ? 'has no period' : 'has a period';
  final renews = period == null ? 'is paid once' : 'renews every $period';
  return [
    if (product.priceString.isEmpty)
      'The package ${plan.id} in RevenueCat has no price.'
    else if (plan.price != product.priceString)
      'The plan ${plan.id} of the app costs ${plan.price}, but its package '
          'in RevenueCat costs ${product.priceString}.',
    if ((period == null) != (plan.period == null))
      'The plan ${plan.id} of the app $hasPeriod, but its product in '
          'RevenueCat $renews.',
  ];
}

/// Checks that premium access that a server grants the user of the app in
/// RevenueCat reaches `appPurchases`, with start_app.sh as the server: once
/// RevenueCat knows the customer, asks for the entitlement premium until
/// [grantDuration] from now in a request in [directory], and reads the
/// customer info anew every [interval] until the app shows that access, for
/// at most [wait]. Then writes its verdict there, `passed` or `failed: ` and
/// the problem, prints it and returns it.
///
/// It asks for nothing when RevenueCat is not configured, as in a build
/// without a key or in a release build, which takes the key of the Test
/// Store in no build but a debug one, nor when the app shows premium access
/// already, which the user of a new install does not have: the verdict then
/// tells why. The [service] is that of the app, and the [directory] the
/// temporary directory of the app, unless a test gives another.
///
/// The check of a [release] build, whose files the script of CI cannot read,
/// prints its verdict only once it asked for access. So the start of a
/// release app in CI, which takes no key of the Test Store and so asks for
/// nothing, prints no failure into a log that passes.
Future<String> checkAccess({
  PurchasesService? service,
  Directory? directory,
  Duration wait = accessTimeout,
  Duration interval = readInterval,
  bool release = kReleaseMode,
}) async {
  final files = directory ?? Directory.systemTemp;
  final request = File('${files.path}/smf_start_request_$exchangeName');
  String verdict;
  try {
    final problem = await _problemOfAccess(
      service ?? createPurchasesService(),
      files,
      wait,
      interval,
    );
    verdict = problem == null ? 'passed' : 'failed: $problem';
  } on Object catch (error) {
    verdict = 'failed: the check threw ${'$error'.trim().split('\n').first}';
  }
  try {
    _write(files, 'smf_start_report_$exchangeName', verdict);
  } on Object catch (error) {
    debugPrint('The check of the access wrote no verdict: $error');
  }
  if (!release || request.existsSync()) {
    debugPrint('The check of the access $verdict');
  }
  return verdict;
}

/// What is wrong with the access that the check asks for in [directory]
/// through [service], or `null` if it reached the app as asked for.
Future<String?> _problemOfAccess(
  PurchasesService service,
  Directory directory,
  Duration wait,
  Duration interval,
) async {
  if (service is! RevenueCatPurchasesService) {
    return 'the purchases of the app are not those of RevenueCat';
  }
  if (!await service.configured.timeout(_wait)) {
    // The failure of a call tells why: the hint of the key, or what
    // RevenueCat answered when it did not start with it.
    final why = await service.access().timeout(_wait).then<String?>(
          (_) => null,
          onError: (Object error) =>
              error is PurchasesFailure ? error.developerHint : '$error',
        );
    return 'RevenueCat is not configured in this build, so no access can '
        'reach the app: ${why ?? 'it did not start.'}';
  }
  // RevenueCat knows the customer once it gave the customer info, so the
  // server finds the customer that it grants the access to.
  await Purchases.getCustomerInfo().timeout(_wait);
  if (appPurchases.value case final PremiumAccess access) {
    return 'the app shows premium access (${_described(access)}) before the '
        'check asked for any, which the user of a new install does not have';
  }
  // In whole seconds, as RevenueCat gives the end of an access.
  final asked = DateTime.fromMillisecondsSinceEpoch(
    DateTime.now().add(grantDuration).millisecondsSinceEpoch ~/ 1000 * 1000,
    isUtc: true,
  );
  _write(
    directory,
    'smf_start_request_$exchangeName',
    jsonEncode({
      'appUserId': await Purchases.appUserID.timeout(_wait),
      'entitlement': _premium,
      'expiresAt': asked.millisecondsSinceEpoch,
    }),
  );
  debugPrint(
    'The check of the access asked for $_premium until '
    '${asked.toIso8601String()}, in the state '
    '${WidgetsBinding.instance.lifecycleState} of the app, and waits for it.',
  );
  final until = DateTime.now().add(wait);
  String? other;
  while (true) {
    if (appPurchases.value case final PremiumAccess access) {
      other = _otherThan(asked, access);
      if (other == null) return null;
    }
    if (!DateTime.now().isBefore(until)) break;
    await Future<void>.delayed(interval);
    try {
      // RevenueCat answers from a cache of the customer info, which a grant
      // of the server does not reach. Read anew, the SDK tells the service
      // of the app of a new access, which tells appPurchases.
      await Purchases.invalidateCustomerInfoCache().timeout(_wait);
      await Purchases.getCustomerInfo().timeout(_wait);
    } on Object catch (error) {
      // A read that fails, as without a network, is read again.
      debugPrint('The check of the access read no customer info: $error');
    }
  }
  return other ??
      'the app shows no premium access ${_timeOf(wait)} after the check '
          'asked for it, in the state '
          '${WidgetsBinding.instance.lifecycleState} of the app';
}

/// What differs between [access], the premium access of the app, and the
/// access that the check asked for, which ends at [asked] and does not
/// renew, or `null` if nothing does.
String? _otherThan(DateTime asked, PremiumAccess access) {
  final expiresAt = access.expiresAt;
  if (!access.renews &&
      expiresAt != null &&
      expiresAt.difference(asked).abs() <= expiryTolerance) {
    return null;
  }
  return 'the app shows premium access (${_described(access)}) rather than '
      'the access that the check asked for, which ends at '
      '${asked.toIso8601String()} and does not renew';
}

/// [access] in a verdict: when it ends and whether it renews.
String _described(PremiumAccess access) => [
      switch (access.expiresAt) {
        final end? => 'ends at ${end.toUtc().toIso8601String()}',
        null => 'never ends',
      },
      if (access.renews) 'renews' else 'does not renew',
    ].join(', ');

/// Writes [text] as one line into the file [name] in [directory], next to
/// it first and then renamed, so that the file is there only whole.
void _write(Directory directory, String name, String text) {
  final file = File('${directory.path}/$name');
  File('${file.path}.part')
    ..writeAsStringSync('$text\n', flush: true)
    ..renameSync(file.path);
}

/// [duration] in minutes, in seconds or in milliseconds.
String _timeOf(Duration duration) => duration.inMilliseconds % 60000 == 0
    ? '${duration.inMinutes} min'
    : duration.inMilliseconds % 1000 == 0
        ? '${duration.inSeconds} s'
        : '${duration.inMilliseconds} ms';
