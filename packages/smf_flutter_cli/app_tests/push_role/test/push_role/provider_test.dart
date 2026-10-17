// A test that continuous integration runs in the apps with the push role,
// whichever module provides it: appPush over the service of the provider.
// The app gets the address of the device that the provider gives, as the
// role asks of the mocks of the platform side of a provider, at once or a
// moment after the start-up. An app that the test launched has no launch
// message, and the service tells of the messages, the taps and the
// addresses on broadcast streams. The provider never asks for the
// permission to show notifications through the notifications of the app,
// when it starts or when the app calls it: a request through its own SDK
// is for the tests of its own module. And the probe of the role, which the
// start check runs on a device, finds no problem, and reports what it
// checks without the address of the device.
//
// It knows only the role, and the notifications role that it requires. The
// start-up of the app runs first, as on a device, since it starts the push
// messages, with the mocks of the platform side of every module of the
// app, which the matrix sets up before the tests of each test file
// (flutter_test_config.dart). No test sends a message or taps one: what a
// provider does with a message that a server sends is for the tests of its
// own module. Each expectation gives its reason, which a provider of the
// role with a known bug fails the test with (brokenProviders of the
// fixture registry).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/notifications/app_notifications.dart';
import 'package:{{app_name}}/core/push/app_push.dart';

import '../../integration_test/push_role/probe.dart';
import 'push_role.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  const timeout = Timeout(Duration(minutes: 2));

  testWidgets(
    'the app gets the address of the device that the provider gives',
    (tester) async {
      await startUp(tester);
      final address = await addressOfApp(tester);
      String? answer;
      await inRealTime(tester, 'asking the service', () async {
        answer = await createPushService().address();
      });

      expect(
        address,
        isNotNull,
        reason: 'The mocks of the platform side of a provider give the '
            'device an address, as the push role says, and the app gets it '
            'once the start-up is over, at once or a moment later.',
      );
      expect(
        answer,
        address,
        reason: 'The address of the app is the one that the service of the '
            'provider gives.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'an app that the test launched has no launch message, and the service '
    'tells of messages, taps and addresses on broadcast streams',
    (tester) async {
      await startUp(tester);
      final service = createPushService();
      PushMessage? launch;
      await inRealTime(tester, 'asking the service', () async {
        launch = await service.launchMessage();
      });

      expect(
        (describe(launch), describe(appPush.launchMessage)),
        ('none', 'none'),
        reason: 'An app that no tap on a message launched has no message '
            'that launched it.',
      );
      expect(
        (
          service.messages.isBroadcast,
          service.taps.isBroadcast,
          service.addressChanges.isBroadcast,
        ),
        (true, true, true),
        reason: 'The service tells of the messages, the taps and the '
            'addresses on broadcast streams, which a listener may cancel and '
            'listen to again.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'the provider never asks for the permission to show notifications '
    'through the notifications of the app, when it starts or when the app '
    'calls it',
    (tester) async {
      await startUp(tester);
      late bool enabled;

      await inRealTime(tester, 'calling the service', () async {
        final service = createPushService();
        await service.address();
        await service.launchMessage();
        final subscriptions = [
          service.messages.listen((_) {}),
          service.taps.listen((_) {}),
          service.addressChanges.listen((_) {}),
        ];
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        // The next start of the push messages creates the service anew.
        await initPush();
        await aMoment();
        enabled = await createNotificationsService().areEnabled();
      });

      expect(
        (appNotifications.permission.value, enabled),
        (NotificationPermission.notAsked, false),
        reason: 'A provider of push messages never asks for the permission '
            'to show notifications through the notifications of the app, '
            'which the permission belongs to: the app starts as on a first '
            'launch, as the notifications role asks of the mocks of a '
            'provider, and nothing has asked. A request through the own SDK '
            'of a provider is for the tests of its module.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'the probe of the role finds no problem, before the address came and '
    'after',
    (tester) async {
      await startUp(tester);
      late List<String> before;
      late List<String> after;

      await inRealTime(tester, 'the probe after the next start', () async {
        // The address of the app is null until the new service gives one.
        await initPush();
        before = await probePush(() async {});
      });
      await addressOfApp(tester);
      await inRealTime(tester, 'the probe with the address', () async {
        after = await probePush(() async {});
      });

      expect(
        [...before, ...after],
        isEmpty,
        reason: 'The probe finds no problem with push messages that keep the '
            'contract of the role.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'the probe of the role reports a launch message of an app that the test '
    'launched, and an address that the service does not give, and never '
    'the address',
    (tester) async {
      await startUp(tester);
      final ofDevice = await addressOfApp(tester);
      const another = 'another address of the tests';
      // A service of the test, whose address and launch message the probe
      // finds in appPush; the service of the provider gives the address of
      // the device.
      await startWith(
        tester,
        ScriptedPush(answer: another, launch: messageOfTests('7')),
      );
      late List<String> problems;
      await inRealTime(tester, 'the probe', () async {
        problems = await probePush(() async {});
      });

      expect(
        (appPush.address.value, problems.length),
        (another, 2),
        reason: 'The probe reports an app with a launch message, which the '
            'start check launched without a tap on a message, and an address '
            'of the app that is not the one that the service of the provider '
            'gives.',
      );
      expect(
        [
          for (final problem in problems)
            if (problem.contains(another) ||
                (ofDevice != null && problem.contains(ofDevice)))
              problem,
        ],
        isEmpty,
        reason: 'The probe never writes the address of the device into a '
            'problem: it is for the backend of the app alone.',
      );
    },
    timeout: timeout,
  );
}
