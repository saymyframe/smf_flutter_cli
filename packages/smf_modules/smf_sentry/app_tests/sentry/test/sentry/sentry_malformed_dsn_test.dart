// A test that continuous integration runs in the apps with the sentry module
// whose .env has a DSN: a value of SENTRY_DSN that is no DSN of Sentry, such
// as one without the id of the project or with a host that is no host, makes
// the start of Sentry throw an error that names the key and never its value,
// starts no Sentry and leaves the handlers of the errors as it found them; and
// the start-up of the app goes on without Sentry and, in a debug build,
// prints why, without the value either. The test gives Sentry such a value
// through configureSentryForTests, after the options of the mocks of Sentry.
@Timeout(Duration(minutes: 2))
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:{{app_name}}/bootstrap.dart';
import 'package:{{app_name}}/core/crash_reporting/sentry_crash_reporter.dart';

import 'sentry.dart';

/// The key of the DSN of the values that the test gives Sentry, which no
/// text may have.
const _key = 'fedcba9876543210fedcba9876543210';

/// Values of the DSN that are no DSN of Sentry, by what is wrong with each.
const _malformed = {
  'without the id of the project': 'https://$_key@o1.ingest.sentry.invalid/',
  'with a host that is no host': 'https://$_key@[o1.ingest.sentry.invalid/1',
};

/// A handler of the errors of Flutter that the start of Sentry finds.
void _flutterErrors(FlutterErrorDetails details) {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('With a DSN that is no DSN of Sentry', () {
    late void Function(SentryFlutterOptions options)? mocks;
    late FlutterExceptionHandler? flutterErrorsBefore;

    setUpAll(() {
      mocks = configureSentryForTests;
      flutterErrorsBefore = FlutterError.onError;
    });

    tearDown(() {
      configureSentryForTests = mocks;
      FlutterError.onError = flutterErrorsBefore;
    });

    /// Gives Sentry [dsn] in place of the DSN of the build.
    void giveSentry(String dsn) {
      configureSentryForTests = (options) {
        mocks?.call(options);
        options.dsn = dsn;
      };
    }

    for (final MapEntry(key: what, value: dsn) in _malformed.entries) {
      test(
          'the start of Sentry with a value $what throws an error that names '
          'the key and not the value, and leaves the handler of the errors of '
          'Flutter as it found it', () async {
        giveSentry(dsn);
        FlutterError.onError = _flutterErrors;

        Object? thrown;
        try {
          await initSentryCrashReporter();
        } on Object catch (error) {
          thrown = error;
        }

        expect(
          thrown,
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(contains('SENTRY_DSN'), isNot(contains(_key))),
          ),
          reason: 'A DSN that Sentry refuses leaves the app without Sentry, '
              'with an error that names the key and not its value, which a '
              'debug build prints.',
        );
        expect(Sentry.isEnabled, isFalse);
        expect(FlutterError.onError, same(_flutterErrors));
      });
    }

    test(
        'the start-up of the app goes on without Sentry, and a debug build '
        'prints why, without the value', () async {
      giveSentry(_malformed.values.first);

      final lines = await printed(bootstrap);

      expect(Sentry.isEnabled, isFalse);
      expect(
        lines,
        contains(
          allOf(
            startsWith('initSentryCrashReporter() failed, so the app works '
                'without it: Bad state: SENTRY_DSN'),
            isNot(contains(_key)),
          ),
        ),
      );
      expect(lines.where((line) => line.contains(_key)), isEmpty);
    });
  }, skip: hasDsn ? false : withoutDsn);
}
