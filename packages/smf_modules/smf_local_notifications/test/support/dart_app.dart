import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:yaml/yaml.dart';

/// A stand-in for the part of Flutter's foundation library that the file of
/// the module and the plugin use, with the signatures of Flutter 3.44: a
/// test sets the platform that the app runs on, which Flutter has as a
/// getter.
const _foundation = '''
enum TargetPlatform { android, fuchsia, iOS, linux, macOS, windows }

TargetPlatform defaultTargetPlatform = TargetPlatform.android;
''';

/// A stand-in for the part of Flutter's widgets library that the file of
/// the module uses, with the signatures of Flutter 3.44: the binding tells
/// its observers of each state of the lifecycle of the app that a test
/// gives it.
const _widgets = '''
export 'foundation.dart';

enum AppLifecycleState { detached, resumed, inactive, hidden, paused }

abstract mixin class WidgetsBindingObserver {
  void didChangeAppLifecycleState(AppLifecycleState state) {}
}

class WidgetsBinding {
  WidgetsBinding._();

  static final WidgetsBinding instance = WidgetsBinding._();

  final List<WidgetsBindingObserver> _observers = [];

  void addObserver(WidgetsBindingObserver observer) => _observers.add(observer);

  bool removeObserver(WidgetsBindingObserver observer) =>
      _observers.remove(observer);

  void handleAppLifecycleStateChanged(AppLifecycleState state) {
    for (final observer in List.of(_observers)) {
      observer.didChangeAppLifecycleState(state);
    }
  }
}
''';

/// A stand-in for the part of the timezone package that the module uses,
/// with the signatures of timezone 0.11: the location of UTC, which needs
/// no database of time zones, and a time in a location.
const _timezone = '''
class Location {
  const Location(this.name);

  final String name;
}

const Location _utc = Location('Etc/UTC');

// ignore: non_constant_identifier_names
Location get UTC => _utc;

class TZDateTime {
  TZDateTime.from(DateTime other, this.location) : instant = other.toUtc();

  final Location location;

  /// The moment of the time, in UTC: the location of every time here.
  final DateTime instant;
}
''';

/// A stand-in for the part of flutter_local_notifications that the module
/// uses, with the signatures of flutter_local_notifications 22.3 and what
/// its plugin does where the service relies on it: the implementation of
/// the platform that `defaultTargetPlatform` names, a tap that the platform
/// tells the callback of the last open of, and the notifications that are
/// scheduled.
///
/// The platform is a device in memory that a script reads and scripts:
/// `pluginCalls`, each call as its method and what it got; whether the app
/// may show notifications; what the system does when the app asks; the
/// tap that launched the app; and a tap while the app runs. Like Android,
/// it keeps the scheduled notification of an id when one with that id is
/// shown. A question of the system takes the app out of the foreground
/// until the user answered, as on a device.
const _plugin = r'''
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:timezone/timezone.dart';

final List<String> pluginCalls = [];

/// Whether the app may show notifications.
bool platformEnabled = false;

/// What the system does when the app asks for the permission: `allows` or
/// `refuses` once it showed its question, `none` without one, or `fails`
/// once it showed it, with an error of the platform.
String systemAnswer = 'allows';

final Map<int, PendingNotificationRequest> _scheduled = {};
NotificationAppLaunchDetails? platformLaunch;
DidReceiveNotificationResponseCallback? _onTap;

/// The ids of the notifications that are scheduled.
List<int> get platformScheduled => [..._scheduled.keys];

/// Has the platform tell the plugin of a tap on the notification [id] with
/// [payload].
void platformTaps(int? id, String? payload) => _onTap?.call(
      NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        id: id,
        payload: payload,
      ),
    );

bool _request() {
  if (platformEnabled || systemAnswer == 'none') return platformEnabled;
  WidgetsBinding.instance
      .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  if (systemAnswer == 'fails') throw StateError('The platform broke.');
  if (systemAnswer == 'allows') platformEnabled = true;
  WidgetsBinding.instance
      .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  return platformEnabled;
}

typedef DidReceiveNotificationResponseCallback = void Function(
  NotificationResponse details,
);

enum Importance {
  unspecified(-1000),
  none(0),
  min(1),
  low(2),
  defaultImportance(3),
  high(4),
  max(5);

  const Importance(this.value);

  final int value;
}

class Priority {
  const Priority(this.value);

  final int value;

  static const Priority min = Priority(-2);
  static const Priority low = Priority(-1);
  static const Priority defaultPriority = Priority(0);
  static const Priority high = Priority(1);
  static const Priority max = Priority(2);
}

enum AndroidScheduleMode {
  alarmClock,
  exact,
  exactAllowWhileIdle,
  inexact,
  inexactAllowWhileIdle,
}

enum NotificationResponseType {
  selectedNotification,
  selectedNotificationAction,
}

enum DateTimeComponents { time, dayOfWeekAndTime, dayOfMonthAndTime, dateAndTime }

class AndroidNotificationDetails {
  const AndroidNotificationDetails(
    this.channelId,
    this.channelName, {
    this.icon,
    this.importance = Importance.defaultImportance,
    this.priority = Priority.defaultPriority,
  });

  final String channelId;
  final String channelName;
  final String? icon;
  final Importance importance;
  final Priority priority;
}

class DarwinNotificationDetails {
  const DarwinNotificationDetails({
    this.presentAlert,
    this.presentBadge,
    this.presentSound,
    this.presentBanner,
    this.presentList,
  });

  final bool? presentAlert;
  final bool? presentBadge;
  final bool? presentSound;
  final bool? presentBanner;
  final bool? presentList;
}

class NotificationDetails {
  const NotificationDetails({this.android, this.iOS});

  final AndroidNotificationDetails? android;
  final DarwinNotificationDetails? iOS;
}

class AndroidInitializationSettings {
  const AndroidInitializationSettings(this.defaultIcon);

  final String defaultIcon;
}

class DarwinInitializationSettings {
  const DarwinInitializationSettings({
    this.requestAlertPermission = true,
    this.requestSoundPermission = true,
    this.requestBadgePermission = true,
    this.requestProvisionalPermission = false,
    this.defaultPresentAlert = true,
    this.defaultPresentSound = true,
    this.defaultPresentBadge = true,
    this.defaultPresentBanner = true,
    this.defaultPresentList = true,
  });

  final bool requestAlertPermission;
  final bool requestSoundPermission;
  final bool requestBadgePermission;
  final bool requestProvisionalPermission;
  final bool defaultPresentAlert;
  final bool defaultPresentSound;
  final bool defaultPresentBadge;
  final bool defaultPresentBanner;
  final bool defaultPresentList;
}

class InitializationSettings {
  const InitializationSettings({this.android, this.iOS});

  final AndroidInitializationSettings? android;
  final DarwinInitializationSettings? iOS;
}

class NotificationResponse {
  const NotificationResponse({
    required this.notificationResponseType,
    this.id,
    this.actionId,
    this.input,
    this.payload,
    this.data = const <String, dynamic>{},
  });

  final int? id;
  final String? actionId;
  final String? input;
  final String? payload;
  final Map<String, dynamic> data;
  final NotificationResponseType notificationResponseType;
}

class NotificationAppLaunchDetails {
  const NotificationAppLaunchDetails(
    this.didNotificationLaunchApp, {
    this.notificationResponse,
  });

  final bool didNotificationLaunchApp;
  final NotificationResponse? notificationResponse;
}

class PendingNotificationRequest {
  const PendingNotificationRequest(this.id, this.title, this.body, this.payload);

  final int id;
  final String? title;
  final String? body;
  final String? payload;
}

class NotificationsEnabledOptions {
  const NotificationsEnabledOptions({
    required this.isEnabled,
    required this.isAlertEnabled,
    required this.isBadgeEnabled,
    required this.isSoundEnabled,
  });

  final bool isEnabled;
  final bool isAlertEnabled;
  final bool isBadgeEnabled;
  final bool isSoundEnabled;
}

class AndroidNotificationChannel {
  const AndroidNotificationChannel(
    this.id,
    this.name, {
    this.description,
    this.importance = Importance.defaultImportance,
  });

  final String id;
  final String name;
  final String? description;
  final Importance importance;
}

abstract class FlutterLocalNotificationsPlatform {}

class AndroidFlutterLocalNotificationsPlugin
    extends FlutterLocalNotificationsPlatform {
  Future<void> createNotificationChannel(
    AndroidNotificationChannel notificationChannel,
  ) async =>
      pluginCalls.add(
        'createNotificationChannel ${notificationChannel.id} '
        '${notificationChannel.name} ${notificationChannel.importance.name}',
      );

  Future<bool?> areNotificationsEnabled() async {
    pluginCalls.add('areNotificationsEnabled');
    return platformEnabled;
  }

  Future<bool?> requestNotificationsPermission() async {
    pluginCalls.add('requestNotificationsPermission');
    return _request();
  }
}

class IOSFlutterLocalNotificationsPlugin
    extends FlutterLocalNotificationsPlatform {
  Future<bool?> requestPermissions({
    bool sound = false,
    bool alert = false,
    bool badge = false,
    bool provisional = false,
    bool critical = false,
    bool carPlay = false,
    bool providesAppNotificationSettings = false,
  }) async {
    pluginCalls.add(
      'requestPermissions sound $sound, alert $alert, badge $badge, '
      'provisional $provisional',
    );
    return _request();
  }

  Future<NotificationsEnabledOptions?> checkPermissions() async {
    pluginCalls.add('checkPermissions');
    return NotificationsEnabledOptions(
      isEnabled: platformEnabled,
      isAlertEnabled: platformEnabled,
      isBadgeEnabled: platformEnabled,
      isSoundEnabled: platformEnabled,
    );
  }
}

class FlutterLocalNotificationsPlugin {
  factory FlutterLocalNotificationsPlugin() => _instance;

  FlutterLocalNotificationsPlugin._();

  static final FlutterLocalNotificationsPlugin _instance =
      FlutterLocalNotificationsPlugin._();

  final AndroidFlutterLocalNotificationsPlugin _android =
      AndroidFlutterLocalNotificationsPlugin();
  final IOSFlutterLocalNotificationsPlugin _ios =
      IOSFlutterLocalNotificationsPlugin();

  T? resolvePlatformSpecificImplementation<
      T extends FlutterLocalNotificationsPlatform>() {
    final FlutterLocalNotificationsPlatform instance =
        defaultTargetPlatform == TargetPlatform.iOS ? _ios : _android;
    return instance is T ? instance : null;
  }

  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  }) async {
    _onTap = onDidReceiveNotificationResponse;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = settings.iOS!;
      pluginCalls.add(
        'initialize iOS asks alert ${ios.requestAlertPermission}, sound '
        '${ios.requestSoundPermission}, badge ${ios.requestBadgePermission}, '
        'provisional ${ios.requestProvisionalPermission}; presents '
        'alert ${ios.defaultPresentAlert}, banner ${ios.defaultPresentBanner}, '
        'list ${ios.defaultPresentList}, sound ${ios.defaultPresentSound}',
      );
    } else {
      pluginCalls.add('initialize Android ${settings.android!.defaultIcon}');
    }
    return true;
  }

  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails() async {
    pluginCalls.add('getNotificationAppLaunchDetails');
    return platformLaunch ?? const NotificationAppLaunchDetails(false);
  }

  Future<void> show({
    required int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails,
    String? payload,
  }) async {
    final android = notificationDetails!.android!;
    pluginCalls.add(
      'show $id $title $body $payload in ${android.channelId} '
      '${android.channelName}, ${android.importance.name}, priority '
      '${android.priority.value}',
    );
  }

  Future<void> zonedSchedule({
    required int id,
    required TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? title,
    String? body,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    pluginCalls.add(
      'zonedSchedule $id $title $body $payload at '
      '${scheduledDate.instant.toIso8601String()} in '
      '${scheduledDate.location.name}, ${androidScheduleMode.name}, in '
      '${notificationDetails.android!.channelId}',
    );
    _scheduled[id] = PendingNotificationRequest(id, title, body, payload);
  }

  Future<void> cancel({required int id, String? tag}) async {
    pluginCalls.add('cancel $id');
    _scheduled.remove(id);
  }

  Future<void> cancelAll() async {
    pluginCalls.add('cancelAll');
    _scheduled.clear();
  }

  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    pluginCalls.add('pendingNotificationRequests');
    return [..._scheduled.values];
  }

  Future<bool?> openAppNotificationSettings() async {
    pluginCalls.add('openAppNotificationSettings');
    return true;
  }
}
''';

/// The Dart files in `lib/` of a rendered app, written to a temporary
/// directory with stand-ins for the libraries of Flutter, of timezone and
/// of flutter_local_notifications that the code of the module uses, so that
/// it can be analyzed and run with the Dart SDK alone: the tests of the
/// package run without the Flutter SDK, which flutter_local_notifications
/// needs.
///
/// The other files of the app need more of Flutter, so the analyzer checks
/// the files of the owners it is given, and a script that runs the app
/// imports none of the others. The real package runs in the tests of the
/// generated apps. [delete] removes the directory.
final class DartApp {
  DartApp._(this._root, this._files);

  /// Writes the Dart files in `lib/` of [app].
  factory DartApp.write(RenderedApp app) {
    final root = Directory.systemTemp.createTempSync(
      'smf_local_notifications_',
    );
    final files = [
      for (final file in app.files.values)
        if (file.path.startsWith('lib/') && file.path.endsWith('.dart')) file,
    ];
    void write(String path, String text) => File('${root.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);

    for (final file in files) {
      write('app/${file.path}', file.text);
    }
    write('flutter/lib/foundation.dart', _foundation);
    write('flutter/lib/widgets.dart', _widgets);
    write('timezone/lib/timezone.dart', _timezone);
    write(
      'flutter_local_notifications/lib/flutter_local_notifications.dart',
      _plugin,
    );
    write('app/pubspec.yaml', 'name: contract_app\n');
    // The stand-ins are in the language of the app too.
    final languageVersion = _languageVersionOf(app);
    write(
      'app/.dart_tool/package_config.json',
      jsonEncode({
        'configVersion': 2,
        'packages': [
          for (final (name, rootUri) in [
            ('contract_app', '../'),
            ('flutter', '../../flutter/'),
            ('timezone', '../../timezone/'),
            (
              'flutter_local_notifications',
              '../../flutter_local_notifications/'
            ),
          ])
            {
              'name': name,
              'rootUri': rootUri,
              'packageUri': 'lib/',
              'languageVersion': languageVersion,
            },
        ],
      }),
    );
    return DartApp._(root, files);
  }

  final Directory _root;
  final List<RenderedFile> _files;

  String get _appPath =>
      Directory('${_root.path}/app').resolveSymbolicLinksSync();

  /// The errors and warnings that the analyzer finds in the files of
  /// [owners], each with the path of its file.
  Future<List<String>> analysisProblems(Set<ContributionOrigin> owners) async {
    final appPath = _appPath;
    final collection = AnalysisContextCollection(includedPaths: [appPath]);
    try {
      final problems = <String>[];
      for (final file in _files) {
        if (!owners.contains(file.owner)) continue;
        // The analyzer takes only the paths of the system, such as
        // C:\app\lib\main.dart on Windows.
        final path = Uri.directory(appPath).resolve(file.path).toFilePath();
        final result = await collection
            .contextFor(path)
            .currentSession
            .getResolvedUnit(path);
        if (result is! ResolvedUnitResult) {
          problems.add('${file.path}: cannot be resolved: $result');
          continue;
        }
        for (final diagnostic in result.diagnostics) {
          if (diagnostic.severity == Severity.info) continue;
          problems.add(
            '${file.path}:${result.lineInfo.getLocation(diagnostic.offset)}: '
            '${diagnostic.message}',
          );
        }
      }
      return problems;
    } finally {
      await collection.dispose();
    }
  }

  /// Runs [script], a Dart library whose `main(List<String>, SendPort)`
  /// imports the app by its package, `contract_app`, in an isolate of its
  /// own, and returns the first message it sends.
  ///
  /// Throws a [StateError] with the error if the isolate fails, or if it
  /// sends nothing in time.
  Future<Object?> run(String script) async {
    final file = File('${_root.path}/check.dart')..writeAsStringSync(script);
    final result = Completer<Object?>();
    void fail(String message) {
      if (!result.isCompleted) result.completeError(StateError(message));
    }

    final messages = ReceivePort()
      ..listen((message) {
        if (!result.isCompleted) result.complete(message);
      });
    final errors = ReceivePort()
      ..listen((error) => fail('The script failed: $error'));
    // The isolate sends its message before it ends, so an end that comes
    // first means that it sent none.
    final exits = ReceivePort()
      ..listen((_) => fail('The script ended without a message.'));
    Isolate? isolate;
    try {
      isolate = await Isolate.spawnUri(
        file.uri,
        const [],
        messages.sendPort,
        onError: errors.sendPort,
        onExit: exits.sendPort,
        packageConfig: Uri.file('$_appPath/.dart_tool/package_config.json'),
      );
      return await result.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw StateError('The script sent nothing in time.'),
      );
    } finally {
      isolate?.kill(priority: Isolate.immediate);
      messages.close();
      errors.close();
      exits.close();
    }
  }

  /// Deletes the directory of the app.
  void delete() => _root.deleteSync(recursive: true);
}

/// The language version of [app]: that of the lower bound of the SDK
/// constraint of its pubspec, such as 3.12 for `^3.12.0`.
String _languageVersionOf(RenderedApp app) {
  final pubspec = loadYaml(app.files['pubspec.yaml']!.text) as YamlMap;
  final sdk = (pubspec['environment'] as YamlMap)['sdk'] as String;
  final version = RegExp(r'(\d+)\.(\d+)').firstMatch(sdk)!;
  return '${version[1]}.${version[2]}';
}
