// A test that continuous integration runs in the apps with the revenuecat
// module: the probe of the module, which the start check runs on a device,
// finds no problem after the start-up of the app, with the key of the tests,
// nor for a user with premium access. It reports an access of the app that
// RevenueCat does not give, a configured RevenueCat in an app without a key,
// and purchases that are not those of RevenueCat.
//
// The start-up of the app runs first, as on a device, with the mocks of the
// platform side of every module of the app, which the matrix sets up before
// the tests of each test file (flutter_test_config.dart), and a device of
// its own of the mocks of RevenueCat, which the test takes before the
// start-up.
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart' show Purchases;
import 'package:{{app_name}}/core/purchases/app_purchases.dart';
import 'package:{{app_name}}/core/purchases/purchases_service.dart';
import 'package:{{app_name}}/core/purchases/revenuecat_purchases_service.dart';

import '../../integration_test/revenuecat/probe.dart';
import '../revenuecat_mocks.dart';
import 'revenuecat.dart';

/// A service of purchases of the test, which is not that of RevenueCat.
final class _OtherPurchases implements PurchasesService {
  @override
  Future<void> identify(String? userId) async {}

  @override
  Future<AppAccess> access() async => const NoAccess();

  @override
  Stream<AppAccess> get accessChanges => const Stream.empty();

  @override
  Future<List<Plan>> plans() async => const [];

  @override
  Future<AppAccess?> purchase(Plan plan) async => null;

  @override
  Future<AppAccess> restore() async => const NoAccess();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  const timeout = Timeout(Duration(minutes: 2));

  late MockRevenueCat revenueCat;
  setUpAll(() => revenueCat = mockRevenueCat());

  testWidgets(
    'finds no problem after the start-up, nor for a user with premium access, '
    'and reports an access of the app that RevenueCat does not give',
    (tester) async {
      await startUp(tester);
      late List<String> afterStartUp;
      late List<String> withPremium;
      late List<String> withGrant;

      await inRealTime(tester, 'the probe after the start-up', () async {
        afterStartUp = await probeRevenueCat(() async {});
      });
      for (final user in [freshUser('throwaway'), freshUser('probed')]) {
        await inRealTime(
          tester,
          'starting the purchases',
          () =>
              appPurchases.start(createPurchasesService(), userId: () => user),
        );
      }
      await inRealTime(tester, 'a purchase and the probe', () async {
        final plans = await appPurchases.plans();
        await appPurchases.purchase(plans.last);
        withPremium = await probeRevenueCat(() async {});
      });
      final granted = freshUser('granted');
      await inRealTime(tester, 'a grant and the probe', () async {
        await appPurchases.start(
          createPurchasesService(),
          userId: () => granted,
        );
        revenueCat.grant(granted, until: DateTime.utc(2099));
        await Purchases.invalidateCustomerInfoCache();
        withGrant = await probeRevenueCat(() async {});
      });

      expect(afterStartUp, isEmpty);
      expect(withPremium, isEmpty);
      expect(withGrant, [
        'The app shows no premium access, but the entitlement premium is '
            'active in RevenueCat.',
      ]);
    },
    timeout: timeout,
  );

  testWidgets(
    'reports a configured RevenueCat in an app without a key, and purchases '
    'that are not those of RevenueCat',
    (tester) async {
      await startUp(tester);
      late List<String> withoutKey;
      late List<String> ofOther;

      await inRealTime(tester, 'the probe', () async {
        withoutKey = await problemsOf(
          RevenueCatPurchasesService(const RevenueCatKey.none('No key.')),
        );
        ofOther = await problemsOf(_OtherPurchases());
      });

      expect(withoutKey, [
        'RevenueCat is configured, though the app has no key for it: No key.',
      ]);
      expect(ofOther, [
        'The purchases of the app are not those of RevenueCat.',
      ]);
    },
    timeout: timeout,
  );
}
