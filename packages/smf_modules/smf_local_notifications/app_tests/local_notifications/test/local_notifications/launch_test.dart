// A test that continuous integration runs in the apps with the
// local_notifications module, on the real flutter_local_notifications,
// whose platform side is a device in memory
// (local_notifications_mocks.dart): the tap on a notification that
// launched the app, which the plugin finds when it opens, is the launch tap
// of the notifications service of the module, with the data of the
// notification, on Android and on iOS. An app that no tap launched has
// none.
//
// It uses the service of the module, which openLocalNotifications() opens
// on a device of each test, and runs none of the start-up of the app.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/notifications/local_notifications_service.dart';
import 'package:{{app_name}}/core/notifications/notifications_service.dart';

import '../local_notifications_mocks.dart';
import 'service.dart';

/// The launch tap of [service] as a test compares it.
String launchOf(NotificationsService service) => switch (service.launchTap) {
      null => 'none',
      final tap => '${tap.id} ${tap.data}',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(onAndroid);

  test(
      'the tap that launched the app is the launch tap of the service, with '
      'the data of the notification', () async {
    final device = mockLocalNotifications()
      ..launchedBy(-4, payload: jsonEncode({'notifications.owner': 'push'}));

    final service = await openLocalNotifications();

    expect(
      launchOf(service),
      '-4 {notifications.owner: push}',
      reason: 'The plugin keeps the tap that launched the app until it is '
          'opened, and the service reads it then, a tap on a notification of '
          'an owner too, which appNotifications gives to that owner.',
    );
    expect(device.methods, contains('getNotificationAppLaunchDetails'));
  });

  test('an app that no tap launched has no launch tap', () async {
    mockLocalNotifications();

    expect(launchOf(await openLocalNotifications()), 'none');
  });

  test('a launch tap whose payload the app did not write has no data',
      () async {
    mockLocalNotifications().launchedBy(5, payload: 'not JSON');

    expect(launchOf(await openLocalNotifications()), '5 {}');
  });

  test('on iOS too, the tap that launched the app is the launch tap', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    mockLocalNotifications(platform: TargetPlatform.iOS)
        .launchedBy(6, payload: jsonEncode({'screen': 'inbox'}));

    expect(launchOf(await openLocalNotifications()), '6 {screen: inbox}');
  });
}
