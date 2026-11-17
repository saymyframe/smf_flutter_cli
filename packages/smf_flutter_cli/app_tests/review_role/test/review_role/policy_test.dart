// A test that continuous integration runs in the apps with the review role,
// whichever module provides it: when a review is due, as the role says. No
// review is due before the third launch of the app, nor before three days
// have passed since its first launch. The app asks once a version, and not
// again within 14 days, also in a new version. A request that the store
// does not take saves nothing, nor does one in an unknown version, and two
// calls at once make one request. A request whose time is to come, after
// the clock of the device went back, counts as recent. The next launch
// counts one more launch and keeps the rest.
//
// It knows only the role. The start-up of the app runs first, as on a
// device, which opens the preferences of the app, with the mocks of the
// platform side of every module of the app, which the matrix sets up before
// the tests of each test file (flutter_test_config.dart). Each test then
// launches the app as controllers of its own, each with a clock of its own
// and a service of the tests, which scripts what a provider answers, over
// the preferences of the app, the real provider of the preferences role,
// and checks what the preferences keep under the keys of the role. Each
// expectation gives its reason.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/preferences/app_preferences.dart';

import 'review_role.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  const timeout = Timeout(Duration(minutes: 2));

  testWidgets(
    'no review is due before the third launch, the app asks once a version, '
    'and not again within 14 days, also in a new version',
    (tester) async {
      await startUp(tester);
      await inRealTime(tester, 'forgetting the reviews', forgetReviews);
      final start = DateTime.utc(2026, 1, 1, 12);
      var clock = start;
      final service = ScriptedReview();
      final requests = <int>[];
      Future<void> launch() async {
        final app = await launchWith(tester, service, now: () => clock);
        await requestIfDue(tester, app);
        requests.add(service.requests);
      }

      // The first two launches, ten days apart.
      await launch();
      clock = clock.add(const Duration(days: 10));
      await launch();
      // The third launch.
      clock = clock.add(const Duration(hours: 1));
      final askedAt = clock;
      final third = await launchWith(tester, service, now: () => clock);
      await requestIfDue(tester, third);
      requests.add(service.requests);
      final afterThird = savedReviews;
      await requestIfDue(tester, third);
      requests.add(service.requests);
      // A new version, five days after the request, a second before 14
      // days have passed since it, and 14 days after it.
      service.version = '1.1.0';
      clock = clock.add(const Duration(days: 5));
      await launch();
      clock = askedAt.add(const Duration(days: 14, seconds: -1));
      await launch();
      clock = askedAt.add(const Duration(days: 14));
      final askedAgain = clock;
      await launch();
      final afterNewVersion = savedReviews;
      // The same version, thirty days later.
      clock = clock.add(const Duration(days: 30));
      await launch();

      expect(
        requests.take(2),
        [0, 0],
        reason: 'No review is due before the third launch of the app.',
      );
      expect(
        requests[2],
        1,
        reason: 'A review is due on the third launch of the app, ten days '
            'after the first: the app asks the store once.',
      );
      expect(
        (
          afterThird.launches,
          afterThird.firstLaunch,
          afterThird.askedAt,
          afterThird.version,
        ),
        (3, start, askedAt, '1.0.0'),
        reason: 'The preferences keep the launches, the first launch, and the '
            'time and the version of the request, under the keys of the '
            'role.',
      );
      expect(
        requests[3],
        1,
        reason: 'The app asks at most once a version.',
      );
      expect(
        requests.sublist(4, 6),
        [1, 1],
        reason: 'The app does not ask again within 14 days, also in a new '
            'version: neither five days after the request nor a second '
            'before 14 days have passed since it.',
      );
      expect(
        (requests[6], afterNewVersion.askedAt, afterNewVersion.version),
        (2, askedAgain, '1.1.0'),
        reason: 'In a new version, 14 days after the last request, a review '
            'is due again.',
      );
      expect(
        requests[7],
        2,
        reason: 'The app does not ask twice in a version.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'no review is due before three days have passed since the first launch, '
    'however many launches',
    (tester) async {
      await startUp(tester);
      await inRealTime(tester, 'forgetting the reviews', forgetReviews);
      final start = DateTime.utc(2026, 2, 1, 12);
      var clock = start;
      final service = ScriptedReview();
      for (var launches = 0; launches < 6; launches++) {
        final app = await launchWith(tester, service, now: () => clock);
        await requestIfDue(tester, app);
        clock = clock.add(const Duration(hours: 12));
      }
      final early = service.requests;
      clock = start.add(const Duration(days: 3));
      final app = await launchWith(tester, service, now: () => clock);
      await requestIfDue(tester, app);

      expect(
        early,
        0,
        reason: 'No review is due before three days have passed since the '
            'first launch of the app.',
      );
      expect(
        (service.requests, savedReviews.launches),
        (1, 7),
        reason: 'Three days after the first launch, a review is due.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'a request that the store does not take saves nothing, and a later call '
    'asks again: a store that cannot show the dialog, a platform that '
    'refuses, and an unknown version',
    (tester) async {
      await startUp(tester);
      final now = DateTime.utc(2026, 3, 1, 12);
      await inRealTime(
        tester,
        'saving a review that is due',
        () => saveDueState(now: now),
      );
      final service = ScriptedReview(available: false);
      final app = await launchWith(tester, service, now: () => now);
      await requestIfDue(tester, app);
      final unavailable = (service.requests, savedReviews.askedAt);
      service
        ..available = true
        ..refuses = true;
      await requestIfDue(tester, app);
      final refused = (service.requests, savedReviews.askedAt);
      service
        ..refuses = false
        ..version = null;
      await requestIfDue(tester, app);
      final unknown = (service.requests, savedReviews.askedAt);
      service.version = '1.0.0';
      await requestIfDue(tester, app);

      expect(
        unavailable,
        (0, null),
        reason: 'The app asks nothing of a store that cannot show the '
            'dialog.',
      );
      expect(
        refused,
        (1, null),
        reason: 'A request that the platform refuses saves nothing: it counts '
            'as no dialog.',
      );
      expect(
        unknown,
        (1, null),
        reason: 'No review is due while the version of the app is unknown.',
      );
      expect(
        (service.requests, savedReviews.askedAt, savedReviews.version),
        (2, now, '1.0.0'),
        reason: 'A later call asks again, and the store takes it.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'two calls at once make one request, which the app saves once the store '
    'took it',
    (tester) async {
      await startUp(tester);
      final now = DateTime.utc(2026, 4, 1, 12);
      await inRealTime(
        tester,
        'saving a review that is due',
        () => saveDueState(now: now),
      );
      final service = ScriptedReview();
      final app = await launchWith(tester, service, now: () => now);
      late bool one;
      late DateTime? whileHeld;
      await inRealTime(tester, 'two calls at once', () async {
        final held = service.held = Completer<void>();
        final first = app.requestIfDue();
        final second = app.requestIfDue();
        one = identical(first, second);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        whileHeld = savedReviews.askedAt;
        held.complete();
        await first;
        await second;
      });

      expect(
        (one, service.requests),
        (true, 1),
        reason: 'A call while a request is on its way gets that request.',
      );
      expect(
        whileHeld,
        isNull,
        reason: 'The app saves a request once the store took it.',
      );
      expect(
        savedReviews.askedAt,
        now,
        reason: 'The app saves a request once the store took it.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'a request or a first launch whose time is to come, after the clock of '
    'the device went back, counts as recent, and the next launch counts one '
    'more launch and keeps the rest',
    (tester) async {
      await startUp(tester);
      final now = DateTime.utc(2026, 5, 1, 12);
      final service = ScriptedReview();
      await inRealTime(tester, 'saving a request to come', () async {
        await saveDueState(now: now);
        final preferences = createAppPreferences();
        await preferences.setInt(
          askedAtKey,
          now.add(const Duration(days: 1)).millisecondsSinceEpoch,
        );
        await preferences.setString(askedVersionKey, '0.9.0');
      });
      var app = await launchWith(tester, service, now: () => now);
      await requestIfDue(tester, app);
      final requestToCome = service.requests;
      await inRealTime(tester, 'saving a first launch to come', () async {
        await saveDueState(now: now, since: const Duration(days: -1));
      });
      app = await launchWith(tester, service, now: () => now);
      await requestIfDue(tester, app);
      final firstLaunchToCome = service.requests;
      final before = savedReviews;
      app = await launchWith(tester, service, now: () => now);
      final after = savedReviews;

      expect(
        requestToCome,
        0,
        reason: 'A request whose time is to come counts as recent.',
      );
      expect(
        firstLaunchToCome,
        0,
        reason: 'A first launch whose time is to come counts as recent.',
      );
      expect(
        (after.launches, after.firstLaunch),
        (before.launches! + 1, before.firstLaunch),
        reason: 'The next launch counts one more launch and keeps the first '
            'launch.',
      );
    },
    timeout: timeout,
  );
}
