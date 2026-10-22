// A test that continuous integration runs in the apps with the purchases
// role, whichever module provides it: a service that the function of the
// provider creates again has what the store and the provider kept, so the
// next start of the app has the premium access that a user bought.
//
// It knows only the role. The start-up of the app runs first, as on a
// device, with the mocks of the platform side of every module of the app,
// which the matrix sets up before the tests of each test file
// (flutter_test_config.dart), and the mocks keep the purchases of each user
// from one launch of the app to the next, as the role asks of them. The
// test identifies a throwaway user first, and then a fresh user of its
// own, who buys a plan (purchases_role.dart). The next start is
// initPurchases() of the role again, which creates the service of the
// provider anew and starts appPurchases with it, and then the test starts
// appPurchases with that service and the same user. Each expectation gives
// its reason, which a provider of the role with a known bug fails the test
// with (brokenProviders of the fixture registry).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/purchases/app_purchases.dart';

import 'purchases_role.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  const timeout = Timeout(Duration(minutes: 2));

  testWidgets(
    'the store keeps what a user bought, so the next start has the premium '
    'access of that user',
    (tester) async {
      await startUp(tester);
      await identifyThrowaway(tester);
      final user = freshUser('next_start');
      await startAs(tester, createPurchasesService(), user);
      Object? failure;
      await inRealTime(tester, 'buying a plan', () async {
        final plans = await appPurchases.plans();
        failure = await errorOf(() => appPurchases.purchase(plans.first));
        await aMoment();
      });
      final bought = describe(appPurchases.value);

      await inRealTime(tester, 'initPurchases()', initPurchases);
      await startAs(tester, createPurchasesService(), user);
      final next = describe(appPurchases.value);

      expect(
        (failure, bought.startsWith('premium access')),
        (null, true),
        reason: 'A purchase by a user without premium access succeeds, and '
            'gives that user premium access.',
      );
      expect(
        next,
        bought,
        reason: 'The store keeps what a user bought, so the next start has '
            'it: a service that the function of the provider creates again '
            'gives the user the same premium access.',
      );
    },
    timeout: timeout,
  );
}
