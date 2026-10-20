// The probe of the notifications role, whichever module provides it, which
// the start check runs on a device once the first screen of the app
// settled, the only place where the platform side of the provider is the
// real one, and which the test of the role runs too (provider_test.dart):
// the permission of the app agrees with what the service of the provider
// says, the service lists the scheduled notifications, and the app, which
// the start check launched without a tap on a notification, has no tap
// that launched it.
//
// It uses no test framework. It only reads: it asks for no permission,
// since the question of the system would stay over the app on a device,
// and shows and schedules nothing.
import 'package:{{app_name}}/core/notifications/app_notifications.dart';

/// The probe of the start check: what is wrong with the notifications of
/// the app as the start-up left them. It waits for no screen, so it leaves
/// [settle] out.
Future<List<String>> probeNotifications(Future<void> Function() settle) async {
  final enabled = await createNotificationsService().areEnabled();
  final permission = appNotifications.permission.value;
  // The service of the provider lists them; a failure reaches the start
  // check, which reports it.
  await appNotifications.scheduled();
  return [
    if ((permission == NotificationPermission.granted) != enabled)
      'The permission of the app is ${permission.name}, though the service '
          'says that the app ${enabled ? 'may' : 'may not'} show '
          'notifications.',
    if (appNotifications.launchTap case final tap?)
      'The app was launched without a tap on a notification, but its launch '
          'tap is a tap on the notification ${tap.id}.',
  ];
}
