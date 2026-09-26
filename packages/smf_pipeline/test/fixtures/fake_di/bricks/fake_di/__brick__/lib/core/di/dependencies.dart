import 'service_locator.dart';

/// Creates the service locator of the app: a map of factories (fixture).
ServiceLocator createServiceLocator() => _MapLocator();

/// Registers the services of the modules of the app.
Future<void> registerDependencies() async {
{{{registrations}}}
}

final class _MapLocator implements ServiceLocator {
  final Map<(Type, String?), Object Function()> _getters = {};
  final Map<(Type, String?), Object Function(Object?, Object?)> _factories =
      {};
  final List<void Function()> _disposers = [];

  @override
  T resolve<T extends Object>({String? instanceName}) {
    final getter = _getters[(T, instanceName)];
    if (getter == null) throw StateError('$T is not registered.');
    return getter() as T;
  }

  @override
  T resolveWith<T extends Object>(Object? param1, [Object? param2]) {
    final factory = _factories[(T, null)];
    if (factory == null) throw StateError('$T is not registered.');
    return factory(param1, param2) as T;
  }

  void singleton<T extends Object>(T instance, {String? name}) =>
      _getters[(T, name)] = () => instance;

  void lazy<T extends Object>(T Function() create, {String? name}) {
    T? instance;
    _getters[(T, name)] = () => instance ??= create();
  }

  void factoryOf<T extends Object>(T Function() create, {String? name}) =>
      _getters[(T, name)] = create;

  void factoryWith<T extends Object>(
    T Function(Object? param1, Object? param2) create, {
    String? name,
  }) =>
      _factories[(T, name)] = create;

  void onDispose(void Function() dispose) => _disposers.add(dispose);
}
