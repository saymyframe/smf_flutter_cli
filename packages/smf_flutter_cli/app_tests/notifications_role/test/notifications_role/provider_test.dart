// A test that continuous integration runs in the apps with the
// notifications role, whichever module provides it: appNotifications over
// the service of the provider. The app starts as on a first launch, as the
// role asks of the mocks of the platform side of a provider. One request
// turns the notifications on, whether the system shows its question or
// opens its settings, where it has none. A scheduled notification is
// listed with what it has until it is cancelled, and one with its id takes
// its place. A notification of an owner, with a negative id, keeps its
// data and takes the place of no notification of the app. The service
// tells of the taps on a broadcast stream, and an app that the test
// launched has no tap that launched it. And the probe of the role, which
// the start check runs on a device, finds no problem.
//
// It knows only the role. The start-up of the app runs first, as on a
// device, since it starts the notifications, with the mocks of the
// platform side of every module of the app, which the matrix sets up
// before the tests of each test file (flutter_test_config.dart). The
// tests of the file run in their order, and the first looks at the app as
// the start-up left it, before any request. Each expectation gives its
// reason, which a provider of the role with a known bug fails the test
// with (brokenProviders of the fixture registry).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/notifications/app_notifications.dart';

import '../../integration_test/notifications_role/probe.dart';
import 'notifications_role.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  const timeout = Timeout(Duration(minutes: 2));

  testWidgets(
    'the app starts as on a first launch: it may not show notifications, '
    'and has not asked',
    (tester) async {
      await startUp(tester);
      late bool enabled;

      await inRealTime(tester, 'asking the service', () async {
        enabled = await createNotificationsService().areEnabled();
      });

      expect(
        (enabled, appNotifications.permission.value, askedSaved),
        (false, NotificationPermission.notAsked, null),
        reason: 'The mocks of the platform side of a provider start as on a '
            'first launch, as the notifications role says: the app may not '
            'show notifications and has not asked.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'one request turns the notifications on, whether the system shows its '
    'question or opens its settings, where it has none',
    (tester) async {
      await startUp(tester);
      late NotificationPermission answer;
      late bool enabled;

      await inRealTime(tester, 'asking', () async {
        answer = await appNotifications.request();
        enabled = await createNotificationsService().areEnabled();
      });

      expect(
        (answer, enabled, appNotifications.permission.value, askedSaved),
        (
          NotificationPermission.granted,
          true,
          NotificationPermission.granted,
          true,
        ),
        reason: 'A request shows the question of the system, or opens the '
            'settings of the system where it has no question, so one request '
            'turns the notifications on, and the mocks of a provider grant '
            'the permission when the app asks, as the role says. The app '
            'remembers that it asked.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'a scheduled notification is listed with what it has until it is '
    'cancelled, and one with its id takes its place',
    (tester) async {
      await startUp(tester);
      final first = notificationOfTests(1);
      final second = notificationOfTests(2, withBody: false);
      final replacing = notificationOfTests(1, title: 'Another title');
      late Map<int, String> scheduled;
      late Map<int, String> replaced;
      late Map<int, String> cancelled;
      late Map<int, String> afterShow;
      late Map<int, String> none;

      await inRealTime(tester, 'scheduling', () async {
        await appNotifications.cancelAll();
        await appNotifications.schedule(first, at: tomorrow);
        await appNotifications.schedule(second, at: tomorrow);
        scheduled = byId(await appNotifications.scheduled());
        await appNotifications.schedule(replacing, at: tomorrow);
        replaced = byId(await appNotifications.scheduled());
        await appNotifications.cancel(1);
        cancelled = byId(await appNotifications.scheduled());
        await appNotifications.show(notificationOfTests(3));
        afterShow = byId(await appNotifications.scheduled());
        await appNotifications.cancelAll();
        none = byId(await appNotifications.scheduled());
      });

      expect(
        scheduled,
        byId([first, second]),
        reason: 'scheduled() lists each notification that is scheduled, with '
            'its id, title, body and data.',
      );
      expect(
        replaced,
        byId([replacing, second]),
        reason: 'A notification scheduled with the id of one that is '
            'scheduled takes its place.',
      );
      expect(
        cancelled,
        byId([second]),
        reason: 'cancel() removes the scheduled notification of its id, and '
            'no other.',
      );
      expect(
        afterShow,
        byId([second]),
        reason: 'A notification that is shown now is not among those that '
            'are scheduled.',
      );
      expect(
        none,
        isEmpty,
        reason: 'cancelAll() removes every scheduled notification.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'a notification of an owner, with a negative id, keeps its data and '
    'takes the place of no notification of the app',
    (tester) async {
      await startUp(tester);
      final ofApp = notificationOfTests(5);
      final owned = notificationOfTests(-5, owner: ownerOfTests);
      late Map<int, String> both;
      late Map<int, String> afterCancel;
      late Map<int, String> none;

      await inRealTime(tester, 'scheduling', () async {
        await appNotifications.cancelAll();
        await appNotifications.schedule(ofApp, at: tomorrow);
        await appNotifications.schedule(owned, at: tomorrow);
        both = byId(await appNotifications.scheduled());
        await appNotifications.cancel(-5);
        afterCancel = byId(await appNotifications.scheduled());
        await appNotifications.schedule(owned, at: tomorrow);
        await appNotifications.cancelAll();
        none = byId(await appNotifications.scheduled());
      });

      expect(
        both,
        byId([ofApp, owned]),
        reason: 'A notification of an owner has a negative id, which is not '
            'the id of a notification of the app, and keeps its data, which '
            'names its owner, so that its taps reach that owner.',
      );
      expect(
        afterCancel,
        byId([ofApp]),
        reason: 'cancel() of a negative id removes the notification of the '
            'owner alone.',
      );
      expect(
        none,
        isEmpty,
        reason: 'cancelAll() removes the notifications of an owner too.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'the service tells of the taps on a broadcast stream, and an app that '
    'the test launched has no tap that launched it',
    (tester) async {
      await startUp(tester);
      final service = createNotificationsService();

      expect(
        service.taps.isBroadcast,
        isTrue,
        reason: 'The service tells of the taps on a broadcast stream, which '
            'a listener of the app may cancel and listen to again.',
      );
      expect(
        (service.launchTap, appNotifications.launchTap),
        (null, null),
        reason: 'An app that no tap on a notification launched has no tap '
            'that launched it.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'the probe of the role finds no problem',
    (tester) async {
      await startUp(tester);
      late List<String> problems;

      await inRealTime(tester, 'the probe', () async {
        problems = await probeNotifications(() async {});
      });

      expect(
        problems,
        isEmpty,
        reason: 'The probe finds no problem with notifications that keep the '
            'contract of the role.',
      );
    },
    timeout: timeout,
  );
}
