// A test that continuous integration runs in the apps with the
// firebase_remote_config module, on the real Firebase packages, whose
// platform side is a device and a project in memory
// (firebase_remote_config_mocks.dart): a value that the Firebase project
// publishes while the app runs becomes active through appRemoteConfig within
// a second. Firebase tells of it in real time on onConfigUpdated, the
// service of the module passes that on in updates, and the controller of
// the remote config role activates it: getValue() of Firebase changes only
// after an activation. Each parameter of the app then reads its published
// value. A provider that drops the real-time updates fails the test.
//
// The controller follows the project only in an app with parameters, which
// the test takes from RemoteValues.defaults of the app: in an app without
// them, it asks Firebase nothing, and the test is skipped. The start-up of
// the app runs first, as on a device, with the mocks of the platform side of
// every module of the app, which the matrix sets up before the tests of each
// test file (flutter_test_config.dart).
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/remote_config/app_remote_config.dart';

import '../firebase_remote_config_mocks.dart';
import 'service.dart';

/// A parameter of the test, which no app reads.
const String _parameter = 'firebase_remote_config_test_value';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockFirebaseRemoteConfig device;

  setUpAll(() => device = mockFirebaseRemoteConfig());

  // testWidgets takes no reason for a skip, and a group does.
  group('in an app with parameters', () {
    testWidgets(
      'a value that the project publishes while the app runs becomes active '
      'through appRemoteConfig within a second, and each parameter of the app '
      'reads its published value',
      (tester) async {
        await startUp(tester);
        final published = {
          _parameter: 'published while the app runs',
          ...publishedTextsOfApp,
        };
        late bool listening;
        late bool active;
        late String valueOfFirebase;
        await inRealTime(tester, 'publishing', () async {
          listening = device.listening;
          device.calls.clear();
          await device.publish(published);
          active = await until(
            () =>
                FirebaseRemoteConfig.instance.getValue(_parameter).asString() ==
                published[_parameter],
          );
          valueOfFirebase =
              FirebaseRemoteConfig.instance.getValue(_parameter).asString();
        });

        expect(
          active,
          isTrue,
          reason: 'A value that the project publishes while the app runs '
              'becomes active within a second: Firebase tells of it on '
              'onConfigUpdated, the service tells of it on updates, and the '
              'controller of the role activates it. Firebase still has '
              '"$valueOfFirebase".',
        );
        expect(
          listening,
          isTrue,
          reason: 'The controller of the role listens to the updates of the '
              'service, which listens to the real-time updates of Firebase.',
        );
        expect(
          device.methods,
          contains('activate'),
          reason: 'getValue() of Firebase changes only after an activation, '
              'which only the controller of the role makes.',
        );
        expect(
          appRemoteConfig.value,
          RemoteValues.of(published),
          reason: 'Each parameter of the app reads the value that the project '
              'published.',
        );
        expect(appRemoteConfig.value, isNot(RemoteValues.initial));
      },
      // A widget test fails after ten minutes by default; a test that hangs
      // fails sooner.
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }, skip: withoutParameters);
}
