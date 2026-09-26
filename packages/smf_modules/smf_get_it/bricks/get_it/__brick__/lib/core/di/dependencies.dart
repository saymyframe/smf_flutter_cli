import 'package:get_it/get_it.dart';

import 'service_locator.dart';

/// Creates the service locator of the app, which finds the services in the
/// global instance of get_it, [GetIt.instance].
ServiceLocator createServiceLocator() => _GetItServiceLocator(GetIt.instance);

/// Registers the services of the modules of the app in get_it, each after
/// the services it takes or waits for, and completes when all of them are
/// ready.
///
/// `GetIt.instance.reset()` removes them again and disposes of those that
/// were created, in the reverse order of their registration.
Future<void> registerDependencies() async {
{{{registrations}}}
}

/// Finds the services of the app in get_it.
final class _GetItServiceLocator implements ServiceLocator {
  _GetItServiceLocator(this._getIt);

  final GetIt _getIt;

  @override
  T resolve<T extends Object>({String? instanceName}) =>
      _getIt<T>(instanceName: instanceName);

  @override
  T resolveWith<T extends Object>(Object? param1, [Object? param2]) =>
      _getIt<T>(param1: param1, param2: param2);
}
