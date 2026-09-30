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
  /// Singletons created asynchronously, which `registerDependencies()`
  /// waits for.
  asyncInit,

  /// Singletons created only after the services they depend on are ready.
  dependsOn,

  /// Singletons and lazy singletons disposed of by a function when
  /// `resetDependencies()` resets the container; see
  /// [DiRole.resetDependencies].
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
/// `resolve` of `lib/core/di/service_locator.dart`.
///
/// Values known only at run time, such as the id of the product that a
/// screen shows, are not part of a registration. The composition function
/// of a feature takes them as parameters, as in
/// `DetailsCubit createDetailsCubit(int id)`. Elsewhere, a factory class
/// that takes its services in its constructor creates the objects with
/// such values in a method such as `call(int id)`; it is registered like
/// any other service, and other services take it in their
/// [FactoryRef.deps].
@immutable
final class DiRegistration {
  /// Registers the service of [type] that [create] creates.
  const DiRegistration({
    required this.type,
    required this.create,
    this.lifetime = DiLifetime.lazySingleton,
    this.isAsync = false,
    this.dependsOn = const [],
    this.dispose,
    this.instanceName,
  });

  /// The type the service is registered as, usually an interface.
  final TypeRef type;

  /// The function that creates the service from the services in its
  /// [FactoryRef.deps].
  final FactoryRef create;

  /// How long the service lives.
  final DiLifetime lifetime;

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
  /// `resetDependencies()` calls it with the instance, if the container
  /// created one, in the reverse order of the registrations; see
  /// [DiRole.resetDependencies].
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
      for (final service in dependsOn) ...service.problems(),
      ...?dispose?.problems(),
      if (instanceName case final name? when name.isEmpty)
        '$label has an empty instance name.',
      if (isAsync && lifetime != DiLifetime.singleton)
        '$label is asynchronous, which only a singleton can be.',
    ];
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
