// A test that continuous integration runs in the apps with the
// firebase_remote_config module, on the real Firebase packages, whose
// platform side is a device and a project in memory
// (firebase_remote_config_mocks.dart): a start of the app finds what an
// earlier launch activated, which Firebase keeps on the device, without the
// network. Right after the start of remote config, the service has those
// values and the parameters of the app read them, and they stay while no
// fetch can reach the project.
//
// It has a file of its own, since the plugin takes what the device kept
// once in a run of the app, when Firebase is initialized, and the start-up
// of the app runs once in a test file. The test puts the values on the
// device and holds every fetch before the start-up of the app runs, which
// then starts remote config on that device.
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/remote_config/app_remote_config.dart';

import '../firebase_remote_config_mocks.dart';
import 'service.dart';

/// A parameter that an earlier launch activated, which no app reads.
const String _kept = 'firebase_remote_config_test_kept';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final kept = {_kept: 'activated at the last launch', ...publishedTextsOfApp};

  setUpAll(() {
    final device = mockFirebaseRemoteConfig()..restoreActive(kept);
    // No fetch reaches the project, as on a device without the network.
    for (var fetch = 0; fetch < 3; fetch++) {
      device.holdNext('fetch');
    }
  });

  testWidgets(
    'a start of the app finds what an earlier launch activated, without the '
    'network, and the parameters of the app read it',
    (tester) async {
      await startUp(tester);
      final afterTheStart = createRemoteConfigService().values;
      await inRealTime(
        tester,
        'waiting',
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      final afterAMoment = createRemoteConfigService().values;

      expect(
        afterTheStart,
        kept,
        reason: 'Firebase keeps on the device what an earlier launch '
            'activated, and the start of remote config makes it active '
            'without the network.',
      );
      expect(
        afterAMoment,
        kept,
        reason: 'While no fetch reaches the project, as in an app with '
            'parameters, which fetches after the start, the values stay those '
            'that the device kept.',
      );
      expect(
        FirebaseRemoteConfig.instance.getValue(_kept).source,
        ValueSource.valueRemote,
      );
      expect(
        appRemoteConfig.value,
        RemoteValues.of(kept),
        reason: 'Each parameter of the app reads what the device kept.',
      );
    },
    // A widget test fails after ten minutes by default; a test that hangs
    // fails sooner.
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
