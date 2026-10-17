// What the tests of the firebase_messaging module share: the start of
// Firebase, which the service of the module works on, the start-up of the
// app, what runs a call in real time, how a test compares a push message,
// and the platforms of the tests.
//
// The tests use the service of the module, which
// createFirebasePushService() creates, on the real Firebase packages, whose
// platform side is the device in memory of firebase_messaging_mocks.dart.
// They initialize Firebase as the start-up of the app does, and run the
// rest of the start-up only where they look at appPush: what appPush does
// with a service, and what every provider of the push role keeps to, is
// for the test of the role. The options of Firebase come with the tests of
// firebase_core, which every app with the module has.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/bootstrap.dart';
import 'package:{{app_name}}/core/push/push_service.dart';
import 'package:{{app_name}}/firebase_options.dart';

/// Initializes Firebase, as the start-up of the app does before it creates
/// the service.
Future<void> initializeFirebase() => Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

/// Makes the platform of the tests iOS, with which the plugin asks for the
/// token of the Apple Push Notification service and the service sets the
/// presentation options: the test puts it back with [onAndroid].
void onIOS() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

/// Puts the platform of the tests back to Android, which a test of iOS
/// changed.
void onAndroid() => debugDefaultTargetPlatformOverride = null;

/// [message] as a test compares it: its id, its title, its body and its
/// data, or `none`.
String describe(PushMessage? message) => message == null
    ? 'none'
    : '${message.id} | ${message.title} | ${message.body} | ${message.data}';

/// Lets what the platform told the plugin reach the listeners of the
/// streams of the service.
Future<void> aMoment() => Future<void>.delayed(Duration.zero);

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

/// Runs the start-up of the app, bootstrap(), as main() runs it before the
/// first frame, in real time: it starts the push messages on the device of
/// the test. The handlers of errors that the start-up installs, such as
/// those of crash reporting, and the builder of the widget of an error go
/// back to those of the test once it returns.
Future<void> startUp(WidgetTester tester) async {
  final onError = FlutterError.onError;
  final onPlatformError = PlatformDispatcher.instance.onError;
  final errorWidgetBuilder = ErrorWidget.builder;
  try {
    await inRealTime(tester, 'bootstrap()', bootstrap);
  } finally {
    FlutterError.onError = onError;
    PlatformDispatcher.instance.onError = onPlatformError;
    ErrorWidget.builder = errorWidgetBuilder;
  }
}
