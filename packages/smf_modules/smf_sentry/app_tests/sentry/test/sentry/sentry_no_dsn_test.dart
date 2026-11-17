// A test that continuous integration runs in the apps with the sentry module
// whose .env has no DSN, as an app has right after it is generated: the start
// of Sentry throws an error that names the key, starts no Sentry and leaves
// the handlers of the errors as it found them, and the start-up of the app
// goes on without Sentry and, in a debug build, prints why.
@Timeout(Duration(minutes: 2))
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:{{app_name}}/bootstrap.dart';
import 'package:{{app_name}}/core/crash_reporting/sentry_crash_reporter.dart';

import 'sentry.dart';

/// A handler of the errors of Flutter that the start of Sentry finds.
void _flutterErrors(FlutterErrorDetails details) {}

/// A handler of the other errors that the start of Sentry finds.
bool _platformErrors(Object error, StackTrace stackTrace) => false;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Without a DSN', () {
    late FlutterExceptionHandler? flutterErrorsBefore;
    late ErrorCallback? platformErrorsBefore;

    setUpAll(() {
      flutterErrorsBefore = FlutterError.onError;
      platformErrorsBefore = PlatformDispatcher.instance.onError;
    });

    tearDown(() {
      FlutterError.onError = flutterErrorsBefore;
      PlatformDispatcher.instance.onError = platformErrorsBefore;
    });

    test(
        'the start of Sentry throws an error that names the key, starts no '
        'Sentry and leaves the handlers of the errors as it found them',
        () async {
      FlutterError.onError = _flutterErrors;
      PlatformDispatcher.instance.onError = _platformErrors;

      await expectLater(
        initSentryCrashReporter(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(
              startsWith('SENTRY_DSN has no value in this build'),
              contains('In .env, give it the DSN of your Sentry project'),
            ),
          ),
        ),
      );
      expect(Sentry.isEnabled, isFalse);
      expect(FlutterError.onError, same(_flutterErrors));
      expect(PlatformDispatcher.instance.onError, same(_platformErrors));
    });

    test(
        'the start-up of the app goes on without Sentry, and a debug build '
        'prints why', () async {
      expect(kDebugMode, isTrue);

      final lines = await printed(bootstrap);

      expect(Sentry.isEnabled, isFalse);
      expect(
        lines,
        contains(
          startsWith(
            'initSentryCrashReporter() failed, so the app works without it: '
            'Bad state: SENTRY_DSN has no value in this build',
          ),
        ),
      );
    });
  }, skip: hasDsn ? withDsn : false);
}
