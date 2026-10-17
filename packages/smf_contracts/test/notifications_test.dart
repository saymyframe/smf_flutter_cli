@TestOn('vm')
library;

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:smf_contracts/bundles/notifications_role_bundle.dart';
import 'package:smf_contracts/bundles/notifications_role_setting_bundle.dart';
import 'package:smf_contracts/bundles/notifications_role_step_bundle.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

import 'dart_files.dart';
import 'role_support.dart';
import 'support.dart';

/// The file of the fake provider of notifications in the test app.
const _fakeFile = ImportRef.app('fakes/fake_notifications.dart');

/// The file of the fake preferences in the test app.
const _fakePreferencesFile = ImportRef.app('fakes/fake_preferences.dart');

/// The file of `appNotifications`, as code imports it.
const _controllerImport = ImportRef.app(
  'core/notifications/app_notifications.dart',
);

/// The template of the role as its owner, as the pipeline names it.
const _template = RoleTemplateOrigin(notificationsRole);

/// The implementation of the service of the test app: one that is created
/// asynchronously, or one created with the app.
RoleImplementation _implementation({required bool async}) => async
    ? const RoleImplementation.async(
        type: TypeRef('FakeNotifications', import: _fakeFile),
        init: FactoryRef('openFakeNotifications', import: _fakeFile),
      )
    : const RoleImplementation(
        type: TypeRef('FakeNotifications', import: _fakeFile),
        create: FactoryRef('createFakeNotifications', import: _fakeFile),
      );

/// What the template of the role contributes, in every app and in some.
List<Contribution> _contributions() =>
    notificationsRole.template.contribute(testContext);

/// The data that the template gives [role], as the pipeline hands it to
/// the hooks of that role: with the template as its origin.
List<RoleData<Object>> _dataFor(Role role) => [
      for (final contribution in _contributions())
        if (contribution case final RoleData<Object> data
            when data.role == role)
          data.withOrigin(_template),
    ];

/// The files of the role in an app with the roles in [present] besides the
/// role and its preferences, rendered with an implementation that is
/// created asynchronously, or with the app, and what the template puts
/// into other sockets.
Future<RenderedTemplate> _rendered({
  Set<Role> present = const {},
  bool async = false,
}) =>
    renderTemplate(
      notificationsRole,
      data: [
        dataOf(
          notificationsRole,
          _implementation(async: async),
          module: 'fake_notifications',
        ),
      ],
      present: {preferencesRole, ...present},
    );

/// A stand-in for the part of Flutter's foundation library that the files
/// of the role and of the preferences use, with the signatures of Flutter
/// 3.44: the app runs in debug mode, and what it prints goes to
/// `debugPrinted`.
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
/// the role use: what that library exports of the foundation library, and
/// the binding with the observers of the lifecycle of the app.
/// `lifecycle()` puts the app into a state, and `resumeApp()` stands for
/// the user who comes back to the app.
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

/// A provider of notifications for the test app, which keeps to the
/// contract of `NotificationsService`.
///
/// Whether the app may show notifications, what the user answers to the
/// question of the system, the tap that launched the app and the scheduled
/// notifications are on variables that stand for the device: each new
/// service reads them, as a service does at the next launch of an app. The
/// services note their calls, and a test holds a call until it lets it go.
const _fakeNotifications = r'''
import 'dart:async';

import '../core/notifications/notifications_service.dart';

/// Whether the device lets the app show notifications.
bool enabled = false;

/// Whether the user allows notifications when the system asks.
bool allows = true;

/// The tap that launched the app, which each new service reads.
NotificationTap? launchedBy;

/// The notifications that are scheduled on the device, by their ids.
final Map<int, AppNotification> onDevice = {};

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

/// How many services were created.
int created = 0;

NotificationsService createFakeNotifications() => FakeNotifications();

Future<NotificationsService> openFakeNotifications() async {
  await Future<void>.delayed(Duration.zero);
  return FakeNotifications();
}

final class FakeNotifications implements NotificationsService {
  FakeNotifications() : launchTap = launchedBy {
    created++;
  }

  final StreamController<NotificationTap> _taps =
      StreamController.broadcast();

  @override
  final NotificationTap? launchTap;

  @override
  Stream<NotificationTap> get taps => _taps.stream;

  /// Whether something listens to the taps.
  bool get hasListener => _taps.hasListener;

  /// The user taps a notification.
  void tap(NotificationTap tap) => _taps.add(tap);

  Future<void> _enter(String call) async {
    calls.add(call);
    await holds[call]?.future;
  }

  @override
  Future<bool> areEnabled() async {
    await _enter('areEnabled');
    return enabled;
  }

  @override
  Future<void> request() async {
    await _enter('request');
    enabled = allows;
  }

  @override
  Future<void> openSettings() => _enter('openSettings');

  @override
  Future<void> show(AppNotification notification) =>
      _enter('show ${notification.id}');

  @override
  Future<void> schedule(AppNotification notification, DateTime at) async {
    await _enter('schedule ${notification.id}');
    onDevice[notification.id] = notification;
  }

  @override
  Future<void> cancel(int id) async {
    await _enter('cancel $id');
    onDevice.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    await _enter('cancelAll');
    onDevice.clear();
  }

  @override
  Future<List<AppNotification>> scheduled() async {
    await _enter('scheduled');
    return [...onDevice.values];
  }
}
''';

/// Preferences of the test app that read and write a `bool`, which is all
/// that the role needs, over a map that stands for the disk: each open
/// reads the map anew, and a write takes a moment, and fails when the test
/// says so. Any other read or write throws.
const _fakePreferences = '''
import '../core/preferences/app_preferences.dart';

/// What the preferences have saved.
final Map<String, Object> disk = {};

/// Whether a write fails once it took its moment.
bool writesFail = false;

AppPreferences openFakePreferences() => FakePreferences();

final class FakePreferences implements AppPreferences {
  FakePreferences() : _values = Map.of(disk);

  final Map<String, Object> _values;

  @override
  bool? getBool(String key) => switch (_values[key]) {
        final bool value => value,
        _ => null,
      };

  @override
  Future<void> setBool(String key, bool value) async {
    await Future<void>.delayed(Duration.zero);
    if (writesFail) throw StateError('The write fails.');
    _values[key] = value;
    disk[key] = value;
  }

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
''';

/// What the scripts for the test app share. `pump` lets what is on its way
/// happen, `failureOf` tells what a call fails with, and `shown` a tap.
const _notes = r'''
import 'dart:async';
import 'dart:isolate';

import 'package:flutter/widgets.dart';
import 'package:my_app/core/notifications/app_notifications.dart';
import 'package:my_app/core/notifications/notifications_step.dart';
import 'package:my_app/core/preferences/app_preferences.dart';
import 'package:my_app/fakes/fake_notifications.dart';
import 'package:my_app/fakes/fake_preferences.dart';

final result = <String, Object?>{};

Future<void> pump() => Future<void>.delayed(Duration.zero);

Future<String> failureOf(Future<void> Function() call) async {
  try {
    await call();
    return 'none';
  } on ArgumentError catch (error) {
    return 'ArgumentError: ${error.message}';
  }
}

String? shown(NotificationTap? tap) =>
    tap == null ? null : '${tap.id} ${tap.data}';

const askedKey = 'notifications.asked';
''';

/// Goes through the life of the permission of the app, with the controller
/// and the functions that the role generates: a first launch, a request
/// that the user answers with a no, the settings of the system, the user
/// who comes back to the app, and the next launch. After each step it notes
/// the permission, the calls that reached the provider, what the listeners
/// of the permission were told of, and what the preferences saved.
const _life = '''
Future<void> main(List<String> arguments, SendPort port) async {
  final heard = <String>[];
  appNotifications.permission.addListener(
    () => heard.add(appNotifications.permission.value.name),
  );
  void note(String step) {
    result[step] = {
      'permission': appNotifications.permission.value.name,
      'calls': takeCalls(),
      'heard': [...heard],
      'saved': disk[askedKey],
    };
    heard.clear();
  }

  try {
    createNotificationsService();
    result['the service before the start'] = 'a service';
  } on Error {
    result['the service before the start'] = 'none';
  }
  note('before the start');

  await initPreferences();
  note('the preferences opened');

  await initNotifications();
  final first = createNotificationsService() as FakeNotifications;
  note('a first launch');
  result['the step shows at a first launch'] = notificationsStepShows();

  allows = false;
  result['the answer of a no'] = (await appNotifications.request()).name;
  note('a no');
  result['the step shows once the app asked'] = notificationsStepShows();

  result['the answer of a request after a no'] =
      (await appNotifications.request()).name;
  note('a request after a no');

  await appNotifications.openSettings();
  note('the settings of the system');

  enabled = true;
  resumeApp();
  await pump();
  note('back from the settings with notifications on');

  result['the answer once granted'] = (await appNotifications.request()).name;
  note('a request once granted');

  enabled = false;
  lifecycle(AppLifecycleState.paused);
  await pump();
  note('away from the app');
  lifecycle(AppLifecycleState.resumed);
  await pump();
  note('back with notifications off');

  await initPreferences();
  await initNotifications();
  await pump();
  note('the next launch');
  result['the services'] = {
    'created': created,
    'the first one is listened to': first.hasListener,
    'observers of the lifecycle': WidgetsBinding.instance.observers.length,
  };
  port.send(result);
}
''';

/// What [_life] sends back.
const Map<String, Object?> _lifeResult = {
  'the service before the start': 'none',
  'before the start': {
    'permission': 'notAsked',
    'calls': <Object?>[],
    'heard': <Object?>[],
    'saved': null,
  },
  'the preferences opened': {
    'permission': 'notAsked',
    'calls': <Object?>[],
    'heard': <Object?>[],
    'saved': null,
  },
  // The app asks the service whether it may show notifications, and asks
  // the user nothing.
  'a first launch': {
    'permission': 'notAsked',
    'calls': ['areEnabled'],
    'heard': <Object?>[],
    'saved': null,
  },
  'the step shows at a first launch': true,
  // The permission is what the service says after the question, not that
  // the question was asked.
  'the answer of a no': 'denied',
  'a no': {
    'permission': 'denied',
    'calls': ['areEnabled', 'request', 'areEnabled'],
    'heard': ['denied'],
    'saved': true,
  },
  'the step shows once the app asked': false,
  'the answer of a request after a no': 'denied',
  'a request after a no': {
    'permission': 'denied',
    'calls': ['areEnabled', 'request', 'areEnabled'],
    'heard': <Object?>[],
    'saved': true,
  },
  'the settings of the system': {
    'permission': 'denied',
    'calls': ['openSettings'],
    'heard': <Object?>[],
    'saved': true,
  },
  'back from the settings with notifications on': {
    'permission': 'granted',
    'calls': ['areEnabled'],
    'heard': ['granted'],
    'saved': true,
  },
  // Granted: nothing to ask.
  'the answer once granted': 'granted',
  'a request once granted': {
    'permission': 'granted',
    'calls': ['areEnabled'],
    'heard': <Object?>[],
    'saved': true,
  },
  // Only a resume asks again.
  'away from the app': {
    'permission': 'granted',
    'calls': <Object?>[],
    'heard': <Object?>[],
    'saved': true,
  },
  'back with notifications off': {
    'permission': 'denied',
    'calls': ['areEnabled'],
    'heard': ['denied'],
    'saved': true,
  },
  'the next launch': {
    'permission': 'denied',
    'calls': ['areEnabled'],
    'heard': <Object?>[],
    'saved': true,
  },
  'the services': {
    'created': 2,
    'the first one is listened to': false,
    'observers of the lifecycle': 1,
  },
};

/// A request that the user allows, two requests while the question is
/// shown, and a request after them.
const _requests = '''
Future<void> main(List<String> arguments, SendPort port) async {
  await initPreferences();
  await initNotifications();
  takeCalls();

  holds['request'] = Completer<void>();
  final first = appNotifications.request();
  final second = appNotifications.request();
  await pump();
  result['the calls while the question is shown'] = takeCalls();
  result['the permission while the question is shown'] =
      appNotifications.permission.value.name;
  holds.remove('request')!.complete();
  result['the answers'] = [(await first).name, (await second).name];
  result['the requests are one'] = identical(first, second);
  result['the calls once the user answered'] = takeCalls();
  result['saved'] = disk[askedKey];
  result['the step shows once allowed'] = notificationsStepShows();

  final third = appNotifications.request();
  result['a later request is another'] = !identical(first, third);
  result['the answer of the later request'] = (await third).name;
  result['the calls of the later request'] = takeCalls();
  port.send(result);
}
''';

/// Calls made before the app started the service, which nothing awaits
/// until it did.
const _beforeStart = '''
Future<void> main(List<String> arguments, SendPort port) async {
  final shownEarly = appNotifications.show(
    const AppNotification(id: 1, title: 'Early'),
  );
  final asked = appNotifications.request();
  final listed = appNotifications.scheduled();
  await pump();
  result['the calls before the start'] = takeCalls();

  await initPreferences();
  await initNotifications();
  await shownEarly;
  result['the answer'] = (await asked).name;
  result['scheduled'] = (await listed).length;
  result['the calls after the start'] = takeCalls()..sort();
  port.send(result);
}
''';

/// The permission when the notifications start before the preferences, at
/// the next launch of an app that asked.
const _order = '''
Future<void> main(List<String> arguments, SendPort port) async {
  disk[askedKey] = true;
  await initNotifications();
  result['started before the preferences'] =
      appNotifications.permission.value.name;
  await initPreferences();
  result['then the preferences opened'] =
      appNotifications.permission.value.name;
  port.send(result);
}
''';

/// The ids and the times that the controller takes and those that it does
/// not, and the calls that reach the provider for each.
const _calls = r'''
Future<void> main(List<String> arguments, SendPort port) async {
  await initPreferences();
  await initNotifications();
  takeCalls();
  const owner = {notificationOwnerKey: 'push'};
  final now = DateTime.now();

  result['refused'] = {
    'a negative id without an owner': await failureOf(
      () => appNotifications.show(const AppNotification(id: -1, title: 'A')),
    ),
    'an owner with the id 0': await failureOf(
      () => appNotifications.show(
        const AppNotification(id: 0, title: 'A', data: owner),
      ),
    ),
    'an id above 32 bits': await failureOf(
      () => appNotifications.show(
        const AppNotification(id: 0x80000000, title: 'A'),
      ),
    ),
    'an id below 32 bits': await failureOf(
      () => appNotifications.show(
        const AppNotification(id: -0x80000001, title: 'A', data: owner),
      ),
    ),
    'a scheduled one with a negative id without an owner': await failureOf(
      () => appNotifications.schedule(
        const AppNotification(id: -1, title: 'A'),
        at: now.add(const Duration(hours: 1)),
      ),
    ),
    'a time that has passed': await failureOf(
      () => appNotifications.schedule(
        const AppNotification(id: 1, title: 'A'),
        at: now.subtract(const Duration(minutes: 1)),
      ),
    ),
  };
  result['the calls of the refused'] = takeCalls();

  result['taken'] = {
    'the id 0': await failureOf(
      () => appNotifications.show(const AppNotification(id: 0, title: 'A')),
    ),
    'the largest id': await failureOf(
      () => appNotifications.show(
        const AppNotification(id: 0x7FFFFFFF, title: 'A'),
      ),
    ),
    'the smallest id with an owner': await failureOf(
      () => appNotifications.show(
        const AppNotification(id: -0x80000000, title: 'A', data: owner),
      ),
    ),
    'a time to come': await failureOf(
      () => appNotifications.schedule(
        const AppNotification(
          id: 2,
          title: 'Soon',
          body: 'In an hour',
          data: {'screen': 'news'},
        ),
        at: now.add(const Duration(hours: 1)),
      ),
    ),
  };
  result['the calls of the taken'] = takeCalls();
  result['scheduled'] = [
    for (final notification in await appNotifications.scheduled())
      '${notification.id} ${notification.title} ${notification.body} '
          '${notification.data}',
  ];
  await appNotifications.cancel(2);
  await appNotifications.cancelAll();
  result['the calls of the rest'] = takeCalls();
  port.send(result);
}
''';

/// The taps on notifications of the app and of owners, the tap that
/// launched the app, and the taps after the next launch.
const _taps = '''
Future<void> main(List<String> arguments, SendPort port) async {
  launchedBy = const NotificationTap(id: 7, data: {'screen': 'news'});
  result['the launch tap before the start'] = shown(appNotifications.launchTap);
  await initPreferences();
  await initNotifications();
  result['the launch tap'] = shown(appNotifications.launchTap);
  result['the launch tap of an owner'] =
      shown(appNotifications.launchTapOf('push'));

  final service = createNotificationsService() as FakeNotifications;
  final heard = <String, List<String>>{};
  void listen(String name, Stream<NotificationTap> taps) =>
      taps.listen((tap) => (heard[name] ??= []).add(shown(tap)!));
  listen('app', appNotifications.taps);
  listen('app, a second listener', appNotifications.taps);
  listen('push', appNotifications.tapsOf('push'));
  listen('chat', appNotifications.tapsOf('chat'));
  service
    ..tap(const NotificationTap(id: 1, data: {'screen': 'news'}))
    ..tap(const NotificationTap(id: -5, data: {notificationOwnerKey: 'push'}))
    ..tap(const NotificationTap(id: 2));
  await pump();
  result['heard'] = {...heard};
  result['the taps are one stream'] =
      identical(appNotifications.taps, appNotifications.taps);

  launchedBy = const NotificationTap(
    id: -9,
    data: {notificationOwnerKey: 'push'},
  );
  await initNotifications();
  await pump();
  result['after a launch by a tap of an owner'] = {
    'the launch tap': shown(appNotifications.launchTap),
    'the launch tap of the owner': shown(appNotifications.launchTapOf('push')),
    'the launch tap of another owner':
        shown(appNotifications.launchTapOf('chat')),
  };
  heard.clear();
  service.tap(const NotificationTap(id: 3));
  (createNotificationsService() as FakeNotifications)
      .tap(const NotificationTap(id: 4));
  await pump();
  result['heard after the next launch'] = {...heard};
  port.send(result);
}
''';

/// A request whose answer the preferences fail to save.
const _failedWrite = '''
Future<void> main(List<String> arguments, SendPort port) async {
  await initPreferences();
  await initNotifications();
  writesFail = true;
  allows = false;
  try {
    await appNotifications.request();
    result['the request'] = 'completed';
  } on StateError catch (error) {
    result['the request'] = error.message;
  }
  result['the permission'] = appNotifications.permission.value.name;
  result['saved'] = disk.containsKey(askedKey);
  // The next request takes a turn of its own.
  writesFail = false;
  result['the answer of the next request'] =
      (await appNotifications.request()).name;
  result['saved after it'] = disk[askedKey];
  port.send(result);
}
''';

/// The files of the test app, with the step of the onboarding: the files of
/// the role, as its template generates them, the file of the preferences
/// with the restorer of the role, and the fakes. The setting of the
/// settings screen is checked on its own, since it needs Flutter's
/// material library.
Future<DartFiles> _app({bool async = false}) async {
  final notifications = await _rendered(
    present: {onboardingScreenRole},
    async: async,
  );
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
      for (final MapEntry(key: path, value: text)
          in notifications.files.entries)
        if (path.endsWith('.dart')) path: text,
      ...preferences.files,
      'lib/fakes/fake_notifications.dart': _fakeNotifications,
      'lib/fakes/fake_preferences.dart': _fakePreferences,
    },
    flutter: const {'foundation.dart': _foundation, 'widgets.dart': _widgets},
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

/// The signature of [member], a method or a getter, as its code.
String _signatureOf(MethodDeclaration member) => [
      '${member.returnType} ',
      if (member.isGetter) 'get ',
      member.name.lexeme,
      '${member.parameters ?? ''}',
    ].join();

/// The members of the class [name] of [unit] that are methods or getters,
/// each as its signature.
List<String> _methodsOf(CompilationUnit unit, String name) => [
      for (final member in unit.declarations
          .whereType<ClassDeclaration>()
          .singleWhere((type) => type.namePart.typeName.lexeme == name)
          .body
          .members)
        if (member is MethodDeclaration) _signatureOf(member),
    ];

/// The top-level constants of [unit], each as its declaration.
Map<String, String> _constantsOf(CompilationUnit unit) => {
      for (final declaration
          in unit.declarations.whereType<TopLevelVariableDeclaration>())
        for (final variable in declaration.variables.variables)
          variable.name.lexeme: declaration.toSource(),
    };

/// The named arguments of each creation of the class [className], in the
/// order of the code.
final class _NamedArgumentsOf extends RecursiveAstVisitor<void> {
  _NamedArgumentsOf(this.className);

  final String className;

  final found = <Map<String, String>>[];

  void _note(String name, ArgumentList arguments) {
    if (name != className) return;
    found.add({
      for (final argument in arguments.arguments.whereType<NamedArgument>())
        argument.name.lexeme: argument.argumentExpression.toSource(),
    });
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _note(node.constructorName.type.name.lexeme, node.argumentList);
    super.visitInstanceCreationExpression(node);
  }

  // Unresolved code has the creation of a class without `new` or `const`
  // as the call of a method.
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null) _note(node.methodName.name, node.argumentList);
    super.visitMethodInvocation(node);
  }
}

/// The provider of the role and a feature that uses the role.
const _provider = ModuleDescriptor(
  id: ModuleId('fake_notifications'),
  description: 'Notifications',
  kind: ModuleKinds.infrastructure,
  providers: [RoleProvider.plain(notificationsRole)],
);
const _feature = ModuleDescriptor(
  id: ModuleId('reminders'),
  description: 'Reminders',
  kind: ModuleKinds.feature,
  uses: {notificationsRole},
);

/// The template of a role whose code may show notifications, as the
/// template of a role of push messages would.
final _otherRole = TestRole<NoDsl>('push', requires: {notificationsRole});

/// The implementation of the provider of the apps of the rules: its class
/// in one file and its function in another.
const _providerImplementation = RoleImplementation(
  type: TypeRef(
    'FakeNotificationsService',
    import: ImportRef.app('core/notifications/fake_notifications_service.dart'),
  ),
  create: FactoryRef(
    'createFakeNotificationsService',
    import: ImportRef.app('core/notifications/fake_notifications.dart'),
  ),
);

/// The file of the function of [_providerImplementation], which imports
/// the file of `NotificationsService`, as the file of an implementation
/// may.
const _factoryFile = DartFileIndex(
  path: 'lib/core/notifications/fake_notifications.dart',
  imports: [IndexedImport('notifications_service.dart')],
  declarations: [
    IndexedDeclaration(
      name: 'createFakeNotificationsService',
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
    notificationsRole.checkStructure(
      StructuralRuleRequest(
        hook: RoleHookRequest(
          data: [
            dataOf(
              notificationsRole,
              _providerImplementation,
              module: 'fake_notifications',
            ),
          ],
          presentRoles: {notificationsRole, preferencesRole},
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

/// The index of the file at [path] that imports the file of
/// `appNotifications` and calls [function] of it.
DartFileIndex _calling(String path, String function) => DartFileIndex(
      path: path,
      imports: const [
        IndexedImport(
          'package:my_app/core/notifications/app_notifications.dart',
        ),
      ],
      invocations: [IndexedInvocation(function)],
    );

void main() {
  group('the notifications role', () {
    test(
        'takes one provider, requires the preferences, which remember that '
        'the app asked, and works with a settings screen, an onboarding and '
        'the languages of the app', () {
      expect(notificationsRole.id, 'notifications');
      expect(notificationsRole.description, 'Notifications');
      expect(notificationsRole.presenceFlag, 'has_notifications');
      expect('$notificationsRole', 'notifications role');
      expect(notificationsRole.cardinality, RoleCardinality.atMostOne);
      expect(notificationsRole.requires, {preferencesRole});
      expect(
        notificationsRole.uses,
        {settingsScreenRole, onboardingScreenRole, localizationRole},
      );
      // Its provider uses what the role uses, so the contract harness
      // builds the apps of a provider with each of those roles and without.
      expect(
        _provider.effectiveUses,
        {settingsScreenRole, onboardingScreenRole, localizationRole},
      );
      expect(_provider.effectiveRequires, {preferencesRole});
      expect(notificationsRole.sockets, const [
        NotificationsRole.implementations,
      ]);
      expect(
        NotificationsRole.implementations.tag,
        'smf_notifications__implementations',
      );
      expect(notificationsRole.options, isEmpty);
      expect(
        [for (final rule in notificationsRole.moduleRules) rule.id],
        ['services.implementations'],
      );
      expect(
        [for (final rule in notificationsRole.structuralRules) rule.id],
        [
          'notifications.factory_calls',
          'notifications.start_calls',
          'notifications.implementation_factories',
        ],
      );
    });

    test(
        'guarantees the files of the service and of the controller, the '
        'small icon of Android and the file that keeps it, but not the '
        'files of the entry and of the step', () {
      expect(notificationsRole.interface.files, [
        'lib/core/notifications/notifications_service.dart',
        'lib/core/notifications/app_notifications.dart',
        'android/app/src/main/res/drawable/ic_notification.xml',
        'android/app/src/main/res/raw/notifications_keep.xml',
      ]);
      expect(notificationsRole.interface.files, [
        NotificationsRole.serviceFile,
        NotificationsRole.controllerFile,
        NotificationsRole.androidIconFile,
        NotificationsRole.androidKeepFile,
      ]);
      expect(notificationsRole.interface.symbols, isEmpty);
      expect(
        NotificationsRole.settingFile,
        'lib/core/notifications/notifications_setting.dart',
      );
      expect(
        NotificationsRole.stepFile,
        'lib/core/notifications/notifications_step.dart',
      );
      // The drawable that a provider, and the meta-data of a module that has
      // the system show a notification, name by its name.
      expect(
        NotificationsRole.androidIconFile,
        'android/app/src/main/res/drawable/'
        '${NotificationsRole.androidIcon}.xml',
      );
      // <owner id>.<setting>, as the preferences role names its keys, and
      // the key of an owner after the id of the role too.
      expect(NotificationsRole.askedKey, '${notificationsRole.id}.asked');
      expect(NotificationsRole.ownerKey, '${notificationsRole.id}.owner');
      expect(NotificationsRole.defaultChannel, 'default');
      expect(NotificationsRole.readmeHeading, 'Notifications');
    });

    test(
        'has the texts of the entry and of the step in English and in '
        'Ukrainian, with no problems', () {
      final texts = [
        NotificationsRole.settingTitle,
        NotificationsRole.settingOn,
        NotificationsRole.settingOff,
        NotificationsRole.stepTitle,
        NotificationsRole.stepText,
        NotificationsRole.stepAction,
        NotificationsRole.stepLater,
      ];
      for (final text in texts) {
        expect(text.problems(), isEmpty, reason: text.name);
        expect(text.languages, ['en', 'uk'], reason: text.name);
      }
      expect(NotificationsRole.stepLater.en, 'Not now');
      expect(NotificationsRole.stepLater.textIn('uk'), 'Не зараз');
      expect(
        {for (final text in texts) text.name},
        hasLength(texts.length),
      );
    });
  });

  group('the notifications template', () {
    test(
        'generates the files of the role in every app, the entry only in an '
        'app with a settings screen and the step only in one with an '
        'onboarding', () async {
      final bricks = _contributions().whereType<BrickContribution>().toList();
      expect(
        [for (final brick in bricks) brick.bundle.name],
        [
          notificationsRoleBundle.name,
          notificationsRoleSettingBundle.name,
          notificationsRoleStepBundle.name,
        ],
      );
      expect(
        [for (final brick in bricks) brick.when],
        [
          isEmpty,
          {settingsScreenRole},
          {onboardingScreenRole},
        ],
      );
      expect(
        templatesOf(notificationsRoleSettingBundle).keys,
        [NotificationsRole.settingFile],
      );
      expect(
        templatesOf(notificationsRoleStepBundle).keys,
        [NotificationsRole.stepFile],
      );

      for (final settings in [false, true]) {
        for (final onboarding in [false, true]) {
          final rendered = await _rendered(
            present: {
              if (settings) settingsScreenRole,
              if (onboarding) onboardingScreenRole,
            },
          );
          expect(
            rendered.files.keys.toSet(),
            {
              ...notificationsRole.interface.files,
              if (settings) NotificationsRole.settingFile,
              if (onboarding) NotificationsRole.stepFile,
            },
            reason: 'settings: $settings, onboarding: $onboarding',
          );
          for (final MapEntry(key: path, value: text)
              in rendered.files.entries) {
            if (path.endsWith('.dart')) expectParses(text, reason: path);
          }
        }
      }
    });

    test(
        'registers nothing in a DI container, and gives the preferences the '
        'restorer of the permission', () {
      final contributions = _contributions();

      expect(_dataFor(diRole), isEmpty);
      final restorer = contributions
          .whereType<SocketContribution>()
          .singleWhere((item) => item.socket == PreferencesRole.restorers);
      expect(restorer.fragment!.code, 'restoreNotifications');
      expect(restorer.fragment!.imports, [_controllerImport]);
      expect(restorer.when, isEmpty);
    });

    test(
        'generates the interface that a provider implements, with the '
        'notification, the tap, and the channel and the icon as constants',
        () async {
      final rendered = await _rendered();
      final unit = parseString(
        content: rendered.files[NotificationsRole.serviceFile]!,
      ).unit;

      expect(_methodsOf(unit, 'NotificationsService'), [
        'NotificationTap? get launchTap',
        'Stream<NotificationTap> get taps',
        'Future<bool> areEnabled()',
        'Future<void> request()',
        'Future<void> openSettings()',
        'Future<void> show(AppNotification notification)',
        'Future<void> schedule(AppNotification notification, DateTime at)',
        'Future<void> cancel(int id)',
        'Future<void> cancelAll()',
        'Future<List<AppNotification>> scheduled()',
      ]);
      expect(_constantsOf(unit), {
        'notificationChannelId':
            "const String notificationChannelId = 'default';",
        // The name of the app, as the app entry names it.
        'notificationChannelName':
            "const String notificationChannelName = 'My App';",
        'notificationIcon':
            "const String notificationIcon = 'ic_notification';",
      });
      expect(
        declarationsOf(rendered.files[NotificationsRole.serviceFile]!),
        containsAll([
          'AppNotification.id',
          'AppNotification.title',
          'AppNotification.body',
          'AppNotification.data',
          'NotificationTap.id',
          'NotificationTap.data',
        ]),
      );
      // The file of the provider needs nothing of Flutter and no other
      // file of the app.
      expect(unit.directives, isEmpty);
    });

    test('names the channel after the app, as a title', () async {
      for (final (name, title) in [
        ('my_app', 'My App'),
        ('shop', 'Shop'),
        ('todo_list_2', 'Todo List 2'),
      ]) {
        final output = notificationsRole.template.render(
          notificationsRole.hookInput(
            RoleHookRequest(
              data: [
                dataOf(
                  notificationsRole,
                  _implementation(async: false),
                  module: 'fake_notifications',
                ),
              ],
              presentRoles: {notificationsRole, preferencesRole},
              context: ModuleContext(
                appName: name,
                orgName: testContext.orgName,
                appIdentity: testContext.appIdentity,
              ),
            ),
          ),
        );
        expect(output.vars['channel_name'], "'$title'", reason: name);
      }
    });

    for (final async in [true, false]) {
      final how = async ? 'created asynchronously' : 'created with the app';

      test(
          'creates an implementation $how in initNotifications(), starts '
          'appNotifications with it, and awaits that in the platform phase '
          'of bootstrap()', () async {
        final rendered = await _rendered(async: async);
        final code = rendered.files[NotificationsRole.controllerFile]!;
        final unit = parseString(content: code).unit;

        final init = _functionsOf(unit)['initNotifications']!;
        expect('${init.returnType}', 'Future<void>');
        expect(init.functionExpression.parameters!.parameters, isEmpty);
        expect(_statementsOf(init), [
          if (async)
            '_notificationsService = await impl0.openFakeNotifications();'
          else
            '_notificationsService = impl0.createFakeNotifications();',
          'await appNotifications.start(_notificationsService);',
        ]);
        expect(
          _constantsOf(unit)['_notificationsService'],
          'late NotificationsService _notificationsService;',
        );
        expect(
          code,
          contains(
            "import 'package:my_app/fakes/fake_notifications.dart' as impl0;",
          ),
        );
        final start = rendered.elsewhere.singleWhere(
          (entry) => entry.socket == AppEntryRole.bootstrapPlatform,
        );
        expect(start.fragment!.code, 'await initNotifications();');
        expect(start.fragment!.imports, [_controllerImport]);
      });
    }

    test('reports the problems of the implementation', () {
      final issues = notificationsRole.template.validate(
        inputOf(
          notificationsRole,
          data: [
            dataOf(
              notificationsRole,
              const RoleImplementation(
                type: TypeRef('_Private'),
                create: FactoryRef('create', import: _fakeFile),
              ),
              module: 'fake_notifications',
            ),
          ],
          present: {preferencesRole},
        ),
      );
      expect(
        issues.single.origin,
        const ModuleOrigin(ModuleId('fake_notifications')),
      );
    });
  });

  group('the small icon of Android', () {
    late Map<String, String> files;

    setUpAll(() async => files = (await _rendered()).files);

    test('is a vector drawable in one colour, named as the role names it', () {
      final drawable = XmlDocument.parse(
        files[NotificationsRole.androidIconFile]!,
      ).rootElement;

      expect(drawable.name.local, 'vector');
      final path = drawable.findElements('path').single;
      expect(path.getAttribute('android:fillColor'), '#FFFFFFFF');
      expect(path.getAttribute('android:pathData'), isNotEmpty);
    });

    test('is kept in a release build by the file of the role', () {
      final keep = XmlDocument.parse(
        files[NotificationsRole.androidKeepFile]!,
      ).rootElement;

      expect(keep.name.local, 'resources');
      expect(
        keep.getAttribute('tools:keep'),
        '@drawable/${NotificationsRole.androidIcon}',
      );
      expect(
        keep.getAttribute('xmlns:tools'),
        'http://schemas.android.com/tools',
      );
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
            'knows the permission when initNotifications() completes, asks '
            'the user only when the app may not show notifications, takes '
            'the permission from the service after the question, remembers '
            'that it asked, and follows the settings of the system when the '
            'user comes back to the app', () async {
          expect(await app.run('$_notes$_life'), _lifeResult);
        });
      });
    }

    group('in one app', () {
      late DartFiles app;

      setUpAll(() async => app = await _app());

      tearDownAll(() => app.delete());

      test(
          'asks once while the question of the system is shown, and every '
          'request then completes with its answer', () async {
        expect(await app.run('$_notes$_requests'), {
          'the calls while the question is shown': ['areEnabled', 'request'],
          'the permission while the question is shown': 'notAsked',
          'the answers': ['granted', 'granted'],
          'the requests are one': true,
          'the calls once the user answered': ['areEnabled'],
          'saved': true,
          'the step shows once allowed': false,
          'a later request is another': true,
          'the answer of the later request': 'granted',
          'the calls of the later request': ['areEnabled'],
        });
      });

      test('makes a call before the start wait for it', () async {
        expect(await app.run('$_notes$_beforeStart'), {
          'the calls before the start': <Object?>[],
          'the answer': 'granted',
          'scheduled': 0,
          'the calls after the start': [
            // The start, and the request with its two reads.
            'areEnabled',
            'areEnabled',
            'areEnabled',
            'request',
            'scheduled',
            'show 1',
          ],
        });
      });

      test(
          'has the permission right whether the preferences open before the '
          'notifications start or after', () async {
        expect(await app.run('$_notes$_order'), {
          'started before the preferences': 'notAsked',
          'then the preferences opened': 'denied',
        });
      });

      test(
          'takes a notification of the app with an id from 0 up, one of an '
          'owner with a negative id, each in 32 bits, and a time to come, '
          'and refuses any other before it reaches the provider', () async {
        const negative = 'A negative id is for a notification with an owner, '
            'which names it under notificationOwnerKey in its data';
        const owned = 'A notification with an owner has a negative id';
        const bits = 'The id is no 32-bit integer';
        expect(await app.run('$_notes$_calls'), {
          'refused': {
            'a negative id without an owner': 'ArgumentError: $negative',
            'an owner with the id 0': 'ArgumentError: $owned',
            'an id above 32 bits': 'ArgumentError: $bits',
            'an id below 32 bits': 'ArgumentError: $bits',
            'a scheduled one with a negative id without an owner':
                'ArgumentError: $negative',
            'a time that has passed':
                'ArgumentError: The time is not in the future',
          },
          'the calls of the refused': <Object?>[],
          'taken': {
            'the id 0': 'none',
            'the largest id': 'none',
            'the smallest id with an owner': 'none',
            'a time to come': 'none',
          },
          'the calls of the taken': [
            'show 0',
            'show 2147483647',
            'show -2147483648',
            'schedule 2',
          ],
          'scheduled': ['2 Soon In an hour {screen: news}'],
          'the calls of the rest': ['scheduled', 'cancel 2', 'cancelAll'],
        });
      });

      test(
          'tells each listener of the taps on the notifications of the app, '
          'gives the taps on those of an owner to that owner, and has the '
          'tap that launched the app for the one or the other', () async {
        expect(await app.run('$_notes$_taps'), {
          'the launch tap before the start': null,
          'the launch tap': '7 {screen: news}',
          'the launch tap of an owner': null,
          'heard': {
            'app': ['1 {screen: news}', '2 {}'],
            'app, a second listener': ['1 {screen: news}', '2 {}'],
            'push': ['-5 {notifications.owner: push}'],
          },
          'the taps are one stream': true,
          'after a launch by a tap of an owner': {
            'the launch tap': null,
            'the launch tap of the owner': '-9 {notifications.owner: push}',
            'the launch tap of another owner': null,
          },
          // The service of the last start alone.
          'heard after the next launch': {
            'app': ['4 {}'],
            'app, a second listener': ['4 {}'],
          },
        });
      });

      test(
          'completes a request with the error of the preferences that fail '
          'to save it, with the permission up to date', () async {
        expect(await app.run('$_notes$_failedWrite'), {
          'the request': 'The write fails.',
          'the permission': 'denied',
          'saved': false,
          'the answer of the next request': 'denied',
          'saved after it': true,
        });
      });
    });
  });

  group('the entry of the settings screen', () {
    late String code;
    late CompilationUnit unit;

    setUpAll(() async {
      final rendered = await renderTemplate(
        notificationsRole,
        data: [
          dataOf(
            notificationsRole,
            _implementation(async: false),
            module: 'fake_notifications',
          ),
          ..._dataFor(localizationRole),
        ],
        present: {preferencesRole, settingsScreenRole, localizationRole},
      );
      code = rendered.files[NotificationsRole.settingFile]!;
      unit = parseString(content: code).unit;
    });

    /// The named arguments of each creation of [className] in the file.
    List<Map<String, String>> created(String className) {
      final found = _NamedArgumentsOf(className);
      unit.accept(found);
      return found.found;
    }

    test(
        'is given to the settings screen role, which shows it, and has a '
        'constant constructor that requires no arguments', () {
      final data = _dataFor(settingsScreenRole);
      final input = inputOf(
        settingsScreenRole,
        data: data,
        present: {routerRole},
      );

      expect(settingsScreenRole.template.validate(input), isEmpty);
      final entry = settingsScreenRole.entriesIn(input).single;
      expect(entry.widget.name, 'NotificationsSetting');
      expect(entry.file, NotificationsRole.settingFile);
      // The data needs no condition: it applies only with the role.
      expect(data.single.when, isEmpty);
      final constructor = unit.declarations
          .whereType<ClassDeclaration>()
          .single
          .body
          .members
          .whereType<ConstructorDeclaration>()
          .single;
      expect(constructor.constKeyword, isNotNull);
      expect(constructor.name, isNull);
      expect('${constructor.parameters}', '({super.key})');
    });

    test(
        'gives the localization role its texts only in an app with a '
        'settings screen, and reads them from the texts of the app', () {
      final texts = [
        for (final data in _dataFor(localizationRole))
          if (data.when.contains(settingsScreenRole)) data,
      ];
      expect(texts.single.when, {settingsScreenRole});
      final input = inputOf(
        localizationRole,
        data: texts,
        present: {settingsScreenRole},
      );
      expect(localizationRole.template.validate(input), isEmpty);
      expect(
        [for (final text in localizationRole.textsIn(input)) text.getter],
        [
          'notificationsSettingTitle',
          'notificationsSettingOn',
          'notificationsSettingOff',
        ],
      );
      for (final text in localizationRole.textsIn(input)) {
        expect(text.owner, _template);
      }

      final row = created('ListTile').single;
      expect(row['title'], 'Text(context.l10n.notificationsSettingTitle)');
      expect(
        code,
        contains(
          'permission == NotificationPermission.granted\n'
          '              ? context.l10n.notificationsSettingOn\n'
          '              : context.l10n.notificationsSettingOff,',
        ),
      );
    });

    test('writes its texts in English in an app without the localization role',
        () async {
      final rendered = await _rendered(present: {settingsScreenRole});
      final english = rendered.files[NotificationsRole.settingFile]!;

      expect(english, contains("title: Text('Notifications'),"));
      expect(english, contains("? 'On'"));
      expect(english, contains(": 'Off',"));
      expectParses(english);
    });

    test(
        'shows the permission as the value of its row, follows it, and asks '
        'on a tap while the app has not asked, or opens the settings of the '
        'system', () {
      final builder = created('ValueListenableBuilder').single;
      expect(builder['valueListenable'], 'appNotifications.permission');
      final row = created('ListTile').single;
      expect(row['leading'], 'const Icon(Icons.notifications_outlined)');
      expect(
        row['onTap'],
        'permission == NotificationPermission.notAsked ? '
        'appNotifications.request : appNotifications.openSettings',
      );
      // At a large text size, the value goes below the title, as in the
      // other entries of the role templates.
      expect(row['subtitle'], 'below ? state : null');
      expect(
        row['trailing'],
        'below ? arrow : Row(mainAxisSize: MainAxisSize.min, children: '
        '[state, const SizedBox(width: 4), arrow])',
      );
      expect(
        code,
        contains(
          'final below = MediaQuery.textScalerOf(context).scale(10) > 13;',
        ),
      );
      expect(
        [
          for (final directive in unit.directives.whereType<ImportDirective>())
            directive.uri.stringValue,
        ],
        unorderedEquals([
          'package:flutter/material.dart',
          'app_notifications.dart',
          'package:my_app/core/l10n/l10n.dart',
        ]),
      );
    });
  });

  group('the step of the onboarding', () {
    test(
        'is given to the onboarding screen role at the stage of the '
        'permissions, with the functions that the brick of the step '
        'generates, and Not now as its second button', () async {
      final data = _dataFor(onboardingScreenRole);
      final step = data.single.value as OnboardingStep;
      expect(data.single.when, isEmpty);
      expect(step.name, NotificationsRole.stepName);
      expect(step.stage, OnboardingStage.permission);
      expect(step.icon.code, 'Icons.notifications_active_outlined');
      expect(step.problems(), isEmpty);
      expect(
        [step.title, step.text, step.action, step.later],
        [
          NotificationsRole.stepTitle,
          NotificationsRole.stepText,
          NotificationsRole.stepAction,
          NotificationsRole.stepLater,
        ],
      );
      expect(
        [for (final function in step.functions) function.name],
        ['allowNotifications', 'notificationsStepShows'],
      );
      for (final function in step.functions) {
        expect('lib/${function.import.uri}', NotificationsRole.stepFile);
      }

      final input = inputOf(
        onboardingScreenRole,
        data: [...data, ..._dataFor(localizationRole)],
        present: {routerRole, localizationRole},
      );
      expect(onboardingScreenRole.template.validate(input), isEmpty);
      expect(
        [
          for (final step in onboardingScreenRole.stepsIn(input)) step.fullName,
        ],
        ['notifications.permission'],
      );

      // The functions of the file of the step, which the rule of the role
      // reads: what each returns, and that neither takes an argument.
      final rendered = await _rendered(present: {onboardingScreenRole});
      final functions = _functionsOf(
        parseString(content: rendered.files[NotificationsRole.stepFile]!).unit,
      );
      expect(
        {
          for (final MapEntry(key: name, value: function) in functions.entries)
            name: '${function.returnType} '
                '${function.functionExpression.parameters}',
        },
        {
          'notificationsStepShows': 'bool ()',
          'allowNotifications': 'Future<void> ()',
        },
      );
      final index = DartFileIndex(
        path: NotificationsRole.stepFile,
        declarations: [
          for (final MapEntry(key: name, value: function) in functions.entries)
            IndexedDeclaration(
              name: name,
              kind: DeclarationKind.function,
              type: '${function.returnType}',
            ),
        ],
      );
      expect(
        onboardingScreenRole.checkStructure(
          StructuralRuleRequest(
            hook: RoleHookRequest(
              data: data,
              presentRoles: {onboardingScreenRole, notificationsRole},
              context: testContext,
            ),
            files: {NotificationsRole.stepFile: index},
            owners: {NotificationsRole.stepFile: _template},
          ),
        ),
        isEmpty,
      );
    });

    test(
        'gives the localization role its texts only in an app with an '
        'onboarding', () {
      final texts = [
        for (final data in _dataFor(localizationRole))
          if (data.when.contains(onboardingScreenRole)) data,
      ];
      expect(texts.single.when, {onboardingScreenRole});
      final input = inputOf(
        localizationRole,
        data: texts,
        present: {onboardingScreenRole},
      );
      expect(localizationRole.template.validate(input), isEmpty);
      expect(
        [for (final text in localizationRole.textsIn(input)) text.getter],
        [
          'notificationsStepTitle',
          'notificationsStepText',
          'notificationsStepAction',
          'notificationsStepLater',
        ],
      );
    });
  });

  group('the notes of the notifications role for coding agents', () {
    test(
        'name what the files of the role declare, in every app and in the '
        'apps with a settings screen or an onboarding', () async {
      final rendered = await _rendered(
        present: {settingsScreenRole, onboardingScreenRole},
      );

      expectNamesOfCode(
        agentNoteOf(notificationsRole),
        {
          NotificationsRole.controllerFile: [
            'appNotifications',
            'notificationOwnerKey',
            'NotificationsController.show',
            'NotificationsController.schedule',
            'NotificationsController.cancel',
            'NotificationsController.cancelAll',
            'NotificationsController.scheduled',
            'NotificationsController.permission',
            'NotificationsController.request',
            'NotificationsController.openSettings',
            'NotificationsController.taps',
            'NotificationsController.launchTap',
            'NotificationsController.tapsOf',
            'NotificationsController.launchTapOf',
            'NotificationsController.start',
            'NotificationPermission.granted',
            'NotificationPermission.denied',
            'NotificationPermission.notAsked',
            'initNotifications',
            'createNotificationsService',
          ],
          NotificationsRole.serviceFile: [
            'NotificationsService',
            'AppNotification',
            'AppNotification.id',
            'AppNotification.title',
            'AppNotification.body',
            'AppNotification.data',
            'NotificationTap',
          ],
        },
        files: rendered.files,
      );
      expectNamesOfCode(
        agentNoteOf(notificationsRole, when: {settingsScreenRole}),
        {
          NotificationsRole.settingFile: ['NotificationsSetting'],
        },
        files: rendered.files,
      );
      expectNamesOfCode(
        agentNoteOf(notificationsRole, when: {onboardingScreenRole}),
        {
          NotificationsRole.controllerFile: ['NotificationsController.request'],
        },
        files: rendered.files,
      );
      expect(
        agentNoteOf(notificationsRole, when: {onboardingScreenRole}).text,
        contains('`${NotificationsRole.stepFile}`'),
      );
      expect(
        agentNoteOf(notificationsRole).text,
        allOf(
          contains('`${NotificationsRole.androidIconFile}`'),
          contains('`${NotificationsRole.askedKey}`'),
        ),
      );
    });

    test(
        'tell in an app with neither a settings screen nor an onboarding '
        'that nothing asks for the permission yet', () {
      const unasked = '- Nothing in this app asks for the permission yet: '
          'call `appNotifications.request()` where the user turns on '
          'something that notifies.';
      for (final present in <Set<Role>>[
        const {},
        {settingsScreenRole},
        {onboardingScreenRole},
        {settingsScreenRole, onboardingScreenRole},
      ]) {
        final output = notificationsRole.template.render(
          inputOf(
            notificationsRole,
            data: [
              dataOf(
                notificationsRole,
                _implementation(async: false),
                module: 'fake_notifications',
              ),
            ],
            present: {preferencesRole, ...present},
          ),
        );
        final notes = [
          for (final fragment in output.fragments)
            if (fragment.socket == AppEntryRole.agentSections) fragment,
        ];

        expect(
          [for (final note in notes) (note.entryValue! as AgentNote).text],
          present.isEmpty ? [unasked] : isEmpty,
          reason: '$present',
        );
        for (final note in notes) {
          expect(note.entryKey, notificationsRole.description);
          expect((note.entryValue! as AgentNote).isOfRole, isTrue);
        }
      }
    });
  });

  group('the section of the notifications role in the README of the app', () {
    /// The section in an app with the roles in [present].
    Future<String> sectionWith(Set<Role> present) async {
      final rendered = await _rendered(present: present);
      final section = rendered.elsewhere.singleWhere(
        (entry) => entry.socket == AppEntryRole.readmeSections,
      );
      expect(section.entryKey, NotificationsRole.readmeHeading);
      return section.entryValue! as String;
    }

    test(
        'tells how the app shows notifications, the permission, and the '
        'small icon of Android, with the names of the code', () async {
      final rendered = await _rendered(
        present: {settingsScreenRole, onboardingScreenRole},
      );
      final section = await sectionWith(
        {settingsScreenRole, onboardingScreenRole},
      );

      expectNamesOfCodeIn(
        section,
        {
          NotificationsRole.controllerFile: [
            'appNotifications',
            'NotificationsController.show',
            'NotificationsController.schedule',
            'NotificationsController.cancel',
            'NotificationsController.cancelAll',
            'NotificationsController.scheduled',
            'NotificationsController.taps',
            'NotificationsController.launchTap',
            'NotificationsController.permission',
            'NotificationsController.request',
            'NotificationsController.openSettings',
            'NotificationPermission.granted',
            'NotificationPermission.denied',
            'NotificationPermission.notAsked',
          ],
          NotificationsRole.settingFile: ['NotificationsSetting'],
        },
        files: rendered.files,
      );
      expect(
        section,
        allOf(
          contains('`${NotificationsRole.androidIconFile}`'),
          contains('`${NotificationsRole.androidKeepFile}`'),
        ),
      );
    });

    test('tells where the app asks for the permission', () async {
      const step = 'The onboarding asks on a page of its own';
      const entry = 'The entry `NotificationsSetting` of the settings screen';
      const nothing = 'Nothing in this app asks yet.';

      final both = await sectionWith(
        {settingsScreenRole, onboardingScreenRole},
      );
      expect(both, allOf(contains(step), contains(entry)));
      expect(both, isNot(contains(nothing)));
      final onboarding = await sectionWith({onboardingScreenRole});
      expect(onboarding, contains(step));
      expect(onboarding, isNot(contains(entry)));
      expect(onboarding, contains('`${NotificationsRole.stepFile}`'));
      final settings = await sectionWith({settingsScreenRole});
      expect(settings, contains(entry));
      expect(settings, isNot(contains(step)));
      expect(settings, contains('`${NotificationsRole.settingFile}`'));
      final neither = await sectionWith(const {});
      expect(neither, contains(nothing));
      expect(neither, isNot(contains(NotificationsRole.settingFile)));
      expect(neither, isNot(contains(NotificationsRole.stepFile)));
    });
  });

  group('the rules of the notifications role', () {
    const service =
        'package:my_app/core/notifications/notifications_service.dart';
    const providerFile =
        'lib/core/notifications/fake_notifications_service.dart';
    const screen = 'lib/features/reminders/reminders_screen.dart';
    const ofProvider = ModuleOrigin(ModuleId('fake_notifications'));
    const ofFeature = ModuleOrigin(ModuleId('reminders'));
    const hint = 'Show notifications and ask for the permission through '
        'appNotifications of lib/core/notifications/app_notifications.dart, '
        'which also exports AppNotification and NotificationTap.';

    test(
        'let each provider contribute one implementation, and no module put '
        'code into the socket of the implementation', () {
      List<SmfIssue> issuesOf(
        ModuleDescriptor module, {
        List<RoleImplementation> implementations = const [],
        List<Contribution> contributions = const [],
      }) =>
          notificationsRole.checkModule(
            ModuleRuleRequest(
              hook: RoleHookRequest(
                data: [
                  for (final implementation in implementations)
                    notificationsRole
                        .data(implementation)
                        .withOrigin(ModuleOrigin(module.id)),
                ],
                presentRoles: {notificationsRole, preferencesRole},
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
            NotificationsRole.implementations,
            Fragment('late NotificationsService _notificationsService;'),
          ),
        ],
      ).single;
      expect(issue.message, contains('socket notifications.implementations'));
    });

    test(
        'notifications.factory_calls: a file of a module, or of the '
        'template of another role, that calls createNotificationsService() '
        'is reported, with appNotifications as what to use', () {
      final issues = _structureIssues({
        _calling(providerFile, 'createNotificationsService'): ofProvider,
        _calling(screen, 'createNotificationsService'): ofFeature,
        _calling('lib/core/push/app_push.dart', 'createNotificationsService'):
            RoleTemplateOrigin(_otherRole),
        // Another file of the template of the role itself, and files that
        // neither a module nor the template of a role owns.
        _calling(
          'lib/core/notifications/more.dart',
          'createNotificationsService',
        ): _template,
        _calling('lib/generated.dart', 'createNotificationsService'):
            const PipelineOrigin(),
        _calling('lib/mine.dart', 'createNotificationsService'): null,
      });

      expect(
        [for (final issue in issues) (issue.path, issue.origin)],
        [
          (providerFile, ofProvider),
          (screen, ofFeature),
          ('lib/core/push/app_push.dart', RoleTemplateOrigin(_otherRole)),
        ],
      );
      for (final issue in issues) {
        expect(
          issue.message,
          '${issue.path} calls createNotificationsService(), which no module '
          'may call.',
        );
        expect(issue.hint, hint);
      }
    });

    test(
        'notifications.factory_calls: only the files of the implementation '
        'of the provider import the file of NotificationsService; any other '
        'file of a module, a widget of the provider too, is reported', () {
      const widget = DartFileIndex(
        path: 'lib/core/notifications/fake_notifications_widget.dart',
        imports: [IndexedImport('notifications_service.dart')],
      );
      const prefixed = DartFileIndex(
        path: screen,
        imports: [IndexedImport(service, prefix: 'notifications')],
      );
      const exporting = DartFileIndex(
        path: 'lib/core/push/app_push.dart',
        exports: [IndexedImport('../notifications/notifications_service.dart')],
      );
      const ofClass = DartFileIndex(
        path: providerFile,
        imports: [IndexedImport('notifications_service.dart')],
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
        [widget.path, screen, 'lib/core/push/app_push.dart'],
      );
      for (final issue in issues) {
        expect(
          issue.message,
          '${issue.path} imports ${NotificationsRole.serviceFile}, the file '
          'of NotificationsService, which only the files of the '
          'implementation of the provider of the notifications role import.',
        );
        expect(issue.hint, hint);
      }
    });

    test(
        'notifications.start_calls: only bootstrap() calls '
        'initNotifications(), and no module calls appNotifications.start()',
        () {
      const startHint = 'The role starts the notifications in bootstrap(), '
          'before the first frame. Read the permission and the taps from '
          'appNotifications.';
      const starting = DartFileIndex(
        path: screen,
        imports: [
          IndexedImport(
            'package:my_app/core/notifications/app_notifications.dart',
          ),
        ],
        invocations: [
          IndexedInvocation('start', target: 'appNotifications'),
        ],
      );
      final issues = _structureIssues({
        _calling(AppEntryRole.bootstrapFile, 'initNotifications'): null,
        _calling(providerFile, 'initNotifications'): ofProvider,
        starting: ofFeature,
        // The template of the role starts the controller itself.
        const DartFileIndex(
          path: 'lib/core/notifications/more.dart',
          imports: [IndexedImport('app_notifications.dart')],
          invocations: [
            IndexedInvocation('start', target: 'appNotifications'),
          ],
        ): _template,
      });

      expect(
        [for (final issue in issues) (issue.message, issue.hint)],
        [
          (
            '$providerFile calls initNotifications(), which only bootstrap() '
                'calls.',
            startHint,
          ),
          (
            '$screen calls appNotifications.start(), which only '
                'initNotifications() calls.',
            startHint,
          ),
        ],
      );
    });

    test(
        'notifications.implementation_factories: the function of the '
        'implementation is in its file and takes no arguments', () {
      final missing = notificationsRole.checkStructure(
        StructuralRuleRequest(
          hook: RoleHookRequest(
            data: [
              dataOf(
                notificationsRole,
                _implementation(async: false),
                module: 'fake_notifications',
              ),
            ],
            presentRoles: {notificationsRole, preferencesRole},
            context: testContext,
          ),
          files: const {
            'lib/fakes/fake_notifications.dart':
                DartFileIndex(path: 'lib/fakes/fake_notifications.dart'),
          },
        ),
      );
      expect(
        missing.single.message,
        contains('does not declare function createFakeNotifications()'),
      );
    });
  });
}
