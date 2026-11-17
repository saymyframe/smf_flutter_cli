// A test that continuous integration runs in the apps with the sentry module
// whose .env has a DSN: the start of Sentry, initSentryCrashReporter(),
// leaves the handlers of the errors that nothing catches as it found them,
// since they belong to the crash reporting of the app, and the crash reporter
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
@Timeout(Duration(minutes: 2))
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:{{app_name}}/core/crash_reporting/crash_reporter.dart';
import 'package:{{app_name}}/core/crash_reporting/sentry_crash_reporter.dart';

import '../sentry_mocks.dart';
import 'sentry.dart';

/// A handler of the errors of Flutter that the start of Sentry finds.
void _flutterErrors(FlutterErrorDetails details) {}

/// A handler of the other errors that the start of Sentry finds.
bool _platformErrors(Object error, StackTrace stackTrace) => false;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('With a DSN, the start of Sentry', () {
    late CrashReporter reporter;
    late FlutterExceptionHandler? flutterErrorsAfter;
    late ErrorCallback? platformErrorsAfter;

    setUpAll(() async {
      final flutterErrorsBefore = FlutterError.onError;
      final platformErrorsBefore = PlatformDispatcher.instance.onError;
      FlutterError.onError = _flutterErrors;
      PlatformDispatcher.instance.onError = _platformErrors;
      try {
        reporter = await initSentryCrashReporter();
      } finally {
        flutterErrorsAfter = FlutterError.onError;
        platformErrorsAfter = PlatformDispatcher.instance.onError;
        FlutterError.onError = flutterErrorsBefore;
        PlatformDispatcher.instance.onError = platformErrorsBefore;
      }
    });

    setUp(sentryEvents.clear);

    test(
        'starts Sentry and leaves the handlers of the errors as it found them, '
        'which belong to the crash reporting of the app', () {
      expect(Sentry.isEnabled, isTrue);
      expect(reporter, isA<SentryCrashReporter>());
      expect(
        flutterErrorsAfter,
        same(_flutterErrors),
        reason: 'The start of Sentry put back FlutterError.onError, which '
            'the integration of Sentry for the errors of Flutter replaces, so '
            'that such an error reaches Sentry once.',
      );
      expect(
        platformErrorsAfter,
        same(_platformErrors),
        reason: 'The start of Sentry removed the integration of Sentry that '
            'takes PlatformDispatcher.instance.onError.',
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
      expect(forNobody.user?.id, isNull);
    });
  }, skip: hasDsn ? false : withoutDsn);
}
