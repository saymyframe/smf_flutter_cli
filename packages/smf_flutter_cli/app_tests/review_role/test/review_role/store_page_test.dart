// A test that continuous integration runs in the apps with the review role,
// whichever module provides it: the page of the app in its store. On
// Android it is the Google Play page of the application id of the flavor
// for a release, also in the build of another flavor, as flutter test
// builds the default flavor. On iOS it is the App Store page of the App
// Store ID, which is all digits, and the page for a review has the action
// that writes one; without a usable ID, the app has no App Store page.
// appReview reads the ID from REVIEW_APP_STORE_ID in .env. Opening a page
// gives the service of the provider exactly that page, and no page opens
// without one or before the app started.
//
// It knows only the role, and the env role that it requires, whose AppEnv
// has the value of the key. The start-up of the app runs first, as on a
// device, with the mocks of the platform side of every module of the app,
// which the matrix sets up before the tests of each test file
// (flutter_test_config.dart). The platform is that of
// debugDefaultTargetPlatformOverride, which each test puts back before it
// ends. Each expectation gives its reason.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/env/app_env.dart';
import 'package:{{app_name}}/core/review/app_review.dart';

import 'review_role.dart';

/// What [controller] has of the pages of the app in its store on
/// [platform]: the page, the page for a review, and whether it has one.
(String, String, bool) _pagesOn(
  AppReviewController controller,
  TargetPlatform platform,
) {
  debugDefaultTargetPlatformOverride = platform;
  try {
    return (
      '${controller.storePage()}',
      '${controller.storePage(review: true)}',
      controller.hasStorePage,
    );
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  const timeout = Timeout(Duration(minutes: 2));

  testWidgets(
    'on Android, the page of the app is the Google Play page of the id of '
    'the flavor for a release, also in the build of another flavor',
    (tester) async {
      const play = 'https://play.google.com/store/apps/details?id=';

      expect(
        _pagesOn(AppReviewController(), TargetPlatform.android),
        ('$play$googlePlayId', '$play$googlePlayId', true),
        reason: 'On Android the app has its Google Play page, which is the '
            'page for a review too.',
      );
      expect(
        googlePlayId,
        matches(RegExp(r'^[A-Za-z][\w]*(\.[A-Za-z][\w]*)+$')),
        reason: 'googlePlayId is an application id of Android.',
      );
      expect(
        [
          for (final suffix in flavorSuffixes)
            if (googlePlayId.endsWith(suffix)) suffix,
        ],
        isEmpty,
        reason: 'The Google Play page is that of the flavor for a release, '
            'though flutter test builds another flavor: the id of another '
            'flavor has no page there.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'on iOS, the page of the app is the App Store page of its App Store ID, '
    'which is all digits, and the app has none without one',
    (tester) async {
      const appStore = 'https://apps.apple.com/app/id1234567890';

      expect(
        _pagesOn(
          AppReviewController(appStoreId: () => '1234567890'),
          TargetPlatform.iOS,
        ),
        (appStore, '$appStore?action=write-review', true),
        reason: 'With the App Store ID, the app has its App Store page, and '
            'the page for a review writes one.',
      );
      for (final id in [null, '', 'id1234567890', '123 456', '12a4']) {
        expect(
          _pagesOn(
            AppReviewController(appStoreId: () => id),
            TargetPlatform.iOS,
          ),
          ('null', 'null', false),
          reason: 'An App Store ID is all digits, so with "$id" the app has '
              'no App Store page.',
        );
      }
      final ofEnv = AppEnv.reviewAppStoreId;
      final digits = ofEnv != null && RegExp(r'^[0-9]+$').hasMatch(ofEnv);
      expect(
        _pagesOn(appReview, TargetPlatform.iOS).$3,
        digits,
        reason: 'appReview reads the App Store ID from REVIEW_APP_STORE_ID '
            'in .env.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'opening a page gives the service of the provider exactly that page, '
    'and opens none without one or before the app started',
    (tester) async {
      await startUp(tester);
      final service = ScriptedReview();
      final idle = AppReviewController(appStoreId: () => '1234567890');
      final now = DateTime.now().toUtc();
      late bool beforeTheStart;
      await inRealTime(tester, 'opening a page before the start', () async {
        beforeTheStart = await idle.openStorePage();
      });
      final android = await launchWith(tester, service, now: () => now);
      final iOS = await launchWith(
        tester,
        service,
        now: () => now,
        appStoreId: () => '1234567890',
      );
      final withoutId = await launchWith(
        tester,
        service,
        now: () => now,
        appStoreId: () => null,
      );
      final opened = <bool>[];
      Future<void> open(
        AppReviewController controller,
        TargetPlatform platform, {
        bool review = false,
      }) =>
          inRealTime(tester, 'opening a page', () async {
            debugDefaultTargetPlatformOverride = platform;
            try {
              opened.add(await controller.openStorePage(review: review));
            } finally {
              debugDefaultTargetPlatformOverride = null;
            }
          });
      await open(android, TargetPlatform.android);
      await open(iOS, TargetPlatform.iOS, review: true);
      service.opens = false;
      await open(iOS, TargetPlatform.iOS);
      await open(withoutId, TargetPlatform.iOS);

      expect(
        beforeTheStart,
        isFalse,
        reason: 'No page opens before the app started.',
      );
      expect(
        service.pages,
        [
          Uri.parse(
            'https://play.google.com/store/apps/details?id=$googlePlayId',
          ),
          Uri.parse(
            'https://apps.apple.com/app/id1234567890?action=write-review',
          ),
          Uri.parse('https://apps.apple.com/app/id1234567890'),
        ],
        reason: 'Opening a page gives the service of the provider exactly '
            'the page of the app in its store.',
      );
      expect(
        opened,
        [true, true, false, false],
        reason: 'openStorePage() returns whether an app of the device opened '
            'the page, and false without a page.',
      );
    },
    timeout: timeout,
  );
}
