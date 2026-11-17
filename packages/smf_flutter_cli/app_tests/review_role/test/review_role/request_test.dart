// A test that continuous integration runs in the apps with the review role,
// whichever module provides it: appReview.requestIfDue() over the service of
// the provider of the app, on a launch on which a review is due. It asks the
// store for its dialog at once, the provider shows nothing of its own
// around it, and the app saves the time and the version of the request
// once the store took it. A provider that asks the user a question of its
// own first, which the stores forbid, keeps the request waiting for the
// user, and the app saves nothing.
//
// It knows only the role. The app starts with main() of lib/main.dart, as
// on a device, with the mocks of the platform side of every module of the
// app, which the matrix sets up before the tests of each test file
// (flutter_test_config.dart). Those of every provider of the role keep to
// one convention: the store of the device can show its dialog, a request
// completes at once and shows nothing, and the version of the app is
// 1.0.0. The next launch is initPreferences() of the preferences role
// again, whose restorer of the role reads the state of a review that is
// due, which the test saved, and initReview() of the role again. Each
// expectation gives its reason, which a provider of the role with a known
// bug fails the test with (brokenProviders of the fixture registry).
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
    'requestIfDue() on a launch on which a review is due asks the store at '
    'once through the provider of the app, and the app saves the request '
    'once the store took it',
    (tester) async {
      await startApp(tester);
      final now = DateTime.now().toUtc();
      late String? version;
      var completed = false;
      await inRealTime(tester, 'requestIfDue()', () async {
        await saveDueState(now: now);
        await initPreferences();
        await initReview();
        version = await createReviewService().appVersion();
        // A request that waits for something else, such as an answer of
        // the user, would keep the test waiting forever.
        await Future.any([
          appReview.requestIfDue().then((_) => completed = true),
          Future<void>.delayed(const Duration(seconds: 5)),
        ]);
      });
      await showFrames(tester);
      final saved = savedReviews;

      expect(
        version,
        '1.0.0',
        reason: 'The mocks of the platform side of every provider give the '
            'app the version 1.0.0.',
      );
      expect(
        (completed, saved.askedAt != null, saved.version),
        (true, true, version),
        reason: 'The provider asks the store for its dialog at once, and the '
            'request completes once the store took it: the app then saves '
            'the time and the version of the request.',
      );
      expect(
        saved.askedAt,
        isA<DateTime>().having(
          (time) => !time.isBefore(now.subtract(const Duration(seconds: 1))),
          'is the time of the request',
          isTrue,
        ),
        reason: 'The app saves the time of the request.',
      );
    },
    timeout: timeout,
  );
}
