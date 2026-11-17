// A test that continuous integration runs in the apps with the sentry module
// whose .env has a DSN: the start-up of the app starts Sentry and then
// installs the handlers of the crash reporting role for the errors that
// nothing catches, which report each such error to Sentry once, as fatal.
// Sentry would install handlers of its own too, and an error of Flutter would
// then reach it twice: once from the handler of Sentry and once from that of
// the role, which calls the handler that it found.
//
// The handlers report to every crash reporter of the app, and what another
// reporter does is known only to the tests of its own module. So the test
// looks only at what reaches Sentry: the mocks of Sentry keep its events
// (sentry_mocks.dart) and turn off the deduplication of Sentry, which would
// otherwise hide a second event of one error. The matrix sets up the mocks
// of the platform side of every module of the app before the tests, so the
// start-up runs whatever other modules the app has. It runs in real time, as
// SentryFlutter.init does not complete in the fake time of a widget test.
@Timeout(Duration(minutes: 2))
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:{{app_name}}/bootstrap.dart';

import '../sentry_mocks.dart';
import 'sentry.dart';

/// Calls [handler], a handler of the errors that nothing catches, leaving
/// out the errors of the reports that it starts and nothing awaits.
void _report(void Function() handler) =>
    runZonedGuarded(handler, (error, stackTrace) {});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('With a DSN, the start-up of the app', () {
    final presentedErrors = <FlutterErrorDetails>[];
    late FlutterExceptionHandler? flutterErrorsBefore;
    late ErrorCallback? platformErrorsBefore;

    setUpAll(() async {
      flutterErrorsBefore = FlutterError.onError;
      platformErrorsBefore = PlatformDispatcher.instance.onError;
      // The handler of the errors of Flutter that the start-up finds, which
      // the handler of the role calls first and which by default presents
      // them: here it counts them.
      FlutterError.onError = presentedErrors.add;
      await bootstrap();
    });

    tearDownAll(() {
      FlutterError.onError = flutterErrorsBefore;
      PlatformDispatcher.instance.onError = platformErrorsBefore;
    });

    setUp(() {
      sentryEvents.clear();
      presentedErrors.clear();
    });

    test(
        'reports an error that Flutter catches to Sentry once, as fatal, and '
        'presents it once', () async {
      final details = FlutterErrorDetails(
        exception: StateError('broken in a build'),
        stack: StackTrace.current,
        library: 'the test',
        context: ErrorDescription('while building the test'),
      );

      _report(() => FlutterError.onError!(details));

      final events = await eventsOf('Bad state: broken in a build');
      expect(
        events,
        hasLength(1),
        reason: 'An error of Flutter reaches Sentry once, through the handler '
            'of the crash reporting role, and not through a handler of Sentry '
            'too.',
      );
      expect(
        (
          exceptionOf(events.single).mechanism?.type,
          exceptionOf(events.single).mechanism?.handled,
          events.single.level,
        ),
        ('CrashReporter.recordFlutterError', false, SentryLevel.fatal),
      );
      expect(presentedErrors, [details]);
    });

    test('reports an error that nothing catches to Sentry once, as fatal',
        () async {
      _report(
        () => PlatformDispatcher.instance.onError!(
          StateError('broken later'),
          StackTrace.current,
        ),
      );

      final events = await eventsOf('Bad state: broken later');
      expect(
        events,
        hasLength(1),
        reason: 'An error that nothing catches reaches Sentry once, through '
            'the handler of the crash reporting role.',
      );
      expect(
        (
          exceptionOf(events.single).mechanism?.type,
          exceptionOf(events.single).mechanism?.handled,
          events.single.level,
        ),
        ('CrashReporter.recordError', false, SentryLevel.fatal),
      );
    });
  }, skip: hasDsn ? false : withoutDsn);
}
