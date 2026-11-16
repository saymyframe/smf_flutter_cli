/// The backend of the values of remote config, which the provider of remote
/// config implements: it keeps on the device what the last fetch got, and
/// asks its backend for new values.
///
/// The code of the app does not use it: it reads the values from
/// `appRemoteConfig` of `app_remote_config.dart`, which calls this service,
/// applies the defaults of the parameters of the app, and makes new values
/// active once they are fetched.
///
/// Every implementation keeps to this:
/// - The function that creates the service asks the backend nothing. It may
///   be called again, as at the next launch of the app, and the service that
///   it returns then has what the device kept.
/// - [open] comes once, before any other member.
/// - What was activated stays on the device from one launch of the app to
///   the next: after [open], [activate] makes what the last fetch got the
///   active values, also without the network, and [values] has them.
/// - [values] has the active values that the backend gave, and nothing else:
///   never a default, and never a value that the provider makes up for a
///   parameter that the backend lacks.
/// - [fetch] asks the backend for its values, unless the last fetch that
///   succeeded is more recent than the fetch interval of [open], also one of
///   an earlier launch of the app. It fails when the backend cannot be
///   reached or refuses, and the active values stay as they were.
/// - [updates] is a broadcast stream, which tells of nothing where
///   [liveUpdates] is false.
abstract interface class RemoteConfigService {
  /// Opens the service for [defaults], the parameters of the app by name,
  /// each with the value that the app has while the backend gives none, of
  /// the type of the parameter. [fetchInterval] is how often [fetch] may ask
  /// the backend at most, also across launches of the app, and
  /// [fetchTimeout] how long a fetch may take. It takes what the device kept
  /// and asks the backend nothing.
  Future<void> open(
    Map<String, Object> defaults, {
    required Duration fetchInterval,
    required Duration fetchTimeout,
  });

  /// Makes what the last fetch got the active values, without asking the
  /// backend, and returns whether they changed.
  Future<bool> activate();

  /// The active values that the backend gave, by parameter, as texts.
  Map<String, String> get values;

  /// Asks the backend for its values and keeps them for [activate], unless
  /// the last fetch that succeeded is more recent than the fetch interval:
  /// then it completes at once.
  Future<void> fetch();

  /// Whether [updates] tells of the values that the backend publishes while
  /// the app runs.
  bool get liveUpdates;

  /// Tells of the values that the backend publishes while the app runs, once
  /// the provider fetched them, so that [activate] makes them active: a
  /// broadcast stream, which tells of nothing where [liveUpdates] is false.
  /// Listening to it may open a connection to the backend.
  Stream<void> get updates;
}
