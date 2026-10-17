// The platform side of flutter_local_notifications for the tests that
// continuous integration runs in the apps with the local_notifications
// module: a device in memory, in place of the notifications of Android or
// iOS. It starts as an app finds the device on its first launch: the app
// may not show notifications, nothing is scheduled, and no tap on a
// notification launched the app. A request for the permission shows the
// question of the system, which the user allows, as the notifications role
// asks of the mocks of a provider. The matrix sets it up before the tests
// of every module of such an app (MatrixAppTest.mocks), so that any of them
// may run the start-up of the app, which opens the notifications on it.
//
// flutter_local_notifications has no mocks for tests, so this answers the
// messages of the plugin to the platform on its method channel, and
// registers the implementation of the plugin for the platform, which
// flutter test does not do. A version of the plugin that changes its
// messages breaks these tests.
//
// It keeps what the platforms keep where the app relies on it: what is
// scheduled and whether the app may show notifications, for as long as the
// tests of a test file last, so a next start of the app finds them. Android
// keeps the alarm of a scheduled notification when one with its id is
// shown, and iOS takes the scheduled one away. Android 13 and later ask
// for the permission twice at most, and iOS once; after that a request
// shows no question and answers at once, as Android before 13 always does.
// A question takes the app out of the foreground until the user answered,
// as on a device.
//
// It differs from a device in this: it shows nothing, a scheduled
// notification never comes due, and the settings of the system that it
// opens change nothing until a test changes MockLocalNotifications.enabled
// as the user does there.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// The method channel of the plugin.
const _channel = MethodChannel('dexterous.com/flutter/local_notifications');

/// What the user does with the question of the system for the permission,
/// when the system shows it.
enum QuestionAnswer {
  /// The user allows the app to show notifications.
  allows,

  /// The user does not allow it.
  refuses,
}

/// A notification of the device: one that is shown or scheduled.
final class _Notification {
  _Notification(Map<Object?, Object?> arguments)
      : id = arguments['id']! as int,
        title = arguments['title'] as String?,
        body = arguments['body'] as String?,
        payload = arguments['payload'] as String?;

  final int id;
  final String? title;
  final String? body;
  final String? payload;

  /// The notification as the platform lists it among the pending ones.
  Map<String, Object?> get pending =>
      {'id': id, 'title': title, 'body': body, 'payload': payload};
}

/// The platform side of flutter_local_notifications in memory; see
/// [mockLocalNotifications].
final class MockLocalNotifications {
  MockLocalNotifications._(this.platform);

  /// The platform that the device is: Android or iOS.
  final TargetPlatform platform;

  /// Whether the app may show notifications, as the settings of the system
  /// have it: a test changes it as the user does there.
  bool enabled = false;

  /// What the user does with the next question of the system.
  QuestionAnswer answer = QuestionAnswer.allows;

  /// How many more times the system shows its question when the app asks,
  /// while the app may not show notifications: twice on Android 13 and
  /// later, once on iOS, and never on Android before 13 ([withoutQuestion]).
  late int questionsLeft = platform == TargetPlatform.iOS ? 1 : 2;

  /// The calls that reached the platform side, in their order.
  final List<MethodCall> calls = [];

  /// The channels of Android that the app created, by their id, as the
  /// platform has them.
  final Map<String, Map<Object?, Object?>> channels = {};

  final Map<int, _Notification> _scheduled = {};
  final Map<int, _Notification> _shown = {};
  Map<String, Object?>? _launch;

  /// Makes the device one on which the system shows no question for the
  /// permission, as Android before 13: a request answers at once with
  /// whether the app may show notifications.
  void withoutQuestion() => questionsLeft = 0;

  /// The ids of the notifications that are shown, in the order in which they
  /// were shown.
  List<int> get shown => [..._shown.keys];

  /// The ids of the notifications that are scheduled, in the order in which
  /// they were scheduled.
  List<int> get scheduled => [..._scheduled.keys];

  /// The names of the methods of the calls that reached the platform side,
  /// in their order.
  List<String> get methods => [for (final call in calls) call.method];

  /// Has the next open of the plugin find that a tap on the notification
  /// [id] with [payload] launched the app, as a device has it when the user
  /// opened the app from a notification.
  void launchedBy(int id, {String? payload}) => _launch = {
        'notificationLaunchedApp': true,
        'notificationResponse': _response(id, payload),
      };

  /// Taps the notification [id] with [payload] while the app runs, as the
  /// platform tells the plugin of it.
  Future<void> tap(int id, {String? payload}) async {
    final completer = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      _channel.name,
      _channel.codec.encodeMethodCall(
        MethodCall('didReceiveNotificationResponse', _response(id, payload)),
      ),
      (_) => completer.complete(),
    );
    await completer.future;
  }

  static Map<String, Object?> _response(int id, String? payload) => {
        'notificationId': id,
        'actionId': null,
        'input': null,
        // NotificationResponseType.selectedNotification
        'notificationResponseType': 0,
        'payload': payload,
      };

  /// Answers the messages of the plugin to the platform.
  void _install() {
    if (platform == TargetPlatform.iOS) {
      IOSFlutterLocalNotificationsPlugin.registerWith();
    } else {
      AndroidFlutterLocalNotificationsPlugin.registerWith();
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return _answer(call);
    });
  }

  Object? _answer(MethodCall call) {
    final arguments = call.arguments;
    switch (call.method) {
      case 'initialize':
        return true;
      case 'createNotificationChannel':
        final channel = arguments as Map<Object?, Object?>;
        channels[channel['id']! as String] = channel;
        return null;
      case 'getNotificationChannels':
        // What Android has of a channel, with the colour of its light as
        // one number.
        return [
          for (final channel in channels.values)
            {
              'description': null,
              'groupId': null,
              'showBadge': true,
              'bypassDnd': false,
              'playSound': true,
              'enableLights': false,
              'enableVibration': true,
              'vibrationPattern': null,
              'audioAttributesUsage': 5,
              ...channel,
              'ledColor': 0,
            },
        ];
      case 'getNotificationAppLaunchDetails':
        return _launch ?? {'notificationLaunchedApp': false};
      case 'areNotificationsEnabled':
        return enabled;
      case 'checkPermissions':
        return {
          'isEnabled': enabled,
          'isAlertEnabled': enabled,
          'isBadgeEnabled': enabled,
          'isSoundEnabled': enabled,
        };
      case 'requestNotificationsPermission' || 'requestPermissions':
        return _request();
      case 'openAppNotificationSettings':
        return true;
      case 'show':
        final notification = _Notification(arguments as Map<Object?, Object?>);
        // iOS takes the scheduled request of the id away, and Android keeps
        // its alarm.
        if (platform == TargetPlatform.iOS) _scheduled.remove(notification.id);
        _shown.remove(notification.id);
        _shown[notification.id] = notification;
        return null;
      case 'zonedSchedule':
        final notification = _Notification(arguments as Map<Object?, Object?>);
        _scheduled.remove(notification.id);
        _scheduled[notification.id] = notification;
        return null;
      case 'pendingNotificationRequests':
        return [
          for (final notification in _scheduled.values) notification.pending
        ];
      case 'cancel':
        // Android sends the id with a tag, and iOS the id alone.
        final id =
            arguments is Map ? arguments['id']! as int : arguments as int;
        _scheduled.remove(id);
        _shown.remove(id);
        return null;
      case 'cancelAll':
        _scheduled.clear();
        _shown.clear();
        return null;
    }
    throw MissingPluginException('No answer for ${call.method}');
  }

  /// Answers a request for the permission: the question of the system,
  /// while the system shows it, takes the app out of the foreground until
  /// the user answered [answer].
  bool _request() {
    if (enabled || questionsLeft == 0) return enabled;
    questionsLeft--;
    final binding = TestWidgetsFlutterBinding.instance
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    if (answer == QuestionAnswer.allows) enabled = true;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    return enabled;
  }
}

/// Answers the platform side of flutter_local_notifications with a device
/// in memory, Android unless [platform] says otherwise, as an app finds it
/// on its first launch, and returns it: a test reads there what reached the
/// platform side, and scripts what the user does.
///
/// The binding of the tests must be initialized first. A test file that
/// calls it for a device of its own does so before it opens the
/// notifications, and one for iOS sets debugDefaultTargetPlatformOverride
/// too, with which the plugin chooses the implementation of the platform.
MockLocalNotifications mockLocalNotifications({
  TargetPlatform platform = TargetPlatform.android,
}) =>
    MockLocalNotifications._(platform).._install();
