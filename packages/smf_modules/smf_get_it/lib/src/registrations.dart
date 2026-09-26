import 'package:smf_contracts/lego.dart';

/// The body of `registerDependencies()` that registers the services of
/// [graph] in get_it, in an app whose package is named [appName], with the
/// imports it needs; empty when the app has no services.
///
/// The services come in the order of [DiGraph.ordered]. The body imports the
/// file of every type and function it names once, with a prefix of its own,
/// `di0`, `di1`, ..., in the order it first names them.
Fragment registrationsOf(DiGraph graph, {required String appName}) {
  final ordered = graph.ordered;
  if (ordered.isEmpty) return const Fragment('');
  final code = _Code(graph, appName);
  final lines = [
    '  final getIt = GetIt.instance;',
    for (final registration in ordered) '  ${code.register(registration)};',
    if (graph.needsAllReady) '  await getIt.allReady();',
  ];
  return Fragment(lines.join('\n'), imports: code.imports);
}

/// Writes the registrations of one app, and the imports they need.
final class _Code {
  _Code(this._graph, this._appName);

  final DiGraph _graph;
  final String _appName;

  /// The imports of the files that the code names, by URI in the app.
  final Map<String, ImportRef> _imports = {};

  /// The imports of the files that the code names so far.
  List<ImportRef> get imports => [..._imports.values];

  /// The registration of [registration] as a call on `getIt`.
  String register(DiRegistration registration) {
    final type = _type(registration.type);
    final params = [for (final param in registration.params) _type(param)];
    final create = registration.create;
    final factory = create.codeWith(_prefixOf(create.import));
    final services = [for (final dep in create.deps) _get(dep)];
    final waits = [
      for (final service in _graph.dependsOnOf(registration)) _waitFor(service),
    ];
    final name = switch (registration.instanceName) {
      null => null,
      final name => 'instanceName: ${SmfNames.dartString(name)}',
    };
    final dependsOn = waits.isEmpty ? null : 'dependsOn: [${waits.join(', ')}]';
    final dispose = switch (registration.dispose) {
      null => null,
      final dispose =>
        'dispose: ${dispose.codeWith(_prefixOf(dispose.import))}',
    };
    final call = '$factory(${services.join(', ')})';

    String registerWith(String method, List<String?> arguments) =>
        'getIt.$method<$type>(${arguments.nonNulls.join(', ')})';

    return switch (registration.lifetime) {
      DiLifetime.singleton when registration.isAsync => registerWith(
          'registerSingletonAsync',
          ['() => $call', name, dependsOn, dispose],
        ),
      DiLifetime.singleton when waits.isNotEmpty => registerWith(
          'registerSingletonWithDependencies',
          ['() => $call', name, dependsOn, dispose],
        ),
      DiLifetime.singleton =>
        registerWith('registerSingleton', [call, name, dispose]),
      DiLifetime.lazySingleton =>
        registerWith('registerLazySingleton', ['() => $call', name, dispose]),
      DiLifetime.factory when params.isEmpty =>
        registerWith('registerFactory', ['() => $call', name]),
      DiLifetime.factory => _registerFactoryParam(
          type,
          params,
          factory,
          services,
        ),
    };
  }

  /// The registration of a factory that takes [params] from the caller
  /// after [services]: get_it passes two values, and `void` stands for the
  /// second when the factory takes one.
  ///
  /// A factory with parameters has no instance name, since `resolveWith`
  /// cannot ask for one.
  String _registerFactoryParam(
    String type,
    List<String> params,
    String factory,
    List<String> services,
  ) {
    final two = params.length == 2;
    final arguments = [...services, 'param1', if (two) 'param2'];
    return 'getIt.registerFactoryParam<$type, ${params.first}, '
        '${two ? params.last : 'void'}>((param1, ${two ? 'param2' : '_'}) => '
        '$factory(${arguments.join(', ')}))';
  }

  /// [service] from get_it, by its type and name.
  String _get(ServiceRef service) {
    final name = service.instanceName;
    final named =
        name == null ? '' : 'instanceName: ${SmfNames.dartString(name)}';
    return 'getIt<${_type(service.type)}>($named)';
  }

  /// [service] among the services that a singleton waits for: its type, or
  /// an `InitDependency` with its name.
  String _waitFor(ServiceRef service) => switch (service.instanceName) {
        null => _type(service.type),
        final name => 'InitDependency(${_type(service.type)}, '
            'instanceName: ${SmfNames.dartString(name)})',
      };

  /// [type] as the code refers to it: a type of `dart:core` by its name,
  /// any other after the prefix of the import of its file.
  String _type(TypeRef type) => switch (type.import) {
        null => type.name,
        final import => type.codeWith(_prefixOf(import)),
      };

  /// The prefix of the import of [import]'s file, which the first use of
  /// the file gives it.
  String _prefixOf(ImportRef import) => _imports
      .putIfAbsent(
        import.resolveUri(_appName),
        () => import.withPrefix('di${_imports.length}'),
      )
      .prefix!;
}
