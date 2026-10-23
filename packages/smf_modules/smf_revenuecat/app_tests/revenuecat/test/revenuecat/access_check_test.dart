// A test that continuous integration runs in the apps with the revenuecat
// module: the check of the access that the probe of the module starts in
// the start check (checkAccess of integration_test/revenuecat/probe.dart).
// Once RevenueCat knows the customer, it writes a request for the
// entitlement premium until an hour from now into the temporary directory
// of the app, which .github/scripts/start_app.sh of the repository of SMF
// answers in CI with a grant of RevenueCat, and then its verdict: `passed`
// once appPurchases shows that access, and `failed: ` and the problem when
// it shows access that ends at another time or renews, none in time, or
// access before the check asked for it, which then asks for nothing, as it
// does when RevenueCat is not configured. Neither the request nor the
// verdict has the key of RevenueCat. Here the test answers, with a grant of
// the backend of the mocks of RevenueCat, which reaches the app once the
// check reads the customer info anew.
//
// It has a file of its own, since the probe starts the check once in a run
// of the app, and the start-up of the app runs once in a test file. The
// start-up runs first, as on a device, with the mocks of the platform side
// of every module of the app, which the matrix sets up before the tests of
// each test file (flutter_test_config.dart), and a device of its own of the
// mocks of RevenueCat. The temporary directory of the app is one of the
// test.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
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
  late Directory temporary;

  setUpAll(() => revenueCat = mockRevenueCat());
  setUp(() => temporary = Directory.systemTemp.createTempSync('revenuecat_'));
  tearDown(() => temporary.deleteSync(recursive: true));

  File request() => File('${temporary.path}/smf_start_request_revenuecat');
  File report() => File('${temporary.path}/smf_start_report_revenuecat');

  /// The text of [file] once the check wrote it, in at most 10 seconds.
  Future<String?> written(File file) async {
    final until = DateTime.now().add(const Duration(seconds: 10));
    while (!file.existsSync() && DateTime.now().isBefore(until)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return file.existsSync() ? file.readAsStringSync().trim() : null;
  }

  /// Runs [action] in real time, and returns the lines that the check of
  /// the access printed meanwhile. A widget test ends with debugPrint as it
  /// began.
  Future<List<String>> checking(
    WidgetTester tester,
    Future<void> Function() action,
  ) async {
    final printed = <String>[];
    final previous = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message case final line?
          when line.startsWith('The check of the access')) {
        printed.add(line);
      }
    };
    try {
      await inRealTime(tester, 'checking the access', action);
    } finally {
      debugPrint = previous;
    }
    return printed;
  }

  /// Starts the purchases of the app with a user that no logIn named. The
  /// first such user of a test file takes over what the user of the device
  /// bought, as the mocks of another module may have, such as one that
  /// opens a guard of premium access for the tests of the app; so a test
  /// starts with a throwaway user first.
  Future<void> startWithNewUser(WidgetTester tester, String name) {
    final user = freshUser(name);
    return inRealTime(
      tester,
      'starting the purchases',
      () => appPurchases.start(createPurchasesService(), userId: () => user),
    );
  }

  /// The keys of the tests, which neither a request nor a verdict may have.
  Matcher withoutKeys() => allOf(
        isNot(contains(googleKeyOfTests)),
        isNot(contains(appleKeyOfTests)),
      );

  testWidgets(
    'the probe asks once for premium access for the user of the app until '
    'an hour from now, and reports that it reached the app as asked for, '
    'without the key',
    (tester) async {
      await startUp(tester);
      // A user without purchases, whatever the mocks of the other modules
      // bought for the user of the device.
      await startWithNewUser(tester, 'throwaway');
      await startWithNewUser(tester, 'probed');
      late List<String> problems;
      String? requested;
      String? verdict;
      var askedAgain = true;
      final before = DateTime.now();

      final printed = await checking(tester, () async {
        problems = await IOOverrides.runZoned(
          () => probeRevenueCat(() async {}),
          getSystemTempDirectory: () => temporary,
        );
        requested = await written(request());
        if (requested == null) return;
        final asked = jsonDecode(requested!) as Map<String, Object?>;
        revenueCat.grant(
          asked['appUserId']! as String,
          until: DateTime.fromMillisecondsSinceEpoch(
            asked['expiresAt']! as int,
            isUtc: true,
          ),
        );
        verdict = await written(report());
        // The probe of a second run of the start check asks for nothing.
        request().deleteSync();
        await IOOverrides.runZoned(
          () => probeRevenueCat(() async {}),
          getSystemTempDirectory: () => temporary,
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
        askedAgain = request().existsSync();
      });

      expect(problems, isEmpty);
      expect(requested, isNotNull, reason: 'The probe asked for nothing.');
      final asked = jsonDecode(requested!) as Map<String, Object?>;
      expect(asked.keys, {'appUserId', 'entitlement', 'expiresAt'});
      expect(asked['appUserId'], revenueCat.appUserId);
      expect(asked['entitlement'], 'premium');
      final expiresAt = asked['expiresAt']! as int;
      expect(expiresAt % 1000, 0, reason: 'Whole seconds.');
      final hour = before.add(const Duration(hours: 1)).millisecondsSinceEpoch;
      expect(expiresAt, inInclusiveRange(hour - 1000, hour + 60000));
      expect(verdict, 'passed');
      expect(askedAgain, isFalse);
      expect(requested, withoutKeys());
      expect(printed.join('\n'), withoutKeys());
      expect(printed, contains('The check of the access passed'));
      expect(
        appPurchases.value,
        isA<PremiumAccess>()
            .having((access) => access.renews, 'renews', isFalse)
            .having(
              (access) => access.expiresAt,
              'expiresAt',
              DateTime.fromMillisecondsSinceEpoch(expiresAt, isUtc: true),
            ),
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'the check reports access that ends at another time, no access in its '
    'time, and access before it asked, for which it asks nothing',
    (tester) async {
      await startUp(tester);
      const short = Duration(milliseconds: 600);
      const interval = Duration(milliseconds: 50);
      late String otherEnd;
      late String none;
      late String before;
      String? requestBefore;

      await startWithNewUser(tester, 'throwaway');
      await startWithNewUser(tester, 'other end');
      await checking(tester, () async {
        final check = checkAccess(
          directory: temporary,
          wait: const Duration(seconds: 5),
          interval: interval,
        );
        final asked = jsonDecode((await written(request()))!) as Map;
        revenueCat.grant(
          asked['appUserId']! as String,
          until: DateTime.fromMillisecondsSinceEpoch(
            asked['expiresAt']! as int,
            isUtc: true,
          ).add(const Duration(hours: 3)),
        );
        otherEnd = await check;
      });

      await startWithNewUser(tester, 'none');
      await checking(tester, () async {
        none = await checkAccess(
          directory: temporary,
          wait: short,
          interval: interval,
        );
      });

      await startWithNewUser(tester, 'buyer');
      await checking(tester, () async {
        final plans = await appPurchases.plans();
        await appPurchases.purchase(plans.last);
        request().deleteSync();
        before = await checkAccess(
          directory: temporary,
          wait: short,
          interval: interval,
        );
        requestBefore = await written(request()).timeout(
          const Duration(seconds: 1),
          onTimeout: () => null,
        );
      });

      expect(
        otherEnd,
        matches(
          RegExp(
            r'^failed: the app shows premium access \(ends at \S+, does not '
            r'renew\) rather than the access that the check asked for, which '
            r'ends at \S+ and does not renew$',
          ),
        ),
      );
      expect(
        none,
        startsWith(
          'failed: the app shows no premium access 600 ms after the check '
          'asked for it, in the state ',
        ),
      );
      expect(
        before,
        'failed: the app shows premium access (never ends, does not renew) '
        'before the check asked for any, which the user of a new install does '
        'not have',
      );
      expect(requestBefore, isNull);
      expect(report().readAsStringSync().trim(), before);
    },
    timeout: timeout,
  );

  testWidgets(
    'the check asks for nothing when RevenueCat is not configured, without '
    'a key or with one that RevenueCat refused, and tells why, or when the '
    'purchases of the app are not those of RevenueCat',
    (tester) async {
      await startUp(tester);
      late String withoutKey;
      late String refused;
      late String ofOther;

      await checking(tester, () async {
        withoutKey = await checkAccess(
          service: RevenueCatPurchasesService(
            const RevenueCatKey.none('REVENUECAT_TEST_KEY has no value.'),
          ),
          directory: temporary,
        );
        // RevenueCat on Android refuses to start with an empty key, and
        // stays as it was.
        refused = await checkAccess(
          service: RevenueCatPurchasesService(
            const RevenueCatKey('REVENUECAT_GOOGLE_KEY', ''),
          ),
          directory: temporary,
        );
        ofOther = await checkAccess(
          service: _OtherPurchases(),
          directory: temporary,
        );
      });

      expect(
        withoutKey,
        'failed: RevenueCat is not configured in this build, so no access can '
        'reach the app: REVENUECAT_TEST_KEY has no value.',
      );
      expect(
        refused,
        'failed: RevenueCat is not configured in this build, so no access can '
        'reach the app: RevenueCat refused to start with '
        'REVENUECAT_GOOGLE_KEY: API key must be set. Get this from the '
        'RevenueCat web app',
      );
      expect(revenueCat.apiKey, googleKeyOfTests);
      expect(
        ofOther,
        'failed: the purchases of the app are not those of RevenueCat',
      );
      expect(request().existsSync(), isFalse);
      expect(report().readAsStringSync().trim(), ofOther);
    },
    timeout: timeout,
  );
}
