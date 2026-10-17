import '../notifications/notifications_service.dart';

/// Whether the app may show notifications on this device. It stands for the
/// settings of the system, which every start of the app finds as the last
/// one left them: at first the app may not, as on a first launch.
bool _enabled = false;

/// The notifications that are scheduled on this device, by their ids. They
/// stand for the alarms of the system, which outlive a start of the app.
final Map<int, AppNotification> _scheduled = {};

/// Waits for the answer of the system, which takes a moment, as with a
/// provider that asks it: a turn of the event loop. So a test makes the
/// calls of the notifications in real time, as it runs the start-up of the
/// app.
Future<void> _answer() => Future<void>.delayed(Duration.zero);

/// Opens the notifications of the fixture, as a start of the app does: it
/// asks the system for what it keeps, which takes a moment, and returns the
/// service. It asks the user nothing.
///
/// A start keeps whether the app may show notifications and the
/// notifications that are scheduled. Nothing outlives the process of the
/// app, so each run of the tests of a file starts as on a first launch.
Future<NotificationsService> openFixtureNotifications() async {
  await _answer();
  return FixtureNotifications._();
}

/// Notifications in memory, on a device whose system has no question for
/// the permission to show them, as Android before 13: [request] opens the
/// settings of the system for the notifications of the app instead, as the
/// notifications role asks of a provider. The user of the tests turns the
/// notifications on there, as the mocks of a provider grant the permission
/// when the app asks, so one request turns them on: through the role, that
/// looks like a question that the user allows.
///
/// The device shows nothing and has no user who taps a notification, so
/// the service tells of no tap.
final class FixtureNotifications implements NotificationsService {
  FixtureNotifications._();

  @override
  NotificationTap? get launchTap => null;

  @override
  Stream<NotificationTap> get taps => const Stream.empty();

  @override
  Future<bool> areEnabled() async {
    await _answer();
    return _enabled;
  }

  /// Opens the settings of the system, since the system has no question to
  /// show, unless the app may show notifications already.
  @override
  Future<void> request() async {
    await _answer();
    if (!_enabled) await openSettings();
  }

  /// The user of the tests turns the notifications of the app on in the
  /// settings of the system.
  @override
  Future<void> openSettings() async {
    await _answer();
    _enabled = true;
  }

  /// Shows nothing, and takes the place of the scheduled notification of
  /// its id, as the role asks of a provider: that one is no longer
  /// scheduled.
  @override
  Future<void> show(AppNotification notification) async {
    await _answer();
    _scheduled.remove(notification.id);
  }

  @override
  Future<void> schedule(AppNotification notification, DateTime at) async {
    await _answer();
    _scheduled[notification.id] = notification;
  }

  @override
  Future<void> cancel(int id) async {
    await _answer();
    _scheduled.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    await _answer();
    _scheduled.clear();
  }

  @override
  Future<List<AppNotification>> scheduled() async {
    await _answer();
    return [..._scheduled.values];
  }
}
