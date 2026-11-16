// A test that continuous integration runs in the apps with the review role,
// whichever module provides it: a launch of the app counts itself, and asks
// for no review by itself. The app asks only where its code calls
// appReview.requestIfDue(), at a natural break, since the App Store asks
// apps not to request a review when the user launches them. A first launch
// saves one launch and the time of the first launch, and a later launch on
// which a review is due counts itself and keeps the first launch, and asks
// for nothing either once its screen is shown.
//
// It knows only the role. The app starts once, with main() of
// lib/main.dart, as on a device, with the mocks of the platform side of
// every module of the app, which the matrix sets up before the tests of
// each test file (flutter_test_config.dart), so the first test sees a first
// launch. The next launch is initPreferences() of the preferences role
// again, whose restorer of the role reads what the test saved, and
// initReview() of the role again, which starts appReview anew. The tests of
// the file run in their order. Each expectation gives its reason.
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/preferences/app_preferences.dart';
import 'package:{{app_name}}/core/review/app_review.dart';

import 'review_role.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  const timeout = Timeout(Duration(minutes: 2));

  testWidgets(
    'a first launch counts itself and saves the time of the first launch, '
    'and asks for no review by itself once its first screen is shown',
    (tester) async {
      final before = DateTime.now().toUtc();
      await startApp(tester);
      await showFrames(tester);
      final after = DateTime.now().toUtc();
      final saved = savedReviews;

      expect(
        saved.launches,
        1,
        reason: 'A launch of the app counts itself under the key of the role.',
      );
      expect(
        saved.firstLaunch,
        isA<DateTime>().having(
          (time) =>
              !time.isBefore(before.subtract(const Duration(seconds: 1))) &&
              !time.isAfter(after),
          'is the time of the launch',
          isTrue,
        ),
        reason: 'A first launch saves its time under the key of the role.',
      );
      expect(
        (saved.askedAt, saved.version),
        (null, null),
        reason: 'A launch asks for no review by itself: the app asks only '
            'where its code calls appReview.requestIfDue().',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'a later launch on which a review is due counts itself, keeps the first '
    'launch, and asks for no review by itself either',
    (tester) async {
      final now = DateTime.now().toUtc();
      await inRealTime(tester, 'the next launch', () async {
        await saveDueState(now: now);
        await initPreferences();
        await initReview();
      });
      await showFrames(tester);
      final saved = savedReviews;

      expect(
        (saved.launches, saved.firstLaunch),
        (
          10,
          DateTime.fromMillisecondsSinceEpoch(
            now.subtract(const Duration(days: 30)).millisecondsSinceEpoch,
            isUtc: true,
          ),
        ),
        reason: 'The next launch counts one more launch, and keeps the time of '
            'the first launch.',
      );
      expect(
        (saved.askedAt, saved.version),
        (null, null),
        reason: 'A launch on which a review is due asks for no review by '
            'itself: the app asks only where its code calls '
            'appReview.requestIfDue().',
      );
    },
    timeout: timeout,
  );
}
