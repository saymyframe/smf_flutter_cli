// A test that continuous integration runs in the apps with the revenuecat
// module: the access of a subscriber at the start of the app waits only a
// moment for the offerings, which tell the period of the plan, so that the
// app knows the access before its first frame also when RevenueCat does not
// give the offerings, as without a network. The access then has no period,
// and a later access has it once RevenueCat gives the offerings.
//
// It is a file of its own, since the service keeps the periods of the
// offerings that it read for as long as the app runs, which here is the
// test file.
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as revenuecat;
import 'package:{{app_name}}/core/purchases/purchases_service.dart';

import '../revenuecat_mocks.dart';
import 'revenuecat.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'the access of a start of the app does not wait for offerings that '
      'RevenueCat does not give, and has the period once it gives them',
      () async {
    final revenueCat = mockRevenueCat();
    // An earlier launch, which bought the plan of a month with RevenueCat
    // itself.
    await revenuecat.Purchases.configure(
      revenuecat.PurchasesConfiguration(googleKeyOfTests),
    );
    final offerings = await revenuecat.Purchases.getOfferings();
    await revenuecat.Purchases.purchase(
      revenuecat.PurchaseParams.package(offerings.current!.monthly!),
    );

    final held = revenueCat.holdNext('getOfferings');
    final service = serviceOfTests();
    await service.identify(null);
    final took = Stopwatch()..start();
    final first = await service.access().timeout(
          const Duration(seconds: 10),
          onTimeout: () => fail('The access waited for the offerings.'),
        );
    took.stop();
    held.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final later = await service.access();

    expect(
      (first as PremiumAccess).period,
      isNull,
      reason: 'Without the offerings, the access has no period.',
    );
    expect(
      took.elapsed,
      lessThan(const Duration(seconds: 3)),
      reason: 'The access waits only a moment for the offerings, well within '
          'the time that the start of the purchases waits for it.',
    );
    expect(
      (later as PremiumAccess).period,
      const BillingPeriod(1, BillingUnit.month),
      reason: 'Once RevenueCat gives the offerings, the access has the period '
          'of its plan.',
    );
  });
}
