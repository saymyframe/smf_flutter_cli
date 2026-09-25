/// The configuration of the fixture's services.
final class FixtureConfig {
  /// Creates the configuration.
  const FixtureConfig(this.name);

  /// The name of the app.
  final String name;
}

/// A client that needs the configuration.
final class FixtureApi {
  /// Creates the client.
  const FixtureApi(this.config);

  /// The configuration.
  final FixtureConfig config;
}

/// A session that takes time to open.
final class FixtureSession {
  /// Creates the session.
  const FixtureSession();
}

/// A cache that waits for the session and must be closed.
final class FixtureCache {
  /// Creates the cache.
  FixtureCache(this.api);

  /// The client.
  final FixtureApi api;

  /// Whether the cache was closed.
  bool closed = false;
}

/// A greeting built from parameters for every call.
final class FixtureGreeting {
  /// Creates the greeting.
  const FixtureGreeting(this.config, this.name, this.times);

  /// The configuration.
  final FixtureConfig config;

  /// Who to greet.
  final String name;

  /// How many times.
  final int times;
}

/// A clock for one time zone.
final class FixtureZone {
  /// Creates the clock of [zone].
  const FixtureZone(this.zone);

  /// The time zone.
  final String zone;
}

/// Creates the configuration.
FixtureConfig createFixtureConfig() => const FixtureConfig('fixture');

/// Creates the client.
FixtureApi createFixtureApi(FixtureConfig config) => FixtureApi(config);

/// Opens the session.
Future<FixtureSession> openFixtureSession() async => const FixtureSession();

/// Creates the cache.
FixtureCache createFixtureCache(FixtureApi api) => FixtureCache(api);

/// Closes the cache.
void closeFixtureCache(FixtureCache cache) => cache.closed = true;

/// Creates a greeting for [name], [times] times.
FixtureGreeting createFixtureGreeting(
  FixtureConfig config,
  String name,
  int times,
) =>
    FixtureGreeting(config, name, times);

/// Creates a greeting for [name] once.
FixtureGreeting createSingleGreeting(FixtureConfig config, String name) =>
    FixtureGreeting(config, name, 1);

/// Creates the clock of UTC.
FixtureZone createUtcZone() => const FixtureZone('UTC');
