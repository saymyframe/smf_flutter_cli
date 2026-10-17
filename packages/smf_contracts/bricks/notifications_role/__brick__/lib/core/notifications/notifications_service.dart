/// The id of the channel of Android in which the app shows its
/// notifications. Android shows a notification only in a channel, and the
/// user turns each channel of an app on or off in the settings of the
/// system.
const String notificationChannelId = {{{channel_id}}};

/// The name of that channel, which the settings of the system show: the
/// name of the app.
const String notificationChannelName = {{{channel_name}}};

/// The name of the drawable of Android that a notification of the app shows
/// as its small icon:
/// `android/app/src/main/res/drawable/ic_notification.xml`.
const String notificationIcon = {{{icon}}};

/// A notification of the app.
final class AppNotification {
  /// Creates the notification [id] with [title], and with [body] and [data]
  /// if they are given.
  const AppNotification({
    required this.id,
    required this.title,
    this.body,
    this.data = const {},
  });

  /// The id of the notification. A notification with the id of one that is
  /// shown or scheduled takes its place, a scheduled one when it shows.
  final int id;

  /// The title of the notification.
  final String title;

  /// The text below the title, or `null` for a notification with a title
  /// alone.
  final String? body;

  /// What the app needs to know when the user taps the notification, such
  /// as the screen that the tap opens.
  final Map<String, String> data;
}

/// A tap of the user on a notification of the app.
final class NotificationTap {
  /// Creates the tap on the notification [id] with [data].
  const NotificationTap({required this.id, this.data = const {}});

  /// The id of the notification.
  final int id;

  /// The data of the notification.
  final Map<String, String> data;
}

/// The notifications of the platform, which the provider of notifications
/// implements: the permission to show them, the notifications that the app
/// shows now or at a time to come, and the taps of the user on them.
///
/// The code of the app does not use it: it uses `appNotifications` of
/// `app_notifications.dart`, which calls this service, remembers that the
/// app asked for the permission and tells the taps of the app from those of
/// an owner.
///
/// Every implementation keeps to this:
/// - The function that creates the service asks the user nothing. It may be
///   called again, and the service that it returns then has what the device
///   kept, such as the notifications that are scheduled.
/// - [show] and [schedule] complete whether the app may show notifications
///   or not. Without the permission the system shows nothing, and may drop
///   a notification that is scheduled.
/// - Every notification goes to the channel [notificationChannelId] with a
///   high importance and, on Android, [notificationIcon] as its small icon.
///   It shows also while the app is in the foreground.
/// - [schedule] shows the notification at about the time that it is given,
///   not to the minute, also when the app is closed then, and after a
///   restart of the device. A notification with the id of one that is shown
///   or scheduled takes its place: [show] cancels the scheduled
///   notification of its id, if there is one, so that it does not show
///   later, and a notification scheduled with the id of one that is shown
///   takes its place when it shows. [cancel] removes the notification of
///   its id, shown or scheduled.
/// - [taps] tells of each tap on a notification of the app while the app
///   runs, and [launchTap] is the tap that launched the app. Each has the
///   data that the notification had, or none if the service cannot read it.
/// - [request] shows the question of the system where the platform has one,
///   and completes once the user answered, also with a no, for which it does
///   not throw. Where the platform has no question to show and the app may
///   not show notifications, as on Android before 13, it opens the settings
///   of the system for the notifications of the app instead, as
///   [openSettings] does, and completes. So the user needs only one request
///   to turn the notifications on, whatever the platform.
abstract interface class NotificationsService {
  /// The tap on a notification that launched the app, or `null` if the app
  /// was launched in another way: known when the service is created.
  NotificationTap? get launchTap;

  /// Tells of each tap of the user on a notification of the app while the
  /// app runs: a broadcast stream.
  Stream<NotificationTap> get taps;

  /// Whether the app may show notifications.
  Future<bool> areEnabled();

  /// Asks the user for the permission to show notifications, or opens the
  /// settings of the system where the platform has no question to show.
  Future<void> request();

  /// Opens the settings of the system for the notifications of the app.
  Future<void> openSettings();

  /// Shows [notification] now, in place of the notification of its id that
  /// is shown, and cancels the scheduled notification of its id.
  Future<void> show(AppNotification notification);

  /// Shows [notification] at about [at].
  Future<void> schedule(AppNotification notification, DateTime at);

  /// Removes the notification [id], whether it is shown or scheduled.
  Future<void> cancel(int id);

  /// Removes every notification of the app, shown or scheduled.
  Future<void> cancelAll();

  /// The notifications that are scheduled and not shown yet.
  Future<List<AppNotification>> scheduled();
}
