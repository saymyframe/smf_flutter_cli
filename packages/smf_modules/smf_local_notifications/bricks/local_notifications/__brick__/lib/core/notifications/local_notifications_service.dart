import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'notifications_service.dart';

/// How the app shows each notification: in its channel, with a high
/// importance, so that Android shows it as a banner, also while the app is
/// in the foreground, as iOS does with the settings of [_settings].
const _details = NotificationDetails(
  android: AndroidNotificationDetails(
    notificationChannelId,
    notificationChannelName,
    importance: Importance.high,
    priority: Priority.high,
  ),
  iOS: DarwinNotificationDetails(),
);

/// The settings of the plugin: the small icon of a notification on Android,
/// and on iOS no question for the permission when the app starts, which
/// the plugin asks by default. The app asks when the user turns on
/// something that notifies, through `appNotifications.request()`.
const _settings = InitializationSettings(
  android: AndroidInitializationSettings(notificationIcon),
  iOS: DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  ),
);

/// Opens the notifications of the app on flutter_local_notifications: sets
/// up the plugin, creates the channel of the app on Android, and reads the
/// tap on a notification that launched the app. It asks the user nothing.
///
/// It may run again, as a test of the next launch of the app does: the
/// service then has what the device kept, such as the notifications that
/// are scheduled, and the taps go to the new service.
Future<NotificationsService> openLocalNotifications() async {
  final plugin = FlutterLocalNotificationsPlugin();
  final taps = StreamController<NotificationTap>.broadcast();
  await plugin.initialize(
    settings: _settings,
    onDidReceiveNotificationResponse: (response) {
      if (_tapOf(response) case final tap?) taps.add(tap);
    },
  );
  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          notificationChannelId,
          notificationChannelName,
          importance: Importance.high,
        ),
      );
  final launch = await plugin.getNotificationAppLaunchDetails();
  final launchResponse = launch != null && launch.didNotificationLaunchApp
      ? launch.notificationResponse
      : null;
  return LocalNotificationsService._(
    plugin,
    taps,
    launchResponse == null ? null : _tapOf(launchResponse),
  );
}

/// The tap of [response], with the data that its notification had, or none
/// when the payload is no data of the app; `null` without an id.
NotificationTap? _tapOf(NotificationResponse response) {
  final id = response.id;
  if (id == null) return null;
  return NotificationTap(id: id, data: _dataOf(response.payload));
}

/// The data in [payload], the JSON of a map of texts, as the app gives the
/// plugin a notification, or none for anything else.
Map<String, String> _dataOf(String? payload) {
  if (payload == null || payload.isEmpty) return const {};
  try {
    final decoded = jsonDecode(payload);
    if (decoded is Map<String, Object?> &&
        decoded.values.every((value) => value is String)) {
      return decoded.cast<String, String>();
    }
  } on FormatException {
    // A payload that the app did not write.
  }
  return const {};
}

/// The notifications of the app on
/// [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications).
///
/// The code of the app does not use it: it shows notifications through
/// `appNotifications` of `app_notifications.dart`.
///
/// A scheduled notification shows at about its time, also when the app is
/// closed then: on Android the plugin sets an inexact alarm, which needs no
/// permission for exact alarms, and sets it again after a restart of the
/// device. Times go to the plugin in UTC, so no database of time zones is
/// needed.
///
/// Where the system shows a question for the permission, [request] asks
/// it. Where the system shows none and the app may not show notifications,
/// as on Android before 13, and once the system asks no more (iOS asks
/// once, Android 13 and later twice), [request] opens the settings of the
/// system for the notifications of the app instead. The plugin does not
/// tell whether the system showed its question, so the service watches the
/// app: the question takes the app out of the foreground until the user
/// answers. A request that starts while the app is out of the foreground,
/// such as under the control center of iOS, opens no settings, since the
/// question then takes nothing away from the app.
final class LocalNotificationsService implements NotificationsService {
  LocalNotificationsService._(this._plugin, this._taps, this.launchTap);

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<NotificationTap> _taps;

  @override
  final NotificationTap? launchTap;

  @override
  Stream<NotificationTap> get taps => _taps.stream;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

  @override
  Future<bool> areEnabled() async {
    if (_android case final android?) {
      return await android.areNotificationsEnabled() ?? false;
    }
    final permissions = await _ios?.checkPermissions();
    return permissions?.isEnabled ?? false;
  }

  @override
  Future<void> request() async {
    final question = _Question(WidgetsBinding.instance.lifecycleState);
    WidgetsBinding.instance.addObserver(question);
    final bool allowed;
    try {
      allowed = await _ask();
    } finally {
      WidgetsBinding.instance.removeObserver(question);
    }
    if (!allowed && !question.shown) await openSettings();
  }

  /// Asks the system for the permission, and returns whether the app may
  /// show notifications then.
  Future<bool> _ask() async {
    if (_android case final android?) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final allowed = await _ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return allowed ?? false;
  }

  @override
  Future<void> openSettings() async {
    await _plugin.openAppNotificationSettings();
  }

  @override
  Future<void> show(AppNotification notification) async {
    // Android keeps the alarm of a scheduled notification when one with its
    // id is shown, so it would show again later.
    final pending = await _plugin.pendingNotificationRequests();
    if (pending.any((request) => request.id == notification.id)) {
      await _plugin.cancel(id: notification.id);
    }
    await _plugin.show(
      id: notification.id,
      title: notification.title,
      body: notification.body,
      notificationDetails: _details,
      payload: jsonEncode(notification.data),
    );
  }

  @override
  Future<void> schedule(AppNotification notification, DateTime at) =>
      _plugin.zonedSchedule(
        id: notification.id,
        title: notification.title,
        body: notification.body,
        scheduledDate: tz.TZDateTime.from(at, tz.UTC),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: jsonEncode(notification.data),
      );

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<List<AppNotification>> scheduled() async => [
        for (final request in await _plugin.pendingNotificationRequests())
          AppNotification(
            id: request.id,
            title: request.title ?? '',
            body: request.body,
            data: _dataOf(request.payload),
          ),
      ];
}

/// Tells whether the system may have shown something over the app while it
/// was watched, such as its question for the permission: the app leaves the
/// foreground then, and comes back once the user answered.
///
/// An app that is out of the foreground when the watch starts, such as one
/// under the control center of iOS, sees no change when the question shows,
/// so the system may have shown it.
final class _Question with WidgetsBindingObserver {
  /// Starts the watch of an app in the lifecycle [state], which is `null`
  /// while the platform has not told it, as in a test: the app is in the
  /// foreground then.
  _Question(AppLifecycleState? state)
      : shown = state != null && state != AppLifecycleState.resumed;

  bool shown;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) shown = true;
  }
}
