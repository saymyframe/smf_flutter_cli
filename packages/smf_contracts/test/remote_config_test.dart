@TestOn('vm')
library;

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contracts/bundles/remote_config_role_bundle.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'dart_files.dart';
import 'role_support.dart';
import 'support.dart';

/// The file of the fake provider of remote config in the test app.
const _fakeFile = ImportRef.app('fakes/fake_remote_config.dart');

/// The file of `appRemoteConfig`, as code imports it.
const _controllerImport =
    ImportRef.app('core/remote_config/app_remote_config.dart');

/// The implementation of the service of the test app.
const _implementation = RemoteConfigImplementation(
  type: TypeRef('FakeRemoteConfig', import: _fakeFile),
  create: FactoryRef('createFakeRemoteConfig', import: _fakeFile),
);

/// The parameters of the module of the test app, one of each type.
const _keys = [
  RemoteConfigKey.text(
    'fake_config_user_greeting',
    defaultValue: 'Hello',
    description: 'The greeting of the fixture',
  ),
  RemoteConfigKey.boolean(
    'fake_config_user_enabled',
    defaultValue: true,
    description: 'Whether the fixture is on',
  ),
  RemoteConfigKey.integer(
    'fake_config_user_limit',
    defaultValue: 3,
    description: 'How many the fixture takes',
  ),
  RemoteConfigKey.decimal(
    'fake_config_user_ratio',
    defaultValue: 0.5,
    description: 'The ratio of the fixture',
  ),
];

/// What the template of the role contributes.
List<Contribution> _contributions() =>
    remoteConfigRole.template.contribute(testContext);

/// The data of an app with the provider and, unless [parameters] is false,
/// the module that gives the role [_keys].
List<RoleData<Object>> _data({bool parameters = true}) => [
      dataOf(remoteConfigRole, _implementation, module: 'fake_remote_config'),
      if (parameters)
        for (final key in _keys)
          dataOf(remoteConfigRole, key, module: 'fake_config_user'),
    ];

/// The files of the role, rendered in an app with the parameters of [_keys],
/// or without parameters, and what the template puts into other sockets.
Future<RenderedTemplate> _rendered({bool parameters = true}) =>
    renderTemplate(remoteConfigRole, data: _data(parameters: parameters));

/// The render hook of the template in an app with [data].
RoleOutput _output(List<RoleData<Object>> data) =>
    remoteConfigRole.template.render(inputOf(remoteConfigRole, data: data));

/// The section of the role in the README of an app with [data].
String _readmeOf(List<RoleData<Object>> data) => _output(data)
    .fragments
    .singleWhere((entry) => entry.socket == AppEntryRole.readmeSections)
    .entryValue! as String;

/// A stand-in for the part of Flutter's foundation library that the files
/// of the role use, with the signatures of Flutter 3.44: the app runs in
/// debug mode, and what it prints goes to `debugPrinted`.
const _foundation = r'''
const bool kDebugMode = true;

/// What the app printed with [debugPrint], in order.
final List<String> debugPrinted = [];

void debugPrint(String? message, {int? wrapWidth}) =>
    debugPrinted.add('$message');

class Immutable {
  const Immutable();
}

const Immutable immutable = Immutable();

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
''';

/// A stand-in for the part of Flutter's widgets library that the files of
/// the role use: what that library exports of the foundation library, and
/// the binding with the observers of the lifecycle of the app. `lifecycle()`
/// puts the app into a state, and `resumeApp()` stands for the user who
/// comes back to the app.
const _widgets = '''
export 'foundation.dart' show ChangeNotifier, Listenable, VoidCallback;

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

/// A provider of remote config for the test app, which keeps to the
/// contract of `RemoteConfigService` unless a test says otherwise.
///
/// What the backend has, what the last fetch got and what is active are on
/// variables that stand for the backend and the device: each new service
/// reads them, as a service does at the next launch of an app. The services
/// note their calls, each with the number of its service, and a test holds a
/// call until it lets it go, or makes it fail.
const _fakeRemoteConfig = r'''
import 'dart:async';

import '../core/remote_config/remote_config_service.dart';

/// What the backend has, by parameter.
Map<String, String> backend = {};

/// What the last fetch got, which the device keeps.
Map<String, String> fetchedOnDevice = {};

/// The active values, which the device keeps.
Map<String, String> activeOnDevice = {};

/// Whether the services tell of the values that the backend publishes.
bool live = false;

/// The calls that reached the services, in order, each with the number of
/// its service.
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

RemoteConfigService createFakeRemoteConfig() => FakeRemoteConfig();

final class FakeRemoteConfig implements RemoteConfigService {
  FakeRemoteConfig() : number = ++created;

  /// The number of the service, from 1.
  final int number;

  final StreamController<void> _updates = StreamController<void>.broadcast();

  /// What [open] got, once it is called.
  ({Map<String, Object> defaults, Duration interval, Duration timeout})?
      opened;

  /// Whether something follows the updates of the service.
  bool get followed => _updates.hasListener;

  /// The backend publishes [values] while the app runs: the service fetches
  /// them and tells of them.
  void publish(Map<String, String> values) {
    backend = {...values};
    fetchedOnDevice = {...values};
    _updates.add(null);
  }

  /// Sends [error] to those who follow the updates.
  void failUpdates(Object error) => _updates.addError(error);

  Future<void> _enter(String call) async {
    calls.add('$call $number');
    await holds[call]?.future;
    if (failures[call] case final failure?) throw failure;
  }

  @override
  Future<void> open(
    Map<String, Object> defaults, {
    required Duration fetchInterval,
    required Duration fetchTimeout,
  }) async {
    opened = (
      defaults: defaults,
      interval: fetchInterval,
      timeout: fetchTimeout,
    );
    await _enter('open');
  }

  @override
  Future<bool> activate() async {
    await _enter('activate');
    final changed = '$fetchedOnDevice' != '$activeOnDevice';
    activeOnDevice = {...fetchedOnDevice};
    return changed;
  }

  @override
  Map<String, String> get values => {...activeOnDevice};

  @override
  Future<void> fetch() async {
    await _enter('fetch');
    fetchedOnDevice = {...backend};
  }

  @override
  bool get liveUpdates => live;

  @override
  Stream<void> get updates => _updates.stream;
}
''';

/// What the scripts for the test app share. `pump` lets what is on its way
/// happen, the fetch of a start among it, which comes a turn of the event
/// loop after the start.
const _notes = '''
import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:my_app/core/remote_config/app_remote_config.dart';
import 'package:my_app/fakes/fake_remote_config.dart';

final result = <String, Object?>{};

Future<void> pump() => Future<void>.delayed(Duration.zero);

/// The service of the app, as a fake.
FakeRemoteConfig get service =>
    createRemoteConfigService() as FakeRemoteConfig;
''';

/// What the scripts for the app with parameters share: the values as a
/// test compares them.
const _withParameters = '''
Map<String, Object> shown(RemoteValues values) => {
      'greeting': values.fakeConfigUserGreeting,
      'enabled': values.fakeConfigUserEnabled,
      'limit': values.fakeConfigUserLimit,
      'ratio': values.fakeConfigUserRatio,
    };
''';

/// Goes through the start of the app and the fetches after it: the values
/// that the device kept, the fetch a turn later, a resume that brings
/// nothing new, and a resume that brings a new value. After each step it
/// notes the values, the calls that reached the provider and how many times
/// the listeners were told of a change.
const _lifecycle = '''
Future<void> main(List<String> arguments, SendPort port) async {
  var heard = 0;
  appRemoteConfig.addListener(() => heard++);
  void note(String step) {
    result[step] = {
      'values': shown(appRemoteConfig.value),
      'calls': takeCalls(),
      'heard': heard,
    };
    heard = 0;
  }

  note('before the start');
  backend = {'fake_config_user_greeting': 'Hi', 'fake_config_user_limit': '7'};
  fetchedOnDevice = {'fake_config_user_ratio': '0.25'};
  await initRemoteConfig();
  note('the start');
  await pump();
  note('a turn later');
  resumeApp();
  await pump();
  note('a resume that brings nothing new');
  backend = {
    'fake_config_user_greeting': 'Hi',
    'fake_config_user_limit': '7',
    'fake_config_user_enabled': 'false',
  };
  resumeApp();
  await pump();
  note('a resume that brings a new value');
  final opened = service.opened!;
  result['open'] = {
    // A copy: a constant map that crosses to another isolate group fails
    // its lookups there.
    'defaults': {...opened.defaults},
    'interval': opened.interval.inSeconds,
    'timeout': opened.timeout.inSeconds,
  };
  result['followed'] = service.followed;
  result['printed'] = debugPrinted;
  port.send(result);
}
''';

/// Values of each type, and texts that their types do not take, which read
/// the default and print once.
const _types = '''
Future<void> main(List<String> arguments, SendPort port) async {
  fetchedOnDevice = {
    'fake_config_user_greeting': 'Hi',
    'fake_config_user_enabled': 'FALSE',
    'fake_config_user_limit': '42',
    'fake_config_user_ratio': '2.5',
  };
  backend = {...fetchedOnDevice};
  await initRemoteConfig();
  await pump();
  result['valid texts'] = shown(appRemoteConfig.value);
  backend = {
    'fake_config_user_greeting': '',
    'fake_config_user_enabled': 'yes',
    'fake_config_user_limit': '4.2',
    'fake_config_user_ratio': 'NaN',
  };
  resumeApp();
  await pump();
  result['invalid texts'] = shown(appRemoteConfig.value);
  result['printed'] = [...debugPrinted];
  debugPrinted.clear();
  resumeApp();
  await pump();
  result['printed again'] = [...debugPrinted];
  backend = {
    'fake_config_user_enabled': 'True',
    'fake_config_user_limit': '-8',
    'fake_config_user_ratio': '1e400',
  };
  resumeApp();
  await pump();
  result['more texts'] = shown(appRemoteConfig.value);
  final initial = RemoteValues.of(const {});
  result['equal values'] = [
    initial == RemoteValues.initial,
    initial.hashCode == RemoteValues.initial.hashCode,
    RemoteValues.of(const {'fake_config_user_limit': '4'}) ==
        RemoteValues.of(const {'fake_config_user_limit': '4'}),
    RemoteValues.of(const {'fake_config_user_limit': '4'}) ==
        RemoteValues.initial,
  ];
  result['defaults'] = {...RemoteValues.defaults};
  port.send(result);
}
''';

/// A service that hangs when it opens: the start ends after `startWait`,
/// and the values come once it answers.
const _hanging = '''
Future<void> main(List<String> arguments, SendPort port) async {
  fetchedOnDevice = {'fake_config_user_greeting': 'Kept'};
  backend = {...fetchedOnDevice};
  holds['open'] = Completer<void>();
  final watch = Stopwatch()..start();
  await initRemoteConfig();
  final took = watch.elapsed;
  result['the start waited startWait, and no more'] =
      took >= AppRemoteConfigController.startWait &&
          took < AppRemoteConfigController.startWait * 2;
  result['the values while it hangs'] = shown(appRemoteConfig.value);
  result['the calls while it hangs'] = takeCalls();
  holds.remove('open')!.complete();
  await pump();
  await pump();
  result['the values once it answers'] = shown(appRemoteConfig.value);
  result['the calls once it answers'] = takeCalls();
  port.send(result);
}
''';

/// A service that tells of the values that the backend publishes, and one
/// that does not, at the next start.
const _live = '''
Future<void> main(List<String> arguments, SendPort port) async {
  live = true;
  await initRemoteConfig();
  final first = service;
  result['followed before the fetch of the start'] = first.followed;
  await pump();
  result['followed'] = first.followed;
  takeCalls();
  first.publish({'fake_config_user_greeting': 'Live'});
  await pump();
  result['a published value'] = shown(appRemoteConfig.value);
  result['the calls of a published value'] = takeCalls();
  live = false;
  await initRemoteConfig();
  await pump();
  result['the first followed after the next start'] = first.followed;
  result['the second followed'] = service.followed;
  first.publish({'fake_config_user_greeting': 'Late'});
  await pump();
  result['a value that the first published after the next start'] =
      shown(appRemoteConfig.value);
  port.send(result);
}
''';

/// A start again with another service while a fetch of the first is on its
/// way: the controller drops the calls of the first.
const _restart = '''
Future<void> main(List<String> arguments, SendPort port) async {
  fetchedOnDevice = {'fake_config_user_greeting': 'First'};
  backend = {...fetchedOnDevice};
  var heard = 0;
  appRemoteConfig.addListener(() => heard++);
  await initRemoteConfig();
  result['the first start'] = shown(appRemoteConfig.value);
  holds['fetch'] = Completer<void>();
  await pump();
  result['the calls of the first'] = takeCalls();
  holds.remove('fetch');
  heard = 0;
  fetchedOnDevice = {};
  backend = {'fake_config_user_greeting': 'Second'};
  // The next start takes the defaults back before the new service opens.
  final starting = initRemoteConfig();
  result['the values right after the next start began'] =
      shown(appRemoteConfig.value);
  result['heard right after the next start began'] = heard;
  await starting;
  await pump();
  await pump();
  result['the values once both are done'] = shown(appRemoteConfig.value);
  result['the calls once both are done'] = takeCalls();
  port.send(result);
}
''';

/// Errors of the service, which keep the values, print in debug mode and
/// reach no handler of the uncaught errors.
const _errors = r'''
Future<void> main(List<String> arguments, SendPort port) async {
  final uncaught = <String>[];
  final done = Completer<void>();
  runZonedGuarded(
    () async {
      fetchedOnDevice = {'fake_config_user_greeting': 'Kept'};
      backend = {'fake_config_user_greeting': 'Fetched'};
      failures['fetch'] = StateError('The fetch broke.');
      live = true;
      await initRemoteConfig();
      await pump();
      result['the values after a failed fetch'] =
          shown(appRemoteConfig.value);
      failures.remove('fetch');
      failures['activate'] = StateError('The activation broke.');
      resumeApp();
      await pump();
      result['the values after a failed activation'] =
          shown(appRemoteConfig.value);
      failures.remove('activate');
      service.failUpdates(StateError('The updates broke.'));
      await pump();
      service.publish({'fake_config_user_greeting': 'Published'});
      await pump();
      result['the values after an error of the updates'] =
          shown(appRemoteConfig.value);
      takeCalls();
      failures['open'] = StateError('The opening broke.');
      await initRemoteConfig();
      await pump();
      resumeApp();
      await pump();
      result['the calls of a service that did not open'] = takeCalls();
      result['the values of a service that did not open'] =
          shown(appRemoteConfig.value);
      done.complete();
    },
    (error, stackTrace) => uncaught.add('$error'),
  );
  await done.future;
  result['printed'] = debugPrinted;
  result['uncaught'] = uncaught;
  port.send(result);
}
''';

/// The start and the returns of the user in an app without parameters: it
/// opens the service and makes active what the device kept, and asks the
/// backend nothing.
const _withoutParameters = '''
Future<void> main(List<String> arguments, SendPort port) async {
  live = true;
  backend = {'remote_config_role_check': 'On the backend'};
  fetchedOnDevice = {'remote_config_role_check': 'Kept'};
  await initRemoteConfig();
  await pump();
  resumeApp();
  await pump();
  result['calls'] = takeCalls();
  result['followed'] = service.followed;
  result['the values of the service'] = service.values;
  result['the values are the defaults'] =
      appRemoteConfig.value == RemoteValues.initial;
  result['defaults'] = {...RemoteValues.defaults};
  port.send(result);
}
''';

/// In a release build, an error of the service and a text that the type of
/// its parameter does not take print nothing.
const _release = '''
Future<void> main(List<String> arguments, SendPort port) async {
  fetchedOnDevice = {'fake_config_user_limit': 'many'};
  backend = {'fake_config_user_limit': '4'};
  failures['fetch'] = StateError('The fetch broke.');
  await initRemoteConfig();
  await pump();
  result['the values'] = shown(appRemoteConfig.value);
  result['printed'] = debugPrinted;
  port.send(result);
}
''';

/// The files of the test app: the files of the role, as its template
/// generates them with the parameters of [_keys] or without parameters, and
/// the fake provider. The app runs in debug mode, or in a release build
/// without [debug].
Future<DartFiles> _app({bool parameters = true, bool debug = true}) async {
  final rendered = await _rendered(parameters: parameters);
  return DartFiles.write(
    {
      for (final MapEntry(key: path, value: text) in rendered.files.entries)
        path: text,
      'lib/fakes/fake_remote_config.dart': _fakeRemoteConfig,
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

/// What a debug build prints of [text], the value of [parameter], which
/// [type], the type of the parameter, does not take.
String _invalidPrinted(String parameter, String text, String type) =>
    'Remote config gives $parameter the value "$text", which is no $type, so '
    'the app reads its default.';

/// What a debug build prints of [error], an error of the service.
String _failurePrinted(String error) =>
    'Remote config keeps its values; its service failed: $error';

/// The provider of the role, a module that requires it, and one that uses
/// it.
const _provider = ModuleDescriptor(
  id: ModuleId('fake_remote_config'),
  description: 'Remote config',
  kind: ModuleKinds.infrastructure,
  providers: [RoleProvider.plain(remoteConfigRole)],
);
const _user = ModuleDescriptor(
  id: ModuleId('fake_config_user'),
  description: 'Parameters',
  kind: ModuleKinds.infrastructure,
  requires: {remoteConfigRole},
);
const _dependent = ModuleDescriptor(
  id: ModuleId('greeter'),
  description: 'Greeter',
  kind: ModuleKinds.feature,
  dependsOn: {ModuleId('fake_config_user')},
  uses: {remoteConfigRole},
);
const _stranger = ModuleDescriptor(
  id: ModuleId('stranger'),
  description: 'Stranger',
  kind: ModuleKinds.feature,
  uses: {remoteConfigRole},
);
const _outsider = ModuleDescriptor(
  id: ModuleId('outsider'),
  description: 'Outsider',
  kind: ModuleKinds.feature,
);

/// The template of another role whose code could reach the service or read
/// a parameter.
final _otherRole = TestRole<NoDsl>('gate', requires: {remoteConfigRole});

/// The file of the function of [_implementation], which imports the file of
/// `RemoteConfigService`, as the file of an implementation may.
const _factoryFile = DartFileIndex(
  path: 'lib/fakes/fake_remote_config.dart',
  imports: [IndexedImport('../core/remote_config/remote_config_service.dart')],
  declarations: [
    IndexedDeclaration(
      name: 'createFakeRemoteConfig',
      kind: DeclarationKind.function,
    ),
  ],
);

/// The issues of the structural rules of the role in an app of the provider
/// and of the module with [_keys], with [files], each with its owner; a file
/// without an owner has `null`.
List<SmfIssue> _structureIssues(
  Map<DartFileIndex, ContributionOrigin?> files,
) =>
    remoteConfigRole.checkStructure(
      StructuralRuleRequest(
        hook: RoleHookRequest(
          data: _data(),
          presentRoles: {remoteConfigRole},
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
        modules: const [_provider, _user, _dependent, _stranger, _outsider],
      ),
    );

/// The index of the file at [path] that imports the file of
/// `appRemoteConfig` and calls [function] of it.
DartFileIndex _calling(String path, String function) => DartFileIndex(
      path: path,
      imports: const [
        IndexedImport(
          'package:my_app/core/remote_config/app_remote_config.dart',
        ),
      ],
      invocations: [IndexedInvocation(function)],
    );

/// The index of the file at [path] that reads the getter [getter] of the
/// values of the app.
DartFileIndex _reading(String path, String getter) => DartFileIndex(
      path: path,
      imports: const [
        IndexedImport(
          'package:my_app/core/remote_config/app_remote_config.dart',
        ),
      ],
      memberAccesses: [IndexedMemberAccess('appRemoteConfig.value', getter)],
    );

/// The issues of the module rules of the role for [module] with [data].
List<SmfIssue> _moduleIssues(
  ModuleDescriptor module,
  List<RemoteConfigData> data, {
  List<Contribution> contributions = const [],
}) =>
    remoteConfigRole.checkModule(
      ModuleRuleRequest(
        hook: RoleHookRequest(
          data: [
            for (final value in data)
              remoteConfigRole.data(value).withOrigin(ModuleOrigin(module.id)),
          ],
          presentRoles: {remoteConfigRole},
          context: testContext,
        ),
        module: module,
        contributions: contributions,
      ),
    );

void main() {
  group('the remote config role', () {
    test(
        'takes one provider, and neither requires nor uses another role, so '
        'its provider has one case', () {
      expect(remoteConfigRole.id, 'remote_config');
      expect(remoteConfigRole.description, 'Remote config');
      expect(remoteConfigRole.presenceFlag, 'has_remote_config');
      expect('$remoteConfigRole', 'remote config role');
      expect(remoteConfigRole.cardinality, RoleCardinality.atMostOne);
      expect(remoteConfigRole.requires, isEmpty);
      expect(remoteConfigRole.uses, isEmpty);
      expect(
        remoteConfigRole.sockets,
        const [RemoteConfigRole.implementations],
      );
      expect(
        RemoteConfigRole.implementations.tag,
        'smf_remote_config__implementations',
      );
      expect(remoteConfigRole.options, isEmpty);
      expect(
        [for (final rule in remoteConfigRole.moduleRules) rule.id],
        ['services.implementations', 'remote_config.keys'],
      );
      expect(
        [for (final rule in remoteConfigRole.structuralRules) rule.id],
        [
          'remote_config.factory_calls',
          'remote_config.start_calls',
          'remote_config.implementation_factories',
          'remote_config.key_access',
        ],
      );
    });

    test(
        'guarantees the files of the service, of the controller and of the '
        'values, and names the parameter of the mocks outside the app', () {
      expect(remoteConfigRole.interface.files, [
        'lib/core/remote_config/remote_config_service.dart',
        'lib/core/remote_config/app_remote_config.dart',
        'lib/core/remote_config/remote_values.dart',
      ]);
      expect(remoteConfigRole.interface.files, [
        RemoteConfigRole.serviceFile,
        RemoteConfigRole.controllerFile,
        RemoteConfigRole.valuesFile,
      ]);
      expect(remoteConfigRole.interface.symbols, isEmpty);
      expect(RemoteConfigRole.readmeHeading, 'Remote config');
      // A name of the role that no module can give, since it starts with the
      // id of the role.
      expect(RemoteConfigRole.checkParameter, 'remote_config_role_check');
      expect(
        RemoteConfigRole.checkParameter,
        startsWith('${remoteConfigRole.id}_'),
      );
    });

    test(
        'has the parameters of the app with their owners, those of the '
        'modules in their order and then those of the templates', () {
      const ofTemplate = RemoteConfigKey.integer(
        'remote_config_retries',
        defaultValue: 2,
        description: 'Retries',
      );
      final keys = remoteConfigRole.keysIn(
        inputOf(
          remoteConfigRole,
          // The data of the modules, and then that of the templates, as
          // the pipeline gives it.
          data: [
            dataOf(remoteConfigRole, _implementation, module: 'provider'),
            for (final key in _keys)
              remoteConfigRole.data(key).withOrigin(
                    const ModuleOrigin(
                      ModuleId('fake_config_user'),
                      variant: ModuleId('fake_bloc'),
                    ),
                  ),
            remoteConfigRole
                .data(ofTemplate)
                .withOrigin(const RoleTemplateOrigin(remoteConfigRole)),
          ],
        ),
      );
      expect(
        [for (final key in keys) '${key.name} ${key.owner}'],
        [
          for (final key in _keys) '${key.name} fake_config_user',
          'remote_config_retries role:remote_config',
        ],
      );
      final greeting = keys.first;
      expect(
        (
          greeting.type,
          greeting.defaultValue,
          greeting.description,
          greeting.getter,
          '$greeting',
        ),
        (
          RemoteParameterType.text,
          'Hello',
          'The greeting of the fixture',
          'fakeConfigUserGreeting',
          'parameter fake_config_user_greeting of the module fake_config_user',
        ),
      );
    });
  });

  group('a parameter of remote config', () {
    test(
        'has a type, a default of that type as Dart code, and a getter in '
        'lowerCamelCase', () {
      expect(
        [
          for (final key in _keys)
            (key.type.dartType, key.defaultCode, key.getter),
        ],
        [
          ('String', "'Hello'", 'fakeConfigUserGreeting'),
          ('bool', 'true', 'fakeConfigUserEnabled'),
          ('int', '3', 'fakeConfigUserLimit'),
          ('double', '0.5', 'fakeConfigUserRatio'),
        ],
      );
      expect(
        [
          const RemoteConfigKey.decimal(
            'a_b',
            defaultValue: 1,
            description: 'd',
          ).defaultCode,
          const RemoteConfigKey.decimal(
            'a_b',
            defaultValue: 1e21,
            description: 'd',
          ).defaultCode,
          const RemoteConfigKey.text(
            'a_b',
            defaultValue: r"it's $5",
            description: 'd',
          ).defaultCode,
        ],
        ['1.0', '1e+21', r"'it\'s \$5'"],
      );
      expect(
        [for (final type in RemoteParameterType.values) type.description],
        ['a text', 'a Boolean', 'a whole number', 'a number'],
      );
      for (final key in _keys) {
        expect(key.problems(), isEmpty, reason: key.name);
      }
    });

    test('reports each problem of its own', () {
      List<String> problemsOf(RemoteConfigKey key) => key.problems();

      expect(
        problemsOf(
          const RemoteConfigKey.text(
            'Greeting',
            defaultValue: '',
            description: 'd',
          ),
        ).single,
        contains('needs a name in lower snake_case of two words or more'),
      );
      expect(
        problemsOf(
          const RemoteConfigKey.text(
            'greeting',
            defaultValue: '',
            description: 'd',
          ),
        ).single,
        contains('needs a name in lower snake_case of two words or more'),
      );
      expect(
        problemsOf(
          RemoteConfigKey.text(
            'a_${'b' * 255}',
            defaultValue: '',
            description: 'd',
          ),
        ).single,
        contains('has a name of 257 characters'),
      );
      expect(
        problemsOf(
          const RemoteConfigKey.text(
            'to_string',
            defaultValue: '',
            description: 'd',
          ),
        ).single,
        contains('would be read as RemoteValues.toString'),
      );
      expect(
        problemsOf(
          const RemoteConfigKey.decimal(
            'a_b',
            defaultValue: double.infinity,
            description: 'd',
          ),
        ).single,
        contains('a decimal default is a finite number'),
      );
      expect(
        problemsOf(
          const RemoteConfigKey.decimal(
            'a_b',
            defaultValue: double.nan,
            description: 'd',
          ),
        ).single,
        contains('a decimal default is a finite number'),
      );
      for (final text in ['one\ntwo', 'one\rtwo', 'with `code`']) {
        expect(
          problemsOf(
            RemoteConfigKey.text('a_b', defaultValue: text, description: 'd'),
          ).single,
          contains('a default that is not one line without a backtick'),
          reason: text,
        );
      }
      expect(
        problemsOf(
          const RemoteConfigKey.boolean(
            'a_b',
            defaultValue: true,
            description: ' ',
          ),
        ).single,
        contains('has no description'),
      );
      for (final description in [' padded', 'one\ntwo']) {
        expect(
          problemsOf(
            RemoteConfigKey.boolean(
              'a_b',
              defaultValue: true,
              description: description,
            ),
          ).single,
          contains('is not one line of text without spaces around it'),
          reason: description,
        );
      }
      expect(
        problemsOf(
          RemoteConfigKey.integer(
            'a_b',
            defaultValue: 1,
            description: 'd' * 101,
          ),
        ).single,
        contains('a description of 101 characters; at most 100'),
      );
      expect(
        problemsOf(
          const RemoteConfigKey.integer(
            'a_b',
            defaultValue: 1,
            description: r'a \ b',
          ),
        ).single,
        contains('has a backslash in its description'),
      );
    });
  });

  group('the remote config template', () {
    test('generates the files of the role, in every app', () async {
      final bricks = _contributions().whereType<BrickContribution>().toList();
      expect(
        [for (final brick in bricks) brick.bundle.name],
        [remoteConfigRoleBundle.name],
      );
      expect(bricks.single.when, isEmpty);

      for (final parameters in [true, false]) {
        final rendered = await _rendered(parameters: parameters);
        expect(
          rendered.files.keys.toSet(),
          remoteConfigRole.interface.files.toSet(),
        );
        for (final MapEntry(key: path, value: text) in rendered.files.entries) {
          expectParses(text, reason: path);
        }
      }
    });

    test('registers nothing in a DI container, and has no step by hand', () {
      final contributions = _contributions();
      expect(contributions.whereType<RoleData<Object>>(), isEmpty);
      expect(contributions.whereType<ManualStep>(), isEmpty);
    });

    test('generates the interface that a provider implements', () async {
      final rendered = await _rendered();
      final code = rendered.files[RemoteConfigRole.serviceFile]!;
      final unit = parseString(content: code).unit;

      const open = 'Future<void> open(Map<String, Object> defaults, {required '
          'Duration fetchInterval, required Duration fetchTimeout})';
      expect(_methodsOf(unit, 'RemoteConfigService'), [
        open,
        'Future<bool> activate()',
        'Map<String, String> get values',
        'Future<void> fetch()',
        'bool get liveUpdates',
        'Stream<void> get updates',
      ]);
      // The file of the provider needs nothing of Flutter and no other file
      // of the app.
      expect(unit.directives, isEmpty);
    });

    test(
        'renders the default and the getter of each parameter of the app, '
        'with its description as its doc, as dart format writes them',
        () async {
      final rendered = await _rendered();
      final code = rendered.files[RemoteConfigRole.valuesFile]!;
      expect(
        code,
        allOf(
          contains(
            '  static const Map<String, Object> defaults = {\n'
            "    'fake_config_user_greeting': 'Hello',\n"
            "    'fake_config_user_enabled': true,\n"
            "    'fake_config_user_limit': 3,\n"
            "    'fake_config_user_ratio': 0.5,\n"
            '  };\n',
          ),
          contains(
            '  final Map<String, Object> _values;\n'
            '\n'
            '  /// The greeting of the fixture\n'
            '  String get fakeConfigUserGreeting =>\n'
            "      _values['fake_config_user_greeting']! as String;\n"
            '\n'
            '  /// Whether the fixture is on\n'
            '  bool get fakeConfigUserEnabled =>\n'
            "      _values['fake_config_user_enabled']! as bool;\n",
          ),
        ),
      );
      expect(
        declarationsOf(code),
        containsAll([
          'RemoteValues.defaults',
          'RemoteValues.initial',
          'RemoteValues.fakeConfigUserGreeting',
          'RemoteValues.fakeConfigUserEnabled',
          'RemoteValues.fakeConfigUserLimit',
          'RemoteValues.fakeConfigUserRatio',
        ]),
      );

      final short = remoteConfigRole.template.render(
        inputOf(
          remoteConfigRole,
          data: [
            dataOf(remoteConfigRole, _implementation, module: 'provider'),
            dataOf(
              remoteConfigRole,
              const RemoteConfigKey.integer(
                'ab_cd',
                defaultValue: 1,
                description: 'Short',
              ),
              module: 'ab',
            ),
          ],
        ),
      );
      // A map and a getter that fit on one line are on one line.
      expect(short.vars['remote_config_defaults'], "{'ab_cd': 1}");
      expect(
        (short.vars['remote_config_getters']! as Fragment).code,
        "\n  /// Short\n  int get abCd => _values['ab_cd']! as int;",
      );
      final none = _output(_data(parameters: false));
      expect(none.vars['remote_config_defaults'], '{}');
      expect((none.vars['remote_config_getters']! as Fragment).code, isEmpty);
    });

    test(
        'creates the implementation in initRemoteConfig(), starts '
        'appRemoteConfig with it, and awaits that in the platform phase of '
        'bootstrap()', () async {
      final rendered = await _rendered();
      final code = rendered.files[RemoteConfigRole.controllerFile]!;
      final unit = parseString(content: code).unit;

      final init = _functionsOf(unit)['initRemoteConfig']!;
      expect('${init.returnType}', 'Future<void>');
      expect(init.functionExpression.parameters!.parameters, isEmpty);
      expect(_statementsOf(init), [
        '_remoteConfigService = impl0.createFakeRemoteConfig();',
        'await appRemoteConfig.start(_remoteConfigService);',
      ]);
      expect(
        [
          for (final declaration
              in unit.declarations.whereType<TopLevelVariableDeclaration>())
            declaration.toSource(),
        ],
        contains('late RemoteConfigService _remoteConfigService;'),
      );
      // The controller imports no file of another role, and exports the
      // values, so the code of the app imports it alone.
      expect(
        [
          for (final directive in unit.directives.whereType<ImportDirective>())
            directive.uri.stringValue,
        ],
        [
          'dart:async',
          'package:flutter/foundation.dart',
          'package:flutter/widgets.dart',
          'remote_config_service.dart',
          'remote_values.dart',
          'package:my_app/fakes/fake_remote_config.dart',
        ],
      );
      expect(
        [
          for (final directive in unit.directives.whereType<ExportDirective>())
            directive.uri.stringValue,
        ],
        ['remote_values.dart'],
      );
      final start = rendered.elsewhere.singleWhere(
        (entry) => entry.socket == AppEntryRole.bootstrapPlatform,
      );
      expect(start.fragment!.code, 'await initRemoteConfig();');
      expect(start.fragment!.imports, [_controllerImport]);
      expect(start.when, isEmpty);
    });

    test(
        'reports the problems of the implementation, of the parameters of '
        'templates, and of two owners with one name or one getter', () {
      List<SmfIssue> issuesOf(List<RoleData<Object>> data) =>
          remoteConfigRole.template.validate(
            inputOf(remoteConfigRole, data: data),
          );

      expect(issuesOf(_data()), isEmpty);
      expect('$_implementation', 'implementation FakeRemoteConfig');
      final implementation = issuesOf([
        dataOf(
          remoteConfigRole,
          const RemoteConfigImplementation(
            type: TypeRef('_Private'),
            create: FactoryRef('create', import: _fakeFile),
          ),
          module: 'fake_remote_config',
        ),
      ]).single;
      expect(
        implementation.origin,
        const ModuleOrigin(ModuleId('fake_remote_config')),
      );

      const template = RoleTemplateOrigin(remoteConfigRole);
      final ofTemplate = issuesOf([
        remoteConfigRole
            .data(
              const RemoteConfigKey.text(
                'other_name',
                defaultValue: '',
                description: 'd',
              ),
            )
            .withOrigin(template),
      ]).single;
      expect(ofTemplate.origin, template);
      expect(
        ofTemplate.message,
        contains('does not start with remote_config_'),
      );

      // The id of one module starts another, so both may name a parameter
      // the same, and parameters whose words are cut differently share a
      // getter.
      final sameName = issuesOf([
        dataOf(
          remoteConfigRole,
          const RemoteConfigKey.text(
            'shop_cart_size',
            defaultValue: '',
            description: 'd',
          ),
          module: 'shop',
        ),
        dataOf(
          remoteConfigRole,
          const RemoteConfigKey.text(
            'shop_cart_size',
            defaultValue: '',
            description: 'd',
          ),
          module: 'shop_cart',
        ),
      ]).single;
      expect(
        sameName.message,
        'Both the module shop and the module shop_cart give the remote config '
        'role the parameter shop_cart_size.',
      );
      expect(sameName.origin, const ModuleOrigin(ModuleId('shop_cart')));
      final sameGetter = issuesOf([
        dataOf(
          remoteConfigRole,
          const RemoteConfigKey.text(
            'shop_1_size',
            defaultValue: '',
            description: 'd',
          ),
          module: 'shop',
        ),
        dataOf(
          remoteConfigRole,
          const RemoteConfigKey.text(
            'shop1_size',
            defaultValue: '',
            description: 'd',
          ),
          module: 'shop1',
        ),
        remoteConfigRole
            .data(
              const RemoteConfigKey.text(
                'remote_config_shop1_size',
                defaultValue: '',
                description: 'd',
              ),
            )
            .withOrigin(template),
      ]).single;
      expect(
        sameGetter.message,
        'The parameter shop_1_size of the module shop and the parameter '
        'shop1_size of the module shop1 would both be read as '
        'RemoteValues.shop1Size.',
      );
      expect(sameGetter.origin, const ModuleOrigin(ModuleId('shop1')));
      // The template of the role that clashes with a module leaves the fault
      // to the module, which lenient mode can leave out.
      final withTemplate = issuesOf([
        dataOf(
          remoteConfigRole,
          const RemoteConfigKey.text(
            'remote_config_size',
            defaultValue: '',
            description: 'd',
          ),
          module: 'remote',
        ),
        remoteConfigRole
            .data(
              const RemoteConfigKey.text(
                'remote_config_size',
                defaultValue: '',
                description: 'd',
              ),
            )
            .withOrigin(template),
      ]).single;
      expect(
        withTemplate.message,
        'Both the module remote and the template of the remote config role '
        'give the remote config role the parameter remote_config_size.',
      );
      expect(withTemplate.origin, const ModuleOrigin(ModuleId('remote')));
    });
  });

  group('the generated controller', () {
    late DartFiles app;

    setUpAll(() async => app = await _app());

    tearDownAll(() => app.delete());

    test('is code that type-checks, and the values are formatted', () async {
      expect(await app.analysisProblems(infos: true), isEmpty);
      for (final path in remoteConfigRole.interface.files) {
        expect(await app.isFormatted(path), isTrue, reason: path);
      }
    });

    test(
        'starts with the values that the device kept, fetches a turn of the '
        'event loop later and on each resume, and tells its listeners only '
        'of a change', () async {
      const defaults = {
        'greeting': 'Hello',
        'enabled': true,
        'limit': 3,
        'ratio': 0.5,
      };
      final lifecycle = await app.run('$_notes$_withParameters$_lifecycle');
      final expected = <String, Object?>{
        'before the start': {
          'values': defaults,
          'calls': <Object?>[],
          'heard': 0,
        },
        // The start activates what the last fetch of the launch before got,
        // and asks the backend nothing yet.
        'the start': {
          'values': {...defaults, 'ratio': 0.25},
          'calls': ['open 1', 'activate 1'],
          'heard': 1,
        },
        // A fetch replaces what the last fetch got, so a parameter that the
        // backend lacks reads its default again.
        'a turn later': {
          'values': {...defaults, 'greeting': 'Hi', 'limit': 7},
          'calls': ['fetch 1', 'activate 1'],
          'heard': 1,
        },
        'a resume that brings nothing new': {
          'values': {...defaults, 'greeting': 'Hi', 'limit': 7},
          'calls': ['fetch 1', 'activate 1'],
          'heard': 0,
        },
        'a resume that brings a new value': {
          'values': {
            ...defaults,
            'greeting': 'Hi',
            'limit': 7,
            'enabled': false,
          },
          'calls': ['fetch 1', 'activate 1'],
          'heard': 1,
        },
        'open': {
          'defaults': {
            'fake_config_user_greeting': 'Hello',
            'fake_config_user_enabled': true,
            'fake_config_user_limit': 3,
            'fake_config_user_ratio': 0.5,
          },
          // No interval in debug mode, so a value changed in the backend
          // shows at the next start.
          'interval': 0,
          'timeout': 10,
        },
        // The service tells of no published values.
        'followed': false,
        'printed': <Object?>[],
      };
      expect(lifecycle, expected);
    });

    test(
        'reads each type, and the default for a text that the type does not '
        'take, which a debug build prints once', () async {
      expect(await app.run('$_notes$_withParameters$_types'), {
        'valid texts': {
          'greeting': 'Hi',
          'enabled': false,
          'limit': 42,
          'ratio': 2.5,
        },
        // An empty text is a text.
        'invalid texts': {
          'greeting': '',
          'enabled': true,
          'limit': 3,
          'ratio': 0.5,
        },
        'printed': [
          _invalidPrinted('fake_config_user_enabled', 'yes', 'bool'),
          _invalidPrinted('fake_config_user_limit', '4.2', 'int'),
          _invalidPrinted('fake_config_user_ratio', 'NaN', 'double'),
        ],
        'printed again': <Object?>[],
        'more texts': {
          'greeting': 'Hello',
          'enabled': true,
          'limit': -8,
          'ratio': 0.5,
        },
        'equal values': [true, true, true, false],
        'defaults': {
          'fake_config_user_greeting': 'Hello',
          'fake_config_user_enabled': true,
          'fake_config_user_limit': 3,
          'fake_config_user_ratio': 0.5,
        },
      });
    });

    test(
        'ends its start within startWait with a service that hangs, and '
        'takes the values once it answers', () async {
      expect(await app.run('$_notes$_withParameters$_hanging'), {
        'the start waited startWait, and no more': true,
        'the values while it hangs': {
          'greeting': 'Hello',
          'enabled': true,
          'limit': 3,
          'ratio': 0.5,
        },
        'the calls while it hangs': ['open 1'],
        'the values once it answers': {
          'greeting': 'Kept',
          'enabled': true,
          'limit': 3,
          'ratio': 0.5,
        },
        'the calls once it answers': [
          'activate 1',
          'fetch 1',
          'activate 1',
        ],
      });
    });

    test(
        'follows the values that the service tells of only where it tells of '
        'them, and once the start is over, and only those of the service of '
        'the last start', () async {
      expect(await app.run('$_notes$_withParameters$_live'), {
        'followed before the fetch of the start': false,
        'followed': true,
        'a published value': {
          'greeting': 'Live',
          'enabled': true,
          'limit': 3,
          'ratio': 0.5,
        },
        // A published value needs no fetch.
        'the calls of a published value': ['activate 1'],
        'the first followed after the next start': false,
        'the second followed': false,
        'a value that the first published after the next start': {
          'greeting': 'Live',
          'enabled': true,
          'limit': 3,
          'ratio': 0.5,
        },
      });
    });

    test(
        'takes the defaults back when it starts again, and drops the calls of '
        'the service before', () async {
      expect(await app.run('$_notes$_withParameters$_restart'), {
        'the first start': {
          'greeting': 'First',
          'enabled': true,
          'limit': 3,
          'ratio': 0.5,
        },
        'the calls of the first': ['open 1', 'activate 1', 'fetch 1'],
        'the values right after the next start began': {
          'greeting': 'Hello',
          'enabled': true,
          'limit': 3,
          'ratio': 0.5,
        },
        'heard right after the next start began': 1,
        'the values once both are done': {
          'greeting': 'Second',
          'enabled': true,
          'limit': 3,
          'ratio': 0.5,
        },
        // The fetch of the first service that was on its way ends, and no
        // other call reaches that service.
        'the calls once both are done': [
          'open 2',
          'activate 2',
          'fetch 2',
          'activate 2',
        ],
      });
    });

    test(
        'keeps its values on an error of the service, prints it, and leaves '
        'no error to the handler of the uncaught errors', () async {
      expect(await app.run('$_notes$_withParameters$_errors'), {
        'the values after a failed fetch': {
          'greeting': 'Kept',
          'enabled': true,
          'limit': 3,
          'ratio': 0.5,
        },
        'the values after a failed activation': {
          'greeting': 'Kept',
          'enabled': true,
          'limit': 3,
          'ratio': 0.5,
        },
        'the values after an error of the updates': {
          'greeting': 'Published',
          'enabled': true,
          'limit': 3,
          'ratio': 0.5,
        },
        // A service that did not open is asked nothing more.
        'the calls of a service that did not open': ['open 2'],
        'the values of a service that did not open': {
          'greeting': 'Hello',
          'enabled': true,
          'limit': 3,
          'ratio': 0.5,
        },
        'printed': [
          _failurePrinted('Bad state: The fetch broke.'),
          _failurePrinted('Bad state: The activation broke.'),
          _failurePrinted('Bad state: The updates broke.'),
          _failurePrinted('Bad state: The opening broke.'),
        ],
        'uncaught': <Object?>[],
      });
    });
  });

  group('the generated controller in an app without parameters', () {
    late DartFiles app;

    setUpAll(() async => app = await _app(parameters: false));

    tearDownAll(() => app.delete());

    test('is code that type-checks', () async {
      expect(await app.analysisProblems(infos: true), isEmpty);
    });

    test(
        'opens the service and makes active what the device kept, but '
        'fetches nothing and follows nothing, also on a resume', () async {
      expect(await app.run('$_notes$_withoutParameters'), {
        'calls': ['open 1', 'activate 1'],
        'followed': false,
        'the values of the service': {'remote_config_role_check': 'Kept'},
        'the values are the defaults': true,
        'defaults': <String, Object?>{},
      });
    });
  });

  group('the generated controller in a release build', () {
    late DartFiles app;

    setUpAll(() async => app = await _app(debug: false));

    tearDownAll(() => app.delete());

    test('prints neither an error nor a text that its type does not take',
        () async {
      expect(await app.run('$_notes$_withParameters$_release'), {
        'the values': {
          'greeting': 'Hello',
          'enabled': true,
          'limit': 3,
          'ratio': 0.5,
        },
        'printed': <Object?>[],
      });
    });
  });

  group('the note of the remote config role for coding agents', () {
    test('names what the files of the role declare', () async {
      final rendered = await _rendered();

      expectNamesOfCode(
        agentNoteOf(remoteConfigRole),
        {
          RemoteConfigRole.controllerFile: [
            'appRemoteConfig',
            'AppRemoteConfigController',
            'AppRemoteConfigController.value',
            'AppRemoteConfigController.start',
            'initRemoteConfig',
            'createRemoteConfigService',
          ],
          RemoteConfigRole.valuesFile: [
            'RemoteValues',
            'RemoteValues.defaults',
          ],
          RemoteConfigRole.serviceFile: ['RemoteConfigService'],
        },
        files: rendered.files,
      );
      expect(
        agentNoteOf(remoteConfigRole).text,
        contains('never put a secret into remote config'),
      );
    });
  });

  group('the section of the remote config role in the README of the app', () {
    test('is under its heading in every app, and names the code of the role',
        () async {
      final rendered = await _rendered();
      final readme = rendered.elsewhere.singleWhere(
        (entry) => entry.socket == AppEntryRole.readmeSections,
      );
      expect(readme.entryKey, RemoteConfigRole.readmeHeading);
      expect(readme.when, isEmpty);
      expectNamesOfCodeIn(
        readme.entryValue! as String,
        {
          RemoteConfigRole.controllerFile: ['appRemoteConfig'],
          RemoteConfigRole.valuesFile: [
            'RemoteValues',
            'RemoteValues.defaults',
            'RemoteValues.fakeConfigUserGreeting',
          ],
        },
        files: rendered.files,
      );
    });

    test(
        'lists each parameter of the app with its type, its getter, its '
        'default, its owner and its description', () {
      final section = _readmeOf([
        ..._data(),
        dataOf(
          remoteConfigRole,
          const RemoteConfigKey.text(
            'update_gate_minimum',
            defaultValue: '',
            description: 'The lowest version',
          ),
          module: 'update_gate',
        ),
      ]);
      expect(
        section,
        contains(
          'The parameters of the app:\n'
          '\n'
          '- `fake_config_user_greeting`, a text read as '
          '`fakeConfigUserGreeting`, by default `Hello`, from the module '
          '`fake_config_user`: The greeting of the fixture\n'
          '- `fake_config_user_enabled`, a Boolean read as '
          '`fakeConfigUserEnabled`, by default `true`, from the module '
          '`fake_config_user`: Whether the fixture is on\n'
          '- `fake_config_user_limit`, a whole number read as '
          '`fakeConfigUserLimit`, by default `3`, from the module '
          '`fake_config_user`: How many the fixture takes\n'
          '- `fake_config_user_ratio`, a number read as `fakeConfigUserRatio`, '
          'by default `0.5`, from the module `fake_config_user`: The ratio of '
          'the fixture\n'
          '- `update_gate_minimum`, a text read as `updateGateMinimum`, by '
          'default empty, from the module `update_gate`: The lowest version\n',
        ),
      );
      expect(
        _readmeOf([
          ..._data(parameters: false),
          remoteConfigRole
              .data(
                const RemoteConfigKey.integer(
                  'remote_config_retries',
                  defaultValue: 2,
                  description: 'How often the role asks again',
                ),
              )
              .withOrigin(const RoleTemplateOrigin(remoteConfigRole)),
        ]),
        contains(
          '- `remote_config_retries`, a whole number read as '
          '`remoteConfigRetries`, by default `2`, from the remote config '
          'role: How often the role asks again\n',
        ),
      );
    });

    test(
        'tells when the values come, that an app without parameters asks the '
        'backend nothing, and that no secret goes there', () {
      final withParameters = _readmeOf(_data());
      final without = _readmeOf(_data(parameters: false));
      for (final section in [withParameters, without]) {
        expect(
          section,
          allOf(
            contains('The values never hold the start of the app.'),
            contains('waits for that at most a second'),
            contains('it starts asking with its first parameter'),
            contains('never put a secret into remote config'),
            contains('`${RemoteConfigRole.valuesFile}`'),
          ),
        );
      }
      expect(without, contains('No module of the app reads a parameter yet.'));
      expect(withParameters, isNot(contains('No module of the app')));
    });
  });

  group('the rules of the remote config role', () {
    const providerFile = 'lib/core/fixture/fake_remote_config_service.dart';
    const screen = 'lib/features/greeter/greeter_screen.dart';
    const ofProvider = ModuleOrigin(ModuleId('fake_remote_config'));
    const ofUser = ModuleOrigin(ModuleId('fake_config_user'));
    const ofDependent = ModuleOrigin(ModuleId('greeter'));
    const ofStranger = ModuleOrigin(ModuleId('stranger'));
    const hint = 'Read the values of remote config from appRemoteConfig of '
        'lib/core/remote_config/app_remote_config.dart, which also exports '
        'RemoteValues.';

    test(
        'let each provider contribute one implementation, and no module put '
        'code into the socket of the implementation', () {
      expect(_moduleIssues(_provider, [_implementation]), isEmpty);
      expect(_moduleIssues(_user, _keys), isEmpty);
      expect(
        _moduleIssues(_provider, const []).single.message,
        contains('exactly one implementation, but the module contributes 0'),
      );
      expect(
        _moduleIssues(_user, [_implementation, ..._keys]).single.message,
        contains('which only its providers do'),
      );
      // A parameter is no implementation.
      expect(
        _moduleIssues(_provider, const [
          _implementation,
          RemoteConfigKey.boolean(
            'fake_remote_config_verbose',
            defaultValue: false,
            description: 'Whether the provider prints more',
          ),
        ]),
        isEmpty,
      );
      final issue = _moduleIssues(
        _provider,
        [_implementation],
        contributions: const [
          SocketContribution.code(
            RemoteConfigRole.implementations,
            Fragment('late RemoteConfigService _remoteConfigService;'),
          ),
        ],
      ).single;
      expect(issue.message, contains('socket remote_config.implementations'));
    });

    test(
        'remote_config.keys: the parameters of a module start with its id, '
        'each once and each with a getter of its own', () {
      final issues = _moduleIssues(_user, const [
        RemoteConfigKey.text(
          'other_greeting',
          defaultValue: '',
          description: 'd',
        ),
        // A name of another form, which has no prefix or getter to check.
        RemoteConfigKey.text('Greeting', defaultValue: '', description: 'd'),
        RemoteConfigKey.text(
          'fake_config_user_greeting',
          defaultValue: '',
          description: 'd',
        ),
        RemoteConfigKey.boolean(
          'fake_config_user_greeting',
          defaultValue: true,
          description: 'd',
        ),
        RemoteConfigKey.integer(
          'fake_config_user_shop1_size',
          defaultValue: 1,
          description: 'd',
        ),
        RemoteConfigKey.integer(
          'fake_config_user_shop_1_size',
          defaultValue: 1,
          description: 'd',
        ),
        RemoteConfigKey.decimal(
          'fake_config_user_ratio',
          defaultValue: double.infinity,
          description: 'd',
        ),
      ]);
      const otherOwner = 'The parameter "other_greeting" does not start with '
          'fake_config_user_, the id of its owner and an underscore.';
      const sameGetter = 'The parameters "fake_config_user_shop1_size" and '
          '"fake_config_user_shop_1_size" would both be read as '
          'RemoteValues.fakeConfigUserShop1Size.';
      const infinite = 'The parameter "fake_config_user_ratio" has the '
          'default Infinity, but a decimal default is a finite number.';
      const otherForm = 'The parameter "Greeting" needs a name in lower '
          'snake_case of two words or more that starts with a letter, such as '
          'update_required_minimum_version.';
      expect(
        [for (final issue in issues) issue.message],
        [
          otherOwner,
          otherForm,
          'Two parameters are named "fake_config_user_greeting".',
          sameGetter,
          infinite,
        ],
      );
      for (final issue in issues) {
        expect(issue.origin, ofUser);
      }
    });

    test(
        'remote_config.factory_calls: a file of a module, or of the template '
        'of another role, that calls createRemoteConfigService() is reported, '
        'with appRemoteConfig as what to use', () {
      final issues = _structureIssues({
        _calling(providerFile, 'createRemoteConfigService'): ofProvider,
        _calling(screen, 'createRemoteConfigService'): ofDependent,
        _calling('lib/core/gate/gate.dart', 'createRemoteConfigService'):
            RoleTemplateOrigin(_otherRole),
        // Another file of the template of the role itself, and files that
        // neither a module nor the template of a role owns.
        _calling(
          'lib/core/remote_config/more.dart',
          'createRemoteConfigService',
        ): const RoleTemplateOrigin(remoteConfigRole),
        _calling('lib/generated.dart', 'createRemoteConfigService'):
            const PipelineOrigin(),
        _calling('lib/mine.dart', 'createRemoteConfigService'): null,
      });

      expect(
        [for (final issue in issues) (issue.path, issue.origin)],
        [
          (providerFile, ofProvider),
          (screen, ofDependent),
          ('lib/core/gate/gate.dart', RoleTemplateOrigin(_otherRole)),
        ],
      );
      for (final issue in issues) {
        expect(
          issue.message,
          '${issue.path} calls createRemoteConfigService(), which no module '
          'may call.',
        );
        expect(issue.hint, hint);
      }
    });

    test(
        'remote_config.factory_calls: only the files of the implementation of '
        'the provider import the file of RemoteConfigService', () {
      const widget = DartFileIndex(
        path: 'lib/fakes/fake_remote_config_widget.dart',
        imports: [
          IndexedImport('../core/remote_config/remote_config_service.dart'),
        ],
      );
      const exporting = DartFileIndex(
        path: 'lib/core/gate/gate.dart',
        exports: [IndexedImport('../remote_config/remote_config_service.dart')],
      );

      final issues = _structureIssues({
        widget: ofProvider,
        exporting: RoleTemplateOrigin(_otherRole),
      });

      expect(
        [for (final issue in issues) issue.path],
        [widget.path, exporting.path],
      );
      for (final issue in issues) {
        expect(
          issue.message,
          '${issue.path} imports ${RemoteConfigRole.serviceFile}, the file of '
          'RemoteConfigService, which only the files of the implementation of '
          'the provider of the remote config role import.',
        );
        expect(issue.hint, hint);
      }
    });

    test(
        'remote_config.start_calls: only bootstrap() calls '
        'initRemoteConfig(), and no module calls appRemoteConfig.start()', () {
      const startHint = 'The role starts remote config in bootstrap(), before '
          'the first frame. Read the values from appRemoteConfig.';
      const starting = DartFileIndex(
        path: screen,
        imports: [
          IndexedImport(
            'package:my_app/core/remote_config/app_remote_config.dart',
          ),
        ],
        invocations: [IndexedInvocation('start', target: 'appRemoteConfig')],
      );
      final issues = _structureIssues({
        _calling(AppEntryRole.bootstrapFile, 'initRemoteConfig'): null,
        _calling(providerFile, 'initRemoteConfig'): ofProvider,
        starting: ofDependent,
      });

      expect(
        [for (final issue in issues) (issue.message, issue.hint)],
        [
          (
            '$providerFile calls initRemoteConfig(), which only bootstrap() '
                'calls.',
            startHint,
          ),
          (
            '$screen calls appRemoteConfig.start(), which only '
                'initRemoteConfig() calls.',
            startHint,
          ),
        ],
      );
    });

    test(
        'remote_config.implementation_factories: the function of the '
        'implementation is in its file and takes no arguments', () {
      final missing = remoteConfigRole.checkStructure(
        StructuralRuleRequest(
          hook: RoleHookRequest(
            data: _data(),
            presentRoles: {remoteConfigRole},
            context: testContext,
          ),
          files: const {
            'lib/fakes/fake_remote_config.dart':
                DartFileIndex(path: 'lib/fakes/fake_remote_config.dart'),
          },
        ),
      );
      expect(
        missing.single.message,
        contains('does not declare function createFakeRemoteConfig()'),
      );
    });

    test(
        'remote_config.key_access: a module reads its own parameters and those '
        'of the modules it depends on, and the template of a role its own', () {
      final issues = _structureIssues({
        // The module of the parameters, and a module that depends on it.
        _reading('lib/core/fixture/values.dart', 'fakeConfigUserGreeting'):
            ofUser,
        _reading(screen, 'fakeConfigUserLimit'): ofDependent,
        // A module that does not depend on it, the template of another role
        // and a variant of a module that does not either.
        _reading('lib/features/stranger/stranger.dart', 'fakeConfigUserRatio'):
            ofStranger,
        _reading('lib/core/gate/gate.dart', 'fakeConfigUserEnabled'):
            RoleTemplateOrigin(_otherRole),
        _reading('lib/features/stranger/bloc.dart', 'fakeConfigUserLimit'):
            const ModuleOrigin(
          ModuleId('stranger'),
          variant: ModuleId('fake_bloc'),
        ),
        // A member of another name, and a module without the role, whose
        // import of the files of the role the harness reports.
        _reading('lib/features/stranger/other.dart', 'length'): ofStranger,
        _reading('lib/features/outsider/outsider.dart', 'fakeConfigUserLimit'):
            const ModuleOrigin(ModuleId('outsider')),
        _reading('lib/mine.dart', 'fakeConfigUserLimit'): null,
        // A module that the app does not have, which has no roles to tell
        // by, and a file of the pipeline, which reads no parameter.
        _reading('lib/features/ghost/ghost.dart', 'fakeConfigUserLimit'):
            const ModuleOrigin(ModuleId('ghost')),
        _reading('lib/generated.dart', 'fakeConfigUserGreeting'):
            const PipelineOrigin(),
      });

      expect(
        [for (final issue in issues) (issue.message, issue.origin)],
        [
          (
            'lib/features/stranger/stranger.dart reads '
                'appRemoteConfig.value.fakeConfigUserRatio, the parameter '
                'fake_config_user_ratio of the module fake_config_user, but '
                'the module stranger may only read its own parameters and '
                'those of the modules it depends on.',
            ofStranger,
          ),
          (
            'lib/core/gate/gate.dart reads '
                'appRemoteConfig.value.fakeConfigUserEnabled, the parameter '
                'fake_config_user_enabled of the module fake_config_user, but '
                'the template of the gate role may only read its own '
                'parameters.',
            RoleTemplateOrigin(_otherRole),
          ),
          (
            'lib/features/stranger/bloc.dart reads '
                'appRemoteConfig.value.fakeConfigUserLimit, the parameter '
                'fake_config_user_limit of the module fake_config_user, but '
                'the module stranger may only read its own parameters and '
                'those of the modules it depends on.',
            ofStranger,
          ),
          (
            'lib/generated.dart reads '
                'appRemoteConfig.value.fakeConfigUserGreeting, the parameter '
                'fake_config_user_greeting of the module fake_config_user, '
                'but the pipeline may only read its own parameters.',
            const PipelineOrigin(),
          ),
        ],
      );
      for (final issue in issues) {
        expect(issue.hint, 'Give the role a parameter of your own.');
      }

      // An app without parameters has no getter to read.
      expect(
        remoteConfigRole.checkStructure(
          StructuralRuleRequest(
            hook: RoleHookRequest(
              data: _data(parameters: false),
              presentRoles: {remoteConfigRole},
              context: testContext,
            ),
            files: {
              _factoryFile.path: _factoryFile,
              screen: _reading(screen, 'fakeConfigUserLimit'),
            },
            owners: {
              _factoryFile.path: ModuleOrigin(_provider.id),
              screen: ofStranger,
            },
            modules: const [_provider, _stranger],
          ),
        ),
        isEmpty,
      );
    });
  });
}
