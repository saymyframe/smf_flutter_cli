// A test that continuous integration runs in the apps with the
// firebase_remote_config module, on the real Firebase packages, whose
// platform side is a device and a project in memory
// (firebase_remote_config_mocks.dart): the probe of the module
// (integration_test/firebase_remote_config/probe.dart), which the start
// check runs on a device, finds nothing while a fetch of the service of the
// app ends, and tells of a fetch that fails, with the error of Firebase, and
// of one that does not end in time. The test asks problemsOfFetch, whose
// problems the probe returns, since the probe also starts the check of a
// value of remote config once in a run of the app, which delivery_test.dart
// checks.
//
// The probe fetches through the service of the app, so the start-up of the
// app runs first, as on a device, with the mocks of the platform side of
// every module of the app, which the matrix sets up before the tests of
// each test file (flutter_test_config.dart), and on a device of the test.
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/firebase_remote_config/probe.dart';
import '../firebase_remote_config_mocks.dart';
import 'service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockFirebaseRemoteConfig device;

  setUpAll(() => device = mockFirebaseRemoteConfig());

  testWidgets(
    'the probe finds nothing while a fetch ends, and tells of a fetch that '
    'fails or does not end in time',
    (tester) async {
      await startUp(tester);
      late List<String> fetching;
      late List<String> failing;
      late List<String> hanging;
      late List<String> methods;

      await inRealTime(tester, 'probing', () async {
        device.calls.clear();
        fetching = await problemsOfFetch();
        methods = device.methods;
        device.failNext(
          'fetch',
          code: 'internal',
          message: 'Failed to get installations token.',
        );
        failing = await problemsOfFetch();
        final hold = device.holdNext('fetch');
        hanging = await problemsOfFetch(
          timeout: const Duration(milliseconds: 200),
        );
        hold.complete();
      });

      expect(fetching, isEmpty);
      expect(
        methods,
        contains('fetch'),
        reason: 'The probe fetches itself, and reads no status of an earlier '
            'fetch, which Firebase on iOS does not update after a failure.',
      );
      expect(
        methods,
        isNot(contains('activate')),
        reason: 'The probe leaves the values of the app as they are.',
      );
      const needs = 'The Firebase project of the build needs the Firebase '
          'Remote Config API (firebaseremoteconfig.googleapis.com), and the '
          'API key of the app must allow it.';
      expect(failing, [
        'A fetch of Firebase Remote Config failed: '
            '[firebase_remote_config/internal] Failed to get installations '
            'token. $needs',
      ]);
      expect(
        hanging,
        [
          'A fetch of Firebase Remote Config did not end within 200 ms. '
              '$needs',
        ],
        reason: 'The probes of the start check share a minute, so the probe '
            'waits for a fetch only as long as it says.',
      );
    },
    // A widget test fails after ten minutes by default; a test that hangs
    // fails sooner.
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
