@TestOn('vm')
library;

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contracts/bundles/push_role_bundle.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'dart_files.dart';
import 'role_support.dart';
import 'support.dart';

/// The file of the fake provider of push messages in the test app.
const _fakeFile = ImportRef.app('fakes/fake_push.dart');

/// The file of the fake provider of notifications in the test app.
const _fakeNotificationsFile = ImportRef.app('fakes/fake_notifications.dart');

/// The file of the fake preferences in the test app.
const _fakePreferencesFile = ImportRef.app('fakes/fake_preferences.dart');

/// The file of `appPush`, as code imports it.
const _controllerImport = ImportRef.app('core/push/app_push.dart');

/// The implementation of the service of the test app: one that is created
/// asynchronously, or one created with the app.
RoleImplementation _implementation({required bool async}) => async
    ? const RoleImplementation.async(
        type: TypeRef('FakePush', import: _fakeFile),
        init: FactoryRef('openFakePush', import: _fakeFile),
      )
    : const RoleImplementation(
        type: TypeRef('FakePush', import: _fakeFile),
        create: FactoryRef('createFakePush', import: _fakeFile),
      );

/// What the template of the role contributes.
List<Contribution> _contributions() =>
    pushRole.template.contribute(testContext);

/// The files of the role in an app with its notifications and their
/// preferences, rendered with an implementation that is created
/// asynchronously, or with the app, and what the template puts into other
/// sockets.
Future<RenderedTemplate> _rendered({bool async = false}) => renderTemplate(
      pushRole,
      data: [
        dataOf(pushRole, _implementation(async: async), module: 'fake_push'),
      ],
      present: {notificationsRole, preferencesRole},
    );

/// The files of the notifications of an app with their preferences,
/// rendered with the fake provider of notifications of the test app, and
/// what their template puts into other sockets.
Future<RenderedTemplate> _notificationsRendered() => renderTemplate(
      notificationsRole,
      data: [
        dataOf(
          notificationsRole,
          const RoleImplementation(
            type: TypeRef('FakeNotifications', import: _fakeNotificationsFile),
            create: FactoryRef(
              'createFakeNotifications',
              import: _fakeNotificationsFile,
            ),
          ),
          module: 'fake_notifications',
        ),
      ],
      present: {preferencesRole},
    );

/// A stand-in for the part of Flutter's foundation library that the files
/// of the role, of the notifications and of the preferences use, with the
/// signatures of Flutter 3.44: the app runs in debug mode, and what it
/// prints goes to `debugPrinted`.
const _foundation = r'''
const bool kDebugMode = true;

/// What the app printed with [debugPrint], in order.
final List<String> debugPrinted = [];

void debugPrint(String? message, {int? wrapWidth}) =>
    debugPrinted.add('$message');

typedef VoidCallback = void Function();

abstract class Listenable {
  const Listenable();

  void addListener(VoidCallback listener);

  void removeListener(VoidCallback listener);
}

abstract class ValueListenable<T> extends Listenable {
  const ValueListenable();

  T get value;
}

mixin class ChangeNotifier implements Listenable {
  final List<VoidCallback> _listeners = [];

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void notifyListeners() {
    for (final listener in [..._listeners]) {
      listener();
    }
  }
}

class ValueNotifier<T> extends ChangeNotifier implements ValueListenable<T> {
  ValueNotifier(this._value);

  T _value;

  @override
  T get value => _value;

  set value(T newValue) {
    if (_value == newValue) return;
    _value = newValue;
    notifyListeners();
  }
}
''';

/// A stand-in for the part of Flutter's widgets library that the files of
/// the role and of the notifications use: what that library exports of the
/// foundation library, and the binding with the observers of the lifecycle
/// of the app. `lifecycle()` puts the app into a state, and `resumeApp()`
/// stands for the user who comes back to the app.
const _widgets = '''
export 'foundation.dart' show ChangeNotifier, Listenable, ValueNotifier, VoidCallback;

enum AppLifecycleState { detached, resumed, inactive, hidden, paused }

abstract mixin class WidgetsBindingObserver {
  void didChangeAppLifecycleState(AppLifecycleState state) {}
}

class WidgetsBinding {
  static final WidgetsBinding instance = WidgetsBinding();

  /// The observers that were added and not removed.
  final List<WidgetsBindingObserver> observers = [];

  void addObserver(WidgetsBindingObserver observer) => observers.add(observer);

  bool removeObserver(WidgetsBindingObserver observer) =>
      observers.remove(observer);
}

/// The app comes into [state], which every observer is told of.
void lifecycle(AppLifecycleState state) {
  for (final observer in [...WidgetsBinding.instance.observers]) {
    observer.didChangeAppLifecycleState(state);
  }
}

/// The user comes back to the app, which was shown but not in use.
void resumeApp() {
  lifecycle(AppLifecycleState.inactive);
  lifecycle(AppLifecycleState.resumed);
}
''';

/// A provider of push messages for the test app, which keeps to the
/// contract of `PushService` unless a test says otherwise.
///
/// The address of the device, whether the platform shows a message in the
/// foreground and the message that launched the app are on variables that
/// stand for the device: each new service reads them, as a service does at
/// the next launch of an app. An answer has the address that the device had
/// when it was asked for. The services note their calls, and a test holds a
/// call until it lets it go, or makes it fail.
const _fakePush = '''
import 'dart:async';

import '../core/push/push_service.dart';

/// The address of the device, or `null` while the platform gives none.
String? addressOnDevice;

/// Whether the platform shows a message that arrives in the foreground.
bool platformShows = false;

/// The message whose tap launched the app, which each new service reads.
PushMessage? launchedBy;

/// The calls that reached the services, in order.
final List<String> calls = [];

/// The [calls] since it last asked.
List<String> takeCalls() {
  final taken = [...calls];
  calls.clear();
  return taken;
}

/// The calls that wait until their completer completes, by their names.
final Map<String, Completer<void>> holds = {};

/// What the calls throw, by their names.
final Map<String, Object> failures = {};

/// How many services were created.
int created = 0;

PushService createFakePush() => FakePush();

Future<PushService> openFakePush() async {
  await Future<void>.delayed(Duration.zero);
  return FakePush();
}

final class FakePush implements PushService {
  FakePush() : _launchedBy = launchedBy {
    created++;
  }

  final PushMessage? _launchedBy;

  final StreamController<String> _addresses = StreamController.broadcast();

  final StreamController<PushMessage> _messages =
      StreamController.broadcast();

  final StreamController<PushMessage> _taps = StreamController.broadcast();

  /// Whether something follows the streams of the service.
  bool get hasListener =>
      _addresses.hasListener || _messages.hasListener || _taps.hasListener;

  /// The device gets [address] in place of the one it had.
  void changeAddress(String address) {
    addressOnDevice = address;
    _addresses.add(address);
  }

  /// [message] arrives while the app is in the foreground.
  void arrive(PushMessage message) => _messages.add(message);

  /// The user taps [message], which the platform showed.
  void tap(PushMessage message) => _taps.add(message);

  /// Sends [error] to those who follow the messages, the taps and the
  /// addresses.
  void fail(Object error) {
    _messages.addError(error);
    _taps.addError(error);
    _addresses.addError(error);
  }

  Future<void> _enter(String call) async {
    calls.add(call);
    await holds[call]?.future;
    if (failures[call] case final failure?) throw failure;
  }

  @override
  bool get platformShowsInForeground => platformShows;

  @override
  Future<String?> address() async {
    final answer = addressOnDevice;
    await _enter('address');
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
    await _enter('launchMessage');
    return _launchedBy;
  }
}
''';

/// A provider of notifications for the test app: the app may show
/// notifications, the notifications that it shows go to `shownByApp`, and
/// the tap that launched the app is on a variable that each new service
/// reads. A test taps a notification, and makes `show` fail.
const _fakeNotifications = '''
import 'dart:async';

import '../core/notifications/notifications_service.dart';

/// The tap on a notification that launched the app.
NotificationTap? launchedByNotification;

/// The notifications that the app showed, in order.
final List<AppNotification> shownByApp = [];

/// What `show` throws, if anything.
Object? showFails;

NotificationsService createFakeNotifications() => FakeNotifications();

final class FakeNotifications implements NotificationsService {
  FakeNotifications() : launchTap = launchedByNotification;

  final StreamController<NotificationTap> _taps =
      StreamController.broadcast();

  @override
  final NotificationTap? launchTap;

  @override
  Stream<NotificationTap> get taps => _taps.stream;

  /// The user taps a notification.
  void tap(NotificationTap tap) => _taps.add(tap);

  @override
  Future<bool> areEnabled() async => true;

  @override
  Future<void> request() async {}

  @override
  Future<void> openSettings() async {}

  @override
  Future<void> show(AppNotification notification) async {
    if (showFails case final failure?) throw failure;
    shownByApp.add(notification);
  }

  @override
  Future<void> schedule(AppNotification notification, DateTime at) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<List<AppNotification>> scheduled() async => [];
}
''';

/// Preferences of the test app that read and write a `bool`, which is all
/// that the notifications need. Any other read or write throws.
const _fakePreferences = '''
import '../core/preferences/app_preferences.dart';

AppPreferences openFakePreferences() => FakePreferences();

final class FakePreferences implements AppPreferences {
  final Map<String, Object> _values = {};

  @override
  bool? getBool(String key) => switch (_values[key]) {
        final bool value => value,
        _ => null,
      };

  @override
  Future<void> setBool(String key, bool value) async => _values[key] = value;

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
''';

/// What the scripts for the test app share. `pump` lets what is on its way
/// happen, `start` starts the app as `bootstrap()` does, `shown` tells a
/// message, and `shownNotification` a notification that the app showed.
const _notes = r'''
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:my_app/core/notifications/app_notifications.dart';
import 'package:my_app/core/preferences/app_preferences.dart';
import 'package:my_app/core/push/app_push.dart';
import 'package:my_app/fakes/fake_notifications.dart';
import 'package:my_app/fakes/fake_push.dart';

final result = <String, Object?>{};

Future<void> pump() => Future<void>.delayed(Duration.zero);

/// Starts the app as `bootstrap()` does: the preferences, then the
/// notifications, then the push messages.
Future<void> start() async {
  await initPreferences();
  await initNotifications();
  await initPush();
}

String? shown(PushMessage? message) => message == null
    ? null
    : '${message.id} ${message.title} ${message.body} ${message.data}';

String shownNotification(AppNotification notification) =>
    '${notification.title} ${notification.body} ${notification.data}';

/// The notifications service of the app, as a fake.
FakeNotifications get notificationsService =>
    createNotificationsService() as FakeNotifications;

/// The push service of the app, as a fake.
FakePush get pushService => createPushService() as FakePush;
''';

/// Goes through the life of the address of the device, which the platform
/// gives late: the start, a resume while the answer is on its way, the
/// answer, a new address, and the next launch of the app. After each step
/// it notes the address, the calls that reached the provider, what the
/// listeners of the address were told of, and what the app printed.
const _address = '''
Future<void> main(List<String> arguments, SendPort port) async {
  final heard = <String?>[];
  appPush.address.addListener(() => heard.add(appPush.address.value));
  void note(String step) {
    result[step] = {
      'address': appPush.address.value,
      'calls': takeCalls(),
      'heard': [...heard],
      'printed': [...debugPrinted],
    };
    heard.clear();
    debugPrinted.clear();
  }

  note('before the start');
  addressOnDevice = 'device-1';
  holds['address'] = Completer<void>();
  await start();
  note('the start, while the platform has not answered');
  resumeApp();
  await pump();
  note('a resume while the answer is on its way');
  holds.remove('address')!.complete();
  await pump();
  note('the answer');
  resumeApp();
  await pump();
  note('a resume with an address');

  final first = pushService;
  first.changeAddress('device-2');
  await pump();
  note('a new address');
  first.changeAddress('device-2');
  await pump();
  note('the same address again');

  holds['address'] = Completer<void>();
  await initPush();
  note('the next launch, while the platform has not answered');
  first.changeAddress('device-3');
  await pump();
  note('a new address of the service of the launch before');
  holds.remove('address')!.complete();
  await pump();
  note('the answer at the next launch');
  result['the services'] = {
    'created': created,
    'the first one is followed': first.hasListener,
    // One of the notifications and one of the push messages.
    'observers of the lifecycle': WidgetsBinding.instance.observers.length,
  };
  port.send(result);
}
''';

/// What [_address] sends back.
const Map<String, Object?> _addressResult = {
  'before the start': {
    'address': null,
    'calls': <Object?>[],
    'heard': <Object?>[],
    'printed': <Object?>[],
  },
  // The start asks for the address and does not wait for it.
  'the start, while the platform has not answered': {
    'address': null,
    'calls': ['address', 'launchMessage'],
    'heard': <Object?>[],
    'printed': <Object?>[],
  },
  // One question at a time.
  'a resume while the answer is on its way': {
    'address': null,
    'calls': <Object?>[],
    'heard': <Object?>[],
    'printed': <Object?>[],
  },
  'the answer': {
    'address': 'device-1',
    'calls': <Object?>[],
    'heard': ['device-1'],
    'printed': ['The address of this device for push messages: device-1'],
  },
  // An address that the app has is not asked for again.
  'a resume with an address': {
    'address': 'device-1',
    'calls': <Object?>[],
    'heard': <Object?>[],
    'printed': <Object?>[],
  },
  'a new address': {
    'address': 'device-2',
    'calls': <Object?>[],
    'heard': ['device-2'],
    'printed': ['The address of this device for push messages: device-2'],
  },
  'the same address again': {
    'address': 'device-2',
    'calls': <Object?>[],
    'heard': <Object?>[],
    'printed': <Object?>[],
  },
  // The address is that of the new service, which has not answered yet.
  'the next launch, while the platform has not answered': {
    'address': null,
    'calls': ['address', 'launchMessage'],
    'heard': [null],
    'printed': <Object?>[],
  },
  'a new address of the service of the launch before': {
    'address': null,
    'calls': <Object?>[],
    'heard': <Object?>[],
    'printed': <Object?>[],
  },
  // The device kept the address that it had when the new service was asked.
  'the answer at the next launch': {
    'address': 'device-2',
    'calls': <Object?>[],
    'heard': ['device-2'],
    'printed': ['The address of this device for push messages: device-2'],
  },
  'the services': {
    'created': 2,
    'the first one is followed': false,
    'observers of the lifecycle': 2,
  },
};

/// A platform that gives no address at first, a resume that asks again,
/// resumes while the question is on its way, an answer that comes after the
/// service told of an address, and an answer of the service of the launch
/// before, which comes after the next launch asked.
const _lateAddress = '''
Future<void> main(List<String> arguments, SendPort port) async {
  await start();
  result['the address while the platform gives none'] = appPush.address.value;
  result['the calls of the start'] = takeCalls();
  resumeApp();
  await pump();
  result['the calls of a resume without an address'] = takeCalls();

  addressOnDevice = 'device-1';
  holds['address'] = Completer<void>();
  resumeApp();
  resumeApp();
  await pump();
  result['the calls of two resumes'] = takeCalls();
  pushService.changeAddress('device-2');
  await pump();
  holds.remove('address')!.complete();
  await pump();
  result['the address after a change and a late answer'] =
      appPush.address.value;

  addressOnDevice = 'first';
  holds['address'] = Completer<void>();
  await initPush();
  addressOnDevice = 'second';
  await initPush();
  result['the calls of two launches'] = takeCalls();
  holds.remove('address')!.complete();
  await pump();
  result['the address once both answered'] = appPush.address.value;
  port.send(result);
}
''';

/// The messages that arrive while the app is in the foreground: with a
/// title and a body, with data alone, with a body alone, twice, and while
/// the platform shows them itself.
const _messages = '''
Future<void> main(List<String> arguments, SendPort port) async {
  await start();
  final heard = <String?>[];
  appPush.messages.listen((message) => heard.add(shown(message)));
  final service = pushService;
  const greeting = PushMessage(
    id: 'm1',
    title: 'Hello',
    body: 'A new message',
    data: {'screen': 'inbox'},
  );
  service
    ..arrive(greeting)
    ..arrive(const PushMessage(id: 'm2', data: {'sync': 'now'}))
    ..arrive(const PushMessage(id: 'm3', body: 'Only a body'))
    // A message equal to the first one, as the provider tells of it again.
    ..arrive(
      PushMessage(
        id: 'm1',
        title: 'Hello',
        body: 'A new message',
        data: {'screen': ['in', 'box'].join()},
      ),
    )
    ..arrive(const PushMessage(title: 'No id'))
    // An empty title or body counts as none.
    ..arrive(const PushMessage(id: 'm5', title: '', body: 'Empty title'))
    ..arrive(const PushMessage(id: 'm6', title: '', body: ''));
  await pump();
  result['heard'] = [...heard];
  result['shown'] = [
    for (final notification in shownByApp) shownNotification(notification),
  ];
  final ids = [for (final notification in shownByApp) notification.id];
  result['the ids are negative'] = ids.every((id) => id < 0);
  result['the same message has the same id'] = ids[0] == ids[2];
  result['other messages have other ids'] =
      {ids[0], ids[1], ids[3], ids[4]}.length == 4;
  result['the message that a notification keeps'] =
      jsonDecode(shownByApp.first.data['push.message']!);
  result['the messages are one stream'] =
      identical(appPush.messages, appPush.messages);

  heard.clear();
  shownByApp.clear();
  platformShows = true;
  service.arrive(greeting);
  await pump();
  result['while the platform shows them'] = {
    'heard': [...heard],
    'shown': shownByApp.length,
  };
  port.send(result);
}
''';

/// The taps on messages that the platform showed, on those that the app
/// showed, on notifications of the app and of another owner, and on
/// notifications of the role whose data lost the message.
const _taps = r'''
Future<void> main(List<String> arguments, SendPort port) async {
  await start();
  final heard = <String, List<String?>>{};
  void listen<T>(String name, Stream<T> taps, String? Function(T) show) =>
      taps.listen((tap) => (heard[name] ??= []).add(show(tap)));
  listen('push', appPush.taps, shown);
  listen('push, a second listener', appPush.taps, shown);
  listen<NotificationTap>(
    'app',
    appNotifications.taps,
    (tap) => '${tap.id} ${tap.data}',
  );

  pushService.tap(const PushMessage(id: 'p1', title: 'By the platform'));
  pushService.arrive(
    const PushMessage(
      id: 'm1',
      title: 'Hello',
      body: 'A new message',
      data: {'screen': 'inbox'},
    ),
  );
  await pump();
  final notification = shownByApp.single;
  notificationsService
    ..tap(NotificationTap(id: notification.id, data: notification.data))
    // The notifications of the role whose data lost the message.
    ..tap(
      const NotificationTap(
        id: -3,
        data: {notificationOwnerKey: 'push', 'screen': 'lost'},
      ),
    )
    ..tap(
      const NotificationTap(
        id: -4,
        data: {
          notificationOwnerKey: 'push',
          'push.message': '{no json',
          'screen': 'broken',
        },
      ),
    )
    ..tap(
      const NotificationTap(
        id: -5,
        data: {notificationOwnerKey: 'push', 'push.message': '{"id": "x"}'},
      ),
    )
    ..tap(
      const NotificationTap(
        id: -6,
        data: {
          notificationOwnerKey: 'push',
          'push.message':
              '{"id": null, "title": null, "body": null, "data": {"n": 1}}',
        },
      ),
    )
    // A notification of another owner, and one of the app.
    ..tap(const NotificationTap(id: -7, data: {notificationOwnerKey: 'chat'}))
    ..tap(const NotificationTap(id: 1, data: {'screen': 'news'}));
  await pump();
  result['heard'] = {...heard};
  result['the taps are one stream'] = identical(appPush.taps, appPush.taps);
  port.send(result);
}
''';

/// The message that launched the app: from the service, from a tap on a
/// notification that the app showed, from both, and from neither.
const _launch = '''
Future<void> main(List<String> arguments, SendPort port) async {
  launchedBy = const PushMessage(id: 'p1', title: 'By the platform');
  result['before the start'] = shown(appPush.launchMessage);
  await start();
  result['by a message that the platform showed'] =
      shown(appPush.launchMessage);

  launchedBy = null;
  launchedByNotification = const NotificationTap(
    id: -2,
    data: {
      'screen': 'inbox',
      notificationOwnerKey: 'push',
      'push.message':
          '{"id":"m1","title":"Hello","body":null,"data":{"screen":"inbox"}}',
    },
  );
  await initNotifications();
  await initPush();
  result['by a message that the app showed'] = {
    'the message': shown(appPush.launchMessage),
    'the launch tap of the notifications': appNotifications.launchTap?.id,
  };

  launchedBy = const PushMessage(id: 'p2', title: 'Both');
  await initNotifications();
  await initPush();
  result['by both'] = shown(appPush.launchMessage);

  launchedBy = null;
  launchedByNotification = const NotificationTap(id: 3);
  await initNotifications();
  await initPush();
  result['by a notification of the app'] = {
    'the message': shown(appPush.launchMessage),
    'the launch tap of the notifications': appNotifications.launchTap?.id,
  };
  port.send(result);
}
''';

/// A second start, after which the service of the first sends a message, a
/// tap and an address, and the notifications tell of a tap on a message.
const _restart = r'''
Future<void> main(List<String> arguments, SendPort port) async {
  await start();
  final first = pushService;
  await initNotifications();
  await initPush();
  final heard = <String?>[];
  appPush.messages.listen((message) => heard.add('message ${message.id}'));
  appPush.taps.listen((message) => heard.add('tap ${message.id}'));
  first
    ..arrive(const PushMessage(id: 'old'))
    ..tap(const PushMessage(id: 'old'))
    ..changeAddress('old');
  pushService
    ..arrive(const PushMessage(id: 'new'))
    ..tap(const PushMessage(id: 'new'));
  notificationsService.tap(
    const NotificationTap(
      id: -1,
      data: {
        notificationOwnerKey: 'push',
        'push.message':
            '{"id":"shown","title":"A","body":null,"data":{}}',
      },
    ),
  );
  await pump();
  result['heard'] = heard;
  result['the address'] = appPush.address.value;
  result['the first service is followed'] = first.hasListener;
  port.send(result);
}
''';

/// Errors of the service on its streams, of an address that the app asks
/// for, of a notification that it shows, and of the message that launched
/// the app.
const _errors = r'''
Future<void> main(List<String> arguments, SendPort port) async {
  final uncaught = <String>[];
  final done = Completer<void>();
  runZonedGuarded(
    () async {
      failures['address'] = StateError('The address broke.');
      await start();
      await pump();
      failures.clear();
      result['the address after an error'] = appPush.address.value;
      addressOnDevice = 'device-1';
      resumeApp();
      await pump();
      result['the address on the next resume'] = appPush.address.value;

      final heard = <String?>[];
      appPush.messages.listen((message) => heard.add(message.id));
      appPush.taps.listen((message) => heard.add('tap ${message.id}'));
      pushService.fail(StateError('The streams broke.'));
      showFails = StateError('The notification broke.');
      pushService
        ..arrive(const PushMessage(id: 'm1', title: 'Hello'))
        ..tap(const PushMessage(id: 'p1'));
      await pump();
      result['heard after the errors'] = heard;

      failures['launchMessage'] = StateError('The launch broke.');
      await initPush();
      result['a start whose launch message fails'] = {
        'the message': shown(appPush.launchMessage),
        'the address': appPush.address.value,
      };
      launchedByNotification = const NotificationTap(
        id: -2,
        data: {
          notificationOwnerKey: 'push',
          'push.message':
              '{"id":"m9","title":"Shown","body":null,"data":{}}',
        },
      );
      await initNotifications();
      await initPush();
      result['a start whose launch message fails, launched by a message '
              'that the app showed'] =
          shown(appPush.launchMessage);
      done.complete();
    },
    (error, stackTrace) => uncaught.add('$error'),
  );
  await done.future;
  result['uncaught'] = uncaught;
  port.send(result);
}
''';

/// The address in a release build: the app knows it, and prints nothing.
const _releaseAddress = '''
Future<void> main(List<String> arguments, SendPort port) async {
  addressOnDevice = 'device-1';
  await start();
  await pump();
  pushService.changeAddress('device-2');
  await pump();
  result['the address'] = appPush.address.value;
  result['printed'] = debugPrinted;
  port.send(result);
}
''';

/// The files of the test app: the files of the role, of the notifications
/// and of the preferences, as their templates generate them, and the fakes.
/// The app runs in debug mode, or in a release build without [debug].
Future<DartFiles> _app({bool async = false, bool debug = true}) async {
  final push = await _rendered(async: async);
  final notifications = await _notificationsRendered();
  final preferences = await renderTemplate(
    preferencesRole,
    data: [
      dataOf(
        preferencesRole,
        const RoleImplementation(
          type: TypeRef('FakePreferences', import: _fakePreferencesFile),
          create: FactoryRef(
            'openFakePreferences',
            import: _fakePreferencesFile,
          ),
        ),
        module: 'fake_preferences',
      ),
    ],
    fromModules: [
      for (final contribution in notifications.contributions)
        if (contribution case final SocketContribution restorer
            when restorer.socket == PreferencesRole.restorers)
          restorer,
    ],
  );
  return DartFiles.write(
    {
      for (final rendered in [push, notifications])
        for (final MapEntry(key: path, value: text) in rendered.files.entries)
          if (path.endsWith('.dart')) path: text,
      ...preferences.files,
      'lib/fakes/fake_push.dart': _fakePush,
      'lib/fakes/fake_notifications.dart': _fakeNotifications,
      'lib/fakes/fake_preferences.dart': _fakePreferences,
    },
    flutter: {
      'foundation.dart': debug
          ? _foundation
          : _foundation.replaceFirst(
              'const bool kDebugMode = true;',
              'const bool kDebugMode = false;',
            ),
      'widgets.dart': _widgets,
    },
  );
}

/// The top-level functions of [unit], by name.
Map<String, FunctionDeclaration> _functionsOf(CompilationUnit unit) => {
      for (final function in unit.declarations.whereType<FunctionDeclaration>())
        function.name.lexeme: function,
    };

/// The statements of the body of [function].
List<String> _statementsOf(FunctionDeclaration function) => [
      for (final statement
          in (function.functionExpression.body as BlockFunctionBody)
              .block
              .statements)
        '$statement',
    ];

/// The members of the class [name] of [unit] that are methods or getters,
/// each as its signature.
List<String> _methodsOf(CompilationUnit unit, String name) => [
      for (final member in unit.declarations
          .whereType<ClassDeclaration>()
          .singleWhere((type) => type.namePart.typeName.lexeme == name)
          .body
          .members)
        if (member is MethodDeclaration)
          [
            '${member.returnType} ',
            if (member.isGetter) 'get ',
            member.name.lexeme,
            '${member.parameters ?? ''}',
          ].join(),
    ];

/// The provider of the role and a feature that uses the role.
const _provider = ModuleDescriptor(
  id: ModuleId('fake_push'),
  description: 'Push messages',
  kind: ModuleKinds.infrastructure,
  providers: [RoleProvider.plain(pushRole)],
);
const _feature = ModuleDescriptor(
  id: ModuleId('inbox'),
  description: 'Inbox',
  kind: ModuleKinds.feature,
  uses: {pushRole},
);

/// The template of another role whose code could reach the service.
final _otherRole = TestRole<NoDsl>('chat', requires: {pushRole});

/// The implementation of the provider of the apps of the rules: its class
/// in one file and its function in another.
const _providerImplementation = RoleImplementation(
  type: TypeRef(
    'FakePushService',
    import: ImportRef.app('core/push/fake_push_service.dart'),
  ),
  create: FactoryRef(
    'createFakePushService',
    import: ImportRef.app('core/push/fake_push.dart'),
  ),
);

/// The file of the function of [_providerImplementation], which imports
/// the file of `PushService`, as the file of an implementation may.
const _factoryFile = DartFileIndex(
  path: 'lib/core/push/fake_push.dart',
  imports: [IndexedImport('push_service.dart')],
  declarations: [
    IndexedDeclaration(
      name: 'createFakePushService',
      kind: DeclarationKind.function,
    ),
  ],
);

/// The issues of the structural rules of the role in an app of the
/// provider with [_providerImplementation] and with [files], each with its
/// owner; a file without an owner has `null`.
List<SmfIssue> _structureIssues(
  Map<DartFileIndex, ContributionOrigin?> files,
) =>
    pushRole.checkStructure(
      StructuralRuleRequest(
        hook: RoleHookRequest(
          data: [
            dataOf(pushRole, _providerImplementation, module: 'fake_push'),
          ],
          presentRoles: {pushRole, notificationsRole, preferencesRole},
          context: testContext,
        ),
        files: {
          _factoryFile.path: _factoryFile,
          for (final file in files.keys) file.path: file,
        },
        owners: {
          _factoryFile.path: ModuleOrigin(_provider.id),
          for (final MapEntry(key: file, value: owner) in files.entries)
            if (owner != null) file.path: owner,
        },
        modules: const [_provider, _feature],
      ),
    );

/// The index of the file at [path] that imports the file of `appPush` and
/// calls [function] of it.
DartFileIndex _calling(String path, String function) => DartFileIndex(
      path: path,
      imports: const [IndexedImport('package:my_app/core/push/app_push.dart')],
      invocations: [IndexedInvocation(function)],
    );

void main() {
  group('the push role', () {
    test(
        'takes one provider, and requires the notifications, which show a '
        'message in the foreground and ask for the permission', () {
      expect(pushRole.id, 'push');
      expect(pushRole.description, 'Push messages');
      expect(pushRole.presenceFlag, 'has_push');
      expect('$pushRole', 'push messages role');
      expect(pushRole.cardinality, RoleCardinality.atMostOne);
      expect(pushRole.requires, {notificationsRole});
      expect(pushRole.uses, isEmpty);
      // Its provider requires what the role requires.
      expect(_provider.effectiveRequires, {notificationsRole});
      expect(_provider.effectiveUses, isEmpty);
      expect(pushRole.sockets, const [PushRole.implementations]);
      expect(PushRole.implementations.tag, 'smf_push__implementations');
      expect(pushRole.options, isEmpty);
      expect(
        [for (final rule in pushRole.moduleRules) rule.id],
        ['services.implementations'],
      );
      expect(
        [for (final rule in pushRole.structuralRules) rule.id],
        [
          'push.factory_calls',
          'push.start_calls',
          'push.implementation_factories',
        ],
      );
    });

    test('guarantees the files of the service and of the controller', () {
      expect(pushRole.interface.files, [
        'lib/core/push/push_service.dart',
        'lib/core/push/app_push.dart',
      ]);
      expect(pushRole.interface.files, [
        PushRole.serviceFile,
        PushRole.controllerFile,
      ]);
      expect(pushRole.interface.symbols, isEmpty);
      expect(PushRole.readmeHeading, 'Push messages');
      // A key of the data of a notification after the id of the role, as
      // the notifications role names its own.
      expect(PushRole.messageKey, '${pushRole.id}.message');
      expect(PushRole.apsEnvironment, 'aps-environment');
      expect(PushRole.backgroundModes, 'UIBackgroundModes');
      expect(PushRole.remoteNotificationMode, 'remote-notification');
    });
  });

  group('the push template', () {
    test('generates the files of the role, in every app', () async {
      final bricks = _contributions().whereType<BrickContribution>().toList();
      expect(
        [for (final brick in bricks) brick.bundle.name],
        [pushRoleBundle.name],
      );
      expect(bricks.single.when, isEmpty);

      final rendered = await _rendered();
      expect(rendered.files.keys.toSet(), pushRole.interface.files.toSet());
      for (final MapEntry(key: path, value: text) in rendered.files.entries) {
        expectParses(text, reason: path);
      }
    });

    test(
        'registers nothing in a DI container, and gives the iOS app the '
        'entitlement of push messages, with the step by hand of the App ID '
        'that it needs, and their background mode in every app', () {
      final contributions = _contributions();
      expect(contributions.whereType<RoleData<Object>>(), isEmpty);
      // Only a paid team signs the entitlement, so the app lists the step
      // of the role of the app entry with it, which a module that adds
      // another such entitlement lists too.
      final step = contributions.whereType<ManualStep>().single;
      expect(step.id, AppEntryRole.iosAppIdStep.id);
      expect(step.title, AppEntryRole.iosAppIdStep.title);
      expect(step.when, isEmpty);
      expect(
        AppEntryRole.paidTeamEntitlements,
        contains(PushRole.apsEnvironment),
      );

      final native = [
        for (final contribution
            in contributions.whereType<SocketContribution>())
          if (contribution.socket == AppEntryRole.iosEntitlements ||
              contribution.socket == AppEntryRole.infoPlist)
            contribution,
      ];
      expect(
        [
          for (final entry in native)
            (entry.socket, entry.entryKey, entry.entryValue),
        ],
        [
          (
            AppEntryRole.iosEntitlements,
            'aps-environment',
            const PlistString('development'),
          ),
          (
            AppEntryRole.infoPlist,
            'UIBackgroundModes',
            const PlistStringArray(['remote-notification']),
          ),
        ],
      );
      for (final entry in native) {
        expect(entry.when, isEmpty);
        expect(entry.socket.problemsWith(entry), isEmpty);
      }
      // The keys as they render in the files of the iOS app.
      expect(
        AppEntryRole.iosEntitlements.render([native.first]).values.single,
        '\t<key>aps-environment</key>\n\t<string>development</string>',
      );
      expect(
        AppEntryRole.infoPlist.render([native.last]).values.single,
        '\t<key>UIBackgroundModes</key>\n'
        '\t<array>\n'
        '\t\t<string>remote-notification</string>\n'
        '\t</array>',
      );
    });

    test('generates the interface that a provider implements, and the message',
        () async {
      final rendered = await _rendered();
      final code = rendered.files[PushRole.serviceFile]!;
      final unit = parseString(content: code).unit;

      expect(_methodsOf(unit, 'PushService'), [
        'bool get platformShowsInForeground',
        'Future<String?> address()',
        'Stream<String> get addressChanges',
        'Stream<PushMessage> get messages',
        'Stream<PushMessage> get taps',
        'Future<PushMessage?> launchMessage()',
      ]);
      expect(
        declarationsOf(code),
        containsAll([
          'PushMessage.id',
          'PushMessage.title',
          'PushMessage.body',
          'PushMessage.data',
        ]),
      );
      // The file of the provider needs nothing of Flutter and no other
      // file of the app.
      expect(unit.directives, isEmpty);
    });

    test(
        'renders the owner of the notifications that show messages, which is '
        'the id of the role, and the key under which they keep a message', () {
      final output = pushRole.template.render(
        inputOf(
          pushRole,
          data: [
            dataOf(
              pushRole,
              _implementation(async: false),
              module: 'fake_push',
            ),
          ],
          present: {notificationsRole, preferencesRole},
        ),
      );
      expect(output.vars, {
        'push_owner': "'push'",
        'message_key': "'push.message'",
      });
    });

    for (final async in [true, false]) {
      final how = async ? 'created asynchronously' : 'created with the app';

      test(
          'creates an implementation $how in initPush(), starts appPush with '
          'it, and awaits that in the platform phase of bootstrap()', () async {
        final rendered = await _rendered(async: async);
        final code = rendered.files[PushRole.controllerFile]!;
        final unit = parseString(content: code).unit;

        final init = _functionsOf(unit)['initPush']!;
        expect('${init.returnType}', 'Future<void>');
        expect(init.functionExpression.parameters!.parameters, isEmpty);
        expect(_statementsOf(init), [
          if (async)
            '_pushService = await impl0.openFakePush();'
          else
            '_pushService = impl0.createFakePush();',
          'await appPush.start(_pushService);',
        ]);
        expect(
          [
            for (final declaration
                in unit.declarations.whereType<TopLevelVariableDeclaration>())
              declaration.toSource(),
          ],
          contains('late PushService _pushService;'),
        );
        expect(
          code,
          contains("import 'package:my_app/fakes/fake_push.dart' as impl0;"),
        );
        // The controller shows messages through the notifications of the
        // app, and imports nothing else of another role.
        expect(
          [
            for (final directive
                in unit.directives.whereType<ImportDirective>())
              directive.uri.stringValue,
          ],
          [
            'dart:async',
            'dart:convert',
            'package:flutter/foundation.dart',
            'package:flutter/widgets.dart',
            '../notifications/app_notifications.dart',
            'push_service.dart',
            'package:my_app/fakes/fake_push.dart',
          ],
        );
        final start = rendered.elsewhere.singleWhere(
          (entry) => entry.socket == AppEntryRole.bootstrapPlatform,
        );
        expect(start.fragment!.code, 'await initPush();');
        expect(start.fragment!.imports, [_controllerImport]);
      });
    }

    test('reports the problems of the implementation', () {
      final issues = pushRole.template.validate(
        inputOf(
          pushRole,
          data: [
            dataOf(
              pushRole,
              const RoleImplementation(
                type: TypeRef('_Private'),
                create: FactoryRef('create', import: _fakeFile),
              ),
              module: 'fake_push',
            ),
          ],
          present: {notificationsRole, preferencesRole},
        ),
      );
      expect(issues.single.origin, const ModuleOrigin(ModuleId('fake_push')));
    });
  });

  group('the generated controller', () {
    for (final async in [false, true]) {
      group(
          'with an implementation '
          '${async ? 'created asynchronously' : 'created with the app'}', () {
        late DartFiles app;

        setUpAll(() async => app = await _app(async: async));

        tearDownAll(() => app.delete());

        test('is code that type-checks', () async {
          expect(await app.analysisProblems(), isEmpty);
        });

        test(
            'asks for the address without waiting for it, asks once at a '
            'time and again on a resume while it has none, follows the new '
            'addresses, prints each in debug mode, and has the address of '
            'the new service at the next launch', () async {
          expect(await app.run('$_notes$_address'), _addressResult);
        });
      });
    }

    group('in one app', () {
      late DartFiles app;

      setUpAll(() async => app = await _app());

      tearDownAll(() => app.delete());

      test(
          'asks again on each resume while the platform gives no address, and '
          'keeps an address that the service told of from a late answer and '
          'from the answer of the service of the launch before', () async {
        expect(await app.run('$_notes$_lateAddress'), {
          'the address while the platform gives none': null,
          'the calls of the start': ['address', 'launchMessage'],
          'the calls of a resume without an address': ['address'],
          'the calls of two resumes': ['address'],
          'the address after a change and a late answer': 'device-2',
          // The question of the next launch does not wait for the one of
          // the launch before.
          'the calls of two launches': [
            'address',
            'launchMessage',
            'address',
            'launchMessage',
          ],
          'the address once both answered': 'second',
        });
      });

      test(
          'tells of each message in the foreground, and shows one with a '
          'title or a body as a notification of the role where the platform '
          'does not', () async {
        // What a notification of the role has in its data: the data of the
        // message, the owner, and the message as JSON.
        const greeting = '{screen: inbox, notifications.owner: push, '
            'push.message: {"id":"m1","title":"Hello","body":"A new '
            'message","data":{"screen":"inbox"}}}';
        const bodyAlone = '{notifications.owner: push, push.message: '
            '{"id":"m3","title":null,"body":"Only a body","data":{}}}';
        const withoutId = '{notifications.owner: push, push.message: '
            '{"id":null,"title":"No id","body":null,"data":{}}}';
        const emptyTitle = '{notifications.owner: push, push.message: '
            '{"id":"m5","title":"","body":"Empty title","data":{}}}';
        expect(await app.run('$_notes$_messages'), {
          'heard': [
            'm1 Hello A new message {screen: inbox}',
            'm2 null null {sync: now}',
            'm3 null Only a body {}',
            'm1 Hello A new message {screen: inbox}',
            'null No id null {}',
            'm5  Empty title {}',
            'm6   {}',
          ],
          // A message with data alone shows nothing, and one with a body
          // alone shows it as its title. The message keeps its texts as
          // they came.
          'shown': [
            'Hello A new message $greeting',
            'Only a body null $bodyAlone',
            'Hello A new message $greeting',
            'No id null $withoutId',
            'Empty title null $emptyTitle',
          ],
          'the ids are negative': true,
          'the same message has the same id': true,
          'other messages have other ids': true,
          'the message that a notification keeps': {
            'id': 'm1',
            'title': 'Hello',
            'body': 'A new message',
            'data': {'screen': 'inbox'},
          },
          'the messages are one stream': true,
          'while the platform shows them': {
            'heard': ['m1 Hello A new message {screen: inbox}'],
            'shown': 0,
          },
        });
      });

      test(
          'tells each listener of the taps on the messages that the platform '
          'or the app showed, and leaves those that the app showed out of '
          'the taps of the notifications of the app', () async {
        expect(await app.run('$_notes$_taps'), {
          'heard': {
            'push': [
              'p1 By the platform null {}',
              'm1 Hello A new message {screen: inbox}',
              // Each notification of the role whose data lost the message
              // gives the rest of its data.
              'null null null {screen: lost}',
              'null null null {screen: broken}',
              'null null null {}',
              'null null null {}',
            ],
            'push, a second listener': [
              'p1 By the platform null {}',
              'm1 Hello A new message {screen: inbox}',
              'null null null {screen: lost}',
              'null null null {screen: broken}',
              'null null null {}',
              'null null null {}',
            ],
            'app': ['1 {screen: news}'],
          },
          'the taps are one stream': true,
        });
      });

      test(
          'has the message whose tap launched the app, from the service or '
          'from the notifications of the app, once bootstrap() is over',
          () async {
        expect(await app.run('$_notes$_launch'), {
          'before the start': null,
          'by a message that the platform showed': 'p1 By the platform null {}',
          'by a message that the app showed': {
            'the message': 'm1 Hello null {screen: inbox}',
            // The notifications of the app leave it out.
            'the launch tap of the notifications': null,
          },
          'by both': 'p2 Both null {}',
          'by a notification of the app': {
            'the message': null,
            'the launch tap of the notifications': 3,
          },
        });
      });

      test(
          'follows only the service of the last start, and the taps of the '
          'notifications once', () async {
        expect(await app.run('$_notes$_restart'), {
          'heard': ['message new', 'tap new', 'tap shown'],
          'the address': null,
          'the first service is followed': false,
        });
      });

      test(
          'leaves an error of the service, of an address or of a '
          'notification to the handler of the uncaught errors, and goes on, '
          'and starts when the launch message fails', () async {
        expect(await app.run('$_notes$_errors'), {
          'the address after an error': null,
          'the address on the next resume': 'device-1',
          'heard after the errors': ['m1', 'tap p1'],
          // The app starts, with the message of the notifications or none.
          'a start whose launch message fails': {
            'the message': null,
            'the address': 'device-1',
          },
          'a start whose launch message fails, launched by a message that '
              'the app showed': 'm9 Shown null {}',
          'uncaught': [
            'Bad state: The address broke.',
            'Bad state: The streams broke.',
            'Bad state: The streams broke.',
            'Bad state: The streams broke.',
            'Bad state: The notification broke.',
            'Bad state: The launch broke.',
            'Bad state: The launch broke.',
          ],
        });
      });
    });
  });

  group('the generated controller in a release build', () {
    late DartFiles app;

    setUpAll(() async => app = await _app(debug: false));

    tearDownAll(() => app.delete());

    test('follows the address and prints none', () async {
      expect(await app.run('$_notes$_releaseAddress'), {
        'the address': 'device-2',
        'printed': <Object?>[],
      });
    });
  });

  group('the note of the push role for coding agents', () {
    test('names what the files of the role and of the notifications declare',
        () async {
      final rendered = await _rendered();
      final notifications = await _notificationsRendered();

      expectNamesOfCode(
        agentNoteOf(pushRole),
        {
          PushRole.controllerFile: [
            'appPush',
            'AppPushController.address',
            'AppPushController.messages',
            'AppPushController.taps',
            'AppPushController.launchMessage',
            'AppPushController.start',
            'initPush',
            'createPushService',
          ],
          PushRole.serviceFile: [
            'PushService',
            'PushMessage',
            'PushMessage.id',
            'PushMessage.title',
            'PushMessage.body',
            'PushMessage.data',
          ],
        },
        files: rendered.files,
      );
      expectNamesOfCode(
        agentNoteOf(pushRole),
        {
          NotificationsRole.controllerFile: [
            'appNotifications',
            'NotificationsController.request',
            'NotificationsController.taps',
          ],
        },
        files: notifications.files,
      );
    });
  });

  group('the section of the push role in the README of the app', () {
    late String section;

    setUpAll(() {
      section = _contributions()
          .whereType<SocketContribution>()
          .singleWhere((entry) => entry.socket == AppEntryRole.readmeSections)
          .entryValue! as String;
    });

    test(
        'is under its heading in every app, and names the code of the role '
        'and of the notifications', () async {
      final readme = _contributions()
          .whereType<SocketContribution>()
          .singleWhere((entry) => entry.socket == AppEntryRole.readmeSections);
      expect(readme.entryKey, PushRole.readmeHeading);
      expect(readme.when, isEmpty);
      final rendered = await _rendered();
      final notifications = await _notificationsRendered();

      expectNamesOfCodeIn(
        section,
        {
          PushRole.controllerFile: [
            'appPush',
            'AppPushController.address',
            'AppPushController.messages',
            'AppPushController.taps',
            'AppPushController.launchMessage',
          ],
        },
        files: rendered.files,
      );
      expectNamesOfCodeIn(
        section,
        {
          NotificationsRole.controllerFile: [
            'appNotifications',
            'NotificationsController.taps',
          ],
        },
        files: notifications.files,
      );
      // The section of the notifications, which tells of the permission.
      expect(
        section,
        contains('the section ${NotificationsRole.readmeHeading}'),
      );
    });

    test(
        'tells what the address needs on iOS and how a free team runs the '
        'app on an iPhone, with the entitlement of the template', () {
      for (final named in [
        PushRole.controllerFile,
        AppEntryRole.iosEntitlementsFile,
        PushRole.apsEnvironment,
      ]) {
        expect(section, contains('`$named`'), reason: named);
      }
      expect(
        section,
        allOf(
          contains('paid Apple Developer Program'),
          contains('free personal team'),
          contains('The simulator needs no change.'),
          contains('(production for a distribution profile)'),
        ),
      );
    });
  });

  group('the rules of the push role', () {
    const providerFile = 'lib/core/push/fake_push_service.dart';
    const screen = 'lib/features/inbox/inbox_screen.dart';
    const ofProvider = ModuleOrigin(ModuleId('fake_push'));
    const ofFeature = ModuleOrigin(ModuleId('inbox'));
    const hint = 'Receive push messages through appPush of '
        'lib/core/push/app_push.dart, which also exports PushMessage.';

    test(
        'let each provider contribute one implementation, and no module put '
        'code into the socket of the implementation', () {
      List<SmfIssue> issuesOf(
        ModuleDescriptor module, {
        List<RoleImplementation> implementations = const [],
        List<Contribution> contributions = const [],
      }) =>
          pushRole.checkModule(
            ModuleRuleRequest(
              hook: RoleHookRequest(
                data: [
                  for (final implementation in implementations)
                    pushRole
                        .data(implementation)
                        .withOrigin(ModuleOrigin(module.id)),
                ],
                presentRoles: {pushRole, notificationsRole, preferencesRole},
                context: testContext,
              ),
              module: module,
              contributions: contributions,
            ),
          );
      final implementation = _implementation(async: false);

      expect(issuesOf(_provider, implementations: [implementation]), isEmpty);
      expect(issuesOf(_feature), isEmpty);
      expect(
        issuesOf(_provider).single.message,
        contains('exactly one implementation, but the module contributes 0'),
      );
      expect(
        issuesOf(_feature, implementations: [implementation]).single.message,
        contains('which only its providers do'),
      );
      final issue = issuesOf(
        _provider,
        implementations: [implementation],
        contributions: const [
          SocketContribution.code(
            PushRole.implementations,
            Fragment('late PushService _pushService;'),
          ),
        ],
      ).single;
      expect(issue.message, contains('socket push.implementations'));
    });

    test(
        'push.factory_calls: a file of a module, or of the template of '
        'another role, that calls createPushService() is reported, with '
        'appPush as what to use', () {
      final issues = _structureIssues({
        _calling(providerFile, 'createPushService'): ofProvider,
        _calling(screen, 'createPushService'): ofFeature,
        _calling('lib/core/chat/chat.dart', 'createPushService'):
            RoleTemplateOrigin(_otherRole),
        // Another file of the template of the role itself, and files that
        // neither a module nor the template of a role owns.
        _calling('lib/core/push/more.dart', 'createPushService'):
            const RoleTemplateOrigin(pushRole),
        _calling('lib/generated.dart', 'createPushService'):
            const PipelineOrigin(),
        _calling('lib/mine.dart', 'createPushService'): null,
      });

      expect(
        [for (final issue in issues) (issue.path, issue.origin)],
        [
          (providerFile, ofProvider),
          (screen, ofFeature),
          ('lib/core/chat/chat.dart', RoleTemplateOrigin(_otherRole)),
        ],
      );
      for (final issue in issues) {
        expect(
          issue.message,
          '${issue.path} calls createPushService(), which no module may call.',
        );
        expect(issue.hint, hint);
      }
    });

    test(
        'push.factory_calls: only the files of the implementation of the '
        'provider import the file of PushService; any other file of a '
        'module, a widget of the provider too, is reported', () {
      const widget = DartFileIndex(
        path: 'lib/core/push/fake_push_widget.dart',
        imports: [IndexedImport('push_service.dart')],
      );
      const prefixed = DartFileIndex(
        path: screen,
        imports: [
          IndexedImport(
            'package:my_app/core/push/push_service.dart',
            prefix: 'push',
          ),
        ],
      );
      const exporting = DartFileIndex(
        path: 'lib/core/chat/chat.dart',
        exports: [IndexedImport('../push/push_service.dart')],
      );
      const ofClass = DartFileIndex(
        path: providerFile,
        imports: [IndexedImport('push_service.dart')],
      );

      final issues = _structureIssues({
        widget: ofProvider,
        prefixed: ofFeature,
        exporting: RoleTemplateOrigin(_otherRole),
        // The file of the class of the implementation, and that of its
        // function, which the helper adds, may.
        ofClass: ofProvider,
      });

      expect(
        [for (final issue in issues) issue.path],
        [widget.path, screen, 'lib/core/chat/chat.dart'],
      );
      for (final issue in issues) {
        expect(
          issue.message,
          '${issue.path} imports ${PushRole.serviceFile}, the file of '
          'PushService, which only the files of the implementation of the '
          'provider of the push messages role import.',
        );
        expect(issue.hint, hint);
      }
    });

    test(
        'push.start_calls: only bootstrap() calls initPush(), and no module '
        'calls appPush.start()', () {
      const startHint = 'The role starts the push messages in bootstrap(), '
          'before the first frame. Read the address, the messages and the '
          'taps from appPush.';
      const starting = DartFileIndex(
        path: screen,
        imports: [IndexedImport('package:my_app/core/push/app_push.dart')],
        invocations: [IndexedInvocation('start', target: 'appPush')],
      );
      final issues = _structureIssues({
        _calling(AppEntryRole.bootstrapFile, 'initPush'): null,
        _calling(providerFile, 'initPush'): ofProvider,
        starting: ofFeature,
        // The template of the role starts the controller itself.
        const DartFileIndex(
          path: 'lib/core/push/more.dart',
          imports: [IndexedImport('app_push.dart')],
          invocations: [IndexedInvocation('start', target: 'appPush')],
        ): const RoleTemplateOrigin(pushRole),
      });

      expect(
        [for (final issue in issues) (issue.message, issue.hint)],
        [
          (
            '$providerFile calls initPush(), which only bootstrap() calls.',
            startHint,
          ),
          (
            '$screen calls appPush.start(), which only initPush() calls.',
            startHint,
          ),
        ],
      );
    });

    test(
        'push.implementation_factories: the function of the implementation '
        'is in its file and takes no arguments', () {
      final missing = pushRole.checkStructure(
        StructuralRuleRequest(
          hook: RoleHookRequest(
            data: [
              dataOf(
                pushRole,
                _implementation(async: false),
                module: 'fake_push',
              ),
            ],
            presentRoles: {pushRole, notificationsRole, preferencesRole},
            context: testContext,
          ),
          files: const {
            'lib/fakes/fake_push.dart':
                DartFileIndex(path: 'lib/fakes/fake_push.dart'),
          },
        ),
      );
      expect(
        missing.single.message,
        contains('does not declare function createFakePush()'),
      );
    });
  });
}
