// A test that continuous integration runs in the apps with the revenuecat
// module: what each call of the service sends to RevenueCat, and what it
// makes of what RevenueCat fails with. The service configures RevenueCat
// when it is created, without a user, and calls nothing else before that
// completed, since iOS stops an app that calls RevenueCat before; identify
// logs a user of the app in, and the user of the device out, where a log
// out of an anonymous user, which RevenueCat fails, counts as done; plans
// reads the offerings, and on iOS asks whether the user may take the intro
// offers; a purchase buys the package of the plan; and a code of RevenueCat
// becomes the reason of the purchases role, also a code that is no number,
// as the plugin gives its own errors, a cancel is no failure, and an
// offering or a purchase that the setup of RevenueCat lacks fails with
// notConfigured and a hint.
//
// It goes through the service of the module, on the real plugin, over a
// device of its own of the mocks of RevenueCat for each test.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/purchases/purchases_service.dart';

import '../revenuecat_mocks.dart';
import 'revenuecat.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockRevenueCat revenueCat;
  setUp(() => revenueCat = mockRevenueCat());

  /// The plan [id] that the service gives.
  Future<Plan> planOf(PurchasesService service, String id) async =>
      (await service.plans()).singleWhere((plan) => plan.id == id);

  test(
      'configures RevenueCat when it is created, without a user, and calls '
      'nothing else before the configuration completed', () async {
    final held = revenueCat.holdNext('setupPurchases');
    final service = serviceOfTests();
    final calls = Future.wait([service.identify(null), service.access()]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final whileHeld = revenueCat.methods;
    held.complete();
    await calls;

    expect(
      whileHeld,
      ['setupPurchases'],
      reason: 'iOS stops an app that calls RevenueCat before it is '
          'configured, so every call waits for the configuration.',
    );
    expect(revenueCat.methods, [
      'setupPurchases',
      'isAnonymous',
      'getCustomerInfo',
    ]);
    final setUp = revenueCat.calls.first.arguments as Map<Object?, Object?>;
    expect(
      (setUp['apiKey'], setUp['appUserId']),
      (googleKeyOfTests, null),
    );
  });

  test(
      'identifies a user of the app with logIn, and the user of the device '
      'with a logOut of a user of the app, and of no anonymous user', () async {
    final service = serviceOfTests();
    final user = freshUser('logged-in');
    await service.identify(null);
    revenueCat.calls.clear();

    await service.identify(user);
    final logIn = [...revenueCat.calls];
    revenueCat.calls.clear();
    await service.identify(null);
    final logOut = revenueCat.methods;
    revenueCat.calls.clear();
    await service.identify(null);

    expect([for (final call in logIn) call.method], ['logIn']);
    expect(logIn.single.arguments, {'appUserID': user});
    expect(logOut, ['isAnonymous', 'logOut']);
    expect(revenueCat.methods, ['isAnonymous']);
    expect(revenueCat.appUserId, startsWith(r'$RCAnonymousID:'));
  });

  test(
      'takes a logOut that RevenueCat fails because its user is anonymous for '
      'done, and fails with any other failure of a logOut', () async {
    final service = serviceOfTests();
    await service.identify(freshUser('logged-in'));

    revenueCat.failNext('logOut', '22');
    final anonymous = await errorOf(() => service.identify(null));
    revenueCat.failNext('logOut', '10');
    final network = await errorOf(() => service.identify(null));

    expect(anonymous, isNull);
    expect(network, failsWith(PurchasesFailureReason.network));
  });

  test(
      'reads the offerings for the plans, and on iOS asks whether the user may '
      'take the intro offers', () async {
    final service = serviceOfTests();
    await service.identify(null);
    revenueCat.calls.clear();

    await service.plans();
    final onAndroid = revenueCat.methods;
    revenueCat.calls.clear();
    await onPlatform(TargetPlatform.iOS, service.plans);

    expect(onAndroid, ['getOfferings']);
    expect(revenueCat.methods, [
      'getOfferings',
      'checkTrialOrIntroductoryPriceEligibility',
    ]);
    expect(revenueCat.calls.last.arguments, {
      'productIdentifiers': ['smf_premium_monthly'],
    });
  });

  test(
      'buys the package of a plan with its offering, restores and reads the '
      'access from the customer info of RevenueCat', () async {
    final service = serviceOfTests();
    await service.identify(freshUser('buyer'));
    final plan = await planOf(service, r'$rc_lifetime');
    revenueCat.calls.clear();

    await service.purchase(plan);
    final purchase = [...revenueCat.calls];
    revenueCat.calls.clear();
    await service.restore();
    await service.access();

    final arguments = purchase.single.arguments as Map<Object?, Object?>;
    expect(purchase.single.method, 'purchasePackage');
    expect(arguments['packageIdentifier'], r'$rc_lifetime');
    expect(arguments['presentedOfferingContext'], {
      'offeringIdentifier': 'default',
      'placementIdentifier': null,
      'targetingContext': null,
    });
    expect(revenueCat.methods, ['restorePurchases', 'getCustomerInfo']);
  });

  test(
      'gives each code of RevenueCat the reason of the purchases role, also a '
      'code that is no number', () async {
    final service = serviceOfTests();
    await service.identify(null);
    const reasons = {
      '20': PurchasesFailureReason.pending,
      '10': PurchasesFailureReason.network,
      '35': PurchasesFailureReason.network,
      '32': PurchasesFailureReason.network,
      '33': PurchasesFailureReason.network,
      '6': PurchasesFailureReason.alreadyOwned,
      '7': PurchasesFailureReason.alreadyOwned,
      '13': PurchasesFailureReason.alreadyOwned,
      '40': PurchasesFailureReason.alreadyOwned,
      '3': PurchasesFailureReason.notAllowed,
      '5': PurchasesFailureReason.unavailable,
      '4': PurchasesFailureReason.unavailable,
      '18': PurchasesFailureReason.unavailable,
      '23': PurchasesFailureReason.notConfigured,
      '11': PurchasesFailureReason.notConfigured,
      '17': PurchasesFailureReason.notConfigured,
      '19': PurchasesFailureReason.notConfigured,
      '2': PurchasesFailureReason.storeProblem,
      '8': PurchasesFailureReason.storeProblem,
      '9': PurchasesFailureReason.storeProblem,
      '12': PurchasesFailureReason.storeProblem,
      '16': PurchasesFailureReason.storeProblem,
      '29': PurchasesFailureReason.storeProblem,
      '30': PurchasesFailureReason.storeProblem,
      '37': PurchasesFailureReason.storeProblem,
      '42': PurchasesFailureReason.storeProblem,
      '0': PurchasesFailureReason.unknown,
      '14': PurchasesFailureReason.unknown,
      '15': PurchasesFailureReason.unknown,
      '22': PurchasesFailureReason.unknown,
      '99': PurchasesFailureReason.unknown,
      'error': PurchasesFailureReason.unknown,
    };
    final failures = <String, Object?>{};
    for (final code in reasons.keys) {
      revenueCat.failNext('getCustomerInfo', code);
      final failure = await errorOf(service.access);
      failures[code] = failure is PurchasesFailure ? failure.reason : failure;
    }

    expect(failures, reasons);
  });

  test(
      'gives a failure of RevenueCat a hint with its code and messages, and '
      'one that tells what to do for a key that RevenueCat refuses, a product '
      'that the store account owns, and a failure of the Test Store', () async {
    final service = serviceOfTests();
    await service.identify(null);
    Future<String?> hintOf(String code, {String? underlying}) async {
      revenueCat.failNext(
        'getCustomerInfo',
        code,
        message: 'RevenueCat failed.',
        underlying: underlying,
      );
      final failure = await errorOf(service.access);
      return (failure! as PurchasesFailure).developerHint;
    }

    expect(
      await hintOf('11', underlying: 'Invalid API Key.'),
      'RevenueCat refused REVENUECAT_GOOGLE_KEY of .env '
      '(invalidCredentialsError: RevenueCat failed. Invalid API Key.): copy '
      'the public API key of the app in RevenueCat into .env.',
    );
    expect(
      await hintOf('6'),
      'The store account owns the product already, and a restore gives the '
      'user its access (productAlreadyPurchasedError: RevenueCat failed.).',
    );
    expect(
      await hintOf('42'),
      'The Test Store of RevenueCat failed the purchase, as its dialog was '
      'told to (testStoreSimulatedPurchaseError: RevenueCat failed.).',
    );
    expect(await hintOf('2'), 'storeProblemError: RevenueCat failed.');
    expect(await hintOf('error'), 'code error: RevenueCat failed.');
  });

  test(
      'completes a purchase that the user cancelled with null, by the code or '
      'by the details of the failure', () async {
    final service = serviceOfTests();
    await service.identify(freshUser('canceller'));
    final plan = await planOf(service, r'$rc_annual');

    revenueCat.failNext('purchasePackage', '1');
    final byCode = await service.purchase(plan);
    revenueCat.failNext('purchasePackage', '2', userCancelled: true);
    final byDetails = await service.purchase(plan);

    expect((byCode, byDetails), (null, null));
    expect(await service.access(), const NoAccess());
  });

  test(
      'fails with notConfigured and a hint without a current offering, or with '
      'one without packages', () async {
    final service = serviceOfTests();
    await service.identify(null);

    revenueCat.packages = null;
    final none = await errorOf(service.plans);
    revenueCat.packages = const [];
    final empty = await errorOf(service.plans);

    expect(
      none,
      failsWith(
        PurchasesFailureReason.notConfigured,
        'RevenueCat has no current offering: make the offering with the '
        'packages of the app current in RevenueCat.',
      ),
    );
    expect(
      empty,
      failsWith(
        PurchasesFailureReason.notConfigured,
        'The current offering default of RevenueCat has no packages: add the '
        'packages of the app to it.',
      ),
    );
  });

  test(
      'fails a purchase that RevenueCat gives no active entitlement premium '
      'for with notConfigured, and a hint that names the product', () async {
    final service = serviceOfTests();
    await service.identify(freshUser('unattached'));
    final plan = await planOf(service, r'$rc_annual');
    revenueCat.unattached.add(r'$rc_annual');

    expect(
      await errorOf(() => service.purchase(plan)),
      failsWith(
        PurchasesFailureReason.notConfigured,
        'The user bought smf_premium:annual, but RevenueCat gives no active '
        'entitlement premium for it: attach the product to the entitlement '
        'premium in RevenueCat, and a restore gives the access.',
      ),
    );
  });

  test(
      'reads the offerings again for a plan that the service did not give, '
      'and fails with unavailable when the offering has no such package',
      () async {
    final service = serviceOfTests();
    await service.identify(freshUser('stranger'));
    const plan = Plan(
      id: r'$rc_weekly',
      title: 'Premium Weekly',
      price: r'$1.99',
      amount: 1.99,
      currencyCode: 'USD',
    );
    revenueCat.calls.clear();

    final failure = await errorOf(() => service.purchase(plan));

    expect(revenueCat.methods, ['getOfferings']);
    expect(
      failure,
      failsWith(
        PurchasesFailureReason.unavailable,
        r'The current offering of RevenueCat has no package $rc_weekly.',
      ),
    );
  });

  test('fails every call with the failure of the configuration', () async {
    revenueCat.failNext('setupPurchases', 'error', message: 'No context.');
    final service = serviceOfTests();

    expect(await service.configured, isFalse);
    expect(
      await errorOf(service.access),
      failsWith(
        PurchasesFailureReason.notConfigured,
        'RevenueCat refused to start with REVENUECAT_GOOGLE_KEY: No context.',
      ),
    );
    expect(revenueCat.methods, ['setupPurchases']);
  });

  test(
      'without the platform side of purchases_flutter, as in a test without '
      'its mocks, is not configured, and fails every call with notConfigured '
      'and a hint that says so', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('purchases_flutter'), null);
    final service = serviceOfTests();

    expect(
      await service.configured,
      isFalse,
      reason: 'A service that nothing calls leaves no error behind.',
    );
    expect(
      await errorOf(service.access),
      failsWith(
        PurchasesFailureReason.notConfigured,
        startsWith(
          'RevenueCat did not start with REVENUECAT_GOOGLE_KEY: the app has '
          'no platform side of purchases_flutter, as in a test without mocks '
          'of the method channel purchases_flutter',
        ),
      ),
    );
  });

  test(
      'leaves no error behind when nothing calls it, also without the '
      'platform side of purchases_flutter', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('purchases_flutter'), null);

    serviceOfTests();
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });

  test(
      'turns an error of another kind than of RevenueCat into the reason '
      'unknown, with the error as its hint', () async {
    final service = serviceOfTests();
    await service.identify(null);
    revenueCat.answerNext('getCustomerInfo', {'entitlements': 'none'});

    expect(
      await errorOf(service.access),
      failsWith(PurchasesFailureReason.unknown, contains('String')),
    );
  });

  test('throws nothing of the plugin', () async {
    final service = serviceOfTests();
    await service.identify(null);
    revenueCat.failNext('getOfferings', '10');

    expect(await errorOf(service.plans), isNot(isA<PlatformException>()));
  });
}
