// What the tests of the firebase_remote_config module share: the start of
// Firebase, which the service of the module works on, the start-up of the
// app, what runs a call in real time, what waits for a condition, and the
// platforms of the tests.
//
// The tests use the service of the module, which
// createFirebaseRemoteConfigService() creates, on the real Firebase
// packages, whose platform side is the device and the project in memory of
// firebase_remote_config_mocks.dart. They initialize Firebase as the
// start-up of the app does, and run the rest of the start-up only where they
// look at appRemoteConfig: what appRemoteConfig does with a service, and
// what every provider of the remote config role keeps to, is for the test of
// the role. The options of Firebase come with the tests of firebase_core,
// which every app with the module has.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/bootstrap.dart';
import 'package:{{app_name}}/core/remote_config/app_remote_config.dart';
import 'package:{{app_name}}/firebase_options_of_flavor.dart';

/// Why a test that needs the app to follow the values of Firebase is
/// skipped in an app without parameters, or `null` in an app with them.
final String? withoutParameters = RemoteValues.defaults.isEmpty
    ? 'The app has no parameter of remote config, so it asks Firebase '
        'nothing and follows no value that the project publishes: the app '
        'starts asking with its first parameter.'
    : null;

/// Why a test of an app without parameters is skipped in an app with them,
/// or `null` in an app without them.
final String? withParameters = RemoteValues.defaults.isEmpty
    ? null
    : 'The app has parameters of remote config, so it follows the values '
        'that the project publishes.';

/// A text that the type of the default [fallback] of a parameter of the app
/// takes, which differs from the text of the default.
String publishedTextOf(Object fallback) => switch (fallback) {
      final bool value => '${!value}',
      final int value => '${value + 1}',
      final double value => '${value + 0.25}',
      final Object value => '$value, published',
    };

/// A text for each parameter of the app that its type takes and that differs
/// from its default, by parameter: what a project publishes for the app.
Map<String, String> get publishedTextsOfApp => {
      for (final MapEntry(key: parameter, value: fallback)
          in RemoteValues.defaults.entries)
        parameter: publishedTextOf(fallback),
    };

/// Initializes Firebase, as the start-up of the app does before it creates
/// the service.
Future<void> initializeFirebase() =>
    Firebase.initializeApp(options: firebaseOptionsOfFlavor);

/// Makes the platform of the tests iOS: the test puts it back with
/// [onAndroid].
void onIOS() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

/// Puts the platform of the tests back to Android, which a test of iOS
/// changed.
void onAndroid() => debugDefaultTargetPlatformOverride = null;

/// Lets what the platform told the plugin reach the listeners of the
/// streams of the service.
Future<void> aMoment() => Future<void>.delayed(Duration.zero);

/// Waits in real time until [holds] does, for at most [within], and
/// returns whether it does.
Future<bool> until(
  bool Function() holds, {
  Duration within = const Duration(seconds: 1),
}) async {
  final end = DateTime.now().add(within);
  while (!holds() && DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return holds();
}

/// Runs [action], which [what] names, in real time, as on a device, so that
/// what it waits for does not wait for the fake time of the test. An error
/// of [action] fails the test, which tester.runAsync would only report to
/// the handler of the errors of Flutter.
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

/// Whether the start-up of the app ran in this test file.
bool _started = false;

/// Runs the start-up of the app, bootstrap(), as main() runs it before the
/// first frame, in real time, unless a test of the file ran it already, and
/// waits a moment for what it sets off, such as the fetch of an app with
/// parameters a turn of the event loop after the start of remote config.
/// The handlers of errors that the start-up installs, such as those of
/// crash reporting, and the builder of the widget of an error go back to
/// those of the test once it returns.
Future<void> startUp(WidgetTester tester) async {
  if (_started) return;
  _started = true;
  final onError = FlutterError.onError;
  final onPlatformError = PlatformDispatcher.instance.onError;
  final errorWidgetBuilder = ErrorWidget.builder;
  try {
    await inRealTime(tester, 'bootstrap()', () async {
      await bootstrap();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
  } finally {
    FlutterError.onError = onError;
    PlatformDispatcher.instance.onError = onPlatformError;
    ErrorWidget.builder = errorWidgetBuilder;
  }
}
