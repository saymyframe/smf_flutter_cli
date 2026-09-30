// What the tests of the analytics role share: the start-up of the app,
// which creates the analytics services, the calls that reach the platform
// side of the fixture analytics, and what a call printed or threw.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/bootstrap.dart';
import 'package:{{app_name}}/core/fixture_analytics/fixture_analytics.dart';

/// Runs the start-up of the app, which creates the analytics services, and
/// then puts back the handlers of the errors and the widget of an error,
/// which it may replace, as the start-up of an app that reports its crashes
/// does: the tests of analytics do not look at them.
///
/// Returns what the start-up threw, or `null`, and the lines that it
/// printed with debugPrint.
Future<(Object?, List<String>)> runStartUp() async {
  final onError = FlutterError.onError;
  final onPlatformError = PlatformDispatcher.instance.onError;
  final errorWidgetBuilder = ErrorWidget.builder;
  Object? failure;
  try {
    final printed = await printedBy(() async {
      failure = await failureOf(bootstrap);
    });
    return (failure, printed);
  } finally {
    FlutterError.onError = onError;
    PlatformDispatcher.instance.onError = onPlatformError;
    ErrorWidget.builder = errorWidgetBuilder;
  }
}

/// Answers the platform side of the fixture analytics, which records in
/// [calls] each call that reaches it but its start, as its method and its
/// arguments. With [failStart], its start fails, as the start of a service
/// does whose platform side is broken.
///
/// It replaces the mocks of the fixture that the matrix set up.
void recordFixtureAnalytics(
  List<List<Object?>> calls, {
  bool failStart = false,
}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(fixtureAnalyticsChannel, (call) async {
    if (call.method == 'start') {
      if (failStart) {
        throw PlatformException(
          code: 'broken',
          message: 'The fixture analytics does not start.',
        );
      }
      return null;
    }
    calls.add([call.method, call.arguments]);
    return null;
  });
}

/// Awaits [call] and returns what it threw, or `null`.
Future<Object?> failureOf(Future<void> Function() call) async {
  try {
    await call();
  } on Object catch (error) {
    return error;
  }
  return null;
}

/// Runs [body] and returns the lines that it printed with debugPrint.
Future<List<String>> printedBy(Future<void> Function() body) async {
  final lines = <String>[];
  final debugPrintBefore = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) =>
      lines.addAll((message ?? '').split('\n'));
  try {
    await body();
  } finally {
    debugPrint = debugPrintBefore;
  }
  return lines;
}
