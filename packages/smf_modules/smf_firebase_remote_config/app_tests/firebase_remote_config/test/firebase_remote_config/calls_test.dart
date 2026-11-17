// A test that continuous integration runs in the apps with the
// firebase_remote_config module, on the real Firebase packages, whose
// platform side is a device and a project in memory
// (firebase_remote_config_mocks.dart): what the remote config service of the
// module, which createFirebaseRemoteConfigService() creates, sends to
// Firebase Remote Config, and what it makes of what Firebase answers and
// tells, on Android and on iOS. open() takes what the device kept and gives
// Firebase the timeout and the interval of a fetch of the role and the
// defaults of the app; values has the active values that the project gave
// and never a default; fetch() and activate() reach their messages, and an
// error comes back as Firebase's; and updates listens to the real-time
// updates of Firebase while something listens to it, and tells of each.
//
// It uses the service of the module and runs none of the start-up of the
// app but the start of Firebase (service.dart), so it runs in an app without
// parameters too. The matrix sets up the mocks of the platform side of every
// module of the app before the tests, and each test takes a device of its
// own, which records what reaches it.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/remote_config/app_remote_config.dart';
import 'package:{{app_name}}/core/remote_config/firebase_remote_config_service.dart';
import 'package:{{app_name}}/core/remote_config/remote_config_service.dart';

import '../firebase_remote_config_mocks.dart';
import 'service.dart';

/// The defaults of the tests, one of each type of a parameter.
const Map<String, Object> _defaults = {
  'test_greeting': 'Hello',
  'test_enabled': true,
  'test_limit': 3,
  'test_ratio': 0.5,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockFirebaseRemoteConfig device;

  setUpAll(() async {
    mockFirebaseRemoteConfig();
    await initializeFirebase();
  });

  setUp(() => device = mockFirebaseRemoteConfig());

  tearDown(onAndroid);

  /// A new service of the module, opened with the defaults of the tests and
  /// the fetch interval and the timeout of the role.
  Future<RemoteConfigService> opened() async {
    final service = createFirebaseRemoteConfigService();
    await service.open(
      _defaults,
      fetchInterval: AppRemoteConfigController.fetchInterval,
      fetchTimeout: AppRemoteConfigController.fetchTimeout,
    );
    return service;
  }

  for (final ios in [false, true]) {
    final platform = ios ? 'iOS' : 'Android';

    test(
        'on $platform, the service asks Firebase nothing when it is created, '
        'and open() takes what the device kept, then gives Firebase the '
        'timeout and the interval of a fetch of the role and the defaults of '
        'the app', () async {
      if (ios) onIOS();
      final service = createFirebaseRemoteConfigService();
      await aMoment();
      final whenCreated = [...device.calls];
      await service.open(
        _defaults,
        fetchInterval: AppRemoteConfigController.fetchInterval,
        fetchTimeout: AppRemoteConfigController.fetchTimeout,
      );

      expect(whenCreated, isEmpty);
      expect(
        [
          for (final call in device.calls)
            // The plugin reads the settings and the values back after it set
            // them, for its getters.
            if (call.first != 'getProperties' && call.first != 'getAll')
              call.first,
        ],
        ['ensureInitialized', 'setConfigSettings', 'setDefaults'],
      );
      expect(
        (device.fetchTimeoutSeconds, device.minimumFetchIntervalSeconds),
        (
          AppRemoteConfigController.fetchTimeout.inSeconds,
          AppRemoteConfigController.fetchInterval.inSeconds,
        ),
        reason: 'The service gives Firebase the timeout of a fetch and the '
            'interval between two fetches of the role, which Firebase '
            'throttles its fetches to.',
      );
      expect(
        device.calls.firstWhere((call) => call.first == 'setDefaults')[1],
        _defaults,
        reason: 'Firebase gets the defaults of the app, each of its type.',
      );
      expect(
        service.liveUpdates,
        isTrue,
        reason: 'Firebase tells of the values that the project publishes '
            'while the app runs.',
      );
    });
  }

  test(
      'values has the active values that the project gave, as texts, and '
      'never a default of the app', () async {
    final service = await opened();
    final beforeAFetch = service.values;
    device.project
      ..['test_greeting'] = 'Hi'
      ..['other_parameter'] = 'of the project';
    await service.fetch();
    final beforeTheActivation = service.values;
    final changed = await service.activate();
    final changedAgain = await service.activate();

    expect(
      beforeAFetch,
      isEmpty,
      reason: 'Firebase has the defaults of the app among its values, which '
          'are not values of the project.',
    );
    expect(
      beforeTheActivation,
      isEmpty,
      reason: 'A fetch keeps what the project has until an activation.',
    );
    expect((changed, changedAgain), (true, false));
    expect(service.values, {
      checkParameter: checkValue,
      'test_greeting': 'Hi',
      'other_parameter': 'of the project',
    });
    expect(
      FirebaseRemoteConfig.instance.getValue('test_limit').source,
      ValueSource.valueDefault,
      reason: 'A parameter that the project lacks has its default in '
          'Firebase, which values leaves out.',
    );
  });

  test(
      'fetch() and activate() reach their messages, and an error of Firebase '
      'comes back as it is', () async {
    final service = await opened();
    device.calls.clear();
    await service.fetch();
    await service.activate();
    final methods = [
      for (final method in device.methods)
        if (method != 'getProperties' && method != 'getAll') method,
    ];
    device.failNext(
      'fetch',
      code: 'internal',
      message: 'Failed to get installations token.',
    );
    Object? fetchError;
    try {
      await service.fetch();
    } on Object catch (error) {
      fetchError = error;
    }
    device.failNext(
      'activate',
      code: 'internal',
      message: 'The platform broke.',
    );
    Object? activateError;
    try {
      await service.activate();
    } on Object catch (error) {
      activateError = error;
    }

    expect(methods, ['fetch', 'activate']);
    expect(
      fetchError,
      isA<FirebaseException>()
          .having((error) => error.plugin, 'plugin', 'firebase_remote_config')
          .having((error) => error.code, 'code', 'internal')
          .having(
            (error) => error.message,
            'message',
            'Failed to get installations token.',
          ),
      reason: 'The controller of the role keeps the values after a fetch '
          'that fails and prints the error in a debug build, so the service '
          'gives it the error of Firebase.',
    );
    expect(
      activateError,
      isA<FirebaseException>()
          .having((error) => error.code, 'code', 'internal'),
    );
  });

  test(
      'updates listens to the real-time updates of Firebase while something '
      'listens to it, on a broadcast stream, and tells of each, after which '
      'an activation makes the published values active', () async {
    final service = await opened();
    device.calls.clear();
    final heard = <String>[];
    final first = service.updates.listen((_) => heard.add('first'));
    final second = service.updates.listen((_) => heard.add('second'));
    await aMoment();
    final listening = device.listening;
    await device.publish({'test_limit': '5'});
    await device.publish({'test_limit': '6'});
    await aMoment();
    final valuesBefore = service.values;
    await service.activate();
    await first.cancel();
    await second.cancel();
    await aMoment();

    expect(service.updates.isBroadcast, isTrue);
    expect(listening, isTrue);
    expect(heard, ['first', 'second', 'first', 'second']);
    expect(
      valuesBefore,
      isEmpty,
      reason: 'Firebase fetched what the project published, but its values '
          'change only once they are activated, which the controller of the '
          'role does when the service tells of an update.',
    );
    expect(service.values, {checkParameter: checkValue, 'test_limit': '6'});
    expect(device.methods, containsAllInOrder(['listen', 'cancel']));
    expect(device.listening, isFalse);
  });
}
