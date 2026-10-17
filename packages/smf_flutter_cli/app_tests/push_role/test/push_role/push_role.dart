// What the tests of the push role share, in the apps with the role,
// whichever module provides it: the owner of the notifications that show
// messages, the start-up of the app, which runs once for the tests of a
// file, what runs a call in real time, what waits for the address of the
// device, what brings the user back to the app, the messages of the tests,
// and a service of push messages and one of notifications of the tests,
// which script what a provider answers.
//
// It knows only the role, and the notifications role that it requires. The
// matrix fills in the owner, which is the id of the role.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/bootstrap.dart';
import 'package:{{app_name}}/core/notifications/app_notifications.dart';
import 'package:{{app_name}}/core/notifications/notifications_service.dart';
import 'package:{{app_name}}/core/push/app_push.dart';
import 'package:{{app_name}}/core/push/push_service.dart';

/// The owner of the notifications through which the app shows a message,
/// under [notificationOwnerKey] in their data: the push role.
const String pushOwner = '{{push_owner}}';

/// Runs [action], which [what] names, in real time, as on a device, so that
/// what it waits for, such as the platform side of the provider, does not
/// wait for the fake time of the test. An error of [action] fails the
/// test, which tester.runAsync would only report to the handler of the
/// errors of Flutter.
Future<void> inRealTime(
  WidgetTester tester,
  String what,
  Future<void> Function() action,
) async {
  Object? error;
  StackTrace? stackTrace;
  await tester.runAsync(() async {
    try {
      await action();
    } on Object catch (thrown, stack) {
      error = thrown;
      stackTrace = stack;
    }
  });
  if (error != null) fail('$what threw $error\n$stackTrace');
}

/// The problem of the start-up of the app, which runs once for the tests of
/// a file: `null` before it runs, and empty if it passed.
String? _startUpProblem;

/// Runs the start-up of the app, bootstrap(), as main() runs it before the
/// first frame, in real time, unless a test of the file ran it already, and
/// fails the test if it failed. The handlers of errors that the start-up
/// installs, such as those of crash reporting, and the builder of the widget
/// of an error go back to those of the test once it returns.
Future<void> startUp(WidgetTester tester) async {
  if (_startUpProblem == null) {
    final onError = FlutterError.onError;
    final onPlatformError = PlatformDispatcher.instance.onError;
    final errorWidgetBuilder = ErrorWidget.builder;
    try {
      _startUpProblem = '';
      await inRealTime(tester, 'bootstrap()', bootstrap);
    } on TestFailure catch (failure) {
      _startUpProblem = failure.message ?? 'bootstrap() failed';
    } finally {
      FlutterError.onError = onError;
      PlatformDispatcher.instance.onError = onPlatformError;
      ErrorWidget.builder = errorWidgetBuilder;
    }
  }
  if (_startUpProblem case final problem? when problem.isNotEmpty) {
    fail(problem);
  }
}

/// Waits in real time, for 5 seconds at most, until the app has an address
/// of the device, and returns it, or `null` if none came. The role asks the
/// provider for it without waiting, and the address may come later than
/// the answer, as on iOS.
Future<String?> addressOfApp(WidgetTester tester) async {
  await inRealTime(tester, 'waiting for the address', () async {
    final until = DateTime.now().add(const Duration(seconds: 5));
    while (appPush.address.value == null && DateTime.now().isBefore(until)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });
  return appPush.address.value;
}

/// Waits a moment in real time, for what a call or a message set off, such
/// as a notification that the app shows, to reach a listener.
Future<void> aMoment() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

/// Brings the user back to the app, and waits a moment for the app to ask
/// the service again.
Future<void> comeBack(WidgetTester tester) => inRealTime(
      tester,
      'coming back to the app',
      () async {
        tester.binding
          ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
          ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await aMoment();
      },
    );

/// The message [id] of the tests, with a title unless [withTitle] is false,
/// a body unless [withBody] is false, and data of its own.
PushMessage messageOfTests(
  String id, {
  bool withTitle = true,
  bool withBody = true,
}) =>
    PushMessage(
      id: id,
      title: withTitle ? 'Title $id' : null,
      body: withBody ? 'Body $id' : null,
      data: {'test': 'message $id', 'screen': '/messages/$id'},
    );

/// [message] as a test compares it, with its id, title, body and data.
String describe(PushMessage? message) => message == null
    ? 'none'
    : '${message.id}, ${message.title}, ${message.body}, ${message.data}';

/// A service of push messages of the tests, which a test gives
/// appPush.start() to script what a provider answers: the address of the
/// device and its changes, the messages that arrive in the foreground, the
/// taps on the messages that the platform showed, and the message whose tap
/// launched the app. It notes each call that reaches it.
final class ScriptedPush implements PushService {
  /// Creates the service on a platform that shows a message in the
  /// foreground if [platformShowsInForeground], whose device has the
  /// address [answer], if any, and which a tap on [launch] launched, if
  /// any.
  ScriptedPush({
    this.platformShowsInForeground = false,
    this.answer,
    this.launch,
  });

  @override
  final bool platformShowsInForeground;

  /// The address that the service answers, or `null` while the platform
  /// gives none: a test changes it.
  String? answer;

  /// The message whose tap launched the app, or `null`.
  final PushMessage? launch;

  /// The calls that reached the service, in their order: `address` and
  /// `launchMessage`.
  final List<String> calls = [];

  /// How many times the app asked the service for the address.
  int get addressCalls => calls.where((call) => call == 'address').length;

  final StreamController<String> _addresses =
      StreamController<String>.broadcast();
  final StreamController<PushMessage> _messages =
      StreamController<PushMessage>.broadcast();
  final StreamController<PushMessage> _taps =
      StreamController<PushMessage>.broadcast();

  /// Gives the device the address [address], and tells the app of it.
  void tellAddress(String address) {
    answer = address;
    _addresses.add(address);
  }

  /// Tells of [message], which arrives while the app is in the foreground.
  void deliver(PushMessage message) => _messages.add(message);

  /// Tells of a tap of the user on [message], which the platform showed.
  void tap(PushMessage message) => _taps.add(message);

  @override
  Future<String?> address() async {
    calls.add('address');
    return answer;
  }

  @override
  Stream<String> get addressChanges => _addresses.stream;

  @override
  Stream<PushMessage> get messages => _messages.stream;

  @override
  Stream<PushMessage> get taps => _taps.stream;

  @override
  Future<PushMessage?> launchMessage() async {
    calls.add('launchMessage');
    return launch;
  }
}

/// A service of notifications of the tests, which a test gives
/// appNotifications.start(): it notes each notification that the app shows,
/// tells of a tap of the user on one, and may have been launched by a tap
/// on one. The app may show notifications on it.
final class NotificationsOfTests implements NotificationsService {
  /// Creates the service, which the tap [launchTap] launched, if any.
  NotificationsOfTests({this.launchTap});

  @override
  final NotificationTap? launchTap;

  /// The notifications that the app showed, in their order.
  final List<AppNotification> shown = [];

  final StreamController<NotificationTap> _taps =
      StreamController<NotificationTap>.broadcast();

  /// Tells of a tap of the user on [notification], with its data.
  void tap(AppNotification notification) => _taps.add(
        NotificationTap(id: notification.id, data: notification.data),
      );

  @override
  Stream<NotificationTap> get taps => _taps.stream;

  @override
  Future<bool> areEnabled() async => true;

  @override
  Future<void> request() async {}

  @override
  Future<void> openSettings() async {}

  @override
  Future<void> show(AppNotification notification) async =>
      shown.add(notification);

  @override
  Future<void> schedule(AppNotification notification, DateTime at) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<List<AppNotification>> scheduled() async => const [];
}

/// Starts appNotifications with [notifications], if given, and then
/// appPush with [push], as the start-up of the app does with the services
/// of the providers.
Future<void> startWith(
  WidgetTester tester,
  ScriptedPush push, {
  NotificationsOfTests? notifications,
}) =>
    inRealTime(tester, 'starting with services of the test', () async {
      if (notifications != null) await appNotifications.start(notifications);
      await appPush.start(push);
      await aMoment();
    });
