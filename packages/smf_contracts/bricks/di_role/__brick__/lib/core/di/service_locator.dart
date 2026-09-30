import 'dependencies.dart';

/// The service locator of the app, created on first use.
final ServiceLocator serviceLocator = createServiceLocator();

/// Returns the service of type [T], or the one named [instanceName].
///
/// Only the composition file of a feature calls it, to create what the
/// feature's screens need; other code receives its services as parameters.
T resolve<T extends Object>({String? instanceName}) =>
    serviceLocator.resolve<T>(instanceName: instanceName);

/// Finds the services that `registerDependencies()` registers.
abstract interface class ServiceLocator {
  /// Returns the service of type [T], or the one named [instanceName].
  T resolve<T extends Object>({String? instanceName});
}
