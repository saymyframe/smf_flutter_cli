// A test that continuous integration runs in the apps with the revenuecat
// module: what the service makes of the offerings and of the customer info
// of RevenueCat. A plan is a package of the current offering, in its order,
// with the price of its product, its period from ISO 8601 and its intro
// offer, which on iOS shows only when iOS says that the user may take it,
// and on Android the title of its product without the name of the app,
// which Google Play appends. The access is the entitlement premium: until
// when, whether it renews, whether it is a free trial, the period of its
// plan and the page where the user manages it, also for a product of a base
// plan of Google Play and for a grant of the backend of RevenueCat, which
// the app sees once the cache of the customer info is emptied.
//
// It goes through the service of the module, on the real plugin, over a
// device of its own of the mocks of RevenueCat for each test.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as revenuecat;
import 'package:{{app_name}}/core/purchases/purchases_service.dart';

import '../revenuecat_mocks.dart';
import 'revenuecat.dart';

/// [plan] as a test compares it.
String _describePlan(Plan plan) {
  final intro = plan.introOffer;
  return [
    plan.id,
    plan.title,
    '${plan.price} (${plan.amount} ${plan.currencyCode})',
    'every ${plan.period}',
    if (intro != null)
      'intro ${intro.price} (${intro.amount}) for ${intro.cycles} x '
          '${intro.period}, free: ${intro.isFree}',
  ].join(' | ');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockRevenueCat revenueCat;
  setUp(() => revenueCat = mockRevenueCat());

  test(
      'gives the packages of the current offering as plans, in its order, '
      'with the titles of their products without the name of the app on '
      'Android, and the intro offer while the store account may take it',
      () async {
    final service = serviceOfTests();
    await service.identify(freshUser('plans'));

    final plans = await service.plans();
    final monthly = plans.first;
    await service.purchase(monthly);
    final afterTrial = await service.plans();

    expect(
      [for (final plan in plans) _describePlan(plan)],
      [
        r'$rc_monthly | Premium Monthly | $4.99 (4.99 USD) | every '
            r'BillingPeriod(1 month) | intro $0.00 (0.0) for 1 x '
            'BillingPeriod(1 week), free: true',
        r'$rc_annual | Premium Annual | $39.99 (39.99 USD) | every '
            'BillingPeriod(1 year)',
        r'$rc_lifetime | Premium Lifetime | $99.99 (99.99 USD) | every null',
      ],
    );
    expect(
      afterTrial.first.introOffer,
      isNull,
      reason: 'Google Play gives a product only the offers that the store '
          'account may take.',
    );
  });

  test(
      'on iOS, gives a plan its intro offer only when iOS says that the user '
      'may take it, and the titles of the products as they are', () async {
    final service = serviceOfTests();
    await service.identify(freshUser('ios'));
    final intros = <String, String?>{};

    await onPlatform(TargetPlatform.iOS, () async {
      for (final status in revenuecat.IntroEligibilityStatus.values) {
        revenueCat.eligibility = status;
        final monthly = (await service.plans()).first;
        intros[status.name] = monthly.introOffer?.price;
      }
      revenueCat.eligibility = null;
    });
    final titles = await onPlatform(
      TargetPlatform.iOS,
      () async => [for (final plan in await service.plans()) plan.title],
    );

    expect(intros, {
      'introEligibilityStatusUnknown': null,
      'introEligibilityStatusIneligible': null,
      'introEligibilityStatusEligible': r'$0.00',
      'introEligibilityStatusNoIntroOfferExists': null,
    });
    expect(titles, ['Premium Monthly', 'Premium Annual', 'Premium Lifetime']);
  });

  test(
      'gives the premium access of a plan that renews, in its free trial, with '
      'its end, its period and the page where the user manages it, the same '
      'from the purchase, from the customer info and from the changes that '
      'RevenueCat tells of', () async {
    final service = serviceOfTests();
    await service.identify(freshUser('trial'));
    final monthly = (await service.plans()).first;
    final told = <AppAccess>[];
    final changes = service.accessChanges.listen(told.add);

    final boughtAt = DateTime.now().toUtc();
    final bought = await service.purchase(monthly);
    await Future<void>.delayed(Duration.zero);
    final read = await service.access();
    await changes.cancel();

    expect(bought, isA<PremiumAccess>());
    final access = bought! as PremiumAccess;
    expect(
      (access.renews, access.inTrial, access.period, access.manageUrl),
      (
        true,
        true,
        const BillingPeriod(1, BillingUnit.month),
        Uri.parse('https://play.google.com/store/account/subscriptions'),
      ),
    );
    expect(
      access.expiresAt!.difference(boughtAt).inDays,
      7,
      reason: 'The free trial of the plan lasts a week.',
    );
    expect(read, access);
    expect(told, [access]);
  });

  test(
      'gives the premium access of a plan of a year, not in a trial, and of '
      'a plan paid once, for good, on Android and on iOS', () async {
    final accesses = <String>[];
    for (final platform in const [TargetPlatform.android, TargetPlatform.iOS]) {
      mockRevenueCat();
      await onPlatform(platform, () async {
        final service = serviceOfTests();
        for (final id in const [r'$rc_annual', r'$rc_lifetime']) {
          await service.identify(freshUser(id));
          final plan =
              (await service.plans()).singleWhere((plan) => plan.id == id);
          final boughtAt = DateTime.now().toUtc();
          final access = await service.purchase(plan) as PremiumAccess?;
          accesses.add(
            [
              platform.name,
              id,
              if (access?.expiresAt case final expiresAt?)
                'ends in ${(expiresAt.difference(boughtAt).inHours / 24 / 365).round()} year'
              else
                'for good',
              'renews: ${access?.renews}',
              'in trial: ${access?.inTrial}',
              'every ${access?.period}',
              'managed at ${access?.manageUrl}',
            ].join(' | '),
          );
        }
      });
    }

    expect(accesses, [
      r'android | $rc_annual | ends in 1 year | renews: true | in trial: '
          'false | every BillingPeriod(1 year) | managed at '
          'https://play.google.com/store/account/subscriptions',
      r'android | $rc_lifetime | for good | renews: false | in trial: false | '
          'every null | managed at null',
      r'iOS | $rc_annual | ends in 1 year | renews: true | in trial: false | '
          'every BillingPeriod(1 year) | managed at '
          'https://apps.apple.com/account/subscriptions',
      r'iOS | $rc_lifetime | for good | renews: false | in trial: false | '
          'every null | managed at null',
    ]);
  });

  test(
      'gives the premium access that the backend granted once the cache of the '
      'customer info is emptied: until its end, without renewal, period and '
      'page of a store', () async {
    final service = serviceOfTests();
    await service.identify(freshUser('granted'));
    final until = DateTime.utc(2099, 1, 2, 3, 4, 5);
    revenueCat.grant(revenueCat.appUserId!, until: until);

    final cached = await service.access();
    await revenuecat.Purchases.invalidateCustomerInfoCache();
    final fresh = await service.access();

    expect(
      cached,
      const NoAccess(),
      reason: 'RevenueCat answers from the cache of the customer info.',
    );
    expect(fresh, PremiumAccess(expiresAt: until));
  });

  test('gives no access without the entitlement premium', () async {
    final service = serviceOfTests();
    await service.identify(freshUser('none'));

    expect(await service.access(), const NoAccess());
    expect(await service.restore(), const NoAccess());
  });
}
