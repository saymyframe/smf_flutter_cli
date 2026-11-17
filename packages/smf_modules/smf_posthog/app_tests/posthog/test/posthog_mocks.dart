// The mocks of PostHog for the tests that continuous integration runs in the
// apps with the posthog module: a device with the SDK of PostHog in memory,
// which records each call that reaches it and sends nothing. The matrix sets
// them up before the tests of every module of such an app
// (MatrixAppTest.mocks), so that any of them may run the start-up of the
// app, which starts PostHog.
//
// posthog_flutter has no mocks for tests. On Android and iOS it talks to its
// SDKs through a method channel, and on Linux and Windows, where flutter test
// registers the plugins of the host, through a client in Dart that writes to
// the disk and to the network. So the mocks replace the implementation of the
// platform, PosthogFlutterPlatformInterface.instance, with a device of their
// own, which works on every host and touches neither. The class is in src/ of
// the package and not exported, so a version of the package that changes it
// breaks these tests.
//
// The device keeps to what the SDK of PostHog for iOS does with the setting
// of collection, which posthog_flutter leaves to the SDKs:
// - what the code chose with optOut() and optIn() is kept on the device, and
//   wins over the optOut of the config at the next start;
// - reset() forgets what was kept, and the registered properties, and keeps
//   the setting in memory until the next start;
// - an optOut() or an optIn() that changes nothing in memory keeps nothing;
// - while it is opted out, it records no event and no property. identify()
//   still makes the user its distinct id then, as the SDKs for Android and
//   iOS do, and only its event is dropped.
// It also ignores a second setup in the same start, as both SDKs do: only
// the next start reads the config again.
//
// ignore_for_file: implementation_imports
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:posthog_flutter/src/posthog_flutter_platform_interface.dart';

/// The device of the tests of a test file, whose SDK of PostHog the app
/// uses: a new one each time the mocks are set up.
MockPostHog postHogDevice = MockPostHog();

/// Gives posthog_flutter a new device, [postHogDevice]: see the top of the
/// file.
void mockPostHog() {
  postHogDevice = MockPostHog();
  PosthogFlutterPlatformInterface.instance = postHogDevice;
}

/// An event that the device would send to PostHog: its name and its
/// properties, the registered ones among them, and the distinct id of the
/// user whom it belongs to.
typedef RecordedEvent = ({
  String event,
  Map<String, Object?> properties,
  String distinctId,
});

/// A device with the SDK of PostHog in memory: see the top of the file.
final class MockPostHog extends PosthogFlutterPlatformInterface {
  /// Each call that reached the device, as its method and its arguments, in
  /// their order.
  final List<List<Object?>> calls = [];

  /// The events that the device would have sent, in their order.
  final List<RecordedEvent> events = [];

  /// The config with which the SDK was set up in this start, or `null`
  /// before it: a later setup of the same start changes nothing.
  PostHogConfig? config;

  /// The setting of collection that the device keeps across starts: whether
  /// it is opted out, or `null` when it keeps nothing.
  bool? storedOptOut;

  /// Whether the SDK is opted out in this start.
  bool optedOut = false;

  /// The properties that every event gets, which the device keeps.
  final Map<String, Object> registered = {};

  /// The distinct id of the user of the device: an anonymous id until the
  /// app identifies the user.
  String distinctId = 'anonymous-1';

  /// The properties of the person of each distinct id, which the device
  /// sent.
  final Map<String, Map<String, Object?>> people = {};

  /// A future that the reads of the device wait for, as an SDK that does not
  /// answer at once, or `null` for one that answers at once.
  Future<void>? hold;

  int _anonymous = 1;

  /// The calls of [method], each with its arguments.
  List<List<Object?>> callsOf(String method) => [
        for (final call in calls)
          if (call.first == method) call.sublist(1),
      ];

  /// The names of the methods of the calls, in their order.
  List<Object?> get methods => [for (final call in calls) call.first];

  /// Starts the app again on this device, as its next launch does: what
  /// the SDK has in memory is gone, and what it kept on the device stays.
  void startAgain() {
    config = null;
    optedOut = false;
  }

  void _record(String event, Map<String, Object?>? properties) {
    if (optedOut) return;
    events.add((
      event: event,
      properties: {...registered, ...?properties},
      distinctId: distinctId,
    ));
  }

  @override
  Future<void> setup(PostHogConfig config) async {
    calls.add(['setup', config]);
    if (this.config != null) return;
    this.config = config;
    optedOut = storedOptOut ?? config.optOut;
  }

  @override
  Future<bool> isOptOut() async {
    calls.add(['isOptOut']);
    await hold;
    return optedOut;
  }

  @override
  Future<void> disable() async {
    calls.add(['disable']);
    if (optedOut) return;
    optedOut = true;
    storedOptOut = true;
  }

  @override
  Future<void> enable() async {
    calls.add(['enable']);
    if (!optedOut) return;
    optedOut = false;
    storedOptOut = false;
  }

  @override
  Future<void> reset() async {
    calls.add(['reset']);
    storedOptOut = null;
    registered.clear();
    distinctId = 'anonymous-${++_anonymous}';
  }

  @override
  Future<void> register(String key, Object value) async {
    calls.add(['register', key, value]);
    registered[key] = value;
  }

  @override
  Future<void> unregister(String key) async {
    calls.add(['unregister', key]);
    registered.remove(key);
  }

  @override
  Future<void> capture({
    required String eventName,
    Map<String, Object>? properties,
    Map<String, Object>? userProperties,
    Map<String, Object>? userPropertiesSetOnce,
  }) async {
    calls.add(['capture', eventName, properties]);
    _record(eventName, properties);
    if (optedOut || eventName != r'$set') return;
    final unset = properties?[r'$unset'];
    if (unset is List) {
      people[distinctId]?.removeWhere((name, _) => unset.contains(name));
    }
  }

  @override
  Future<void> screen({
    required String screenName,
    Map<String, Object>? properties,
  }) async {
    calls.add(['screen', screenName]);
    _record(r'$screen', {r'$screen_name': screenName, ...?properties});
  }

  @override
  Future<void> identify({
    required String userId,
    Map<String, Object>? userProperties,
    Map<String, Object>? userPropertiesSetOnce,
  }) async {
    calls.add(['identify', userId, userProperties]);
    distinctId = userId;
    // The event of the identification carries the properties.
    if (optedOut) return;
    (people[userId] ??= {}).addAll({...?userProperties});
    _record(r'$identify', null);
  }

  @override
  Future<void> setPersonProperties({
    Map<String, Object>? userPropertiesToSet,
    Map<String, Object>? userPropertiesToSetOnce,
  }) async {
    calls.add(['setPersonProperties', userPropertiesToSet]);
    if (optedOut) return;
    (people[distinctId] ??= {}).addAll({...?userPropertiesToSet});
    _record(r'$set', null);
  }

  @override
  Future<String> getDistinctId() async {
    calls.add(['getDistinctId']);
    await hold;
    return distinctId;
  }

  @override
  Future<void> flush() async {
    calls.add(['flush']);
  }

  @override
  Future<void> debug(bool enabled) async {
    calls.add(['debug', enabled]);
  }

  @override
  Future<void> close() async {
    calls.add(['close']);
    config = null;
  }
}
