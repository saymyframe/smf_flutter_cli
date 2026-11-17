// A test that continuous integration runs in the apps with the review role,
// whichever module provides it: the probe of the role, which the start check
// runs on a device. On a first launch of the app through main(), with the
// service of the provider, it finds nothing wrong. It reports a service that
// does not tell in time whether the store can show its dialog, or fails to,
// and preferences without this launch counted, without the time of the
// first launch or with one that is to come, and with a request on the first
// launch. A store that cannot show the dialog is no problem.
//
// It knows only the role, and the preferences role that it requires. The
// app starts once, with main() of lib/main.dart, as on a device, with the
// mocks of the platform side of every module of the app, which the matrix
// sets up before the tests of each test file (flutter_test_config.dart), so
// the first test sees a first launch. The tests of the file run in their
// order, and the later ones save states of their own under the keys of the
// role. Each expectation gives its reason.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/preferences/app_preferences.dart';
import 'package:{{app_name}}/core/review/review_service.dart';

import '../../integration_test/review_role/probe.dart';
import 'review_role.dart';

/// A service of a provider whose [isAvailable] never completes, or throws
/// if [fails], and which does nothing else.
final class _Silent implements ReviewService {
  _Silent({this.fails = false});

  /// Whether [isAvailable] throws rather than never completing.
  final bool fails;

  @override
  Future<bool> isAvailable() =>
      fails ? Future.error(StateError('No store')) : Completer<bool>().future;

  @override
  Future<void> requestReview() async {}

  @override
  Future<bool> openStorePage(Uri page) async => false;

  @override
  Future<String?> appVersion() async => '1.0.0';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  const timeout = Timeout(Duration(minutes: 2));

  /// The problems that the probe finds in the preferences of the app with
  /// [service] at [now], with a short wait, in real time.
  Future<List<String>> problemsWith(
    WidgetTester tester,
    ReviewService service, {
    DateTime? now,
  }) async {
    var problems = <String>[];
    await inRealTime(tester, 'the probe', () async {
      problems = await problemsOfReviews(
        service,
        createAppPreferences(),
        now: now ?? DateTime.now(),
        wait: const Duration(milliseconds: 200),
      );
    });
    return problems;
  }

  testWidgets(
    'finds nothing wrong on a first launch, with the service of the provider',
    (tester) async {
      await startApp(tester);
      var problems = <String>['the probe did not run'];
      await inRealTime(tester, 'the probe', () async {
        problems = await probeReview(() async {});
      });

      expect(
        problems,
        isEmpty,
        reason: 'The service of the provider tells at once whether the store '
            'can show its dialog, and the first launch counted itself and '
            'asked for no review.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'reports a service that does not tell in time whether the store can show '
    'its dialog, or fails to, and no store that cannot show it',
    (tester) async {
      expect(
        await problemsWith(tester, _Silent()),
        [
          'The service of the provider did not tell within 200 ms whether the '
              'store of the device can show its review dialog.',
        ],
        reason: 'A service that does not answer would hold the start check.',
      );
      expect(
        await problemsWith(tester, _Silent(fails: true)),
        [
          'The service of the provider failed to tell whether the store of '
              'the device can show its review dialog: Bad state: No store',
        ],
        reason: 'isAvailable() of the service never throws.',
      );
      expect(
        await problemsWith(tester, ScriptedReview(available: false)),
        isEmpty,
        reason: 'A device whose store cannot show the dialog, as an emulator '
            'without Google Play, is no problem.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'reports preferences without this launch or the time of the first '
    'launch, a first launch that is to come, and a request on the first '
    'launch',
    (tester) async {
      final now = DateTime.now().toUtc();
      final preferences = createAppPreferences();
      await inRealTime(tester, 'forgetting the reviews', forgetReviews);
      expect(
        await problemsWith(tester, ScriptedReview(), now: now),
        [
          'The preferences have null launches of the app under '
              '$launchesKey, though the start-up counts this one.',
          'The preferences have no time of the first launch of the app under '
              '$firstLaunchKey.',
        ],
        reason: 'The start-up counts each launch and saves the time of the '
            'first.',
      );

      await inRealTime(tester, 'a first launch to come', () async {
        await preferences.setInt(launchesKey, 1);
        await preferences.setInt(
          firstLaunchKey,
          now.add(const Duration(hours: 1)).millisecondsSinceEpoch,
        );
      });
      expect(
        await problemsWith(tester, ScriptedReview(), now: now),
        [
          'The time of the first launch of the app under $firstLaunchKey is '
              'to come.',
        ],
        reason: 'The time of the first launch is the time of a launch that '
            'has been.',
      );

      await inRealTime(tester, 'a request on the first launch', () async {
        await preferences.setInt(
          firstLaunchKey,
          now.millisecondsSinceEpoch,
        );
        await preferences.setInt(askedAtKey, now.millisecondsSinceEpoch);
      });
      expect(
        await problemsWith(tester, ScriptedReview(), now: now),
        [
          'The app asked for a review on its first launch, which the role '
              'never does.',
        ],
        reason: 'No review is due on the first launch of the app.',
      );

      await inRealTime(tester, 'a later launch', () async {
        await preferences.setInt(launchesKey, 2);
      });
      expect(
        await problemsWith(tester, ScriptedReview(), now: now),
        isEmpty,
        reason: 'A later launch may have asked.',
      );
    },
    timeout: timeout,
  );
}
