// A test that continuous integration runs in the apps with the push role,
// whichever module provides it: appPush, the controller that the template
// of the role generates, over a service of push messages of the test that
// scripts what a provider answers. The address is null until the service
// gives one, follows each address that the service tells of, and is asked
// for again when the user comes back while the app has none. Each message
// in the foreground reaches every listener of the messages once. Where the
// platform does not show a message, the app shows each one with a title or
// a body as one notification whose owner is the role, and a tap on it
// reaches appPush.taps and not appNotifications.taps. Where the platform
// shows it, the app shows none, and the taps of the service reach
// appPush.taps. And the message whose tap launched the app is the launch
// message, whether the platform or the app showed it, and not among
// appPush.taps.
//
// It knows only the role, and the notifications role that it requires. The
// start-up of the app runs first, as on a device, with the mocks of the
// platform side of every module of the app, which the matrix sets up
// before the tests of each test file (flutter_test_config.dart). Then each
// test starts appPush with a service of its own, as the role lets a test
// do, and appNotifications with a service of notifications of its own
// where it looks at the notifications that the app shows.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/notifications/app_notifications.dart';
import 'package:{{app_name}}/core/push/app_push.dart';

import 'push_role.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  const timeout = Timeout(Duration(minutes: 2));

  testWidgets(
    'the address is null until the service gives one, follows each address '
    'that the service tells of, and is asked for again when the user comes '
    'back while the app has none',
    (tester) async {
      await startUp(tester);
      final service = ScriptedPush();
      await startWith(tester, service);
      final atStart = appPush.address.value;
      final asksAtStart = service.addressCalls;
      service.answer = 'address 1';
      await comeBack(tester);
      final afterComingBack = appPush.address.value;
      await comeBack(tester);
      final asksWithAddress = service.addressCalls;
      await inRealTime(tester, 'telling of a new address', () async {
        service.tellAddress('address 2');
        await aMoment();
      });
      final changed = appPush.address.value;
      final next = ScriptedPush();
      await startWith(tester, next);
      final atNextStart = appPush.address.value;
      await inRealTime(tester, 'telling of the first address', () async {
        next.tellAddress('address 3');
        await aMoment();
      });
      final firstTold = appPush.address.value;

      expect(
        (atStart, asksAtStart),
        (null, 1),
        reason: 'The app asks the service for the address when it starts, '
            'and has none while the service gives none.',
      );
      expect(
        afterComingBack,
        'address 1',
        reason: 'While it has no address, the app asks the service again '
            'when the user comes back to the app.',
      );
      expect(
        asksWithAddress,
        2,
        reason: 'Once it has an address, the app does not ask again when the '
            'user comes back.',
      );
      expect(
        changed,
        'address 2',
        reason: 'The app follows each new address that the service tells '
            'of.',
      );
      expect(
        (atNextStart, firstTold),
        (null, 'address 3'),
        reason: 'Started with another service, the app has the address of '
            'that service: none until it gives one, and the first address '
            'that it tells of after it answered none.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'each message in the foreground reaches every listener of the messages '
    'once, and one with a title or a body that the platform does not show '
    'shows as one notification of the role, whose tap reaches the taps of '
    'the push messages and not those of the notifications',
    (tester) async {
      await startUp(tester);
      final notifications = NotificationsOfTests();
      final push = ScriptedPush();
      await startWith(tester, push, notifications: notifications);
      final full = messageOfTests('1');
      final bodyOnly = messageOfTests('2', withTitle: false);
      final dataOnly = messageOfTests('3', withTitle: false, withBody: false);
      final heard = <String, List<String>>{
        'first': [],
        'second': [],
        'taps': [],
        'taps of the notifications': [],
      };
      final subscriptions = <StreamSubscription<Object>>[];
      addTearDown(() async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      });
      late List<AppNotification> shown;

      await inRealTime(tester, 'receiving messages', () async {
        // The listeners follow the messages and the taps in real time, as
        // they come.
        subscriptions.addAll([
          appPush.messages
              .listen((message) => heard['first']!.add(describe(message))),
          appPush.messages
              .listen((message) => heard['second']!.add(describe(message))),
          appPush.taps
              .listen((message) => heard['taps']!.add(describe(message))),
          appNotifications.taps.listen(
            (tap) => heard['taps of the notifications']!.add('${tap.id}'),
          ),
        ]);
        push
          ..deliver(full)
          ..deliver(bodyOnly)
          ..deliver(dataOnly);
        await aMoment();
        shown = [...notifications.shown];
        shown.forEach(notifications.tap);
        await aMoment();
      });

      expect(
        heard['first'],
        [describe(full), describe(bodyOnly), describe(dataOnly)],
        reason: 'Each message that arrives while the app is in the '
            'foreground reaches the messages of the app once, in order, with '
            'what it has.',
      );
      expect(
        heard['second'],
        heard['first'],
        reason: 'Every listener of the messages hears each message.',
      );
      expect(
        [
          for (final notification in shown)
            '${notification.title}, ${notification.body}',
        ],
        ['Title 1, Body 1', 'Body 2, null'],
        reason: 'Where the platform does not show a message, the app shows '
            'each message with a title or a body as one notification, with '
            'its title and its body, or with its body as the title. A '
            'message with data alone shows none.',
      );
      expect(
        [
          for (final notification in shown)
            (
              notification.id < 0,
              notification.data[notificationOwnerKey],
              notification.data['screen'],
            ),
        ],
        [(true, pushOwner, '/messages/1'), (true, pushOwner, '/messages/2')],
        reason: 'Such a notification is one of the push role, which is its '
            'owner, with a negative id, so that it takes the place of no '
            'notification of the app, and the data of its message.',
      );
      expect(
        '${heard['taps']}, ${heard['taps of the notifications']}',
        '${[describe(full), describe(bodyOnly)]}, []',
        reason: 'A tap on such a notification reaches the taps of the push '
            'messages with its message, and not the taps of the '
            'notifications of the app, so the code of the app sees it once.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'where the platform shows a message in the foreground, the app shows '
    'none, and a tap that the service tells of reaches the taps of the push '
    'messages',
    (tester) async {
      await startUp(tester);
      final notifications = NotificationsOfTests();
      final push = ScriptedPush(platformShowsInForeground: true);
      await startWith(tester, push, notifications: notifications);
      final message = messageOfTests('1');
      final heard = <String, List<String>>{
        'messages': [],
        'taps': [],
        'taps of the notifications': [],
      };
      final subscriptions = <StreamSubscription<Object>>[];
      addTearDown(() async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      });

      await inRealTime(tester, 'receiving a message', () async {
        subscriptions.addAll([
          appPush.messages
              .listen((message) => heard['messages']!.add(describe(message))),
          appPush.taps
              .listen((message) => heard['taps']!.add(describe(message))),
          appNotifications.taps.listen(
            (tap) => heard['taps of the notifications']!.add('${tap.id}'),
          ),
        ]);
        push.deliver(message);
        await aMoment();
        push.tap(message);
        await aMoment();
      });

      expect(
        '${heard['messages']}, ${notifications.shown.length} shown',
        '${[describe(message)]}, 0 shown',
        reason: 'A message reaches the messages of the app, and where the '
            'platform shows it in the foreground, the app shows no '
            'notification for it.',
      );
      expect(
        '${heard['taps']}, ${heard['taps of the notifications']}',
        '${[describe(message)]}, []',
        reason: 'A tap on a message that the platform showed, which the '
            'service tells of, reaches the taps of the push messages, and '
            'not the taps of the notifications of the app.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'the message whose tap launched the app is its launch message, whether '
    'the platform or the app showed it, and not among the taps, and an app '
    'that no such tap launched has none',
    (tester) async {
      await startUp(tester);
      final taps = <String>[];
      late StreamSubscription<PushMessage> subscription;
      await inRealTime(tester, 'listening to the taps', () async {
        subscription = appPush.taps.listen((tap) => taps.add(describe(tap)));
      });
      addTearDown(() => subscription.cancel());
      final launched = messageOfTests('1');
      await startWith(
        tester,
        ScriptedPush(launch: launched),
        notifications: NotificationsOfTests(),
      );
      final ofPlatform = appPush.launchMessage;
      final notifications = NotificationsOfTests();
      final push = ScriptedPush();
      await startWith(tester, push, notifications: notifications);
      final none = appPush.launchMessage;
      final shownByApp = messageOfTests('2');
      await inRealTime(tester, 'receiving a message', () async {
        push.deliver(shownByApp);
        await aMoment();
      });
      final notification = notifications.shown.single;
      await startWith(
        tester,
        ScriptedPush(),
        notifications: NotificationsOfTests(
          launchTap: NotificationTap(
            id: notification.id,
            data: notification.data,
          ),
        ),
      );
      final ofApp = appPush.launchMessage;
      final launchTap = appNotifications.launchTap;

      expect(
        describe(ofPlatform),
        describe(launched),
        reason: 'The message whose tap launched the app, which the platform '
            'showed, is the launch message once the app started.',
      );
      expect(
        describe(none),
        'none',
        reason: 'An app that no tap on a message launched has no launch '
            'message.',
      );
      expect(
        (describe(ofApp), launchTap),
        (describe(shownByApp), null),
        reason: 'The message of a notification that the app showed, whose tap '
            'launched the app, is the launch message, and not the launch tap '
            'of the notifications of the app.',
      );
      expect(
        taps,
        isEmpty,
        reason: 'The message whose tap launched the app is not among the taps '
            'of the push messages, so the code of the app sees the tap once.',
      );
    },
    timeout: timeout,
  );
}
