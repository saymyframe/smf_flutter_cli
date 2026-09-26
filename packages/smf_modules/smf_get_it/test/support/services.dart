import 'dart:convert';

import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
import 'package:smf_contracts/lego.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_get_it/smf_get_it.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';

/// The modules of the tests: flutter_core, which creates the app, this
/// module, and two modules whose services need every capability of the DI
/// role.
const List<SmfModule> testModules = [
  FlutterCoreModule(),
  GetItModule(),
  NetworkModule(),
  StorageModule(),
];

/// What the contract harness finds for the app of [modules] among
/// [registry], [testModules] by default, which has no errors and is
/// rendered.
Future<ContractResult> renderedApp(
  List<ModuleId> modules, {
  List<SmfModule> registry = testModules,
}) async {
  final result = await ContractHarness(ModuleRegistry(registry)).check(
    ContractCase(modules.join(', '), requested: modules),
  );
  if (result.errors.isNotEmpty || result.app == null) {
    throw StateError(
      'The app of $modules has errors: ${result.errors.join('\n')}',
    );
  }
  return result;
}

/// The path below `lib/` of the file of the services of [NetworkModule].
const networkFile = 'core/network/network.dart';

/// The path below `lib/` of the file of the services of [StorageModule].
const storageFile = 'core/storage/storage.dart';

/// Services that are ready once registered: singletons, lazy singletons
/// and factories, one of them with a parameter, and two services of one
/// type, one of them named.
///
/// Its file also has `events`, where every function of the services of the
/// tests writes what it did, in order.
///
/// - `Endpoint`, a singleton that takes `ApiConfig`, which comes after it;
/// - `ApiConfig`, a singleton;
/// - `ApiClient`, a lazy singleton that takes `ApiConfig`, with a function
///   that disposes of it;
/// - `Clock` named `utc` and `Clock`, lazy singletons;
/// - `Token`, a factory that takes `ApiConfig`;
/// - `Request`, a factory that takes `ApiClient` and a path.
final class NetworkModule extends SmfModule {
  /// Creates the module.
  const NetworkModule();

  /// The id of the module.
  static const id = ModuleId('network');

  static const _file = ImportRef.app(networkFile);

  static const _config = TypeRef('ApiConfig', import: _file);
  static const _client = TypeRef('ApiClient', import: _file);
  static const _clock = TypeRef('Clock', import: _file);

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Services that are ready once registered (test)',
        kind: ModuleKinds.infrastructure,
        requires: {diRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(bundleOf('network', {'lib/$networkFile': _code})),
        diRole.data(
          const DiRegistration(
            type: TypeRef('Endpoint', import: _file),
            create: FactoryRef(
              'createEndpoint',
              import: _file,
              deps: [ServiceRef(_config)],
            ),
            lifetime: DiLifetime.singleton,
            dispose: FunctionRef('closeEndpoint', import: _file),
          ),
        ),
        diRole.data(
          const DiRegistration(
            type: _config,
            create: FactoryRef('createApiConfig', import: _file),
            lifetime: DiLifetime.singleton,
          ),
        ),
        diRole.data(
          const DiRegistration(
            type: _client,
            create: FactoryRef(
              'createApiClient',
              import: _file,
              deps: [ServiceRef(_config)],
            ),
            dispose: FunctionRef('closeApiClient', import: _file),
          ),
        ),
        diRole.data(
          const DiRegistration(
            type: _clock,
            create: FactoryRef('createUtcClock', import: _file),
            instanceName: 'utc',
          ),
        ),
        diRole.data(
          const DiRegistration(
            type: _clock,
            create: FactoryRef('createLocalClock', import: _file),
          ),
        ),
        diRole.data(
          const DiRegistration(
            type: TypeRef('Token', import: _file),
            create: FactoryRef(
              'createToken',
              import: _file,
              deps: [ServiceRef(_config)],
            ),
            lifetime: DiLifetime.factory,
          ),
        ),
        diRole.data(
          const DiRegistration(
            type: TypeRef('Request', import: _file),
            create: FactoryRef(
              'createRequest',
              import: _file,
              deps: [ServiceRef(_client)],
            ),
            lifetime: DiLifetime.factory,
            params: [TypeRef('String')],
          ),
        ),
      ];

  static const _code = r'''
/// What the functions of the services did, in order.
final List<String> events = [];

final class ApiConfig {
  const ApiConfig(this.host);

  final String host;
}

final class Endpoint {
  const Endpoint(this.config);

  final ApiConfig config;
}

final class ApiClient {
  const ApiClient(this.config);

  final ApiConfig config;
}

final class Clock {
  const Clock(this.zone);

  final String zone;
}

final class Token {
  const Token(this.config);

  final ApiConfig config;
}

final class Request {
  const Request(this.client, this.path);

  final ApiClient client;

  final String path;
}

ApiConfig createApiConfig() {
  events.add('create ApiConfig');
  return const ApiConfig('example.com');
}

Endpoint createEndpoint(ApiConfig config) {
  events.add('create Endpoint');
  return Endpoint(config);
}

void closeEndpoint(Endpoint endpoint) => events.add('close Endpoint');

ApiClient createApiClient(ApiConfig config) {
  events.add('create ApiClient');
  return ApiClient(config);
}

void closeApiClient(ApiClient client) => events.add('close ApiClient');

Clock createUtcClock() {
  events.add('create utc Clock');
  return const Clock('UTC');
}

Clock createLocalClock() {
  events.add('create Clock');
  return const Clock('local');
}

Token createToken(ApiConfig config) {
  events.add('create Token');
  return Token(config);
}

Request createRequest(ApiClient client, String path) {
  events.add('create Request $path');
  return Request(client, path);
}
''';
}

/// Services that need what get_it can do beyond [NetworkModule]: services
/// created asynchronously, singletons that wait for them, a factory with
/// two parameters, a named service to wait for, and a type of `dart:math`.
///
/// The singletons that wait come before what they take, so the order of
/// the registrations is not the order of their declaration:
/// - `Sync`, a singleton that takes the lazy singleton `Repository`, which
///   takes `Store`, so it waits for `Store`, with a function that disposes
///   of it;
/// - `Report`, a factory that takes `Repository`, a title and a number of
///   pages;
/// - `Repository`, a lazy singleton that takes `Store` and the `Clock`
///   named `utc`;
/// - `Store`, a singleton that takes `Database`, so it waits for it;
/// - `Database`, a singleton created asynchronously that takes `ApiConfig`;
/// - `Session` and `Session` named `backup`, singletons created
///   asynchronously, with a function that disposes of them;
/// - `Cache`, a singleton that takes `ApiClient` and waits for `Session`,
///   with a function that disposes of it;
/// - `Mirror`, a singleton created asynchronously that waits for the
///   `Session` named `backup`;
/// - `Random` of `dart:math`, a lazy singleton.
final class StorageModule extends SmfModule {
  /// Creates the module.
  const StorageModule();

  /// The id of the module.
  static const id = ModuleId('storage');

  static const _file = ImportRef.app(storageFile);
  static const _network = ImportRef.app(networkFile);

  static const _session = TypeRef('Session', import: _file);
  static const _repository = TypeRef('Repository', import: _file);
  static const _store = TypeRef('Store', import: _file);
  static const _database = TypeRef('Database', import: _file);

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Services created asynchronously (test)',
        kind: ModuleKinds.infrastructure,
        dependsOn: {NetworkModule.id},
        requires: {diRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(bundleOf('storage', {'lib/$storageFile': _code})),
        diRole.data(
          const DiRegistration(
            type: TypeRef('Sync', import: _file),
            create: FactoryRef(
              'startSync',
              import: _file,
              deps: [ServiceRef(_repository)],
            ),
            lifetime: DiLifetime.singleton,
            dispose: FunctionRef('stopSync', import: _file),
          ),
        ),
        diRole.data(
          const DiRegistration(
            type: TypeRef('Report', import: _file),
            create: FactoryRef(
              'createReport',
              import: _file,
              deps: [ServiceRef(_repository)],
            ),
            lifetime: DiLifetime.factory,
            params: [TypeRef('String'), TypeRef('int')],
          ),
        ),
        diRole.data(
          const DiRegistration(
            type: _repository,
            create: FactoryRef(
              'createRepository',
              import: _file,
              deps: [
                ServiceRef(_store),
                ServiceRef(
                  TypeRef('Clock', import: _network),
                  instanceName: 'utc',
                ),
              ],
            ),
          ),
        ),
        diRole.data(
          const DiRegistration(
            type: _store,
            create: FactoryRef(
              'createStore',
              import: _file,
              deps: [ServiceRef(_database)],
            ),
            lifetime: DiLifetime.singleton,
          ),
        ),
        diRole.data(
          const DiRegistration(
            type: _database,
            create: FactoryRef(
              'openDatabase',
              import: _file,
              deps: [ServiceRef(TypeRef('ApiConfig', import: _network))],
            ),
            lifetime: DiLifetime.singleton,
            isAsync: true,
          ),
        ),
        diRole.data(
          const DiRegistration(
            type: _session,
            create: FactoryRef('openSession', import: _file),
            lifetime: DiLifetime.singleton,
            isAsync: true,
            dispose: FunctionRef('closeSession', import: _file),
          ),
        ),
        diRole.data(
          const DiRegistration(
            type: _session,
            create: FactoryRef('openBackupSession', import: _file),
            lifetime: DiLifetime.singleton,
            isAsync: true,
            dispose: FunctionRef('closeSession', import: _file),
            instanceName: 'backup',
          ),
        ),
        diRole.data(
          const DiRegistration(
            type: TypeRef('Cache', import: _file),
            create: FactoryRef(
              'createCache',
              import: _file,
              deps: [ServiceRef(TypeRef('ApiClient', import: _network))],
            ),
            lifetime: DiLifetime.singleton,
            dependsOn: [ServiceRef(_session)],
            dispose: FunctionRef('closeCache', import: _file),
          ),
        ),
        diRole.data(
          const DiRegistration(
            type: TypeRef('Mirror', import: _file),
            create: FactoryRef('openMirror', import: _file),
            lifetime: DiLifetime.singleton,
            isAsync: true,
            dependsOn: [ServiceRef(_session, instanceName: 'backup')],
          ),
        ),
        diRole.data(
          const DiRegistration(
            type: TypeRef('Random', import: ImportRef('dart:math')),
            create: FactoryRef('createRandom', import: _file),
          ),
        ),
      ];

  static const _code = r'''
import 'dart:math';

import '../network/network.dart';

final class Database {
  const Database(this.config);

  final ApiConfig config;
}

final class Store {
  const Store(this.database);

  final Database database;
}

final class Repository {
  const Repository(this.store, this.clock);

  final Store store;

  final Clock clock;
}

final class Sync {
  const Sync(this.repository);

  final Repository repository;
}

final class Report {
  const Report(this.repository, this.title, this.pages);

  final Repository repository;

  final String title;

  final int pages;
}

final class Session {
  const Session(this.name);

  final String name;
}

final class Cache {
  const Cache(this.client);

  final ApiClient client;
}

final class Mirror {
  const Mirror();
}

Future<Database> openDatabase(ApiConfig config) async {
  events.add('open Database');
  await Future<void>.delayed(Duration.zero);
  events.add('opened Database');
  return Database(config);
}

Store createStore(Database database) {
  events.add('create Store');
  return Store(database);
}

Repository createRepository(Store store, Clock clock) {
  events.add('create Repository');
  return Repository(store, clock);
}

Sync startSync(Repository repository) {
  events.add('start Sync');
  return Sync(repository);
}

void stopSync(Sync sync) => events.add('stop Sync');

Report createReport(Repository repository, String title, int pages) {
  events.add('create Report $title');
  return Report(repository, title, pages);
}

Future<Session> openSession() async {
  events.add('open main Session');
  await Future<void>.delayed(Duration.zero);
  events.add('opened main Session');
  return const Session('main');
}

Future<Session> openBackupSession() async {
  events.add('open backup Session');
  await Future<void>.delayed(Duration.zero);
  events.add('opened backup Session');
  return const Session('backup');
}

void closeSession(Session session) => events.add('close ${session.name} Session');

Cache createCache(ApiClient client) {
  events.add('create Cache');
  return Cache(client);
}

void closeCache(Cache cache) => events.add('close Cache');

Future<Mirror> openMirror() async {
  events.add('open Mirror');
  return const Mirror();
}

Random createRandom() {
  events.add('create Random');
  return Random(7);
}
''';
}

/// A mason bundle named [name] with the text [files] by path.
MasonBundle bundleOf(String name, Map<String, String> files) => MasonBundle(
      name: name,
      description: name,
      version: '0.1.0',
      files: [
        for (final MapEntry(key: path, value: text) in files.entries)
          MasonBundledFile(path, base64.encode(utf8.encode(text)), 'text'),
      ],
    );
