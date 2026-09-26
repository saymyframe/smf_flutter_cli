import 'dependencies.dart';

/// The service locator of the app, created on first use.
final ServiceLocator serviceLocator = createServiceLocator();

/// Returns the service of type [T], or the one named [instanceName].
///
/// Only the composition file of a feature calls it, to create what the
/// feature's screens need; other code receives its services as parameters.
T resolve<T extends Object>({String? instanceName}) =>
    serviceLocator.resolve<T>(instanceName: instanceName);

/// Returns a new service of type [T] from a factory that takes parameters,
/// created with [param1] and [param2].
T resolveWith<T extends Object>(Object? param1, [Object? param2]) =>
    serviceLocator.resolveWith<T>(param1, param2);

/// Finds the services that `registerDependencies()` registers.
abstract interface class ServiceLocator {
  /// Returns the service of type [T], or the one named [instanceName].
  T resolve<T extends Object>({String? instanceName});

  /// Returns a new service of type [T] from a factory that takes
  /// parameters, created with [param1] and [param2].
  T resolveWith<T extends Object>(Object? param1, [Object? param2]);
}
