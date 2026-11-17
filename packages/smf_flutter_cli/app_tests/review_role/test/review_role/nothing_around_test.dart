// A test that continuous integration runs in the apps with the review role,
// whichever module provides it: the app shows nothing of its own around the
// review dialog of the store, as the stores ask. Google Play forbids a
// question before the dialog, such as "Do you like the app?", and the App
// Store allows no prompt but its own. So when the provider asks the store
// for its dialog, the app shows no new text and no new modal barrier, which
// a dialog of its own would have. Nor does a request of appReview, which
// decides when a review is due.
//
// It knows only the role. The app starts once, with main() of
// lib/main.dart, as on a device, with the mocks of the platform side of
// every module of the app, which the matrix sets up before the tests of
// each test file (flutter_test_config.dart). The dialog of the store shows
// nothing that Flutter builds. Each expectation gives its reason, which a
// provider of the role with a known bug fails the test with
// (brokenProviders of the fixture registry).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/review/app_review.dart';

import 'review_role.dart';

/// Why the app shows nothing new around the review dialog.
const String _nothingAround = 'The provider asks the store for its dialog '
    'and shows nothing of its own around it, as the stores ask: the app '
    'showed something of its own around the review dialog.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  const timeout = Timeout(Duration(minutes: 2));

  testWidgets(
    'the provider asks the store for its dialog and shows nothing of its own '
    'around it',
    (tester) async {
      await startApp(tester);
      final before = shownBy(tester);
      await inRealTime(tester, 'asking the store', () async {
        // The request may wait for the dialog of the store, so the test does
        // not wait for it.
        unawaited(createReviewService().requestReview().catchError((_) {}));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await showFrames(tester);
      final after = shownBy(tester);

      expect(
        after.texts.difference(before.texts),
        isEmpty,
        reason: _nothingAround,
      );
      expect(
        after.barriers,
        lessThanOrEqualTo(before.barriers),
        reason: _nothingAround,
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'a request of appReview on which a review is due shows nothing of its '
    'own around the dialog of the store',
    (tester) async {
      final now = DateTime.now().toUtc();
      await inRealTime(
        tester,
        'saving a review that is due',
        () => saveDueState(now: now),
      );
      final service = ScriptedReview();
      final app = await launchWith(tester, service, now: () => now);
      final before = shownBy(tester);
      await requestIfDue(tester, app);
      await showFrames(tester);
      final after = shownBy(tester);

      expect(
        service.requests,
        1,
        reason: 'A review is due, so the request asks the store.',
      );
      const reason = 'A request of appReview shows nothing of its own '
          'around the dialog of the store.';
      expect(after.texts.difference(before.texts), isEmpty, reason: reason);
      expect(
        after.barriers,
        lessThanOrEqualTo(before.barriers),
        reason: reason,
      );
    },
    timeout: timeout,
  );
}
