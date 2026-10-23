// What the tests of the revenuecat module share: the key of the tests, the
// service of the module with it, what returns the failure of a call, what
// makes the id of a user that no logIn named before, what runs a test on a
// platform, and the start-up of the app for the tests that go through
// appPurchases.
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/bootstrap.dart';
import 'package:{{app_name}}/core/purchases/purchases_service.dart';
import 'package:{{app_name}}/core/purchases/revenuecat_purchases_service.dart';

/// The key that the matrix of SMF writes into .env for the tests of an app
/// with the module under REVENUECAT_GOOGLE_KEY, and its value under
/// REVENUECAT_APPLE_KEY: keys that only the mocks take.
const String googleKeyOfTests = 'goog_tests';
const String appleKeyOfTests = 'appl_tests';

/// The service of the module with the key of the tests on Android, which
/// configures the RevenueCat of the mocks when it is created.
RevenueCatPurchasesService serviceOfTests() => RevenueCatPurchasesService(
      const RevenueCatKey('REVENUECAT_GOOGLE_KEY', googleKeyOfTests),
    );

/// What [call] failed with, or `null` if it completed.
Future<Object?> errorOf(Future<void> Function() call) async {
  try {
    await call();
    return null;
  } on Object catch (error) {
    return error;
  }
}

/// Matches a [PurchasesFailure] for [reason], with a hint that [hint]
/// matches, if given.
Matcher failsWith(PurchasesFailureReason reason, [Object? hint]) =>
    isA<PurchasesFailure>()
        .having((failure) => failure.reason, 'reason', reason)
        .having(
          (failure) => failure.developerHint,
          'developerHint',
          hint ?? anything,
        );

/// How many ids of users the tests of the file made.
int _users = 0;

/// A new id of a user of the app, which no logIn named before: [name], the
/// time and a number of its own.
String freshUser(String name) =>
    'revenuecat-$name-${DateTime.now().microsecondsSinceEpoch}-${++_users}';

/// Runs [body] while the app runs on [platform], as the plugin and the
/// mocks read it.
Future<T> onPlatform<T>(
  TargetPlatform platform,
  Future<T> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    return await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

/// Runs [action], which [what] names, in real time, as on a device, so
/// that what it waits for does not wait for the fake time of a widget test.
/// An error of [action] fails the test, which tester.runAsync would only
/// report to the handler of the errors of Flutter.
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

/// Whether the start-up of the app ran for the tests of the file.
bool _startedUp = false;

/// Runs the start-up of the app, bootstrap(), as main() runs it before the
/// first frame, in real time, unless a test of the file ran it already. The
/// handlers of errors that the start-up installs, such as those of crash
/// reporting, and the builder of the widget of an error go back to those of
/// the test once it returns.
Future<void> startUp(WidgetTester tester) async {
  if (_startedUp) return;
  _startedUp = true;
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

/// Brings the user back to the app, and waits a moment for the app to ask
/// RevenueCat again.
Future<void> comeBack(WidgetTester tester) =>
    inRealTime(tester, 'coming back to the app', () async {
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
