// A test that continuous integration runs in the apps with the
// local_notifications module, on the real flutter_local_notifications,
// whose platform side is a device in memory
// (local_notifications_mocks.dart): what the notifications service of the
// module, which openLocalNotifications() opens, sends to the plugin. The
// plugin opens with the small icon of the app and, on iOS, without the
// question for the permission that it asks by default, and the channel of
// the app has its name and a high importance. A notification goes to that
// channel with its data as JSON, and showing one cancels the scheduled one
// of its id, whose alarm Android keeps. A scheduled notification uses an
// inexact alarm, at its time in UTC. A request shows the question of the
// system, and opens the settings of the system where the system shows
// none, as on Android before 13. And the calls to open those settings and
// to cancel reach the plugin, on Android and on iOS.
//
// It uses the service of the module and runs none of the start-up of the
// app (service.dart). The matrix sets up the mocks of the platform side of
// every module of the app before the tests, and each test takes a device
// of its own, which records what reaches it.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/notifications/local_notifications_service.dart';
import 'package:{{app_name}}/core/notifications/notifications_service.dart';

import '../local_notifications_mocks.dart';
import 'service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(onAndroid);

  test(
      'the plugin opens with the small icon of the app, and the channel of '
      'the app has its name and a high importance', () async {
    final device = mockLocalNotifications();

    final service = await openLocalNotifications();

    expect(
      device.methods,
      [
        'initialize',
        'createNotificationChannel',
        'getNotificationAppLaunchDetails',
      ],
      reason: 'The service sets up the plugin, creates the channel of the app '
          'and reads the tap that launched the app, and asks the user '
          'nothing.',
    );
    expect(
      argumentsOf(device.calls, 'initialize')['defaultIcon'],
      notificationIcon,
      reason: 'A notification shows the small icon of the role, the drawable '
          'that the template of the role generates.',
    );
    final channel = argumentsOf(device.calls, 'createNotificationChannel');
    expect(
      (channel['id'], channel['name'], channel['importance']),
      (notificationChannelId, notificationChannelName, Importance.high.value),
      reason: 'The channel of the app has the id of the role and the name of '
          'the app, and a high importance, with which Android shows a '
          'notification as a banner.',
    );
    expect(service.launchTap, isNull);
  });

  test(
      'on iOS the plugin opens without asking for the permission, and shows a '
      'notification while the app is in the foreground', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final device = mockLocalNotifications(platform: TargetPlatform.iOS);

    await openLocalNotifications();

    expect(
      device.methods,
      ['initialize', 'getNotificationAppLaunchDetails'],
      reason: 'iOS has no channels.',
    );
    final settings = argumentsOf(device.calls, 'initialize');
    expect(
      {
        for (final key in [
          'requestAlertPermission',
          'requestSoundPermission',
          'requestBadgePermission',
          'requestProvisionalPermission',
        ])
          key: settings[key],
      }.values,
      everyElement(isFalse),
      reason: 'The plugin asks for the permission when it opens unless it is '
          'told not to: the app asks when the user turns on something that '
          'notifies.',
    );
    expect(
      {
        for (final key in [
          'defaultPresentAlert',
          'defaultPresentBanner',
          'defaultPresentList',
          'defaultPresentSound',
        ])
          key: settings[key],
      }.values,
      everyElement(isTrue),
      reason: 'A notification shows also while the app is in the foreground, '
          'as the role says.',
    );
  });

  test(
      'a notification goes to the channel of the app with a high importance, '
      'with its data as JSON', () async {
    final (device, service) = await openOnNewDevice();

    await service.show(
      const AppNotification(
        id: 3,
        title: 'Title',
        body: 'Body',
        data: {'screen': 'inbox'},
      ),
    );

    final shown = argumentsOf(device.calls, 'show');
    final details = shown['platformSpecifics']! as Map<Object?, Object?>;
    expect(
      (shown['id'], shown['title'], shown['body']),
      (3, 'Title', 'Body'),
    );
    expect(
      jsonDecode(shown['payload']! as String),
      {'screen': 'inbox'},
      reason: 'The data of a notification goes to the plugin as the JSON of '
          'a map, which a tap brings back.',
    );
    expect(
      (
        details['channelId'],
        details['channelName'],
        details['importance'],
        details['priority'],
      ),
      (
        notificationChannelId,
        notificationChannelName,
        Importance.high.value,
        Priority.high.value,
      ),
      reason: 'Every notification goes to the channel of the app, with a '
          'high importance, as the role says.',
    );
    expect(device.shown, [3]);
  });

  test(
      'showing a notification cancels the scheduled one of its id, whose '
      'alarm Android keeps, and no other', () async {
    final (device, service) = await openOnNewDevice();
    final tomorrow = DateTime.now().add(const Duration(days: 1));

    await service.schedule(const AppNotification(id: 4, title: '4'), tomorrow);
    await service.schedule(const AppNotification(id: 6, title: '6'), tomorrow);
    device.calls.clear();
    await service.show(const AppNotification(id: 4, title: 'Shown 4'));
    final withScheduled = device.methods;
    device.calls.clear();
    await service.show(const AppNotification(id: 5, title: 'Shown 5'));

    expect(
      device.scheduled,
      [6],
      reason: 'A notification that is shown with the id of a scheduled one '
          'takes its place, as the role says: Android would show the '
          'scheduled one at its time too.',
    );
    expect(withScheduled, ['pendingNotificationRequests', 'cancel', 'show']);
    expect(
      device.methods,
      ['pendingNotificationRequests', 'show'],
      reason: 'Without a scheduled notification of its id, the service '
          'cancels nothing, so a notification that is shown with the id of a '
          'shown one takes its place without going away first.',
    );
  });

  test(
      'a scheduled notification uses an inexact alarm, at its time in UTC, '
      'with its data as JSON, and is listed with it', () async {
    final (device, service) = await openOnNewDevice();
    // A time to come to the second, to which the plugin takes it.
    final at = DateTime(2100, 1, 2, 3, 4, 5);

    await service.schedule(
      const AppNotification(
        id: -7,
        title: 'Title',
        data: {'notifications.owner': 'tests', 'screen': 'inbox'},
      ),
      at,
    );

    final scheduled = argumentsOf(device.calls, 'zonedSchedule');
    final details = scheduled['platformSpecifics']! as Map<Object?, Object?>;
    expect(
      details['scheduleMode'],
      AndroidScheduleMode.inexactAllowWhileIdle.name,
      reason: 'A scheduled notification is inexact, as the role says: an '
          'exact alarm needs a permission that Google Play allows only for '
          'some apps.',
    );
    expect(
      scheduled['timeZoneName'],
      anyOf('UTC', 'Etc/UTC'),
      reason: 'The time goes to the plugin in UTC, so the app needs no '
          'database of time zones.',
    );
    expect(
      DateTime.parse('${scheduled['scheduledDateTime']}Z'),
      predicate<DateTime>((time) => time.isAtSameMomentAs(at)),
      reason: 'The plugin gets the time of the notification as the time of '
          'day in UTC.',
    );
    expect(
      jsonDecode(scheduled['payload']! as String),
      {'notifications.owner': 'tests', 'screen': 'inbox'},
    );
    expect(
      [
        for (final notification in await service.scheduled())
          '${notification.id} ${notification.title} ${notification.body} '
              '${notification.data}',
      ],
      ['-7 Title null {notifications.owner: tests, screen: inbox}'],
      reason: 'The service lists a scheduled notification with what it has, '
          'its data from the JSON in the payload.',
    );
  });

  test(
      'a request shows the question of the system, and opens no settings '
      'once the user answered it, yes or no', () async {
    final (allowing, allowed) = await openOnNewDevice();
    await allowed.request();

    expect(
      allowing.methods,
      ['requestNotificationsPermission'],
      reason: 'A request shows the question of the system where it has one, '
          'as on Android 13 and later.',
    );
    expect(await allowed.areEnabled(), isTrue);

    // A device of its own answers the plugin from here on.
    final (refusing, refused) = await openOnNewDevice();
    refusing.answer = QuestionAnswer.refuses;
    await refused.request();

    expect(
      refusing.methods,
      ['requestNotificationsPermission'],
      reason: 'A request completes once the user answered, also with a no, '
          'and does not throw for it, and opens no settings: the user just '
          'answered.',
    );
    expect(await refused.areEnabled(), isFalse);
  });

  test(
      'where the system shows no question, a request opens the settings of '
      'the notifications of the app instead', () async {
    final (before13, onBefore13) = await openOnNewDevice();
    before13.withoutQuestion();
    await onBefore13.request();

    expect(
      before13.methods,
      ['requestNotificationsPermission', 'openAppNotificationSettings'],
      reason: 'Android before 13 shows no question, and the app may not show '
          'notifications once the user turned them off: the request opens '
          'the settings of the system instead, as the role says, so that '
          'the user needs one request to turn them on.',
    );

    // A device of its own answers the plugin from here on.
    final (askedTwice, onAskedTwice) = await openOnNewDevice();
    askedTwice.answer = QuestionAnswer.refuses;
    await onAskedTwice.request();
    await onAskedTwice.request();
    final twice = askedTwice.methods;
    askedTwice.calls.clear();
    await onAskedTwice.request();

    expect(twice, [
      'requestNotificationsPermission',
      'requestNotificationsPermission',
    ]);
    expect(
      askedTwice.methods,
      ['requestNotificationsPermission', 'openAppNotificationSettings'],
      reason: 'Android 13 and later ask no more after a second no, so a '
          'request opens the settings of the system then.',
    );
  });

  test('a request of an app that may show notifications opens no settings',
      () async {
    final (device, service) = await openOnNewDevice();
    device
      ..withoutQuestion()
      ..enabled = true;

    await service.request();

    expect(device.methods, ['requestNotificationsPermission']);
  });

  test(
      'on iOS a request asks for alerts, badges and sounds, and opens the '
      'settings once iOS asks no more', () async {
    final (device, service) =
        await openOnNewDevice(platform: TargetPlatform.iOS);
    device.answer = QuestionAnswer.refuses;

    await service.request();
    final first = [...device.calls];
    device.calls.clear();
    await service.request();

    expect(
      [for (final call in first) call.method],
      ['requestPermissions'],
      reason: 'The first request shows the question of iOS, and the user '
          'answers it.',
    );
    expect(
      first.single.arguments,
      {
        'sound': true,
        'alert': true,
        'badge': true,
        'provisional': false,
        'critical': false,
        'carPlay': false,
        'providesAppNotificationSettings': false,
      },
      reason: 'The app asks iOS for alerts, badges and sounds.',
    );
    expect(
      device.methods,
      ['requestPermissions', 'openAppNotificationSettings'],
      reason: 'iOS asks only once, so the next request opens the settings of '
          'the system.',
    );
    expect(await service.areEnabled(), isFalse);
    device
      ..enabled = true
      ..alertsOff = true;
    expect(
      await service.areEnabled(),
      isTrue,
      reason: 'On iOS the service reads the permission from the settings of '
          'the app: an app that the user allows to show notifications may '
          'show them also with its alerts turned off, in the notification '
          'center.',
    );
  });

  test(
      'a request that starts while the app is out of the foreground, as '
      'under the control center, opens no settings after a no: the question '
      'of the system may have shown without a change that the app sees',
      () async {
    final binding = TestWidgetsFlutterBinding.instance;
    addTearDown(
      () => binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
    );
    final (androidDevice, androidService) = await openOnNewDevice();
    androidDevice.answer = QuestionAnswer.refuses;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await androidService.request();
    final (iOSDevice, iOSService) =
        await openOnNewDevice(platform: TargetPlatform.iOS);
    iOSDevice.answer = QuestionAnswer.refuses;
    await iOSService.request();

    expect(
      androidDevice.methods,
      ['requestNotificationsPermission'],
      reason: 'The question of the system takes no app out of the foreground '
          'that is out of it already, so the service cannot tell a question '
          'that the user said no to from none, and opens no settings over '
          'the answer of the user.',
    );
    expect(iOSDevice.methods, ['requestPermissions']);
  });

  test(
      'opening the settings and cancelling reach the plugin, on Android and '
      'on iOS', () async {
    final (androidDevice, androidService) = await openOnNewDevice();
    await androidService.openSettings();
    await androidService.cancel(7);
    await androidService.cancelAll();
    final (iOSDevice, iOSService) =
        await openOnNewDevice(platform: TargetPlatform.iOS);
    await iOSService.openSettings();
    await iOSService.cancel(7);
    await iOSService.cancelAll();

    expect(
      [
        for (final call in androidDevice.calls)
          '${call.method} ${call.arguments}'
      ],
      [
        'openAppNotificationSettings null',
        'cancel {id: 7, tag: null}',
        'cancelAll null',
      ],
    );
    expect(
      [for (final call in iOSDevice.calls) '${call.method} ${call.arguments}'],
      ['openAppNotificationSettings null', 'cancel 7', 'cancelAll null'],
    );
  });
}
