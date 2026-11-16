import 'package:firebase_remote_config/firebase_remote_config.dart';

import 'remote_config_service.dart';

/// The remote config of the app on Firebase Remote Config: the values that
/// the Firebase project of the flavor of the build publishes.
///
/// Firebase keeps on the device what the last fetch got and what was
/// activated, from one launch of the app to the next. While the app runs,
/// it tells of the values that the project publishes in real time, once it
/// fetched them.
///
/// The code of the app reads the values through `appRemoteConfig` of
/// `app_remote_config.dart`, which calls this service.
final class FirebaseRemoteConfigService implements RemoteConfigService {
  FirebaseRemoteConfigService._(this._config);

  final FirebaseRemoteConfig _config;

  /// Takes what the device kept, then gives Firebase the fetch interval,
  /// the timeout of a fetch and the defaults of the parameters of the app.
  @override
  Future<void> open(
    Map<String, Object> defaults, {
    required Duration fetchInterval,
    required Duration fetchTimeout,
  }) async {
    await _config.ensureInitialized();
    await _config.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: fetchTimeout,
        minimumFetchInterval: fetchInterval,
      ),
    );
    await _config.setDefaults(defaults);
  }

  @override
  Future<bool> activate() => _config.activate();

  /// The active values that the Firebase project gave: Firebase also has
  /// the defaults of the app among its values, which are not the project's.
  @override
  Map<String, String> get values => {
    for (final MapEntry(key: parameter, value: value)
        in _config.getAll().entries)
      if (value.source == ValueSource.valueRemote) parameter: value.asString(),
  };

  @override
  Future<void> fetch() => _config.fetch();

  /// Firebase tells of the values that the project publishes while the app
  /// runs.
  @override
  bool get liveUpdates => true;

  /// Each update of Firebase, once Firebase fetched the values that the
  /// project published. Listening opens a connection to Firebase, which the
  /// last listener closes.
  @override
  Stream<void> get updates => _config.onConfigUpdated.map((_) {});
}

/// Returns the remote config service of the app on Firebase Remote Config.
/// It asks Firebase nothing.
RemoteConfigService createFirebaseRemoteConfigService() =>
    FirebaseRemoteConfigService._(FirebaseRemoteConfig.instance);
