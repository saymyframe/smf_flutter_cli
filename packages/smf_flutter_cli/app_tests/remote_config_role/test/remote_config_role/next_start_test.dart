// A test that continuous integration runs in the apps with the remote config
// role, whichever module provides it: the next start of the app,
// initRemoteConfig() again, which creates the service of the provider anew,
// ends within startWait, and each parameter of the app still reads its
// default, since the backend of the mocks of every provider has no value of a
// parameter of the app. And the device keeps what was activated from one
// launch of the app to the next, as the role asks: the backend of the mocks
// of every provider has one parameter outside the app,
// remote_config_role_check, which the test fetches and activates through the
// service of the provider, since an app without parameters fetches nothing.
// The next start then has it, before any fetch.
//
// It knows only the role, and reads the parameters of the app from keys.dart,
// which the matrix writes from the data of the role. The start-up of the app
// runs first, as on a device, with the mocks of the platform side of every
// module of the app, which the matrix sets up before the tests of each test
// file (flutter_test_config.dart). Each expectation gives its reason, which a
// provider of the role with a known bug fails the test with (brokenProviders
// of the fixture registry).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/remote_config/app_remote_config.dart';

import 'keys.dart';
import 'remote_config_role.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  const timeout = Timeout(Duration(minutes: 2));

  testWidgets(
    'the next start ends within startWait with a new service of the '
    'provider, and each parameter of the app still reads its default',
    (tester) async {
      await startUp(tester);
      final before = createRemoteConfigService();
      late Duration took;
      await inRealTime(tester, 'initRemoteConfig()', () async {
        final watch = Stopwatch()..start();
        await initRemoteConfig();
        took = watch.elapsed;
        // What the start sets off, such as the fetch of an app with
        // parameters, a turn of the event loop after it.
        await aMoment();
      });

      expect(
        took < AppRemoteConfigController.startWait,
        isTrue,
        reason: 'The values never hold the start: the next start ends within '
            'startWait over the mocks of a provider, which answer at once, '
            'but it took $took.',
      );
      expect(
        identical(createRemoteConfigService(), before),
        isFalse,
        reason: 'initRemoteConfig() creates the service of the provider anew, '
            'as the next launch of the app does.',
      );
      expect(
        valuesOf(appRemoteConfig.value),
        defaultsOfApp,
        reason: 'The backend of the mocks of every provider has no value of a '
            'parameter of the app, so after the next start each parameter of '
            'the app still reads its default.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'the device keeps what was activated from one launch to the next',
    (tester) async {
      await startUp(tester);
      Map<String, String>? activated;
      await inRealTime(tester, 'fetching and activating', () async {
        final service = createRemoteConfigService();
        await service.fetch();
        await service.activate();
        activated = service.values;
      });
      Map<String, String>? kept;
      await inRealTime(tester, 'the next start, with its fetch held', () async {
        await initRemoteConfig();
        // The role fetches no sooner than a turn of the event loop after the
        // start, so these are the values that the next start made active of
        // what the device kept: the fetch is held until the test read them.
        kept = createRemoteConfigService().values;
      });

      expect(
        activated?[checkParameter],
        isNotNull,
        reason: 'The backend of the mocks of every provider has the parameter '
            '$checkParameter, which no app reads, as the role asks of them: a '
            'fetch gets it, and an activation makes it active.',
      );
      expect(
        kept?[checkParameter],
        activated?[checkParameter],
        reason: 'The device keeps what was activated from one launch of the '
            'app to the next: right after the next start, before any fetch, '
            'the service has the parameter that the launch before activated.',
      );
    },
    timeout: timeout,
  );
}
