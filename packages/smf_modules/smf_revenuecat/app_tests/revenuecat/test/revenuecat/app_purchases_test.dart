// A test that continuous integration runs in the apps with the revenuecat
// module: what RevenueCat tells reaches appPurchases of the purchases role.
// The start-up of the app configures RevenueCat with the key of the tests
// from .env; a purchase gives appPurchases the premium access; and a grant
// of the backend of RevenueCat, which the device sees only once the cache of
// the customer info is emptied, reaches appPurchases when the user comes
// back to the app, and when the SDK refreshes the customer info itself and
// tells the app.
//
// The start-up of the app runs first, as on a device, with the mocks of the
// platform side of every module of the app, which the matrix sets up before
// the tests of each test file (flutter_test_config.dart), and a device of
// its own of the mocks of RevenueCat, which the test takes before the
// start-up. Each test starts appPurchases with the service of the app and a
// user of its own, as a start of the app does with the user of the app, and
// first with a throwaway user, which takes over what the user of the device
// bought, such as a plan that the mocks of a module bought before the app
// started.
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart' show Purchases;
import 'package:{{app_name}}/core/purchases/app_purchases.dart';

import '../revenuecat_mocks.dart';
import 'revenuecat.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  const timeout = Timeout(Duration(minutes: 2));

  late MockRevenueCat revenueCat;
  setUpAll(() => revenueCat = mockRevenueCat());

  /// Runs the start-up of the app once for the tests of the file, and starts
  /// appPurchases with a throwaway user and then with a fresh user [name].
  Future<void> startAs(WidgetTester tester, String name) async {
    await startUp(tester);
    for (final user in [freshUser('throwaway'), freshUser(name)]) {
      await inRealTime(
        tester,
        'starting the purchases',
        () => appPurchases.start(createPurchasesService(), userId: () => user),
      );
    }
  }

  testWidgets(
    'the start-up configures RevenueCat with the key of the tests, and a '
    'purchase gives appPurchases the premium access',
    (tester) async {
      await startAs(tester, 'buyer');
      await inRealTime(tester, 'buying a plan of a year', () async {
        final plans = await appPurchases.plans();
        await appPurchases.purchase(
          plans.singleWhere((plan) => plan.id == r'$rc_annual'),
        );
      });

      expect(revenueCat.apiKey, googleKeyOfTests);
      expect(
        appPurchases.value,
        isA<PremiumAccess>().having(
          (access) => access.period,
          'period',
          const BillingPeriod(1, BillingUnit.year),
        ),
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'a grant of the backend reaches appPurchases when the user comes back to '
    'the app once the cache of the customer info is emptied',
    (tester) async {
      await startAs(tester, 'granted');
      final until = DateTime.utc(2099);
      revenueCat.grant(revenueCat.appUserId!, until: until);

      await comeBack(tester);
      final cached = appPurchases.value;
      await inRealTime(
        tester,
        'emptying the cache of the customer info',
        Purchases.invalidateCustomerInfoCache,
      );
      await comeBack(tester);

      expect(
        cached,
        const NoAccess(),
        reason: 'RevenueCat answers from the cache of the customer info.',
      );
      expect(appPurchases.value, PremiumAccess(expiresAt: until));
    },
    timeout: timeout,
  );

  testWidgets(
    'a grant of the backend reaches appPurchases when the SDK refreshes the '
    'customer info and tells the app',
    (tester) async {
      await startAs(tester, 'told');
      final until = DateTime.utc(2098);
      revenueCat.grant(revenueCat.appUserId!, until: until);

      await inRealTime(tester, 'a refresh of the SDK', () async {
        await revenueCat.refresh();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });

      expect(appPurchases.value, PremiumAccess(expiresAt: until));
    },
    timeout: timeout,
  );
}
