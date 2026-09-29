import 'service_locator.dart';

/// Creates the service locator of the app: a map of factories (fixture).
ServiceLocator createServiceLocator() => _MapLocator();

/// Registers the services of the modules of the app.
Future<void> registerDependencies() async {
{{{registrations}}}
}

final class _MapLocator implements ServiceLocator {
  final Map<(Type, String?), Object Function()> _getters = {};
  final List<void Function()> _disposers = [];

  @override
  T resolve<T extends Object>({String? instanceName}) {
    final getter = _getters[(T, instanceName)];
    if (getter == null) throw StateError('$T is not registered.');
    return getter() as T;
  }

  void singleton<T extends Object>(T instance, {String? name}) =>
      _getters[(T, name)] = () => instance;

  void lazy<T extends Object>(T Function() create, {String? name}) {
    T? instance;
    _getters[(T, name)] = () => instance ??= create();
  }

  void factoryOf<T extends Object>(T Function() create, {String? name}) =>
      _getters[(T, name)] = create;

  void onDispose(void Function() dispose) => _disposers.add(dispose);
}
