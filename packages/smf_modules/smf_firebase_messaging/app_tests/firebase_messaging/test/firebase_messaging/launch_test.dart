// A test that continuous integration runs in the apps with the
// firebase_messaging module, on the real Firebase packages, whose platform
// side is a device in memory (firebase_messaging_mocks.dart): the message
// whose tap launched the app, which Firebase gives the app once, is
// appPush.launchMessage once the start-up of the app is over, with what it
// has, and it does not reach appPush.taps.
//
// It has a file of its own, since the start-up of the app runs once in a
// test file and the device of the test has to give the message before it
// runs. The mocks of the platform side of every module of the app come
// first, which the matrix sets up before the tests of each test file
// (flutter_test_config.dart).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/push/app_push.dart';

import '../firebase_messaging_mocks.dart';
import 'service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    mockFirebaseMessaging().launchWith(
      messageOfPlatform(
        id: 'launch-1',
        title: 'Hello',
        body: 'World',
        data: {'screen': 'inbox', 'count': 3},
      ),
    );
  });

  testWidgets(
    'the message whose tap launched the app is the launch message of appPush, '
    'and not among its taps',
    (tester) async {
      final taps = <String>[];
      final subscription =
          appPush.taps.listen((message) => taps.add(describe(message)));
      addTearDown(subscription.cancel);

      await startUp(tester);
      await inRealTime(tester, 'waiting a moment', aMoment);

      expect(
        describe(appPush.launchMessage),
        'launch-1 | Hello | World | {screen: inbox, count: 3}',
        reason: 'appPush takes the message whose tap launched the app from '
            'the service, before the first frame, with its data as texts.',
      );
      expect(taps, isEmpty);
    },
    // A widget test fails after ten minutes by default; a test that hangs
    // fails sooner.
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
