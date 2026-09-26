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

/// A label built from a text for every call.
final class FixtureLabel {
  /// Creates the label.
  const FixtureLabel(this.config, this.text);

  /// The configuration.
  final FixtureConfig config;

  /// The text of the label.
  final String text;
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

/// Creates a label with [text].
FixtureLabel createFixtureLabel(FixtureConfig config, String text) =>
    FixtureLabel(config, text);

/// Creates the clock of UTC.
FixtureZone createUtcZone() => const FixtureZone('UTC');

/// A stamp of the time in a zone, new for every call.
final class FixtureStamp {
  /// Creates the stamp.
  const FixtureStamp(this.zone);

  /// The zone of the time.
  final FixtureZone zone;
}

/// A log of what the app did.
final class FixtureLog {
  /// Whether the log was closed.
  bool closed = false;
}

/// An index of what a session holds.
final class FixtureIndex {
  /// Creates the index.
  const FixtureIndex(this.session);

  /// The session.
  final FixtureSession session;
}

/// A replica that opens after the backup session.
final class FixtureReplica {
  /// Creates the replica.
  const FixtureReplica();
}

/// A counter of events.
final class FixtureCounter {
  /// How many events it counted.
  int count = 0;
}

/// Creates a stamp in [zone].
FixtureStamp createFixtureStamp(FixtureZone zone) => FixtureStamp(zone);

/// Creates the audit log.
FixtureLog createAuditLog() => FixtureLog();

/// Closes the log.
void closeFixtureLog(FixtureLog log) => log.closed = true;

/// Creates the index of [session].
FixtureIndex createFixtureIndex(FixtureSession session) =>
    FixtureIndex(session);

/// Opens the backup session.
Future<FixtureSession> openBackupSession() async => const FixtureSession();

/// Closes [session].
void closeFixtureSession(FixtureSession session) {}

/// Opens the replica.
Future<FixtureReplica> openFixtureReplica() async => const FixtureReplica();

/// Creates the counter.
FixtureCounter createFixtureCounter() => FixtureCounter();

/// Resets the counter.
void closeFixtureCounter(FixtureCounter counter) => counter.count = 0;
