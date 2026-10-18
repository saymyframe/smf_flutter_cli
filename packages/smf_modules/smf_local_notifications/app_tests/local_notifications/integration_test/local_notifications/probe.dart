// The probe of the local_notifications module, which the start check runs
// on a device once the first screen of the app settled, the only place
// where the platform side of flutter_local_notifications is the real one,
// and which the tests of the module run over the device in memory too
// (probe_test.dart): on Android, the channel of the app, which the service
// of the module creates when the app starts, has the name of the app and a
// high importance. Android keeps the importance of a channel that exists,
// whatever the app later creates it with, so only a device shows what a
// notification of the app gets. iOS has no channels.
//
// It uses no test framework. It only reads: it asks for no permission,
// since the question of the system would stay over the app on a device,
// and shows and schedules nothing.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:{{app_name}}/core/notifications/notifications_service.dart';

/// The probe of the start check: what is wrong with the channel of the app
/// on an Android device. It waits for no screen, so it leaves [settle] out.
Future<List<String>> probeLocalNotifications(
  Future<void> Function() settle,
) async {
  final android = FlutterLocalNotificationsPlugin()
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  if (android == null) return const [];
  final channels = await android.getNotificationChannels() ?? const [];
  final channel = channels
      .where((channel) => channel.id == notificationChannelId)
      .firstOrNull;
  if (channel == null) {
    return [
      'The device has no channel $notificationChannelId of the app, which '
          'the service creates when the app starts.',
    ];
  }
  return [
    if (channel.name != notificationChannelName)
      'The channel $notificationChannelId of the app is named '
          '"${channel.name}", not "$notificationChannelName".',
    if (channel.importance != Importance.high)
      'The channel $notificationChannelId of the app has the importance '
          '${channel.importance.name}, not high.',
  ];
}
