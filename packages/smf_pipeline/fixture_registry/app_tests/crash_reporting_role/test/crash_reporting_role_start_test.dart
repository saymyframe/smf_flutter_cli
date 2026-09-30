// A test of the crash reporting role that continuous integration runs in
// the app with every module of the registry of several providers, whichever
// modules provide the role there: a crash reporter that starts
// asynchronously fails to start, as a service does whose platform side is
// broken. The start-up leaves that crash reporter out, prints its error in
// debug mode and installs the handlers of the errors, and the app starts,
// and the other crash reporters work.
//
// The platform side of the fixture crash reporting fails its start in this
// test, and the service log of the fixtures, which the app creates with the
// start-up, is the other crash reporter that it looks at. The crash
// reporters are created once for the tests of this file.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/crash_reporting/crash_reporter.dart';
import 'package:{{app_name}}/core/fixture_service_log/fixture_service_log.dart';

import 'crash_reporting_role.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  putBackTheHandlersAfterAll();
  // The errors of Flutter that the handler that the start-up finds
  // presents, which the handler of the role calls first.
  final presented = <FlutterErrorDetails>[];
  // What reached the platform side of the fixture crash reporting after its
  // start: each call as its method and its arguments.
  final fixtureCalls = <List<Object?>>[];
  Object? failure;
  var printed = <String>[];

  setUpAll(() async {
    recordFixtureCrash(fixtureCalls, failStart: true);
    (failure, printed) = await runStartUp(presented.add);
  });

  test(
      'the start-up leaves out a crash reporter that fails to start, and '
      'prints its error once in debug mode', () {
    expect(
      failure,
      isNull,
      reason: 'The app starts without the crash reporter.',
    );
    expect(
      printed.where(
        (line) =>
            line.contains('initFixtureCrashReporter()') &&
            line.contains('The fixture crash reporting does not start.'),
      ),
      hasLength(1),
      reason: 'In debug mode, the start-up prints the error of the start '
          'once, with the name of the function that starts the crash '
          'reporter.',
    );
  });

  test(
      'the other crash reporters get each error that nothing catches, and '
      'each call', () async {
    final details = detailsOf(StateError('broken in a build'));

    final uncaught = await runHandler(() => FlutterError.onError!(details));
    final failed = await failureOf(() => createCrashReporter().log('saved'));

    expect(
      [for (final call in loggedCrashReporterCalls) call.first],
      ['recordFlutterError', 'log'],
      reason: 'The handlers of the errors that the start-up installed, and '
          'the crash reporter of the app, reach the service log.',
    );
    expect(loggedCrashReporterCalls, [
      ['recordFlutterError', same(details), true],
      ['log', 'saved'],
    ]);
    expect(
      presented,
      hasLength(1),
      reason: 'The handler of the errors of Flutter that the start-up found '
          'presents the error once.',
    );
    expect(
      fixtureCalls,
      isEmpty,
      reason: 'The fixture crash reporting, which the start-up left out, '
          'gets nothing.',
    );
    expect(uncaught, isEmpty);
    expect(failed, isNull, reason: 'The call does not fail.');
  });
}
