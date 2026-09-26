@TestOn('vm')
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contracts/lego.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_get_it/smf_get_it.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'support/dart_app.dart';
import 'support/services.dart';

/// The path of the file of the module.
const String _dependencies = DiRole.dependenciesFile;

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

/// The parsed file of the module in [app].
CompilationUnit _dependenciesOf(RenderedApp app) =>
    parseString(content: app.files[_dependencies]!.text).unit;

/// The top-level function [name] of [unit].
FunctionDeclaration _function(CompilationUnit unit, String name) =>
    unit.declarations
        .whereType<FunctionDeclaration>()
        .singleWhere((function) => function.name.lexeme == name);

/// The statements of `registerDependencies()` in [unit].
List<Statement> _registrationsOf(CompilationUnit unit) =>
    (_function(unit, 'registerDependencies').functionExpression.body
            as BlockFunctionBody)
        .block
        .statements;

/// The registration [statement] as its method and the types it registers,
/// such as `registerSingleton<di0.ApiConfig>`; a statement that is not a
/// call is itself.
String _registration(Statement statement) => switch (statement) {
      ExpressionStatement(expression: final MethodInvocation call) =>
        '${call.methodName.name}${call.typeArguments}',
      _ => statement.toSource(),
    };

/// [code] as the analyzer prints it, to compare code without its layout.
String _source(String code) =>
    parseString(content: code).unit.declarations.single.toSource();

/// `registerDependencies()` of the app of the services of both modules: the
/// services in the order of their graph, each after what it takes or waits
/// for, the singletons that wait for services created asynchronously or
/// waiting themselves registered with the services they wait for, a named
/// one by an `InitDependency`, and a wait for all at the end.
final String _expectedRegistrations = _source('''
Future<void> registerDependencies() async {
  final getIt = GetIt.instance;
  getIt.registerSingleton<di0.ApiConfig>(di0.createApiConfig());
  getIt.registerSingletonAsync<di1.Database>(
    () => di1.openDatabase(getIt<di0.ApiConfig>()),
  );
  getIt.registerSingletonWithDependencies<di1.Store>(
    () => di1.createStore(getIt<di1.Database>()),
    dependsOn: [di1.Database],
  );
  getIt.registerLazySingleton<di0.Clock>(
    () => di0.createUtcClock(),
    instanceName: 'utc',
  );
  getIt.registerLazySingleton<di1.Repository>(
    () => di1.createRepository(
      getIt<di1.Store>(),
      getIt<di0.Clock>(instanceName: 'utc'),
    ),
  );
  getIt.registerSingletonWithDependencies<di1.Sync>(
    () => di1.startSync(getIt<di1.Repository>()),
    dependsOn: [di1.Store],
    dispose: di1.stopSync,
  );
  getIt.registerFactoryParam<di1.Report, String, int>(
    (param1, param2) =>
        di1.createReport(getIt<di1.Repository>(), param1, param2),
  );
  getIt.registerSingletonAsync<di1.Session>(
    () => di1.openSession(),
    dispose: di1.closeSession,
  );
  getIt.registerSingletonAsync<di1.Session>(
    () => di1.openBackupSession(),
    instanceName: 'backup',
    dispose: di1.closeSession,
  );
  getIt.registerLazySingleton<di0.ApiClient>(
    () => di0.createApiClient(getIt<di0.ApiConfig>()),
    dispose: di0.closeApiClient,
  );
  getIt.registerSingletonWithDependencies<di1.Cache>(
    () => di1.createCache(getIt<di0.ApiClient>()),
    dependsOn: [di1.Session],
    dispose: di1.closeCache,
  );
  getIt.registerSingletonWithDependencies<di1.Cache>(
    () => di1.createBackupCache(getIt<di0.ApiClient>()),
    instanceName: 'backup',
    dependsOn: [InitDependency(di1.Session, instanceName: 'backup')],
    dispose: di1.closeCache,
  );
  getIt.registerSingletonAsync<di1.Mirror>(
    () => di1.openMirror(),
    dependsOn: [InitDependency(di1.Session, instanceName: 'backup')],
  );
  getIt.registerLazySingleton<di2.Random>(() => di1.createRandom());
  getIt.registerSingleton<di0.Endpoint>(
    di0.createEndpoint(getIt<di0.ApiConfig>()),
    dispose: di0.closeEndpoint,
  );
  getIt.registerSingleton<di0.ApiConfig>(
    di0.createStagingConfig(),
    instanceName: 'staging',
  );
  getIt.registerLazySingleton<di0.Clock>(() => di0.createLocalClock());
  getIt.registerFactory<di0.Token>(
    () => di0.createToken(getIt<di0.ApiConfig>()),
  );
  getIt.registerFactory<di0.Token>(
    () => di0.createRefreshToken(getIt<di0.ApiConfig>(instanceName: 'staging')),
    instanceName: 'refresh',
  );
  getIt.registerFactoryParam<di0.Request, String, void>(
    (param1, _) => di0.createRequest(getIt<di0.ApiClient>(), param1),
  );
  await getIt.allReady();
}
''');

/// Runs `registerDependencies()` of the app of the services of both
/// modules, resolves services of each kind, by name too, and with one and
/// two parameters, resets get_it, and sends what the functions of the
/// services did at each stage and what the services were.
///
/// It imports the files of the DI role and of the services only, not those
/// of the app entry, which may need Flutter.
const _script = '''
import 'dart:isolate';
import 'dart:math';

import 'package:contract_app/core/di/dependencies.dart';
import 'package:contract_app/core/di/service_locator.dart';
import 'package:contract_app/core/network/network.dart';
import 'package:contract_app/core/storage/storage.dart';
import 'package:get_it/get_it.dart';

Future<void> main(List<String> arguments, SendPort port) async {
  await registerDependencies();
  final ready = [...events];
  events.clear();
  final sync = resolve<Sync>();
  final report = resolveWith<Report>('Weekly', 3);
  final request = resolveWith<Request>('/items');
  final services = <String, Object?>{
    'one singleton': identical(resolve<Sync>(), sync),
    'one lazy singleton': identical(resolve<Repository>(), sync.repository),
    'a new instance of a factory':
        !identical(resolve<Token>(), resolve<Token>()),
    'report': [
      report.title,
      report.pages,
      identical(report.repository, sync.repository),
    ],
    'request': [request.path, identical(request.client, resolve<ApiClient>())],
    'configs': [
      resolve<ApiConfig>().host,
      resolve<ApiConfig>(instanceName: 'staging').host,
    ],
    'tokens': [
      resolve<Token>().config.host,
      resolve<Token>(instanceName: 'refresh').config.host,
    ],
    'clocks': [
      resolve<Clock>(instanceName: 'utc').zone,
      resolve<Clock>().zone,
    ],
    'sessions': [
      resolve<Session>().name,
      resolve<Session>(instanceName: 'backup').name,
    ],
    'caches': [
      resolve<Cache>().name,
      resolve<Cache>(instanceName: 'backup').name,
    ],
    'one random': identical(resolve<Random>(), resolve<Random>()),
  };
  final resolved = [...events];
  events.clear();
  await GetIt.instance.reset();
  port.send({
    'ready': ready,
    'resolved': resolved,
    'services': services,
    'disposed': [...events],
  });
}
''';

/// A module for the tests that registers [registrations], which get_it
/// cannot register, with the functions of [code] in its file.
final class _Unregistrable extends SmfModule {
  const _Unregistrable(this.registrations, this.code);

  static const id = ModuleId('unregistrable');

  static const file = ImportRef.app('core/unregistrable/unregistrable.dart');

  final List<DiRegistration> registrations;

  final String code;

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Services that get_it cannot register (test)',
        kind: ModuleKinds.infrastructure,
        requires: {diRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          bundleOf('unregistrable', {'lib/${file.uri}': code}),
        ),
        for (final registration in registrations) diRole.data(registration),
      ];
}

void main() {
  const module = GetItModule();

  group('GetItModule', () {
    test('is infrastructure that provides the DI role', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('get_it'));
      expect(descriptor.kind, ModuleKinds.infrastructure);
      expect(descriptor.provides, {diRole});
      expect(descriptor.dependsOn, isEmpty);
      expect(descriptor.requires, isEmpty);
      expect(descriptor.uses, isEmpty);
      expect(descriptor.variants, isNull);
    });

    test('registers services with every capability of the DI role', () {
      final provider = module.descriptor.providers.single as DiProvider;

      expect(provider.capabilities, DiCapability.values.toSet());
    });

    test('forms a valid registry with the modules of the tests', () {
      expect(ModuleRegistry.problemsOf(testModules), isEmpty);
    });

    test('adds to apps the get_it that its tests run with', () {
      final dependency = module
          .contribute(ContractHarness.defaultContext)
          .whereType<PubspecDependency>()
          .single;
      final pubspec = _yamlOf(File('pubspec.yaml').readAsStringSync());

      expect(dependency.package, 'get_it');
      expect(dependency.dev, isFalse);
      expect(
        (pubspec['dev_dependencies']! as Map<String, Object?>)['get_it'],
        dependency.constraint,
      );
    });
  });

  group('the contract harness', () {
    late List<ContractResult> results;

    setUpAll(() async {
      results = await ContractHarness(ModuleRegistry(testModules)).checkAll();
    });

    test('builds the apps of the container with services and without', () {
      expect(results.map((result) => result.contractCase.name), [
        'flutter_core',
        'get_it',
        'network',
        'storage',
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

    test('renders apps whose code type-checks with get_it', () async {
      for (final result in results) {
        final app = await DartApp.write(result.app!);
        try {
          expect(
            await app.analysisProblems(),
            isEmpty,
            reason: '${result.contractCase}',
          );
        } finally {
          app.delete();
        }
      }
    });
  });

  group('an app without services', () {
    late ContractResult result;
    late RenderedApp withContainer;
    late RenderedApp without;

    setUpAll(() async {
      result = await renderedApp(const [GetItModule.id]);
      withContainer = result.app!;
      without = (await renderedApp(const [FlutterCoreModule.id])).app!;
    });

    test('gets get_it and the brick of the container, and nothing else', () {
      final contributions = [
        for (final collected
            in result.collection!.ofModule(module.descriptor.id))
          collected.contribution,
      ];

      expect(contributions, hasLength(2));
      expect((contributions.first as BrickContribution).bundle.name, 'get_it');
      final dependency = contributions.last as PubspecDependency;
      expect(dependency.package, 'get_it');
      expect(dependency.constraint, '^9.3.0');
      expect(
        _yamlOf(withContainer.files['pubspec.yaml']!.text)['dependencies'],
        {
          'flutter': {'sdk': 'flutter'},
          'get_it': '^9.3.0',
        },
      );
    });

    test('registers nothing and finds the services in get_it', () {
      final unit = _dependenciesOf(withContainer);

      expect(_registrationsOf(unit), isEmpty);
      expect(withContainer.files[_dependencies]!.addedImports, isEmpty);
      expect(
        _function(unit, 'createServiceLocator').toSource(),
        'ServiceLocator createServiceLocator() => '
        '_GetItServiceLocator(GetIt.instance);',
      );
      final locator =
          unit.declarations.whereType<ClassDeclaration>().singleWhere(
                (declaration) =>
                    declaration.name.lexeme == '_GetItServiceLocator',
              );
      String bodyOf(String method) => locator.members
          .whereType<MethodDeclaration>()
          .singleWhere((declaration) => declaration.name.lexeme == method)
          .body
          .toSource();
      expect(bodyOf('resolve'), '=> _getIt<T>(instanceName: instanceName);');
      expect(
        bodyOf('resolveWith'),
        '=> _getIt<T>(param1: param1, param2: param2);',
      );
    });

    test('awaits the registration of the services in bootstrap()', () {
      final bootstrap = withContainer.files['lib/bootstrap.dart']!;

      expect(
        bootstrap.text,
        contains('await ${DiRole.registerDependencies.name}();'),
      );
      expect(
        bootstrap.addedImports.map(
          (added) => (added.import.uri, '${added.contributor}'),
        ),
        [('package:contract_app/core/di/dependencies.dart', 'role:di')],
      );
    });

    test('is the app without a container but for the container', () {
      expect(
        withContainer.files.keys.toSet(),
        {
          ...without.files.keys,
          DiRole.serviceLocatorFile,
          DiRole.dependenciesFile,
        },
      );
      expect(
        withContainer.files[_dependencies]!.owner,
        const ModuleOrigin(GetItModule.id),
      );
      for (final MapEntry(key: path, value: file) in without.files.entries) {
        if (const {'pubspec.yaml', 'lib/bootstrap.dart'}.contains(path)) {
          continue;
        }
        expect(withContainer.files[path]!.bytes, file.bytes, reason: path);
      }
      final pubspec = _yamlOf(withContainer.files['pubspec.yaml']!.text);
      final dependencies = {
        ...pubspec['dependencies']! as Map<String, Object?>,
      }..remove('get_it');
      expect(
        {...pubspec, 'dependencies': dependencies},
        _yamlOf(without.files['pubspec.yaml']!.text),
      );
    });
  });

  group('an app with services', () {
    late RenderedApp app;
    late CompilationUnit unit;

    setUpAll(() async {
      app = (await renderedApp(const [StorageModule.id])).app!;
      unit = _dependenciesOf(app);
    });

    test(
        'registers every service in the order of their graph, in the form '
        'of get_it for what it needs', () {
      expect(
        _function(unit, 'registerDependencies').toSource(),
        _expectedRegistrations,
      );
    });

    test('imports the file of each type and function once, with a prefix', () {
      expect(
        [
          for (final added in app.files[_dependencies]!.addedImports)
            (added.import.uri, added.import.prefix, '${added.contributor}'),
        ],
        [
          (
            'package:contract_app/$networkFile',
            'di0',
            '${GetItModule.id}',
          ),
          (
            'package:contract_app/$storageFile',
            'di1',
            '${GetItModule.id}',
          ),
          ('dart:math', 'di2', '${GetItModule.id}'),
        ],
      );
    });

    test('waits for nothing without services created asynchronously', () async {
      final network = _dependenciesOf(
        (await renderedApp(const [NetworkModule.id])).app!,
      );

      final statements = _registrationsOf(network);
      expect(
        statements.first.toSource(),
        'final getIt = GetIt.instance;',
      );
      // No singleton waits, and nothing waits for them all.
      expect(statements.skip(1).map(_registration), [
        'registerSingleton<di0.ApiConfig>',
        'registerSingleton<di0.Endpoint>',
        'registerSingleton<di0.ApiConfig>',
        'registerLazySingleton<di0.ApiClient>',
        'registerLazySingleton<di0.Clock>',
        'registerLazySingleton<di0.Clock>',
        'registerFactory<di0.Token>',
        'registerFactory<di0.Token>',
        'registerFactoryParam<di0.Request, String, void>',
      ]);
    });

    test(
        'runs in the order of its graph with get_it: the services that '
        'singletons wait for are ready first, registerDependencies() waits '
        'for all, and reset disposes of them in the reverse order', () async {
      final dart = await DartApp.write(app);
      final Map<Object?, Object?> result;
      try {
        result = (await dart.run(_script))! as Map<Object?, Object?>;
      } finally {
        dart.delete();
      }
      final ready = [...result['ready']! as List<Object?>];
      bool before(String first, String second) =>
          ready.indexOf(first) < ready.indexOf(second);

      // The waiting that registerDependencies() does: every service that
      // is created asynchronously, or waits, is ready when it completes,
      // while lazy singletons and factories wait for use.
      expect(ready.toSet(), {
        'create ApiConfig',
        'create Endpoint',
        'create staging ApiConfig',
        'open Database',
        'opened Database',
        'create Store',
        'create utc Clock',
        'create Repository',
        'start Sync',
        'open main Session',
        'opened main Session',
        'create ApiClient',
        'create main Cache',
        'open backup Session',
        'opened backup Session',
        'create backup Cache',
        'open Mirror',
      });
      expect(ready, hasLength(17));
      // Each after what it takes or waits for.
      expect(before('create ApiConfig', 'create Endpoint'), isTrue);
      expect(before('opened Database', 'create Store'), isTrue);
      expect(before('create Store', 'create Repository'), isTrue);
      expect(before('create Repository', 'start Sync'), isTrue);
      expect(before('opened main Session', 'create main Cache'), isTrue);
      expect(before('opened backup Session', 'create backup Cache'), isTrue);
      expect(before('opened backup Session', 'open Mirror'), isTrue);

      expect(result['resolved'], [
        'create Report Weekly',
        'create Request /items',
        'create Token',
        'create Token',
        'create Token',
        'create refresh Token',
        'create Clock',
        'create Random',
      ]);
      expect(result['services'], {
        'one singleton': true,
        'one lazy singleton': true,
        'a new instance of a factory': true,
        'report': ['Weekly', 3, true],
        'request': ['/items', true],
        'configs': ['example.com', 'staging.example.com'],
        'tokens': ['example.com', 'staging.example.com'],
        'clocks': ['UTC', 'local'],
        'sessions': ['main', 'backup'],
        'caches': ['main', 'backup'],
        'one random': true,
      });
      // The reverse order of registration: what a service takes is
      // disposed of after it.
      expect(result['disposed'], [
        'close Endpoint',
        'close backup Cache',
        'close main Cache',
        'close ApiClient',
        'close backup Session',
        'close main Session',
        'stop Sync',
      ]);
    });
  });

  group('services that get_it cannot register stop the generation', () {
    Future<List<String>> errorsOf(
      List<DiRegistration> registrations,
      String code,
    ) async {
      final result = await ContractHarness(
        ModuleRegistry([
          const FlutterCoreModule(),
          module,
          _Unregistrable(registrations, code),
        ]),
      ).check(
        const ContractCase('unregistrable', requested: [_Unregistrable.id]),
      );
      expect(result.app, isNull);
      return [for (final issue in result.errors) issue.message];
    }

    const a = TypeRef('A', import: _Unregistrable.file);
    const b = TypeRef('B', import: _Unregistrable.file);

    test('services that need each other', () async {
      expect(
        await errorsOf(
          const [
            DiRegistration(
              type: a,
              create: FactoryRef(
                'createA',
                import: _Unregistrable.file,
                deps: [ServiceRef(b)],
              ),
            ),
            DiRegistration(
              type: b,
              create: FactoryRef(
                'createB',
                import: _Unregistrable.file,
                deps: [ServiceRef(a)],
              ),
            ),
          ],
          '''
final class A {}

final class B {}

A createA(B b) => A();

B createB(A a) => B();
''',
        ),
        [contains('need each other in a cycle')],
      );
    });

    test(
        'a singleton that waits for a service that get_it cannot wait for, '
        'which it would reject as it registers it', () async {
      expect(
        await errorsOf(
          const [
            DiRegistration(
              type: a,
              create: FactoryRef('createA', import: _Unregistrable.file),
            ),
            DiRegistration(
              type: b,
              create: FactoryRef('createB', import: _Unregistrable.file),
              lifetime: DiLifetime.singleton,
              dependsOn: [ServiceRef(a)],
            ),
          ],
          '''
final class A {}

final class B {}

A createA() => A();

B createB() => B();
''',
        ),
        [contains('which is not a singleton created asynchronously')],
      );
    });

    test('a factory with a function that disposes of it', () async {
      expect(
        await errorsOf(
          const [
            DiRegistration(
              type: a,
              create: FactoryRef('createA', import: _Unregistrable.file),
              lifetime: DiLifetime.factory,
              dispose: FunctionRef('closeA', import: _Unregistrable.file),
            ),
          ],
          '''
final class A {}

A createA() => A();

void closeA(A a) {}
''',
        ),
        [contains('the container does not keep to dispose of')],
      );
    });
  });
}
