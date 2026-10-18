// A test that continuous integration runs in the apps with the
// firebase_messaging module, on the real Firebase packages, whose platform
// side is a device in memory (firebase_messaging_mocks.dart): once the
// start-up of the app started the push messages on the service of the
// module, appPush has the registration token of the device as its address,
// and the new one that Firebase tells of; a message that arrives in the
// foreground reaches appPush.messages; and a tap on a message that the
// platform showed reaches appPush.taps. So the plugin tells the app of what
// the platform sends from the start-up on.
//
// The start-up of the app runs once, with the mocks of the platform side of
// every module of the app, which the matrix sets up before the tests of
// each test file (flutter_test_config.dart), and on a device of the test,
// which records what reaches it. What appPush does with a message beyond
// telling of it, such as showing it as a notification of the app, is for
// the test of the push role.
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/push/app_push.dart';

import '../firebase_messaging_mocks.dart';
import 'service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockFirebaseMessaging device;

  setUpAll(() => device = mockFirebaseMessaging());

  testWidgets(
    'appPush has the registration token of the device, and the new one that '
    'Firebase tells of; a message in the foreground reaches its messages, '
    'and a tap on a message that the platform showed its taps',
    (tester) async {
      await startUp(tester);
      final messages = <String>[];
      final taps = <String>[];
      String? first;
      await inRealTime(tester, 'telling the app', () async {
        final until = DateTime.now().add(const Duration(seconds: 5));
        while (
            appPush.address.value == null && DateTime.now().isBefore(until)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        first = appPush.address.value;
        final subscriptions = [
          appPush.messages.listen((message) => messages.add(describe(message))),
          appPush.taps.listen((message) => taps.add(describe(message))),
        ];
        await device.refreshAddress('a new token of the tests');
        await device.deliver(
          messageOfPlatform(
            id: 'message-1',
            title: 'Title',
            body: 'Body',
            data: {'screen': 'inbox', 'count': 1},
          ),
        );
        await device.open(
          messageOfPlatform(id: 'message-2', title: 'Tapped'),
        );
        await aMoment();
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      });

      expect(
        first,
        tokenOfTests,
        reason: 'The address of the device is its registration token of '
            'Firebase Cloud Messaging.',
      );
      expect(
        appPush.address.value,
        'a new token of the tests',
        reason: 'appPush follows the new tokens that Firebase tells of.',
      );
      expect(
        messages,
        ['message-1 | Title | Body | {screen: inbox, count: 1}'],
        reason: 'The plugin tells the app of each message in the foreground '
            'from the start-up on.',
      );
      expect(taps, ['message-2 | Tapped | null | {}']);
    },
    // A widget test fails after ten minutes by default; a test that hangs
    // fails sooner.
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
