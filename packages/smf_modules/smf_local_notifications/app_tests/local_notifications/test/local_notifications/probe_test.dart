// A test that continuous integration runs in the apps with the
// local_notifications module, on the real flutter_local_notifications,
// whose platform side is a device in memory
// (local_notifications_mocks.dart): the probe of the module, which the
// start check runs on a device, finds no problem once the service of the
// module opened, and finds the channel of the app missing, or with another
// name or importance, as a device that kept an older channel has it.
//
// It uses the service of the module, which openLocalNotifications() opens
// on a device of each test, and runs none of the start-up of the app.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/notifications/local_notifications_service.dart';
import 'package:{{app_name}}/core/notifications/notifications_service.dart';

import '../../integration_test/local_notifications/probe.dart';
import '../local_notifications_mocks.dart';
import 'service.dart';

/// What the probe finds, in real time as on a device.
Future<List<String>> probe() => probeLocalNotifications(() async {});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(onAndroid);

  test('the probe finds no problem once the service opened', () async {
    mockLocalNotifications();
    await openLocalNotifications();

    expect(
      await probe(),
      isEmpty,
      reason: 'The service creates the channel of the app with its name and a '
          'high importance when it opens.',
    );
  });

  test(
      'the probe finds the channel of the app missing, or with another name '
      'or importance', () async {
    final missing = mockLocalNotifications();
    final withoutChannel = await probe();
    missing.channels[notificationChannelId] = {
      'id': notificationChannelId,
      'name': 'An older name',
      'importance': 3,
    };
    final older = await probe();

    expect(withoutChannel, [
      'The device has no channel $notificationChannelId of the app, which the '
          'service creates when the app starts.',
    ]);
    expect(older, [
      'The channel $notificationChannelId of the app is named "An older '
          'name", not "$notificationChannelName".',
      'The channel $notificationChannelId of the app has the importance '
          'defaultImportance, not high.',
    ]);
  });

  test('on iOS, which has no channels, the probe finds nothing to check',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final device = mockLocalNotifications(platform: TargetPlatform.iOS);

    expect(await probe(), isEmpty);
    expect(device.calls, isEmpty);
  });
}
