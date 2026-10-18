// What the tests of the notifications role share, in the apps with the
// role, whichever module provides it: the key under which the app
// remembers that it asked for the permission, the start-up of the app,
// which runs once for the tests of a file, what runs a call in real time,
// what has the app forget that it asked, what brings the user back to the
// app, the notifications of the tests, and a service of the tests, which
// scripts what a provider answers.
//
// It knows only the role, and the preferences role that it requires. The
// matrix fills in the key, which the role publishes.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/bootstrap.dart';
import 'package:{{app_name}}/core/notifications/app_notifications.dart';
import 'package:{{app_name}}/core/notifications/notifications_service.dart';
import 'package:{{app_name}}/core/preferences/app_preferences.dart';

/// The key of the preferences of the app under which the app remembers
/// that it asked for the permission to show notifications.
const String askedKey = '{{asked_key}}';

/// The owner of the notifications of an owner that the tests show and
/// schedule, under [notificationOwnerKey] in their data: no role has this
/// id.
const String ownerOfTests = 'notifications_role_tests';

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

/// Has the app forget that it asked for the permission, as on a first
/// launch: saves `false` under [askedKey] and opens the preferences again,
/// as the next start does, so that the restorer of the role reads it. A
/// key that is removed would not do: the restorer keeps what the app has
/// when nothing is saved.
Future<void> forgetAsking() async {
  await createAppPreferences().setBool(askedKey, false);
  await initPreferences();
}

/// Whether the preferences have saved that the app asked for the
/// permission, or `null` if they have saved nothing under [askedKey].
bool? get askedSaved => createAppPreferences().getBool(askedKey);

/// Brings the user back to the app, as from the settings of the system,
/// and waits a moment for the app to ask the service again.
Future<void> comeBack(WidgetTester tester) => inRealTime(
      tester,
      'coming back to the app',
      () async {
        tester.binding
          ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
          ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
    );

/// A time to come for a scheduled notification: a day from now, so that
/// the system does not show it while a test runs.
DateTime get tomorrow => DateTime.now().add(const Duration(days: 1));

/// The notification [id] of the tests, with a [title], a body unless
/// [withBody] is false, and data of its own, under the owner [owner] if
/// given, which takes a negative id.
AppNotification notificationOfTests(
  int id, {
  String title = 'Title',
  bool withBody = true,
  String? owner,
}) =>
    AppNotification(
      id: id,
      title: '$title $id',
      body: withBody ? 'Body $id' : null,
      data: owner == null
          ? {'test': 'notification $id'}
          : {'test': 'notification $id', notificationOwnerKey: owner},
    );

/// [notifications] as a test compares them: each with its id, title, body
/// and data, by its id, whatever the order in which a provider lists them.
Map<int, String> byId(List<AppNotification> notifications) => {
      for (final notification in notifications)
        notification.id: '${notification.title}, ${notification.body}, '
            '${notification.data}',
    };

/// What the system of a [ScriptedNotifications] does when the app asks for
/// the permission.
enum SystemAnswer {
  /// It shows its question, and the user allows.
  allows,

  /// It shows its question, and the user does not allow.
  refuses,

  /// It has no question to show, as Android before 13, so the request opens
  /// the settings of the system for the notifications of the app, and
  /// completes before the user did anything there.
  opensSettings,
}

/// A service of the tests, which a test gives appNotifications.start() to
/// script what a provider answers: whether the app may show notifications,
/// what the system does when the app asks, the tap that launched the app
/// and the taps of the user. It notes each call that reaches it.
final class ScriptedNotifications implements NotificationsService {
  /// Creates the service on a system that does [answer] when the app asks,
  /// on which the app may show notifications if [enabled], and which the
  /// tap [launchTap] launched, if any.
  ScriptedNotifications({
    this.answer = SystemAnswer.allows,
    this.enabled = false,
    this.launchTap,
  });

  /// What the system does when the app asks for the permission.
  final SystemAnswer answer;

  /// Whether the app may show notifications, as the settings of the system
  /// have it: a test changes it as the user does there.
  bool enabled;

  @override
  final NotificationTap? launchTap;

  /// The calls that reached the service, in their order, such as
  /// `areEnabled`, `request` and `show 3`.
  final List<String> calls = [];

  /// How many times the app asked the service for the permission.
  int get requests => calls.where((call) => call == 'request').length;

  /// Holds a request back until it completes, if set. A test sets it in
  /// real time, since a future of the fake time of the test completes only
  /// when that time goes on.
  Completer<void>? held;

  final StreamController<NotificationTap> _taps =
      StreamController<NotificationTap>.broadcast();

  /// Tells of a tap of the user on the notification [id] with [data].
  void tap(int id, [Map<String, String> data = const {}]) =>
      _taps.add(NotificationTap(id: id, data: data));

  @override
  Stream<NotificationTap> get taps => _taps.stream;

  @override
  Future<bool> areEnabled() async {
    calls.add('areEnabled');
    return enabled;
  }

  @override
  Future<void> request() async {
    calls.add('request');
    await held?.future;
    if (answer == SystemAnswer.allows) enabled = true;
  }

  @override
  Future<void> openSettings() async => calls.add('openSettings');

  @override
  Future<void> show(AppNotification notification) async =>
      calls.add('show ${notification.id}');

  @override
  Future<void> schedule(AppNotification notification, DateTime at) async =>
      calls.add('schedule ${notification.id}');

  @override
  Future<void> cancel(int id) async => calls.add('cancel $id');

  @override
  Future<void> cancelAll() async => calls.add('cancelAll');

  @override
  Future<List<AppNotification>> scheduled() async {
    calls.add('scheduled');
    return const [];
  }
}
