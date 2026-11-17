// A test that continuous integration runs in the apps with the sentry module
// whose .env has a DSN: the start of Sentry, initSentryCrashReporter(),
// leaves the handlers of the errors that nothing catches to the crash
// reporting of the app and sends no default PII, and the crash reporter
// of the module reports each of its calls to Sentry, with the environment of
// the flavor of the build, and neither presents nor prints what it reports.
//
// The app may have other crash reporters, which only the tests of their own
// modules know, so the test uses the reporter of the module rather than
// createCrashReporter(), which reports to all of them, and starts Sentry as
// the start-up of the app does, without the rest of the start-up;
// sentry_uncaught_errors_test.dart checks the handlers that the start-up
// installs. The mocks of Sentry keep the events and send none
// (sentry_mocks.dart), and the matrix sets them up before the tests.
//
// On Windows, flutter_tester gives Dart its arguments in the code page of
// Windows, and a read of them fails with an error that no catch takes once a
// path among them has a letter beyond ASCII, as the directory of the app may
// have. The processor of Sentry that adds the device and the runtime to each
// event reads them, so the start leaves it out there; the test checks that,
// and that a report completes in time wherever the app is.
@Timeout(Duration(minutes: 2))
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:{{app_name}}/core/crash_reporting/crash_reporter.dart';
import 'package:{{app_name}}/core/crash_reporting/sentry_crash_reporter.dart';

import '../sentry_mocks.dart';
import 'sentry.dart';

/// A handler of the errors of Flutter that the start of Sentry finds.
void _flutterErrors(FlutterErrorDetails details) {}

/// The class of the processor of Sentry that adds the device, the system
/// and the runtime to each event, which the start leaves out on Windows by
/// this name.
const _enricher = 'IoEnricherEventProcessor';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('With a DSN, the start of Sentry', () {
    late CrashReporter reporter;
    late FlutterExceptionHandler? flutterErrorsAfter;
    late SentryFlutterOptions options;

    setUpAll(() async {
      final flutterErrorsBefore = FlutterError.onError;
      final platformErrorsBefore = PlatformDispatcher.instance.onError;
      final mocks = configureSentryForTests;
      configureSentryForTests = (started) {
        mocks?.call(started);
        options = started;
      };
      FlutterError.onError = _flutterErrors;
      try {
        reporter = await initSentryCrashReporter();
      } finally {
        configureSentryForTests = mocks;
        flutterErrorsAfter = FlutterError.onError;
        FlutterError.onError = flutterErrorsBefore;
        PlatformDispatcher.instance.onError = platformErrorsBefore;
      }
    });

    setUp(sentryEvents.clear);

    test(
        'leaves out the processor of Sentry that reads the arguments of the '
        'process on Windows, where the app runs only in flutter test, and '
        'keeps it elsewhere', () {
      final processors = [
        for (final processor in options.eventProcessors)
          '${processor.runtimeType}',
      ];
      if (Platform.isWindows) {
        expect(
          processors,
          isNot(contains(_enricher)),
          reason: 'flutter_tester gives Dart its arguments in the code page '
              'of Windows, and the processor reads them for each event, which '
              'fails with an error that no catch takes once the path of the '
              'app has a letter beyond ASCII: the event never reaches Sentry.',
        );
      } else {
        expect(
          processors,
          contains(_enricher),
          reason: 'The start leaves out the processor by the name of its '
              'class on Windows, so Sentry still has a processor of that name.',
        );
      }
    });

    // The deadline fails a report that waits for good, such as on a future
    // that never completes. It does not catch the processor above: its error
    // stops the isolate, so no timer fires, and the test of the processor is
    // the one that fails on it.
    test('completes a report in time, wherever the app is', () async {
      await reporter
          .recordError(StateError('wherever the app is'), StackTrace.current)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => fail(
              'The report did not complete in 30 seconds, so a test that '
              'reports an error to Sentry would wait for good.',
            ),
          );

      expect(await eventsOf('Bad state: wherever the app is'), hasLength(1));
    });

    test(
        'starts Sentry and leaves the handlers of the errors to the crash '
        'reporting of the app: it puts back the handler of the errors of '
        'Flutter that it found, and removes the integration of Sentry that '
        'takes the handler of the other errors', () async {
      expect(Sentry.isEnabled, isTrue);
      expect(reporter, isA<SentryCrashReporter>());
      expect(
        flutterErrorsAfter,
        same(_flutterErrors),
        reason: 'The start of Sentry put back FlutterError.onError, which '
            'the integration of Sentry for the errors of Flutter replaces, so '
            'that such an error reaches Sentry once.',
      );
      // flutter_test keeps no handler that a test gives
      // PlatformDispatcher.instance.onError, so the test reads the
      // integrations that ran, which each event lists.
      await reporter.recordError(StateError('for the integrations'), null);
      final event = (await eventsOf('Bad state: for the integrations')).single;
      final integrations = event.sdk?.integrations ?? const <String>[];
      expect(integrations, contains('flutterErrorIntegration'));
      expect(
        integrations,
        isNot(contains('OnErrorIntegration')),
        reason: 'The start of Sentry removed OnErrorIntegration, which would '
            'take PlatformDispatcher.instance.onError, a handler of the crash '
            'reporting of the app.',
      );
    });

    test(
        'reports an error that the code reports, as handled, and a fatal one '
        'as unhandled, each with its level, its reason and the environment of '
        'the flavor of the build', () async {
      await reporter.recordError(
        ArgumentError('caught'),
        StackTrace.current,
        reason: 'while saving',
      );
      await reporter.recordError(
        StateError('broken later'),
        StackTrace.current,
        fatal: true,
      );

      final caught = (await eventsOf('Invalid argument(s): caught')).single;
      final fatal = (await eventsOf('Bad state: broken later')).single;
      expect(caught.environment, '{{default_flavor}}');
      expect(fatal.environment, '{{default_flavor}}');
      expect(
        (
          exceptionOf(caught).mechanism?.type,
          exceptionOf(caught).mechanism?.handled,
          caught.level,
        ),
        ('CrashReporter.recordError', true, SentryLevel.error),
      );
      expect(caught.contexts['reason'], {'reason': 'while saving'});
      expect(
        caught.user?.ipAddress,
        isNull,
        reason: 'Sentry starts without its default PII, so an event asks '
            'Sentry for no IP address of the user.',
      );
      expect(exceptionOf(caught).stackTrace?.frames, isNotEmpty);
      expect(
        (
          exceptionOf(fatal).mechanism?.type,
          exceptionOf(fatal).mechanism?.handled,
          fatal.level,
        ),
        ('CrashReporter.recordError', false, SentryLevel.fatal),
      );
      expect(fatal.contexts['reason'], isNull);
    });

    test(
        'reports an error of Flutter with what Flutter tells of it, and '
        'neither presents nor prints what it reports', () async {
      final details = FlutterErrorDetails(
        exception: StateError('broken in a build'),
        stack: StackTrace.current,
        library: 'the test',
        context: ErrorDescription('while building the test'),
        informationCollector: () => [ErrorDescription('The widget was new.')],
      );

      late List<String> lines;
      final errors = await presented(() async {
        lines = await printed(() async {
          await reporter.recordFlutterError(details, fatal: true);
          await reporter.recordError(StateError('quiet'), null);
          await reporter.log('quiet');
          await reporter.setUserId('quiet');
          await reporter.setUserId(null);
        });
      });

      expect(errors, isEmpty);
      expect(lines, isEmpty);
      final event = (await eventsOf('Bad state: broken in a build')).single;
      expect(
        (
          exceptionOf(event).mechanism?.type,
          exceptionOf(event).mechanism?.handled,
          event.level,
        ),
        ('CrashReporter.recordFlutterError', false, SentryLevel.fatal),
      );
      expect(event.contexts['flutter_error_details'], {
        'context': 'thrown while building the test',
        'information': 'The widget was new.',
        'library': 'the test',
      });
    });

    test(
        'adds what the code logs to the next report, and reports for the user '
        'that the code sets until it clears it', () async {
      await reporter.log('saved the note');
      await reporter.setUserId('user-1');
      await reporter.recordError(StateError('for the user'), null);
      await reporter.setUserId(null);
      await reporter.recordError(StateError('for nobody'), null);

      final forUser = (await eventsOf('Bad state: for the user')).single;
      final forNobody = (await eventsOf('Bad state: for nobody')).single;
      expect(
        [
          for (final breadcrumb in forUser.breadcrumbs ?? const <Breadcrumb>[])
            if (breadcrumb.category == 'log') breadcrumb.message,
        ],
        contains('saved the note'),
      );
      expect(forUser.user?.id, 'user-1');
      expect(
        forUser.user?.ipAddress,
        isNull,
        reason: 'Sentry starts without its default PII, so the user of an '
            'event has the id that the code set and no IP address.',
      );
      expect(forNobody.user?.id, isNull);
    });
  }, skip: hasDsn ? false : withoutDsn);
}
