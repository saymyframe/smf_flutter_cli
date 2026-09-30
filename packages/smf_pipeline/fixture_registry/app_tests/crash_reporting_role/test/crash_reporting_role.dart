// What the tests of the crash reporting role share: the start-up of the
// app, which creates the crash reporters and installs the handlers of the
// errors, the calls that reach the platform side of the fixture crash
// reporting, the handlers run as an app runs them, and what a call printed
// or threw.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/bootstrap.dart';
import 'package:{{app_name}}/core/fixture_crash/fixture_crash.dart';

/// The number of errors that nothing catches that [runHandler] sends to
/// the handler of the platform dispatcher, beyond which it takes the
/// reports for a loop and stops it.
const _loopLimit = 10;

/// Keeps the handlers of the errors, and the builder of the widget of an
/// error, that flutter_test has now, and puts them back after the last test
/// of the file: the start-up of the app replaces them, and the tests use
/// its handlers.
void putBackTheHandlersAfterAll() {
  final onError = FlutterError.onError;
  final onPlatformError = PlatformDispatcher.instance.onError;
  final errorWidgetBuilder = ErrorWidget.builder;
  tearDownAll(() {
    FlutterError.onError = onError;
    PlatformDispatcher.instance.onError = onPlatformError;
    ErrorWidget.builder = errorWidgetBuilder;
  });
}

/// Runs the start-up of the app, which creates the crash reporters and
/// installs the handlers of the errors, with [present] as the handler of
/// the errors of Flutter that it finds, which the handler of the role calls
/// first.
///
/// Returns what the start-up threw, or `null`, and the lines that it
/// printed with debugPrint.
Future<(Object?, List<String>)> runStartUp(
  FlutterExceptionHandler present,
) async {
  FlutterError.onError = present;
  Object? failure;
  final printed = await printedBy(() async {
    failure = await failureOf(bootstrap);
  });
  return (failure, printed);
}

/// Answers the platform side of the fixture crash reporting, which records
/// in [calls] each call that reaches it but its start, as its method and
/// its arguments. With [failStart], its start fails, as the start of a
/// service does whose platform side is broken.
///
/// It replaces the mocks of the fixture that the matrix set up.
void recordFixtureCrash(List<List<Object?>> calls, {bool failStart = false}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(fixtureCrashChannel, (call) async {
    if (call.method == 'start') {
      if (failStart) {
        throw PlatformException(
          code: 'broken',
          message: 'The fixture crash reporting does not start.',
        );
      }
      return null;
    }
    calls.add([call.method, call.arguments]);
    return null;
  });
}

/// Runs [handler], a handler of the errors that nothing catches, as an app
/// runs it, and waits for the reports that it starts; returns the errors
/// that nothing caught meanwhile.
///
/// In an app, an error that nothing catches, such as the failure of a
/// report that nothing awaits, goes to PlatformDispatcher.instance.onError,
/// and what that handler starts runs in the root zone of the app again. A
/// test runs in a zone of its own, which fails the test on such an error
/// instead. So [handler] runs in a zone that sends each error that nothing
/// catches to the handler of the platform dispatcher and runs it there, as
/// the engine does in an app, up to [_loopLimit] of them.
Future<List<Object>> runHandler(void Function() handler) async {
  final uncaught = <Object>[];
  Zone.current.fork(
    specification: ZoneSpecification(
      handleUncaughtError: (self, parent, zone, error, stackTrace) {
        uncaught.add(error);
        if (uncaught.length > _loopLimit) return;
        self.run(
          () => PlatformDispatcher.instance.onError?.call(
            error,
            stackTrace,
          ),
        );
      },
    ),
  ).run(handler);
  await pumpEventQueue();
  return uncaught;
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

/// The details of an error of Flutter with [exception].
FlutterErrorDetails detailsOf(Object exception) => FlutterErrorDetails(
      exception: exception,
      stack: StackTrace.current,
      library: 'the test',
    );
