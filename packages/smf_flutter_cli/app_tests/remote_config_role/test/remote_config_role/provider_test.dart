// A test that continuous integration runs in the apps with the remote config
// role, whichever module provides it: appRemoteConfig over the service of the
// provider. On a first launch the service has no value of a parameter of the
// app, since the backend of the mocks of every provider has none, as the role
// asks of them, and each parameter of the app reads its default. A value of
// the service is one that the backend gave, so a parameter that the backend
// lacks never reads a value that the provider makes up for it. activate() and
// fetch() end within their bounds, and the service tells of the values that
// the backend publishes on a broadcast stream.
//
// It knows only the role, and reads the parameters of the app from keys.dart,
// which the matrix writes from the data of the role. The start-up of the app
// runs first, as on a device, since it starts remote config, with the mocks of
// the platform side of every module of the app, which the matrix sets up
// before the tests of each test file (flutter_test_config.dart). Each
// expectation gives its reason, which a provider of the role with a known bug
// fails the test with (brokenProviders of the fixture registry).
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
    'on a first launch, the service has no value of a parameter of the app, '
    'and each parameter of the app reads its default',
    (tester) async {
      await startUp(tester);
      final values = createRemoteConfigService().values;

      expect(
        [
          for (final parameter in appParameters)
            if (values.containsKey(parameter.name)) parameter.name,
        ],
        isEmpty,
        reason: 'The backend of the mocks of every provider has no value of a '
            'parameter of the app, and the values of the service are those '
            'that the backend gave: a parameter that the backend lacks read a '
            'value of the provider in place of its default.',
      );
      expect(
        valuesOf(appRemoteConfig.value),
        defaultsOfApp,
        reason: 'Each parameter of the app reads its default while the '
            'backend gives it no value.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'activate() and fetch() end within their bounds, and the service tells '
    'of the values that the backend publishes on a broadcast stream',
    (tester) async {
      await startUp(tester);
      final service = createRemoteConfigService();
      late Duration activating;
      late Duration fetching;
      await inRealTime(tester, 'activating and fetching', () async {
        final watch = Stopwatch()..start();
        await service.activate();
        activating = watch.elapsed;
        watch.reset();
        await service.fetch();
        fetching = watch.elapsed;
      });
      final first = service.updates.listen((_) {});
      final second = service.updates.listen((_) {});
      addTearDown(() async {
        await first.cancel();
        await second.cancel();
      });

      expect(
        activating < AppRemoteConfigController.startWait,
        isTrue,
        reason: 'activate() asks the backend nothing, so it ends within '
            'startWait, but it took $activating.',
      );
      expect(
        fetching < AppRemoteConfigController.fetchTimeout,
        isTrue,
        reason: 'A fetch over the mocks of a provider, whose backend answers '
            'at once, ends within fetchTimeout, but it took $fetching.',
      );
      expect(
        service.updates.isBroadcast,
        isTrue,
        reason: 'The service tells of the values that the backend publishes '
            'on a broadcast stream, which more than one may listen to.',
      );
    },
    timeout: timeout,
  );
}
