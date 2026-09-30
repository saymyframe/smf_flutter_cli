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
// service log of the fixtures, which notes each call and misbehaves when
// the test says so, and the fixture crash reporting, through its platform
// side. The service log is created with the app, and the fixture crash
// reporting starts asynchronously, so it comes after the log among the
// crash reporters of the app. What another crash reporter, such as
// Crashlytics, does with a call, only the tests of its own module know.
// The matrix sets up the mocks of the platform side of every module of the
// app before the tests, so the start-up runs whatever other modules the
// app has.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/crash_reporting/crash_reporter.dart';
import 'package:{{app_name}}/core/fixture_service_log/fixture_service_log.dart';

import 'crash_reporting_role.dart';

/// Why each crash reporter must get what it got.
const _once = 'Each call reaches every crash reporter once, in the order of '
    'the calls.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  putBackTheHandlersAfterAll();
  // The errors of Flutter that the handler that the start-up finds
  // presents, which the handler of the role calls first.
  final presented = <FlutterErrorDetails>[];
  // What reached the platform side of the fixture crash reporting: each
  // call as its method and its arguments.
  final fixtureCalls = <List<Object?>>[];

  setUpAll(() async {
    recordFixtureCrash(fixtureCalls);
    final (failure, _) = await runStartUp(presented.add);
    expect(failure, isNull, reason: 'The app starts.');
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
    final details = detailsOf(StateError('broken in a build'));

    final uncaught = await runHandler(() => FlutterError.onError!(details));

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

    final uncaught = await runHandler(
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
    final details = detailsOf(StateError('shown'));

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
      final details = detailsOf(StateError('broken in a build'));
      final error = StateError('broken later');
      final uncaught = <Object>[];
      Object? failed;

      final printed = await printedBy(() async {
        uncaught
          ..addAll(await runHandler(() => FlutterError.onError!(details)))
          ..addAll(
            await runHandler(
              () => PlatformDispatcher.instance.onError!(
                error,
                StackTrace.current,
              ),
            ),
          );
        failed = await failureOf(() => createCrashReporter().log('saved'));
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
