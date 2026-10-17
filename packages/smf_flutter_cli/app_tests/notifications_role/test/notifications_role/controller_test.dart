// A test that continuous integration runs in the apps with the
// notifications role, whichever module provides it: appNotifications, the
// controller that the template of the role generates, over a service of
// the test that scripts what a provider answers. The permission follows
// what the service says, and is denied once the app asked, which the
// preferences remember. A request asks the user only while the app may not
// show notifications, once for two requests at once. On a system without a
// question, the request opens its settings, and the app sees what the user
// did there once the user comes back. Each tap on a notification of the app
// reaches every listener of the taps, and the taps on a notification of an
// owner reach only that owner. And the controller refuses an id that the
// app does not take, and a time that has passed, before the service.
//
// It knows only the role. The start-up of the app runs first, as on a
// device, with the mocks of the platform side of every module of the app,
// which the matrix sets up before the tests of each test file
// (flutter_test_config.dart). Then each test starts appNotifications with a
// service of its own, as the role lets a test do, and has the app forget
// that it asked.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/notifications/app_notifications.dart';

import 'notifications_role.dart';

/// Starts appNotifications with [service], as the start-up of the app does
/// with the service of the provider, once the app forgot that it asked.
Future<void> _startWith(WidgetTester tester, ScriptedNotifications service) =>
    inRealTime(tester, 'starting with a service of the test', () async {
      await forgetAsking();
      await appNotifications.start(service);
    });

/// What [call] failed with, or `null` if it completed.
Future<Object?> _errorOf(Future<void> Function() call) async {
  try {
    await call();
    return null;
  } on Object catch (error) {
    return error;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  const timeout = Timeout(Duration(minutes: 2));

  testWidgets(
    'a request asks the user while the app may not show notifications, and '
    'the permission is what the service says once the user answered',
    (tester) async {
      await startUp(tester);
      final allows = ScriptedNotifications();
      final heard = <NotificationPermission>[];
      void listener() => heard.add(appNotifications.permission.value);
      appNotifications.permission.addListener(listener);
      addTearDown(() => appNotifications.permission.removeListener(listener));

      await _startWith(tester, allows);
      final atStart = appNotifications.permission.value;
      late NotificationPermission allowed;
      late NotificationPermission again;
      await inRealTime(tester, 'asking twice', () async {
        allowed = await appNotifications.request();
        again = await appNotifications.request();
      });
      final savedAfterAllowing = askedSaved;
      final requestsAfterAllowing = allows.requests;

      final refuses = ScriptedNotifications(answer: SystemAnswer.refuses);
      await _startWith(tester, refuses);
      final atSecondStart = appNotifications.permission.value;
      late NotificationPermission refused;
      await inRealTime(tester, 'asking', () async {
        refused = await appNotifications.request();
      });

      expect(
        atStart,
        NotificationPermission.notAsked,
        reason: 'An app that may not show notifications and has not asked '
            'has the permission notAsked.',
      );
      expect(
        allowed,
        NotificationPermission.granted,
        reason: 'A request completes with the permission once the user '
            'answered: granted once the service says that the app may show '
            'notifications.',
      );
      expect(
        (again, requestsAfterAllowing),
        (NotificationPermission.granted, 1),
        reason: 'A request asks the user nothing while the app may show '
            'notifications.',
      );
      expect(
        savedAfterAllowing,
        isTrue,
        reason: 'A request saves under the key of the role that the app '
            'asked.',
      );
      expect(
        (atSecondStart, refused, refuses.requests, askedSaved),
        (
          NotificationPermission.notAsked,
          NotificationPermission.denied,
          1,
          true
        ),
        reason: 'Once the user did not allow it, the permission is denied, '
            'and the preferences remember that the app asked.',
      );
      expect(
        heard,
        containsAllInOrder([
          NotificationPermission.granted,
          NotificationPermission.notAsked,
          NotificationPermission.denied,
        ]),
        reason: 'The listeners of the permission hear of each change.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'a request while another is on its way asks the user nothing more and '
    'completes with that one, and the app saves that it asked only once the '
    'user answered',
    (tester) async {
      await startUp(tester);
      final service = ScriptedNotifications();
      await _startWith(tester, service);
      late List<NotificationPermission> answers;
      late bool? savedWhileAsking;

      await inRealTime(tester, 'asking twice at once', () async {
        // The question of the system stays on the screen until the test
        // completes this.
        service.held = Completer<void>();
        final first = appNotifications.request();
        final second = appNotifications.request();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        savedWhileAsking = askedSaved;
        service.held!.complete();
        answers = await Future.wait([first, second]);
      });

      expect(
        '$answers, ${service.requests} request',
        '[${NotificationPermission.granted}, '
            '${NotificationPermission.granted}], 1 request',
        reason: 'The system shows one question at a time, so a request '
            'while another is on its way completes with that one.',
      );
      expect(
        savedWhileAsking,
        isFalse,
        reason: 'The app saves that it asked once the user answered, not '
            'while the question is on the screen: a request that fails, or '
            'an app that is closed while the question is up, leaves the app '
            'as it was before.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'on a system without a question, a request opens its settings, and the '
    'app sees what the user did there once the user comes back',
    (tester) async {
      await startUp(tester);
      final service = ScriptedNotifications(
        answer: SystemAnswer.opensSettings,
      );
      await _startWith(tester, service);
      late NotificationPermission answer;

      await inRealTime(tester, 'asking', () async {
        answer = await appNotifications.request();
      });
      final saved = askedSaved;
      // The user turns the notifications on in the settings of the system,
      // and comes back to the app.
      service.enabled = true;
      await comeBack(tester);
      final turnedOn = appNotifications.permission.value;
      // The user turns them off there later.
      service.enabled = false;
      await comeBack(tester);
      final turnedOff = appNotifications.permission.value;
      await inRealTime(tester, 'opening the settings', () async {
        await appNotifications.openSettings();
      });
      service.enabled = true;
      await comeBack(tester);

      expect(
        (answer, saved, service.requests),
        (NotificationPermission.denied, true, 1),
        reason: 'A request on a system without a question completes once '
            'the settings of the system are open, before the user turned '
            'the notifications on there: the app asked, and may not show '
            'notifications yet.',
      );
      expect(
        turnedOn,
        NotificationPermission.granted,
        reason: 'When the user comes back to the app, the app asks the '
            'service again: the user turned the notifications on in the '
            'settings of the system.',
      );
      expect(
        turnedOff,
        NotificationPermission.denied,
        reason: 'The permission of an app that asked is denied once the user '
            'turned the notifications of the app off.',
      );
      expect(
        (
          service.calls.contains('openSettings'),
          service.calls.last,
          appNotifications.permission.value,
        ),
        (true, 'areEnabled', NotificationPermission.granted),
        reason: 'openSettings() opens the settings of the system through the '
            'service, and the app sees what the user did there once the '
            'user comes back.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'each tap on a notification of the app reaches every listener of the '
    'taps, and a tap on a notification of an owner reaches only the taps of '
    'that owner',
    (tester) async {
      await startUp(tester);
      final first = ScriptedNotifications(
        launchTap: const NotificationTap(id: 1, data: {'test': 'launch'}),
      );
      await _startWith(tester, first);
      final launch = appNotifications.launchTap;
      final ownedLaunch = appNotifications.launchTapOf(ownerOfTests);
      String note(NotificationTap tap) => '${tap.id} ${tap.data}';
      final heard = <String, List<String>>{
        'first': [],
        'second': [],
        'owner': [],
        'other owner': [],
      };
      final subscriptions = <StreamSubscription<NotificationTap>>[];
      addTearDown(() async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      });
      const owned = {'test': 'owned', notificationOwnerKey: ownerOfTests};

      await inRealTime(tester, 'tapping', () async {
        // The listeners follow the taps in real time, as the taps come.
        subscriptions.addAll([
          appNotifications.taps.listen((tap) => heard['first']!.add(note(tap))),
          appNotifications.taps
              .listen((tap) => heard['second']!.add(note(tap))),
          appNotifications
              .tapsOf(ownerOfTests)
              .listen((tap) => heard['owner']!.add(note(tap))),
          appNotifications
              .tapsOf('another_owner')
              .listen((tap) => heard['other owner']!.add(note(tap))),
        ]);
        first
          ..tap(2, const {'test': 'two'})
          ..tap(-3, owned)
          // The notification of an owner whose data the provider could not
          // read.
          ..tap(-4)
          ..tap(5);
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      final ownedLauncher = ScriptedNotifications(
        launchTap: const NotificationTap(id: -6, data: owned),
      );
      await _startWith(tester, ownedLauncher);
      await inRealTime(tester, 'tapping after the next start', () async {
        ownedLauncher.tap(7);
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });

      expect(
        (launch == first.launchTap, ownedLaunch == null),
        (true, true),
        reason: 'The tap that launched the app on a notification of the app '
            'is launchTap, which the service told of when it was created.',
      );
      expect(
        heard['first'],
        ['2 {test: two}', '5 {}', '7 {}'],
        reason: 'Each tap on a notification of the app reaches the taps of '
            'the app once, in order, with its data, also after the app '
            'started again: the stream is the same for the life of the app. '
            'The taps on a notification of an owner and on one with a '
            'negative id do not.',
      );
      expect(
        heard['second'],
        heard['first'],
        reason: 'Every listener of the taps hears each tap.',
      );
      expect(
        '${heard['owner']}, ${heard['other owner']}',
        '${['-3 $owned']}, []',
        reason: 'A tap on a notification of an owner reaches the taps of that '
            'owner alone.',
      );
      expect(
        (
          appNotifications.launchTap == null,
          appNotifications.launchTapOf(ownerOfTests)?.id,
        ),
        (true, -6),
        reason: 'The tap that launched the app on a notification of an owner '
            'is the launch tap of that owner, and not launchTap.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'show() and schedule() refuse an id that the app does not take, and '
    'schedule() a time that is not in the future, before the service',
    (tester) async {
      await startUp(tester);
      final service = ScriptedNotifications();
      await _startWith(tester, service);
      final refused = <String, Object?>{};

      await inRealTime(tester, 'showing and scheduling', () async {
        service.calls.clear();
        final ids = {
          'an id beyond 32 bits': notificationOfTests(0x80000000),
          'an id below 32 bits': notificationOfTests(
            -0x80000001,
            owner: ownerOfTests,
          ),
          'a negative id without an owner': notificationOfTests(-1),
          'an owner with an id that is not negative': notificationOfTests(
            1,
            owner: ownerOfTests,
          ),
        };
        for (final MapEntry(key: what, value: notification) in ids.entries) {
          refused['show() of $what'] =
              await _errorOf(() => appNotifications.show(notification));
          refused['schedule() of $what'] = await _errorOf(
            () => appNotifications.schedule(notification, at: tomorrow),
          );
        }
        refused['schedule() at a time that passed'] = await _errorOf(
          () => appNotifications.schedule(
            notificationOfTests(2),
            at: DateTime.now().subtract(const Duration(minutes: 1)),
          ),
        );
      });
      final refusedCalls = [...service.calls];
      await inRealTime(tester, 'showing a notification of an owner', () async {
        await appNotifications.show(
          notificationOfTests(-2, owner: ownerOfTests),
        );
        await appNotifications.schedule(
          notificationOfTests(-3, owner: ownerOfTests),
          at: tomorrow,
        );
      });

      expect(
        {
          for (final MapEntry(:key, :value) in refused.entries)
            key: value.runtimeType,
        },
        {for (final key in refused.keys) key: ArgumentError},
        reason: 'The id of a notification is a 32-bit integer, 0 or more '
            'unless the notification has an owner, which takes a negative '
            'id, and a scheduled notification shows at a time to come.',
      );
      expect(
        refusedCalls,
        isEmpty,
        reason: 'A notification that the app refuses never reaches the '
            'service.',
      );
      expect(
        service.calls,
        ['show -2', 'schedule -3'],
        reason: 'A notification of an owner with a negative id reaches the '
            'service.',
      );
    },
    timeout: timeout,
  );
}
