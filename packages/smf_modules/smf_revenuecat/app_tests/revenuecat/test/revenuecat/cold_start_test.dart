// A test that continuous integration runs in the apps with the revenuecat
// module: the access of a subscriber at the start of the app has the period
// of the plan, though the app has not asked for the plans. An earlier launch
// bought the plan of a month, and the first access of a new service has its
// period, which RevenueCat gives only with the offerings.
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
      'the first access of a start of the app has the period of the plan '
      'that the user bought at an earlier launch', () async {
    mockRevenueCat();
    // The earlier launch, which bought the plan of a month with RevenueCat
    // itself.
    await revenuecat.Purchases.configure(
      revenuecat.PurchasesConfiguration(googleKeyOfTests),
    );
    final offerings = await revenuecat.Purchases.getOfferings();
    await revenuecat.Purchases.purchase(
      revenuecat.PurchaseParams.package(offerings.current!.monthly!),
    );

    final service = serviceOfTests();
    await service.identify(null);
    final access = await service.access();

    expect(
      access,
      isA<PremiumAccess>().having(
        (access) => access.period,
        'period',
        const BillingPeriod(1, BillingUnit.month),
      ),
      reason: 'The service reads the offerings for the period of the plan of '
          'an access, which the info of the customer does not have.',
    );
  });
}
