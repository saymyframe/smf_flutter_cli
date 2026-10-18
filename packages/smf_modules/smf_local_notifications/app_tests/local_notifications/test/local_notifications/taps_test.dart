// A test that continuous integration runs in the apps with the
// local_notifications module, on the real flutter_local_notifications,
// whose platform side is a device in memory
// (local_notifications_mocks.dart): a tap on a notification, which the
// platform tells the plugin of, reaches the taps of the notifications
// service of the module with the data of the notification, and through
// them the taps of appNotifications. A tap whose payload the app did not
// write has no data. And only the service of the last open of the plugin
// hears of the taps, as after the next start of the app.
//
// It uses the service of the module, which openLocalNotifications() opens
// (service.dart), and runs none of the start-up of the app.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/notifications/app_notifications.dart';
import 'package:{{app_name}}/core/notifications/local_notifications_service.dart';

import 'service.dart';

/// The taps of [taps] as a test compares them, each as its id and data,
/// that come while [action] runs.
Future<List<String>> tapsDuring(
  Stream<NotificationTap> taps,
  Future<void> Function() action,
) async {
  final heard = <String>[];
  final subscription = taps.listen((tap) => heard.add('${tap.id} ${tap.data}'));
  await action();
  await Future<void>.delayed(Duration.zero);
  await subscription.cancel();
  return heard;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'a tap on a notification reaches the taps of the service with the data '
      'of the notification', () async {
    final (device, service) = await openOnNewDevice();

    final heard = await tapsDuring(
      service.taps,
      () => device.tap(3, payload: jsonEncode({'screen': 'inbox'})),
    );

    expect(
      heard,
      ['3 {screen: inbox}'],
      reason: 'The plugin tells the service of a tap with the payload of the '
          'notification, in which the service gave it the data as JSON.',
    );
  });

  test('a tap whose payload the app did not write has no data', () async {
    final (device, service) = await openOnNewDevice();

    final heard = await tapsDuring(service.taps, () async {
      await device.tap(1, payload: 'not JSON');
      await device.tap(2, payload: '["a list"]');
      await device.tap(3, payload: '{"count": 1}');
      await device.tap(4, payload: '');
      await device.tap(5);
    });

    expect(
      heard,
      ['1 {}', '2 {}', '3 {}', '4 {}', '5 {}'],
      reason: 'Data that the service cannot read gives a tap with no data, '
          'as the role says, rather than an error.',
    );
  });

  test(
      'only the service of the last open of the plugin hears of the taps, as '
      'after the next start of the app', () async {
    final (device, first) = await openOnNewDevice();
    final second = await openLocalNotifications();

    final heardFirst = <String>[];
    final subscription =
        first.taps.listen((tap) => heardFirst.add('${tap.id}'));
    final heardSecond = await tapsDuring(second.taps, () => device.tap(8));
    await subscription.cancel();

    expect(heardSecond, ['8 {}']);
    expect(
      heardFirst,
      isEmpty,
      reason: 'The plugin tells only the service that opened it last, which '
          'appNotifications starts with at the next start.',
    );
  });

  test(
      'a tap on a notification of the app reaches the taps of the app once '
      'appNotifications started with the service', () async {
    final (device, service) = await openOnNewDevice();
    await appNotifications.start(service);

    final heard = await tapsDuring(
      appNotifications.taps,
      () => device.tap(9, payload: jsonEncode({'screen': 'inbox'})),
    );

    expect(
      heard,
      ['9 {screen: inbox}'],
      reason: 'The taps of the service are those of the app, which reads '
          'them from appNotifications.',
    );
  });
}
