// What the tests of the local_notifications module share: the device of a
// test, on which the test opens the notifications service of the module,
// and how a test reads what reached the platform side.
//
// The tests use the service of the module, which openLocalNotifications()
// opens, on the real flutter_local_notifications, whose platform side is
// the device in memory of local_notifications_mocks.dart. They run none of
// the start-up of the app: what appNotifications does with a service, and
// what every provider of the notifications role keeps to, is for the test
// of the role.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:{{app_name}}/core/notifications/local_notifications_service.dart';
import 'package:{{app_name}}/core/notifications/notifications_service.dart';

import '../local_notifications_mocks.dart';

/// Opens the service of the module on a new device of [platform], as the
/// app finds it on its first launch, and returns both, with the calls of
/// the open forgotten.
///
/// For iOS it sets debugDefaultTargetPlatformOverride, with which the
/// plugin and the service choose the platform: the test puts it back with
/// [onAndroid].
Future<(MockLocalNotifications, NotificationsService)> openOnNewDevice({
  TargetPlatform platform = TargetPlatform.android,
}) async {
  debugDefaultTargetPlatformOverride =
      platform == TargetPlatform.android ? null : platform;
  final device = mockLocalNotifications(platform: platform);
  final service = await openLocalNotifications();
  device.calls.clear();
  return (device, service);
}

/// Puts the platform of the tests back to Android, which a test of iOS
/// changed.
void onAndroid() => debugDefaultTargetPlatformOverride = null;

/// The arguments of the only call of [method] among [calls].
Map<Object?, Object?> argumentsOf(List<MethodCall> calls, String method) =>
    calls.singleWhere((call) => call.method == method).arguments
        as Map<Object?, Object?>;
