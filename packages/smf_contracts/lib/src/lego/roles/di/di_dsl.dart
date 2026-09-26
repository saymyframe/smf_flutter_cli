part of '../di.dart';

/// How long a service of the DI container lives.
enum DiLifetime {
  /// One instance, created while `registerDependencies()` runs, after the
  /// services it depends on.
  singleton,

  /// One instance, created on first use.
  lazySingleton,

  /// A new instance on every use.
  factory,
}

/// What a DI container can do beyond singletons, lazy singletons and
/// factories whose factory functions take services; see
/// [DiProvider.capabilities].
enum DiCapability {
  /// Factories that take up to two parameters from the caller, resolved
  /// with `resolveWith`.
  factoryWithParams,

  /// Singletons created asynchronously, which `registerDependencies()`
  /// waits for.
  asyncInit,

  /// Singletons created only after the services they depend on are ready.
  dependsOn,

  /// Singletons disposed of by a function when the container is reset.
  dispose,

  /// Several services of one type told apart by name.
  instanceName,
}

/// A service of the app's DI container: the data of the [DiRole].
///
/// A module registers a service it generates, and the DI provider renders
/// the registration in the form of its container. The container creates the
/// service by calling [create] with the services in [FactoryRef.deps], so
/// the module declares what the service needs instead of looking it up:
///
/// ```dart
/// diRole.data(
///   const DiRegistration(
///     type: TypeRef('AuthRepository', import: authFile),
///     create: FactoryRef(
///       'createAuthRepository',
///       import: authFile,
///       deps: [ServiceRef(TypeRef('HttpClient', import: httpFile))],
///     ),
///   ),
/// )
/// ```
///
/// Only the composition file of a feature resolves services itself, with
/// `resolve` and `resolveWith` of `lib/core/di/service_locator.dart`.
@immutable
final class DiRegistration {
  /// Registers the service of [type] that [create] creates.
  const DiRegistration({
    required this.type,
    required this.create,
    this.lifetime = DiLifetime.lazySingleton,
    this.params = const [],
    this.isAsync = false,
    this.dependsOn = const [],
    this.dispose,
    this.instanceName,
  });

  /// The type the service is registered as, usually an interface.
  final TypeRef type;

  /// The function that creates the service: `create(deps..., params...)`.
  final FactoryRef create;

  /// How long the service lives.
  final DiLifetime lifetime;

  /// The types of up to two values that callers pass to a
  /// [DiLifetime.factory] with `resolveWith`, after its [FactoryRef.deps].
  ///
  /// Needs [DiCapability.factoryWithParams].
  final List<TypeRef> params;

  /// Whether [create] returns a `Future` of the service. Only a
  /// [DiLifetime.singleton] can be created asynchronously, and
  /// `registerDependencies()` waits for it.
  ///
  /// Needs [DiCapability.asyncInit].
  final bool isAsync;

  /// Asynchronously created services that a [DiLifetime.singleton] must
  /// wait for although it does not take them.
  ///
  /// A singleton waits for the services in [FactoryRef.deps] that are
  /// created asynchronously without listing them here; see
  /// [DiGraph.dependsOnOf]. Needs [DiCapability.dependsOn].
  final List<ServiceRef> dependsOn;

  /// The function that disposes of the instance of a singleton or lazy
  /// singleton, such as `(HttpClient client) => client.close()` declared as
  /// a top-level function.
  ///
  /// Needs [DiCapability.dispose].
  final FunctionRef? dispose;

  /// The name that tells this service apart from others of the same type.
  ///
  /// Needs [DiCapability.instanceName].
  final String? instanceName;

  /// The service this registration provides.
  ServiceRef get key => ServiceRef(type, instanceName: instanceName);

  /// Describes what is wrong with the registration on its own, or returns
  /// an empty list; see [DiGraph.issues] for its relation to others.
  List<String> problems() {
    final label = 'The registration of $key';
    final problems = [
      ...type.problems(),
      ...create.problems(),
      for (final param in params) ...param.problems(),
      for (final service in dependsOn) ...service.problems(),
      ...?dispose?.problems(),
      if (instanceName case final name? when name.isEmpty)
        '$label has an empty instance name.',
      if (params.isNotEmpty && lifetime != DiLifetime.factory)
        '$label takes parameters, which only a factory can.',
      if (params.isNotEmpty && instanceName != null)
        _namedFactoryProblem(label),
      if (isAsync && lifetime != DiLifetime.singleton)
        '$label is asynchronous, which only a singleton can be.',
    ];
    if (params.length > 2) {
      problems.add(
        '$label takes ${params.length} parameters; a factory takes at most '
        'two.',
      );
    }
    if (dependsOn.isNotEmpty && lifetime != DiLifetime.singleton) {
      problems.add(
        '$label waits for other services, which only a singleton can do.',
      );
    }
    if (dispose != null && lifetime == DiLifetime.factory) {
      problems.add(
        '$label is a factory, whose instances the container does not keep '
        'to dispose of.',
      );
    }
    return problems;
  }

  @override
  String toString() => 'registration of $key';
}

String _namedFactoryProblem(String label) =>
    '$label takes parameters and has an instance name, which resolveWith '
    'cannot ask for.';
