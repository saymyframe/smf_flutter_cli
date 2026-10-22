// A test that continuous integration runs in the apps with the revenuecat
// module: the key of .env with which the app configures RevenueCat. A
// debug build takes the key of the Test Store when .env has one, and no
// other build ever does, since RevenueCat stops such a build on purpose;
// otherwise the app takes the key of the store of the platform. It takes no
// empty key, no secret key and, outside a debug build, no key of the Test
// Store, and says which key to fill in. The app reads the keys from .env,
// where the matrix wrote the keys of the tests. And without a key, the
// service calls nothing of RevenueCat, since iOS stops an app that calls it
// before it is configured, and fails every call with notConfigured.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/purchases/purchases_service.dart';
import 'package:{{app_name}}/core/purchases/revenuecat_purchases_service.dart';

import '../revenuecat_mocks.dart';
import 'revenuecat.dart';

/// The key that [revenueCatKey] chooses, as a test compares it: the name of
/// the key and its value, or the hint of no key.
String _chosen({
  TargetPlatform platform = TargetPlatform.android,
  bool debug = true,
  String? apple = 'appl_a',
  String? google = 'goog_g',
  String? test,
}) {
  final key = revenueCatKey(
    platform: platform,
    debug: debug,
    apple: apple,
    google: google,
    test: test,
  );
  return key.value == null ? 'none: ${key.hint}' : '${key.name}=${key.value}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('revenueCatKey', () {
    test(
        'takes the key of the Test Store in a debug build when .env has '
        'one, on iOS and on Android', () {
      expect(
        [
          _chosen(test: 'test_t'),
          _chosen(platform: TargetPlatform.iOS, test: 'test_t'),
          _chosen(apple: null, google: null, test: 'test_t'),
        ],
        everyElement('REVENUECAT_TEST_KEY=test_t'),
      );
    });

    test(
        'never takes the key of the Test Store in a profile or release '
        'build, and takes the key of the store of the platform', () {
      expect(
        [
          _chosen(debug: false, test: 'test_t'),
          _chosen(platform: TargetPlatform.iOS, debug: false, test: 'test_t'),
          _chosen(),
          _chosen(platform: TargetPlatform.iOS),
        ],
        [
          'REVENUECAT_GOOGLE_KEY=goog_g',
          'REVENUECAT_APPLE_KEY=appl_a',
          'REVENUECAT_GOOGLE_KEY=goog_g',
          'REVENUECAT_APPLE_KEY=appl_a',
        ],
      );
    });

    test(
        'takes no empty key, and names the key to fill in, and in a debug '
        'build the key of the Test Store too', () {
      expect(
        _chosen(google: null),
        'none: REVENUECAT_GOOGLE_KEY in .env is empty: fill it in with the '
        'public API key of the Play Store app in RevenueCat, or fill in '
        'REVENUECAT_TEST_KEY with the public API key of the Test Store.',
      );
      expect(
        _chosen(platform: TargetPlatform.iOS, debug: false, apple: null),
        'none: REVENUECAT_APPLE_KEY in .env is empty: fill it in with the '
        'public API key of the App Store app in RevenueCat.',
      );
    });

    test('takes no secret key of RevenueCat', () {
      expect(
        [
          _chosen(google: 'sk_secret'),
          _chosen(test: 'sk_secret'),
        ],
        [
          'none: REVENUECAT_GOOGLE_KEY in .env is a secret key of RevenueCat, '
              'which never goes into an app: use the public API key of the '
              'Play Store app.',
          'none: REVENUECAT_TEST_KEY in .env is a secret key of RevenueCat, '
              'which never goes into an app: use the public API key of the '
              'Test Store.',
        ],
      );
    });

    test(
        'takes no key of the Test Store in place of the key of a store in a '
        'profile or release build, and takes it in a debug build', () {
      expect(
        _chosen(debug: false, google: 'test_t'),
        'none: REVENUECAT_GOOGLE_KEY in .env is a key of the Test Store, which '
        'RevenueCat refuses in a profile or release build: use the public API '
        'key of the Play Store app.',
      );
      expect(_chosen(google: 'test_t'), 'REVENUECAT_GOOGLE_KEY=test_t');
    });

    test('takes no key on a platform other than Android and iOS', () {
      expect(
        _chosen(platform: TargetPlatform.macOS),
        'none: The app sells through RevenueCat on Android and iOS only, and '
        'runs on macOS here.',
      );
    });
  });

  test(
      'the app configures RevenueCat with the key of the store of the '
      'platform from .env, which has the keys of the tests', () async {
    final keys = <TargetPlatform, String?>{};
    for (final platform in const [TargetPlatform.android, TargetPlatform.iOS]) {
      final revenueCat = mockRevenueCat();
      await onPlatform(platform, () async {
        await createRevenueCatPurchasesService().access();
      });
      keys[platform] = revenueCat.apiKey;
    }

    expect(
      keys,
      {
        TargetPlatform.android: googleKeyOfTests,
        TargetPlatform.iOS: appleKeyOfTests,
      },
      reason: 'A debug build without the key of the Test Store takes the key '
          'of the store of the platform, which the app reads from .env.',
    );
  });

  test(
      'without a key, the service calls nothing of RevenueCat, tells of no '
      'change, and fails every call with notConfigured and the hint of the '
      'key', () async {
    final revenueCat = mockRevenueCat();
    final service = RevenueCatPurchasesService(
      const RevenueCatKey.none('REVENUECAT_GOOGLE_KEY in .env is empty.'),
    );
    const plan = Plan(
      id: r'$rc_monthly',
      title: 'Premium Monthly',
      price: r'$4.99',
      amount: 4.99,
      currencyCode: 'USD',
    );

    final failures = [
      await errorOf(() => service.identify(null)),
      await errorOf(() => service.identify('a user')),
      await errorOf(service.access),
      await errorOf(service.plans),
      await errorOf(() => service.purchase(plan)),
      await errorOf(service.restore),
    ];

    expect(
      failures,
      everyElement(
        failsWith(
          PurchasesFailureReason.notConfigured,
          'REVENUECAT_GOOGLE_KEY in .env is empty.',
        ),
      ),
    );
    expect(await service.configured, isFalse);
    expect(await service.accessChanges.isEmpty, isTrue);
    expect(
      revenueCat.calls,
      isEmpty,
      reason: 'Without a key, the service never calls RevenueCat: iOS stops '
          'an app that calls it before it is configured.',
    );
  });
}
