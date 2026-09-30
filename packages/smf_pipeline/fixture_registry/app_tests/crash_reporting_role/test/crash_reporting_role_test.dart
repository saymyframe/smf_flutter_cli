// A test of the crash reporting role that continuous integration runs in
// the app with every module of the registry of several providers, whichever
// modules provide the role there: the start-up of the app installs the
// handlers of the role, which report each error that nothing catches to
// every crash reporter once, as fatal, and the crash reporter of the app,
// createCrashReporter(), forwards each call to every crash reporter once.
// A crash reporter that throws as it is called, or whose report fails,
// keeps no other from the call, and its failure reaches neither the code
// that called nor the handlers of the errors, which would report it again
// to the same crash reporter, without end.
//
// It looks only at what reaches the fixture providers of the role: the
// service log of the fixtures, which notes each call and fails when the
// test says so, and the fixture crash reporting, through its platform side.
// The service log is created with the app, and the fixture crash reporting
// starts asynchronously, so it comes after the log among the crash
// reporters of the app. What another crash reporter, such as Crashlytics,
// does with a call, only the tests of its own module know. The matrix sets
// up the mocks of the platform side of every module of the app before the
// tests, so the start-up runs whatever other modules the app has.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/bootstrap.dart';
import 'package:{{app_name}}/core/crash_reporting/crash_reporter.dart';
import 'package:{{app_name}}/core/fixture_crash/fixture_crash.dart';
import 'package:{{app_name}}/core/fixture_service_log/fixture_service_log.dart';

/// The number of errors that nothing catches that [_handle] sends to the
/// handler of the platform dispatcher, beyond which it takes the reports
/// for a loop and stops it.
const _loopLimit = 10;

/// Why each crash reporter must get what it got.
const _once = 'Each call reaches every crash reporter once, in the order of '
    'the calls.';

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
Future<List<Object>> _handle(void Function() handler) async {
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
Future<Object?> _failureOf(Future<void> Function() call) async {
  try {
    await call();
  } on Object catch (error) {
    return error;
  }
  return null;
}

/// Runs [body] and returns the lines that it printed with debugPrint.
Future<List<String>> _printed(Future<void> Function() body) async {
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
FlutterErrorDetails _detailsOf(Object exception) => FlutterErrorDetails(
      exception: exception,
      stack: StackTrace.current,
      library: 'the test',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final onErrorBefore = FlutterError.onError;
  final onPlatformErrorBefore = PlatformDispatcher.instance.onError;
  final errorWidgetBuilderBefore = ErrorWidget.builder;
  // The errors of Flutter that the handler that the start-up finds
  // presents, which the handler of the role calls first.
  final presented = <FlutterErrorDetails>[];
  // What reached the platform side of the fixture crash reporting: each
  // call as its method and its arguments.
  final fixtureCalls = <List<Object?>>[];

  setUpAll(() async {
    FlutterError.onError = presented.add;
    await bootstrap();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fixtureCrashChannel, (call) async {
      fixtureCalls.add([call.method, call.arguments]);
      return null;
    });
  });

  // The start-up replaced the handlers of the errors, and the widget of an
  // error: the tests use its handlers, and put back those of flutter_test
  // after the last.
  tearDownAll(() {
    FlutterError.onError = onErrorBefore;
    PlatformDispatcher.instance.onError = onPlatformErrorBefore;
    ErrorWidget.builder = errorWidgetBuilderBefore;
  });

  setUp(() {
    presented.clear();
    fixtureCalls.clear();
    loggedCrashReporterCalls.clear();
  });

  tearDown(() => serviceLogFailure = ServiceLogFailure.none);

  test(
      'an error of Flutter reaches every crash reporter once, as fatal, once '
      'the handler that the start-up found presents it', () async {
    final details = _detailsOf(StateError('broken in a build'));

    final uncaught = await _handle(() => FlutterError.onError!(details));

    expect(
      presented,
      hasLength(1),
      reason: 'The handler of the errors of Flutter that the start-up found '
          'presents each of them once.',
    );
    expect(presented.single, same(details));
    expect(
      loggedCrashReporterCalls,
      [
        ['recordFlutterError', same(details), true],
      ],
      reason: _once,
    );
    expect(
      fixtureCalls,
      [
        [
          'recordError',
          {'error': 'Bad state: broken in a build', 'fatal': true},
        ],
      ],
      reason: _once,
    );
    expect(uncaught, isEmpty);
  });

  test(
      'an error that nothing catches reaches every crash reporter once, as '
      'fatal, and stays unhandled in debug mode, so that the engine prints '
      'it', () async {
    final error = StateError('broken later');
    bool? handled;

    final uncaught = await _handle(
      () => handled = PlatformDispatcher.instance.onError!(
        error,
        StackTrace.current,
      ),
    );

    expect(
      handled,
      !kDebugMode,
      reason: 'The handler leaves the error unhandled in debug mode only.',
    );
    expect(
      loggedCrashReporterCalls,
      [
        ['recordError', same(error), true, null],
      ],
      reason: _once,
    );
    expect(
      fixtureCalls,
      [
        [
          'recordError',
          {'error': 'Bad state: broken later', 'fatal': true, 'reason': null},
        ],
      ],
      reason: _once,
    );
    expect(uncaught, isEmpty);
  });

  test(
      'the crash reporter of the app forwards each call to every crash '
      'reporter once', () async {
    final reporter = createCrashReporter();
    final error = ArgumentError('caught');
    final details = _detailsOf(StateError('shown'));

    await reporter.recordError(
      error,
      StackTrace.current,
      reason: 'while saving',
    );
    await reporter.recordFlutterError(details);
    await reporter.log('saved');
    await reporter.setUserId('user-1');
    await reporter.setUserId(null);

    expect(
      loggedCrashReporterCalls,
      [
        ['recordError', same(error), false, 'while saving'],
        ['recordFlutterError', same(details), false],
        ['log', 'saved'],
        ['setUserId', 'user-1'],
        ['setUserId', null],
      ],
      reason: _once,
    );
    expect(
      fixtureCalls,
      [
        [
          'recordError',
          {
            'error': 'Invalid argument(s): caught',
            'fatal': false,
            'reason': 'while saving',
          },
        ],
        [
          'recordError',
          {'error': 'Bad state: shown', 'fatal': false},
        ],
        ['log', 'saved'],
        ['setUserId', 'user-1'],
        ['setUserId', null],
      ],
      reason: _once,
    );
  });

  for (final (failure, how) in [
    (ServiceLogFailure.throwing, 'throws as it is called'),
    (ServiceLogFailure.failing, 'returns a future that fails'),
  ]) {
    test(
        'a crash reporter that $how keeps no other from a call, and its '
        'failure reaches neither the code that called nor the handlers of '
        'the errors', () async {
      serviceLogFailure = failure;
      final details = _detailsOf(StateError('broken in a build'));
      final error = StateError('broken later');
      final uncaught = <Object>[];
      Object? failed;

      final printed = await _printed(() async {
        uncaught
          ..addAll(await _handle(() => FlutterError.onError!(details)))
          ..addAll(
            await _handle(
              () => PlatformDispatcher.instance.onError!(
                error,
                StackTrace.current,
              ),
            ),
          );
        failed = await _failureOf(() => createCrashReporter().log('saved'));
      });

      expect(
        fixtureCalls,
        [
          [
            'recordError',
            {'error': 'Bad state: broken in a build', 'fatal': true},
          ],
          [
            'recordError',
            {'error': 'Bad state: broken later', 'fatal': true, 'reason': null},
          ],
          ['log', 'saved'],
        ],
        reason: 'Every other crash reporter gets each call once, and no '
            'report of the failure of the service log.',
      );
      expect(
        loggedCrashReporterCalls,
        [
          ['recordFlutterError', same(details), true],
          ['recordError', same(error), true, null],
          ['log', 'saved'],
        ],
        reason: 'The service log gets each call once, and no report of its '
            'own failure.',
      );
      expect(
        uncaught,
        isEmpty,
        reason: 'The failure of a report goes back to no handler of the '
            'errors.',
      );
      expect(
        failed,
        isNull,
        reason: 'The failure of one crash reporter does not reach the code '
            'that called the crash reporter of the app.',
      );
      expect(
        printed.where((line) => line.contains('The service log failed on')),
        hasLength(3),
        reason: 'In debug mode, the crash reporter of the app prints each '
            'failure of a crash reporter, once.',
      );
    });
  }
}
