import 'dart:async';

import 'service_locator.dart';

/// Creates the service locator of the app: a map of factories (fixture).
ServiceLocator createServiceLocator() => _MapLocator();

/// Registers the services of the modules of the app.
Future<void> registerDependencies() async {
{{{registrations}}}
}

/// Disposes of the services that the map created, with the functions that
/// dispose of them, in the reverse order of their registration, and
/// removes every service, so that [registerDependencies] can register them
/// again.
Future<void> resetDependencies() => (serviceLocator as _MapLocator).reset();

final class _MapLocator implements ServiceLocator {
  final Map<(Type, String?), Object Function()> _getters = {};

  /// What disposes of each service that has a function to dispose of it,
  /// in the order of the registrations.
  final List<FutureOr<void> Function()> _disposers = [];

  @override
  T resolve<T extends Object>({String? instanceName}) {
    final getter = _getters[(T, instanceName)];
    if (getter == null) throw StateError('$T is not registered.');
    return getter() as T;
  }

  void singleton<T extends Object>(
    T instance, {
    String? name,
    FutureOr<void> Function(T service)? dispose,
  }) {
    _getters[(T, name)] = () => instance;
    if (dispose != null) _disposers.add(() => dispose(instance));
  }

  void lazy<T extends Object>(
    T Function() create, {
    String? name,
    FutureOr<void> Function(T service)? dispose,
  }) {
    T? instance;
    _getters[(T, name)] = () => instance ??= create();
    if (dispose != null) {
      // A lazy singleton that nothing resolved is not created only to be
      // disposed of.
      _disposers.add(() {
        if (instance case final created?) return dispose(created);
      });
    }
  }

  void factoryOf<T extends Object>(T Function() create, {String? name}) =>
      _getters[(T, name)] = create;

  Future<void> reset() async {
    for (final dispose in _disposers.reversed) {
      await dispose();
    }
    _disposers.clear();
    _getters.clear();
  }
}
