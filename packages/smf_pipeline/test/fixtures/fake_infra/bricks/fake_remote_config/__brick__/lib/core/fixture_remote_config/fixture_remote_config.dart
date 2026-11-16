import '../remote_config/remote_config_service.dart';

/// What the backend of the fixture has, by parameter: no value of a
/// parameter of the app, and the parameter of the check of the remote config
/// role, which no app reads, as the role asks of the mocks of every provider.
const Map<String, String> _backend = {
  {{{check_parameter}}}: 'On the backend of the fixture',
};

/// What the last fetch got, by parameter. It stands for what the device
/// keeps, which every start of the app finds as the last one left it.
Map<String, String> _fetched = const {};

/// The active values, by parameter, which the device keeps too.
Map<String, String> _active = const {};

/// When the last fetch that succeeded was, which the device keeps too.
DateTime? _lastFetch;

/// Waits for the answer of the system, which takes a moment, as with a
/// provider that asks it: a turn of the event loop. So a test makes the
/// calls of remote config in real time, as it runs the start-up of the app.
Future<void> _answer() => Future<void>.delayed(Duration.zero);

/// Creates the remote config of the fixture, as a start of the app does: it
/// asks the backend nothing. Nothing outlives the process of the app, so
/// each run of the tests of a file starts as on a first launch.
RemoteConfigService createFixtureRemoteConfig() => FixtureRemoteConfig._();

/// Remote config in memory: a backend with no value of a parameter of the
/// app, which publishes nothing while the app runs, and a device that keeps
/// what was fetched and activated from one start of the app to the next.
final class FixtureRemoteConfig implements RemoteConfigService {
  FixtureRemoteConfig._();

  /// How often [fetch] may ask the backend at most.
  Duration _interval = Duration.zero;

  @override
  Future<void> open(
    Map<String, Object> defaults, {
    required Duration fetchInterval,
    required Duration fetchTimeout,
  }) async {
    await _answer();
    _interval = fetchInterval;
  }

  @override
  Future<bool> activate() async {
    final changed = !_same(_fetched, _active);
    _active = _fetched;
    return changed;
  }

  @override
  Map<String, String> get values => Map.unmodifiable(_active);

  @override
  Future<void> fetch() async {
    await _answer();
    final last = _lastFetch;
    final now = DateTime.now();
    if (last != null && now.difference(last) < _interval) return;
    _fetched = Map.unmodifiable(_backend);
    _lastFetch = now;
  }

  @override
  bool get liveUpdates => false;

  @override
  Stream<void> get updates => const Stream<void>.empty();
}

/// Whether [one] and [other] have the same values of the same parameters.
bool _same(Map<String, String> one, Map<String, String> other) =>
    one.length == other.length &&
    one.entries.every((entry) => other[entry.key] == entry.value);
