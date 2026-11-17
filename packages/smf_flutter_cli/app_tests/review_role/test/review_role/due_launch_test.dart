// A test that continuous integration runs in the apps with the review role,
// whichever module provides it: a launch on which a review is due counts
// itself, and asks for no review on its own, neither while the app starts
// nor once its first screen is shown. The app asks only where its code
// calls appReview.requestIfDue(), at a natural break, since the App Store
// asks apps not to request a review when the user launches them. So no
// widget around the root of the app or around the screen of a route, and
// no callback of the first frame, may ask.
//
// It knows only the role, and the preferences role that it requires. The
// device has kept the state of a review that is due, which the test saves
// under the keys of the role through the preferences of the app, once it
// has opened them with initPreferences() as the start-up does. The app then
// starts once, with main() of lib/main.dart, as on a device, with the mocks
// of the platform side of every module of the app, which the matrix sets up
// before the tests of each test file (flutter_test_config.dart), and whose
// start-up opens the preferences anew and reads that state. A start-up runs
// once in a test file, so this test has a file of its own. Each expectation
// gives its reason.
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/preferences/app_preferences.dart';

import 'review_role.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'a launch on which a review is due counts itself, and asks for no review '
    'on its own once its first screen is shown',
    (tester) async {
      final now = DateTime.now().toUtc();
      await inRealTime(tester, 'what the device kept', () async {
        await initPreferences();
        await saveDueState(now: now);
      });
      await startApp(tester);
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
        reason: 'The launch counts one more launch, and keeps the time of the '
            'first launch that the device kept.',
      );
      expect(
        (saved.askedAt, saved.version),
        (null, null),
        reason: 'A launch on which a review is due asks for no review on its '
            'own, neither while the app starts nor once its first screen is '
            'shown: the app asks only where its code calls '
            'appReview.requestIfDue().',
      );
    },
    // A widget test fails after ten minutes by default; a test that hangs
    // fails sooner.
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
