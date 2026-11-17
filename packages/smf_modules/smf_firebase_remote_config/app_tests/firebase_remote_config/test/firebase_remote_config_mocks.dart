// The platform side of Firebase Remote Config for the tests that continuous
// integration runs in the apps with the firebase_remote_config module: a
// device and a Firebase project in memory, in place of the Firebase SDK of
// a device and of the server behind it. It keeps to the convention of the
// mocks of every provider of the remote config role: the project has no
// value of a parameter of the app, and one parameter outside the app,
// remote_config_role_check, which no app reads; a fetch completes at once
// with what the project has; no value comes from the project while the app
// runs unless a test of this module publishes one; and the device keeps
// what was activated for as long as the tests of a test file last, as it
// keeps it from one launch of the app to the next. The matrix sets it up
// before the tests of every module of such an app (MatrixAppTest.mocks), so
// that any of them may run the start-up of the app, which starts remote
// config on it. The mocks of Firebase Core come with the tests of
// firebase_core, which every app with the module has.
//
// firebase_remote_config_platform_interface 3 has no mocks for tests, as
// those of Firebase Core and Crashlytics have, so this answers its messages
// to the platform: each method of FirebaseRemoteConfigHostApi on a channel
// of its own, in the codec of the package, and the event channel of the
// real-time updates. The main library of the package does not export the
// codec, so this imports the file that declares it. A version of the
// package that changes its messages breaks these tests.
//
// It answers at once, without a timer, so a call completes in a widget test
// too. It keeps to what Firebase does where the app relies on it: the values
// of a parameter are the active value that came from the project, or else
// the default that the app set, each with its source; a fetch keeps what
// the project has until an activation makes it active, and does not ask the
// project again within the minimum fetch interval of the app; and once the
// plugin listens to the real-time updates, a value that the project
// publishes is fetched at once and told of, with the parameters that changed,
// without waiting for that interval.
//
// It differs from Firebase in this: it has no conditions, no installation
// and no network, takes any text for a value, and sends nothing to a
// server.
import 'dart:async';
import 'dart:convert';

// The codec of the messages and the class of the settings, which the main
// library of the package does not export.
// ignore: implementation_imports
import 'package:firebase_remote_config_platform_interface/src/pigeon/messages.pigeon.dart'
    show FirebaseRemoteConfigHostApi, RemoteConfigPigeonSettings;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'firebase_core_mocks.dart';

/// The channel of the plugin, under which Firebase Core gives it its
/// constants.
const _plugin = 'plugins.flutter.io/firebase_remote_config';

/// The prefix of the channels of the methods of the plugin.
const _channels =
    'dev.flutter.pigeon.firebase_remote_config_platform_interface.'
    'FirebaseRemoteConfigHostApi.';

/// The event channel of the real-time updates, which the plugin listens to
/// with the methods `listen` and `cancel` and on which the platform tells it
/// of the parameters that changed.
const _updates = MethodChannel(
  'plugins.flutter.io/firebase_remote_config_updated',
);

/// The parameter outside the app that the project of the mocks has, as the
/// remote config role asks of the mocks of every provider, and its value.
const String checkParameter = 'remote_config_role_check';
const String checkValue = 'the value of the check of the role';

/// An error as the platform answers a call with it.
final class _Failure {
  const _Failure(this.code, this.message);

  final String code;
  final String message;
}

/// The platform side of Firebase Remote Config in memory; see
/// [mockFirebaseRemoteConfig].
final class MockFirebaseRemoteConfig {
  MockFirebaseRemoteConfig._();

  /// What the Firebase project has, by parameter, which a fetch gets: at
  /// first only [checkParameter].
  final Map<String, String> project = {checkParameter: checkValue};

  /// The active values on the device that came from the project, by
  /// parameter.
  Map<String, String> active = {};

  /// The defaults that the app set, as texts, by parameter.
  Map<String, String> _defaults = {};

  /// What the last fetch got, until an activation makes it active.
  Map<String, String>? _fetched;

  /// The timeout of a fetch and the minimum interval between two fetches
  /// that the app set, in seconds: those of Firebase until it sets them.
  int get fetchTimeoutSeconds => _fetchTimeoutSeconds;
  int get minimumFetchIntervalSeconds => _minimumFetchIntervalSeconds;
  int _fetchTimeoutSeconds = 60;
  int _minimumFetchIntervalSeconds = 43200;
  DateTime? _lastFetch;
  String _lastFetchStatus = 'noFetchYet';

  final Map<String, _Failure> _failures = {};

  /// What the next calls of each method wait for before they answer.
  final Map<String, List<Completer<void>>> _holds = {};

  /// Whether the plugin listens to the real-time updates.
  bool listening = false;

  /// The calls that reached the platform side, each as its method followed
  /// by its arguments, without the Firebase app that each has first, and
  /// `listen` and `cancel` of the real-time updates.
  final List<List<Object?>> calls = [];

  /// The methods of the [calls], in their order.
  List<String> get methods => [for (final call in calls) call.first! as String];

  /// Answers the next call of [method], such as `fetch`, with an error with
  /// [code] and [message], as the platform sends them: the plugin turns it
  /// into a FirebaseException with that code and message. The call changes
  /// nothing.
  void failNext(
    String method, {
    required String code,
    required String message,
  }) =>
      _failures[method] = _Failure(code, message);

  /// Holds back the next call of [method] that no hold has yet: it answers
  /// once the completer that this returns completes, as a platform without
  /// a network does, and never if it does not complete.
  Completer<void> holdNext(String method) {
    final hold = Completer<void>();
    (_holds[method] ??= []).add(hold);
    return hold;
  }

  /// Puts [values] on the device as the active values that came from the
  /// project, as a start of the app finds what an earlier launch activated:
  /// the plugin gets them when Firebase is initialized, so call it before
  /// that.
  void restoreActive(Map<String, String> values) {
    active = {...values};
    firebasePluginConstants[_plugin] = _constants;
  }

  /// The project publishes [values], which a fetch gets from then on. While
  /// the plugin listens to the real-time updates, the device fetches them at
  /// once and tells the plugin of the parameters whose values differ from
  /// the active ones, as Firebase does.
  Future<void> publish(Map<String, String> values) async {
    project.addAll(values);
    if (!listening) return;
    final fetched = _fetched = {...project};
    _fetchedNow();
    final changed = [
      for (final parameter in {...fetched.keys, ...active.keys})
        if (fetched[parameter] != active[parameter]) parameter,
    ];
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      _updates.name,
      _updates.codec.encodeSuccessEnvelope(changed),
      (_) {},
    );
  }

  /// What the plugin gets when Firebase is initialized: the settings, the
  /// last fetch, and the values, as the platform keeps them.
  Map<String, Object?> get _constants => {
        'fetchTimeout': _fetchTimeoutSeconds,
        'minimumFetchInterval': _minimumFetchIntervalSeconds,
        'lastFetchTime': _lastFetch?.millisecondsSinceEpoch ?? 0,
        'lastFetchStatus': _lastFetchStatus,
        'parameters': _parameters,
      };

  /// The values of the device as the platform gives them to the plugin: the
  /// active value of each parameter that came from the project, or else the
  /// default that the app set, each with its source.
  Map<String, Object?> get _parameters => {
        for (final MapEntry(key: parameter, value: text) in _defaults.entries)
          parameter: _value(text, 'default'),
        for (final MapEntry(key: parameter, value: text) in active.entries)
          parameter: _value(text, 'remote'),
      };

  static Map<String, Object?> _value(String text, String source) => {
        'value': Uint8List.fromList(utf8.encode(text)),
        'source': source,
      };

  /// The device fetched what the project has.
  void _fetchedNow() {
    _lastFetch = DateTime.now();
    _lastFetchStatus = 'success';
  }

  /// Asks the project for its values, unless the last fetch is more recent
  /// than the minimum fetch interval.
  void _fetch() {
    final last = _lastFetch;
    if (last != null &&
        DateTime.now().difference(last) <
            Duration(seconds: _minimumFetchIntervalSeconds)) {
      return;
    }
    _fetched = {...project};
    _fetchedNow();
  }

  /// Makes what the last fetch got active, and returns whether that changed
  /// the active values.
  bool _activate() {
    final fetched = _fetched;
    _fetched = null;
    if (fetched == null) return false;
    final changed = fetched.length != active.length ||
        fetched.entries.any((entry) => active[entry.key] != entry.value);
    active = fetched;
    return changed;
  }

  /// Answers the messages of the plugin to the platform.
  void _install() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const codec = FirebaseRemoteConfigHostApi.pigeonChannelCodec;
    void answer(
        String method, Object? Function(List<Object?> arguments) handle) {
      messenger.setMockMessageHandler('$_channels$method', (message) async {
        final arguments =
            (codec.decodeMessage(message)! as List<Object?>).sublist(1);
        calls.add([method, ...arguments]);
        final holds = _holds[method];
        if (holds != null && holds.isNotEmpty) await holds.removeAt(0).future;
        if (_failures.remove(method) case final failure?) {
          if (method == 'fetch') _lastFetchStatus = 'failure';
          return codec.encodeMessage(<Object?>[
            'firebase_remote_config',
            failure.message,
            {'code': failure.code, 'message': failure.message},
          ]);
        }
        return codec.encodeMessage(<Object?>[handle(arguments)]);
      });
    }

    answer('ensureInitialized', (_) => null);
    answer('setConfigSettings', (arguments) {
      final settings = arguments[0]! as RemoteConfigPigeonSettings;
      _fetchTimeoutSeconds = settings.fetchTimeoutSeconds;
      _minimumFetchIntervalSeconds = settings.minimumFetchIntervalSeconds;
      return null;
    });
    answer('setDefaults', (arguments) {
      _defaults = {
        for (final MapEntry(:key, :value)
            in (arguments[0]! as Map<Object?, Object?>).entries)
          '$key': '$value',
      };
      return null;
    });
    answer('fetch', (_) {
      _fetch();
      return null;
    });
    answer('activate', (_) => _activate());
    answer('fetchAndActivate', (_) {
      _fetch();
      return _activate();
    });
    answer('getAll', (_) => _parameters);
    answer('getProperties', (_) {
      final constants = {..._constants}..remove('parameters');
      return constants;
    });
    answer('setCustomSignals', (_) => null);
    messenger.setMockMethodCallHandler(_updates, (call) async {
      calls.add([call.method]);
      listening = call.method == 'listen';
      return null;
    });
    firebasePluginConstants[_plugin] = _constants;
  }
}

/// Answers the platform side of Firebase Remote Config with a device that
/// has activated nothing and a project with the parameter outside the app
/// alone, and returns it: a test reads there what reached the platform side,
/// and scripts what the project publishes and what the platform answers.
/// The plugin starts with what the device has, as on a first launch of the
/// app.
///
/// The binding of the tests must be initialized first. A test file that
/// calls it for a device of its own does so before the app starts or
/// Firebase is initialized, since the plugin takes what the device kept
/// when it starts.
MockFirebaseRemoteConfig mockFirebaseRemoteConfig() =>
    MockFirebaseRemoteConfig._().._install();
