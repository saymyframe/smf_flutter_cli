// What the tests of the remote config role share, in the apps with the role,
// whichever module provides it: the start-up of the app, which runs once for
// the tests of a file, what runs a call in real time, what waits a moment and
// what brings the user back to the app, the values of the parameters of the
// app as a test compares them, texts that the type of a parameter takes and
// does not take, and a service of remote config of the tests, which scripts
// what a provider answers.
//
// It knows only the role. The matrix writes the parameters of the app into
// keys.dart, from the data of the role.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/bootstrap.dart';
import 'package:{{app_name}}/core/remote_config/app_remote_config.dart';
import 'package:{{app_name}}/core/remote_config/remote_config_service.dart';

import 'keys.dart';

/// Runs [action], which [what] names, in real time, as on a device, so that
/// what it waits for, such as the platform side of the provider, does not
/// wait for the fake time of the test. An error of [action] fails the test,
/// which tester.runAsync would only report to the handler of the errors of
/// Flutter.
Future<void> inRealTime(
  WidgetTester tester,
  String what,
  Future<void> Function() action,
) async {
  Object? error;
  StackTrace? stackTrace;
  await tester.runAsync(() async {
    try {
      await action();
    } on Object catch (thrown, stack) {
      error = thrown;
      stackTrace = stack;
    }
  });
  if (error != null) fail('$what threw $error\n$stackTrace');
}

/// The problem of the start-up of the app, which runs once for the tests of
/// a file: `null` before it runs, and empty if it passed.
String? _startUpProblem;

/// Runs the start-up of the app, bootstrap(), as main() runs it before the
/// first frame, in real time, unless a test of the file ran it already, and
/// fails the test if it failed. The handlers of errors that the start-up
/// installs, such as those of crash reporting, and the builder of the widget
/// of an error go back to those of the test once it returns.
Future<void> startUp(WidgetTester tester) async {
  if (_startUpProblem == null) {
    final onError = FlutterError.onError;
    final onPlatformError = PlatformDispatcher.instance.onError;
    final errorWidgetBuilder = ErrorWidget.builder;
    try {
      _startUpProblem = '';
      await inRealTime(tester, 'bootstrap()', bootstrap);
    } on TestFailure catch (failure) {
      _startUpProblem = failure.message ?? 'bootstrap() failed';
    } finally {
      FlutterError.onError = onError;
      PlatformDispatcher.instance.onError = onPlatformError;
      ErrorWidget.builder = errorWidgetBuilder;
    }
  }
  if (_startUpProblem case final problem? when problem.isNotEmpty) {
    fail(problem);
  }
}

/// Waits a moment in real time, for what a call set off to happen, such as
/// the fetch that the role makes a turn of the event loop after a start.
Future<void> aMoment() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

/// Brings the user back to the app, and waits a moment for the app to fetch.
Future<void> comeBack(WidgetTester tester) => inRealTime(
      tester,
      'coming back to the app',
      () async {
        tester.binding
          ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
          ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await aMoment();
      },
    );

/// The values of the parameters of the app in [values], by name.
Map<String, Object> valuesOf(RemoteValues values) => {
      for (final parameter in appParameters)
        parameter.name: parameter.read(values),
    };

/// The default of each parameter of the app, by name.
Map<String, Object> get defaultsOfApp => {
      for (final parameter in appParameters)
        parameter.name: parameter.defaultValue,
    };

/// A text that the type of [parameter] takes, and the value that the app
/// reads of it, which differs from the default of the parameter.
(String, Object) validTextOf(AppParameter parameter) =>
    switch ((parameter.type, parameter.defaultValue)) {
      ('boolean', final bool value) =>
        value ? ('FALSE', false) : ('True', true),
      ('integer', final int value) => ('${value + 1}', value + 1),
      ('decimal', final double value) => ('${value + 0.25}', value + 0.25),
      (_, final Object value) => (
          '$value, from the backend',
          '$value, from the backend'
        ),
    };

/// A text that the type of [parameter] does not take, or `null` for a text,
/// which takes any.
String? invalidTextOf(AppParameter parameter) => switch (parameter.type) {
      'boolean' => 'yes',
      'integer' => '1.5',
      'decimal' => 'many',
      _ => null,
    };

/// A service of remote config of the tests, which a test gives
/// appRemoteConfig.start() to script what a provider answers: what the
/// device kept of the last fetch, what the backend has, and whether it tells
/// of the values that the backend publishes. It notes each call that reaches
/// it, and holds a call until a test lets it go.
final class ScriptedRemoteConfig implements RemoteConfigService {
  /// Creates the service on a device that kept [kept] of the last fetch, of
  /// a backend that has what it kept, which tells of the values that the
  /// backend publishes if [liveUpdates].
  ScriptedRemoteConfig({
    this.liveUpdates = false,
    Map<String, String> kept = const {},
  })  : _fetched = {...kept},
        backend = {...kept};

  @override
  final bool liveUpdates;

  /// What the backend has, by parameter, which a fetch gets: at first what
  /// the device kept, so that the fetch of a start changes nothing.
  Map<String, String> backend;

  /// The calls that reached the service, in their order: `open`,
  /// `activate` and `fetch`.
  final List<String> calls = [];

  /// The calls that wait until their completers complete, by name.
  final Map<String, Completer<void>> holds = {};

  Map<String, String> _fetched;
  Map<String, String> _active = {};

  final StreamController<void> _updates = StreamController<void>.broadcast();

  /// Whether something follows the values that the service tells of.
  bool get followed => _updates.hasListener;

  /// The backend publishes [values] while the app runs: the service fetches
  /// them and tells of them.
  void publish(Map<String, String> values) {
    backend = {...values};
    _fetched = {...values};
    _updates.add(null);
  }

  Future<void> _enter(String call) async {
    calls.add(call);
    await holds[call]?.future;
  }

  @override
  Future<void> open(
    Map<String, Object> defaults, {
    required Duration fetchInterval,
    required Duration fetchTimeout,
  }) =>
      _enter('open');

  @override
  Future<bool> activate() async {
    await _enter('activate');
    final changed = !mapEquals(_fetched, _active);
    _active = {..._fetched};
    return changed;
  }

  @override
  Map<String, String> get values => {..._active};

  @override
  Future<void> fetch() async {
    await _enter('fetch');
    _fetched = {...backend};
  }

  @override
  Stream<void> get updates => _updates.stream;
}

/// Holds the next [call] of [service] until a test completes its completer.
/// The completer is made in real time: one made in the fake time of the body
/// of a widget test would let the call go only once that time runs.
Future<void> holdInRealTime(
  WidgetTester tester,
  ScriptedRemoteConfig service,
  String call,
) =>
    inRealTime(tester, 'holding $call', () async {
      service.holds[call] = Completer<void>();
    });

/// Starts appRemoteConfig with [service], as the start-up of the app does
/// with the service of the provider, and waits a moment for what the start
/// sets off, such as the fetch a turn of the event loop after it.
Future<void> startWith(WidgetTester tester, ScriptedRemoteConfig service) =>
    inRealTime(tester, 'starting with a service of the test', () async {
      await appRemoteConfig.start(service);
      await aMoment();
    });
