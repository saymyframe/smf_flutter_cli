import 'package:get_it/get_it.dart';

import 'service_locator.dart';

/// Creates the service locator of the app, which finds the services in the
/// global instance of get_it, [GetIt.instance].
ServiceLocator createServiceLocator() => _GetItServiceLocator(GetIt.instance);

/// Registers the services of the modules of the app in get_it, each after
/// the services it takes or waits for, and completes when all of them are
/// ready.
///
/// [resetDependencies] removes them again.
Future<void> registerDependencies() async {
{{{registrations}}}
}

/// Disposes of the services that get_it created, with the functions that
/// dispose of them, in the reverse order of their registration, and removes
/// every service from get_it, so that [registerDependencies] can register
/// them again.
Future<void> resetDependencies() => GetIt.instance.reset();

/// Finds the services of the app in get_it.
final class _GetItServiceLocator implements ServiceLocator {
  _GetItServiceLocator(this._getIt);

  final GetIt _getIt;

  @override
  T resolve<T extends Object>({String? instanceName}) =>
      _getIt<T>(instanceName: instanceName);
}
