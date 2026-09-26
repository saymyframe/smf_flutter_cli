@TestOn('vm')
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contracts/lego.dart';
import 'package:smf_event_bus/smf_event_bus.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_get_it/smf_get_it.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'support/dart_app.dart';

/// The modules of the tests: flutter_core, which creates the app, this
/// module, and get_it, a DI container, which registers the service in the
/// apps that have it.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  EventBusModule(),
  GetItModule(),
];

/// The path of the file of the module.
const _implementation = 'lib/core/events/event_bus_communication_service.dart';

/// The owners of the code of the events: the template of the role and this
/// module.
final Set<ContributionOrigin> _events = {
  const RoleTemplateOrigin(eventsRole),
  const ModuleOrigin(EventBusModule.id),
};

/// What the contract harness finds for the app of [modules], which has no
/// errors and is rendered.
Future<ContractResult> _resultOf(List<ModuleId> modules) async {
  final result = await ContractHarness(ModuleRegistry(_modules)).check(
    ContractCase(modules.join(', '), requested: modules),
  );
  if (result.errors.isNotEmpty || result.app == null) {
    throw StateError(
      'The app of $modules has errors: ${result.errors.join('\n')}',
    );
  }
  return result;
}

/// The pubspec [text] as plain maps and lists.
Map<String, Object?> _yamlOf(String text) {
  Object? plain(Object? node) => switch (node) {
        final YamlMap map => {
            for (final MapEntry(:key, :value) in map.entries)
              '$key': plain(value),
          },
        final YamlList list => [for (final item in list) plain(item)],
        _ => node,
      };
  return plain(loadYaml(text))! as Map<String, Object?>;
}

/// The pubspec of [app] without the dependency on event_bus.
Map<String, Object?> _pubspecWithoutEventBus(RenderedApp app) {
  final pubspec = _yamlOf(app.files['pubspec.yaml']!.text);
  final dependencies = {
    ...pubspec['dependencies']! as Map<String, Object?>,
  }..remove('event_bus');
  return {...pubspec, 'dependencies': dependencies};
}

/// Checks that [app] is [without] but for the files of the events, the
/// dependency on event_bus, and the files at [changed].
void _expectTheAppWithout(
  RenderedApp app,
  RenderedApp without, {
  Set<String> changed = const {},
}) {
  expect(
    app.files.keys.toSet(),
    {...without.files.keys, EventsRole.file, _implementation},
  );
  expect(
    app.files[EventsRole.file]!.owner,
    const RoleTemplateOrigin(eventsRole),
  );
  expect(
    app.files[_implementation]!.owner,
    const ModuleOrigin(EventBusModule.id),
  );
  for (final MapEntry(key: path, value: file) in without.files.entries) {
    if (path == 'pubspec.yaml' || changed.contains(path)) continue;
    expect(app.files[path]!.bytes, file.bytes, reason: path);
    expect(app.files[path]!.owner, file.owner, reason: path);
  }
  expect(
    _pubspecWithoutEventBus(app),
    _yamlOf(without.files['pubspec.yaml']!.text),
  );
}

/// Sends events of several types through the service of the app and sends
/// back who got which, the service, and what listeners had got before the
/// code that fired the events completed.
///
/// It imports only the file of the events role, which needs nothing but
/// Dart and event_bus.
const _script = r'''
import 'dart:isolate';

import 'package:contract_app/core/events/communication_service.dart';

final class Ping extends AppEvent {
  const Ping(this.count);

  final int count;
}

final class LoudPing extends Ping {
  const LoudPing(super.count);
}

final class Pong extends AppEvent {
  const Pong();
}

Future<void> main(List<String> arguments, SendPort port) async {
  final service = createCommunicationService();
  final got = <String, List<String>>{
    'pings': [],
    'pings again': [],
    'pongs': [],
    'all': [],
    'late': [],
  };
  void listen<T extends AppEvent>(String listener) => service
      .on<T>()
      .listen((event) => got[listener]!.add(describe(event)));

  listen<Ping>('pings');
  listen<Ping>('pings again');
  listen<Pong>('pongs');
  listen<AppEvent>('all');
  service
    ..fire(const Ping(1))
    ..fire(const Pong())
    ..fire(const LoudPing(2));
  listen<AppEvent>('late');
  final beforeDelivery = [for (final events in got.values) ...events];
  await Future<void>.delayed(Duration.zero);
  service.fire(const Pong());
  await Future<void>.delayed(Duration.zero);
  port.send({
    'one service': identical(createCommunicationService(), service),
    'implementation': '${service.runtimeType}',
    'before delivery': beforeDelivery,
    ...got,
  });
}

String describe(AppEvent event) => switch (event) {
      Ping(:final count) => '${event.runtimeType} $count',
      _ => '${event.runtimeType}',
    };
''';

void main() {
  const module = EventBusModule();

  group('EventBusModule', () {
    test('is infrastructure that provides the events role', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('event_bus'));
      expect(descriptor.kind, ModuleKinds.infrastructure);
      expect(descriptor.provides, {eventsRole});
      expect(descriptor.dependsOn, isEmpty);
      expect(descriptor.requires, isEmpty);
      expect(descriptor.uses, isEmpty);
      expect(descriptor.variants, isNull);
    });

    test('forms a valid registry with the modules of the tests', () {
      expect(ModuleRegistry.problemsOf(_modules), isEmpty);
    });

    test(
        'contributes its brick, event_bus and its implementation of the '
        'service, created without waiting, and nothing else', () {
      final contributions = module.contribute(ContractHarness.defaultContext);

      expect(contributions, hasLength(3));
      expect(
        (contributions[0] as BrickContribution).bundle.name,
        'event_bus',
      );
      final dependency = contributions[1] as PubspecDependency;
      expect(dependency.package, 'event_bus');
      expect(dependency.constraint, '^2.0.1');
      expect(dependency.dev, isFalse);
      final data = contributions[2] as RoleData<Object>;
      expect(data.role, eventsRole);
      final implementation = data.value as RoleImplementation;
      expect(implementation.isAsync, isFalse);
      expect(implementation.type.name, 'EventBusCommunicationService');
      expect(implementation.create!.name, 'createEventBusCommunicationService');
      expect(implementation.create!.deps, isEmpty);
      expect(
        implementation.type.import,
        const ImportRef.app('core/events/event_bus_communication_service.dart'),
      );
      expect(implementation.create!.import, implementation.type.import);
    });

    test('adds to apps the event_bus that its tests run with', () {
      final dependency = module
          .contribute(ContractHarness.defaultContext)
          .whereType<PubspecDependency>()
          .single;
      final pubspec = _yamlOf(File('pubspec.yaml').readAsStringSync());

      expect(
        (pubspec['dev_dependencies']! as Map<String, Object?>)['event_bus'],
        dependency.constraint,
      );
    });
  });

  group('the contract harness', () {
    late List<ContractResult> results;

    setUpAll(() async {
      results = await ContractHarness(ModuleRegistry(_modules)).checkAll();
    });

    test('builds the apps of the events with a DI container and without', () {
      expect(results.map((result) => result.contractCase.name), [
        'flutter_core',
        'event_bus with di',
        'event_bus',
        'get_it',
      ]);
    });

    test('finds no errors in any app, rendered code included', () {
      for (final result in results) {
        expect(
          result.errors.map((issue) => '$issue'),
          isEmpty,
          reason: '${result.contractCase}',
        );
        expect(result.app, isNotNull, reason: '${result.contractCase}');
      }
    });

    test('renders code of the events that type-checks with event_bus',
        () async {
      final withEvents = [
        for (final result in results)
          if (result.app!.files.containsKey(_implementation)) result,
      ];
      expect(withEvents, hasLength(2));
      for (final result in withEvents) {
        final app = await DartApp.write(result.app!);
        try {
          expect(
            await app.analysisProblems(_events),
            isEmpty,
            reason: '${result.contractCase}',
          );
        } finally {
          app.delete();
        }
      }
    });
  });

  group('an app without a DI container', () {
    late RenderedApp withEvents;
    late RenderedApp without;

    setUpAll(() async {
      withEvents = (await _resultOf(const [EventBusModule.id])).app!;
      without = (await _resultOf(const [FlutterCoreModule.id])).app!;
    });

    test(
        'is the app without the events but for the service, its '
        'implementation and event_bus', () {
      _expectTheAppWithout(withEvents, without);
      expect(
        _yamlOf(withEvents.files['pubspec.yaml']!.text)['dependencies'],
        {
          'event_bus': '^2.0.1',
          'flutter': {'sdk': 'flutter'},
        },
      );
    });

    test(
        'returns the implementation of event_bus from the service, created '
        'on first use', () {
      final file = withEvents.files[EventsRole.file]!;
      final unit = parseString(content: file.text).unit;

      final variable = unit.declarations
          .whereType<TopLevelVariableDeclaration>()
          .single
          .variables;
      expect(variable.toSource(), startsWith('final CommunicationService '));
      expect(
        variable.variables.single.initializer!.toSource(),
        'impl0.createEventBusCommunicationService()',
      );
      expect(
        [
          for (final added in file.addedImports)
            (added.import.uri, added.import.prefix, '${added.contributor}'),
        ],
        [
          (
            'package:contract_app/core/events/'
                'event_bus_communication_service.dart',
            'impl0',
            'role:events',
          ),
        ],
      );
      // Nothing to await: bootstrap() is that of the app without it.
      expect(
        unit.declarations
            .whereType<FunctionDeclaration>()
            .map((function) => function.name.lexeme),
        ['createCommunicationService'],
      );
    });

    test(
        'delivers an event to everyone listening to its type, or to a type '
        'it extends, after the code that fires it', () async {
      final app = await DartApp.write(withEvents);
      final Map<Object?, Object?> result;
      try {
        result = (await app.run(_script))! as Map<Object?, Object?>;
      } finally {
        app.delete();
      }

      expect(result, {
        'one service': true,
        'implementation': 'EventBusCommunicationService',
        // Listeners get the events after the code that fires them.
        'before delivery': <Object?>[],
        'pings': ['Ping 1', 'LoudPing 2'],
        'pings again': ['Ping 1', 'LoudPing 2'],
        'pongs': ['Pong', 'Pong'],
        'all': ['Ping 1', 'Pong', 'LoudPing 2', 'Pong'],
        // A listener gets only the events fired after it started.
        'late': ['Pong'],
      });
    });
  });

  group('an app with a DI container', () {
    late ContractResult result;
    late RenderedApp withEvents;
    late RenderedApp without;

    setUpAll(() async {
      result = await _resultOf(const [EventBusModule.id, GetItModule.id]);
      withEvents = result.app!;
      without = (await _resultOf(const [GetItModule.id])).app!;
    });

    test(
        'is the app of the container without the events but for the service, '
        'its implementation, event_bus and the registration', () {
      _expectTheAppWithout(
        withEvents,
        without,
        changed: const {DiRole.dependenciesFile},
      );
    });

    test('registers the service in the container, which creates it', () {
      final registrations = [
        for (final data in result.collection!.roleData)
          if (identical(data.role, diRole) &&
              data.origin == const RoleTemplateOrigin(eventsRole))
            data.value as DiRegistration,
      ];
      expect(registrations, hasLength(1));
      final registration = registrations.single;
      expect(registration.type.name, 'CommunicationService');
      expect(registration.create.name, 'createCommunicationService');
      expect(registration.create.deps, isEmpty);
      expect(registration.lifetime, DiLifetime.lazySingleton);

      final container = withEvents.files[DiRole.dependenciesFile]!;
      final calls = DartFileIndexer.index(container.path, container.text)
          .invocations
          .where((call) => call.name == 'createCommunicationService');
      expect(calls, hasLength(1));
      expect(
        calls.single.enclosingDeclaration,
        DiRole.registerDependencies.name,
      );
    });
  });
}
