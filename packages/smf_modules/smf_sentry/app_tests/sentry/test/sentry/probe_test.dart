// A test that continuous integration runs in the apps with the sentry
// module: the probe of the module, which the start check runs on a device.
// Sentry is enabled exactly when the build has a DSN. In a debug build with
// a DSN, the check of the probe sends an event through the reporter of the
// module and writes a request with its id, its nonce and its environment,
// which the answer of CI looks up in Sentry; without a DSN it writes its
// verdict in place of a request; a release build writes neither, and no file
// has the DSN. The test asks problemsOf, whose problems the probe returns,
// and checkDelivery with a directory of its own, since the probe starts the
// check in the temporary directory of the app.
//
// Sentry starts as the start-up of the app starts it, with the mocks of
// Sentry, which keep the events (sentry_mocks.dart), and in real time.
@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:{{app_name}}/core/crash_reporting/sentry_crash_reporter.dart';
import 'package:{{app_name}}/core/env/app_env.dart';

import '../../integration_test/sentry/probe.dart';
import '../sentry_mocks.dart';
import 'sentry.dart';

/// 32 hexadecimal digits in lower case, as the id of an event and a nonce.
final _hex32 = RegExp(r'^[0-9a-f]{32}$');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('smf_sentry_probe_');
  });
  tearDown(() => directory.deleteSync(recursive: true));

  /// The names of the files in [directory].
  List<String> files() => [
        for (final file in directory.listSync())
          file.uri.pathSegments.lastWhere((segment) => segment.isNotEmpty),
      ];

  test(
      'reports Sentry that runs without a DSN, and a DSN without Sentry, '
      'without the DSN', () {
    expect(problemsOf(enabled: true, hasDsn: true), isEmpty);
    expect(problemsOf(enabled: false, hasDsn: false), isEmpty);
    expect(problemsOf(enabled: true, hasDsn: false), [
      'Sentry is enabled, though the app has no SENTRY_DSN in this build.',
    ]);
    expect(problemsOf(enabled: false, hasDsn: true), [
      'The app has a SENTRY_DSN in this build, but Sentry is not enabled: '
          'initSentryCrashReporter() failed, as the log of a debug build '
          'tells.',
    ]);
  });

  group('With a DSN', () {
    setUpAll(() async {
      final flutterErrors = FlutterError.onError;
      final platformErrors = PlatformDispatcher.instance.onError;
      try {
        await initSentryCrashReporter();
      } finally {
        FlutterError.onError = flutterErrors;
        PlatformDispatcher.instance.onError = platformErrors;
      }
    });

    setUp(sentryEvents.clear);

    test(
        'the probe finds no problem once Sentry started, and its check sends an '
        'event through the reporter of the module and asks for the check of it, '
        'with neither the DSN nor a verdict', () async {
      expect(
        problemsOf(enabled: Sentry.isEnabled, hasDsn: AppEnv.sentryDsn != null),
        isEmpty,
      );

      final written = await checkDelivery(directory: directory, release: false);

      expect(files(), ['smf_start_request_sentry']);
      final text =
          File('${directory.path}/smf_start_request_sentry').readAsStringSync();
      expect(text, '$written\n');
      expect(text, isNot(contains(AppEnv.sentryDsn!)));
      final request = jsonDecode(written!) as Map<String, Object?>;
      expect(request.keys, ['eventId', 'nonce', 'environment']);
      expect(request['eventId'], matches(_hex32));
      expect(request['nonce'], matches(_hex32));
      expect(request['environment'], '{{default_flavor}}');
      final event = sentryEvents.singleWhere(
        (event) => '${event.eventId}' == request['eventId'],
      );
      expect(event.environment, '{{default_flavor}}');
      expect(
        (
          exceptionOf(event).type,
          exceptionOf(event).mechanism?.type,
          exceptionOf(event).mechanism?.handled,
          event.level,
        ),
        (
          'SentryStartCheck',
          'CrashReporter.recordError',
          true,
          SentryLevel.error
        ),
      );
      expect(exceptionOf(event).value, contains('${request['nonce']}'));
      expect(exceptionOf(event).stackTrace?.frames, isNotEmpty);

      final second = Directory('${directory.path}/again')..createSync();
      final again = jsonDecode(
        (await checkDelivery(directory: second, release: false))!,
      ) as Map<String, Object?>;
      expect(again['nonce'], isNot(request['nonce']));
      expect(again['eventId'], isNot(request['eventId']));
    });

    test('the check of a release build writes nothing', () async {
      expect(await checkDelivery(directory: directory, release: true), isNull);

      expect(files(), isEmpty);
      expect(sentryEvents, isEmpty);
    });
  }, skip: hasDsn ? false : withoutDsn);

  group('Without a DSN', () {
    test(
        'the probe finds no problem, and its check writes its verdict, which '
        'names the key, in place of a request', () async {
      expect(
        problemsOf(enabled: Sentry.isEnabled, hasDsn: AppEnv.sentryDsn != null),
        isEmpty,
      );

      final written = await checkDelivery(directory: directory, release: false);

      expect(files(), ['smf_start_report_sentry']);
      expect(
        written,
        'failed: SENTRY_DSN has no value in this build, so no event reaches '
        'Sentry: give .env of the app the DSN of the Sentry project of CI.',
      );
      expect(
        File('${directory.path}/smf_start_report_sentry').readAsStringSync(),
        '$written\n',
      );
    });

    test('the check of a release build writes nothing', () async {
      expect(await checkDelivery(directory: directory, release: true), isNull);

      expect(files(), isEmpty);
    });
  }, skip: hasDsn ? withDsn : false);
}
