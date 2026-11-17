// A test that continuous integration runs in the apps with the posthog
// module: the probe of the module, which the start check runs on a device.
// PostHog started exactly when the build has a project token, its SDK is
// opted out exactly when the app collects nothing from its first start, and
// it has a distinct id; the probe waits for its reads at most a second. In a
// debug build with a token and collection on, the check of the probe records
// an event through the service of the module, has PostHog send it at once
// and writes a request with its nonce, the distinct id and the flavor, which
// the answer of CI looks up in PostHog; without a token, while PostHog
// collects nothing, or when PostHog does not answer one of its calls within
// a second, it writes its verdict in place of a request; a release build
// writes neither, and no file has the token. The probe starts its check
// once in a run of the app, in the temporary directory of the app, so the
// test gives it a directory of its own first, and runs checkDelivery with one
// of its own too.
//
// PostHog starts as the start-up of the app starts it, over the mocks of its
// platform side (posthog_mocks.dart).
@Timeout(Duration(minutes: 2))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/analytics/analytics_service.dart';
import 'package:{{app_name}}/core/analytics/posthog_analytics_service.dart';
import 'package:{{app_name}}/core/env/app_env.dart';

import '../../integration_test/posthog/probe.dart';
import '../posthog_mocks.dart';
import 'posthog.dart';

/// 32 hexadecimal digits in lower case, as a nonce.
final _hex32 = RegExp(r'^[0-9a-f]{32}$');

/// Whether the app collects from its first start, which the tests branch on
/// when the app runs.
final bool _collectedFromFirstStart = analyticsCollectedFromFirstStart;

/// The text of the file [name] in [directory], once the check that the probe
/// started has written it: waits for it for at most 10 seconds, and then a
/// moment longer, so that what a second check would record has come too.
Future<String> _fileIn(Directory directory, String name) async {
  final file = File('${directory.path}/$name');
  final until = DateTime.now().add(const Duration(seconds: 10));
  while (!file.existsSync() && DateTime.now().isBefore(until)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  await Future<void>.delayed(const Duration(milliseconds: 500));
  return file.readAsStringSync().trim();
}

/// The events of the check that reached the device.
List<RecordedEvent> get _checks => [
      for (final event in postHogDevice.events)
        if (event.event == 'smf_start_check') event,
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('smf_posthog_probe_');
  });
  tearDown(() => directory.deleteSync(recursive: true));

  /// The names of the files in [directory].
  List<String> files() => [
        for (final file in directory.listSync())
          file.uri.pathSegments.lastWhere((segment) => segment.isNotEmpty),
      ];

  test(
      'reports PostHog that runs without a token, a token without PostHog, a '
      'setting of collection that is not the one of a new install, and no '
      'distinct id', () {
    expect(problemsOf(started: true, hasToken: true), isEmpty);
    expect(problemsOf(started: false, hasToken: false), isEmpty);
    expect(problemsOf(started: true, hasToken: false), [
      'PostHog started, though the app has no POSTHOG_PROJECT_TOKEN in this '
          'build.',
    ]);
    expect(problemsOf(started: false, hasToken: true), [
      'The app has a POSTHOG_PROJECT_TOKEN in this build, but PostHog did not '
          'start: initPostHogAnalytics() failed, as the log of a debug build '
          'tells.',
    ]);
    expect(
      problemsOf(
        started: true,
        hasToken: true,
        optOut: !_collectedFromFirstStart,
        distinctId: 'anonymous-1',
      ),
      isEmpty,
    );
    expect(
      problemsOf(
        started: true,
        hasToken: true,
        optOut: _collectedFromFirstStart,
        distinctId: '',
      ),
      [
        if (_collectedFromFirstStart)
          'PostHog is opted out, though the app collects from its first start '
              'and the code never chose on a new install.'
        else
          'PostHog is opted in, though the app collects nothing before its '
              'code chose: the default of the app did not reach the SDK of '
              'PostHog.',
        'PostHog has no distinct id for the user of the device.',
      ],
    );
  });

  group('With a project token', () {
    late AnalyticsService service;

    setUpAll(() async {
      mockPostHog();
      service = await initPostHogAnalytics();
    });

    tearDown(() async {
      postHogDevice
        ..hold = null
        ..held = {'isOptOut', 'getDistinctId'};
      await service.setAnalyticsCollectionEnabled(_collectedFromFirstStart);
      postHogDevice.events.clear();
    });

    test(
        'the probe finds no problem on a new install, and starts its check '
        'once, which records one event and writes one request, or its verdict '
        'in an app that collects nothing before its code chose', () async {
      exchangeDirectory = directory;

      expect(await probePostHog(() async {}), isEmpty);
      expect(await probePostHog(() async {}), isEmpty);

      if (_collectedFromFirstStart) {
        final request = await _fileIn(directory, 'smf_start_request_posthog');
        expect(files(), ['smf_start_request_posthog']);
        final asked = jsonDecode(request) as Map<String, Object?>;
        expect(
          _checks,
          hasLength(1),
          reason: 'The probe starts the check of the event once in a run of '
              'the app, however often the start check runs it.',
        );
        expect(_checks.single.properties['smf_check'], asked['nonce']);
      } else {
        expect(
          await _fileIn(directory, 'smf_start_report_posthog'),
          startsWith('failed: PostHog collects nothing on this device'),
        );
        expect(files(), ['smf_start_report_posthog']);
        expect(_checks, isEmpty);
      }
    });

    test(
        'the check records an event through the service of the module, has '
        'PostHog send it at once and asks for the check of it, with neither '
        'the token nor a verdict', () async {
      await service.setAnalyticsCollectionEnabled(true);
      postHogDevice.calls.clear();

      final written = await checkDelivery(directory: directory, release: false);

      expect(files(), ['smf_start_request_posthog']);
      final text = File('${directory.path}/smf_start_request_posthog')
          .readAsStringSync();
      expect(text, '$written\n');
      expect(text, isNot(contains(AppEnv.posthogProjectToken!)));
      final request = jsonDecode(written!) as Map<String, Object?>;
      expect(request.keys, ['nonce', 'distinctId', 'flavor']);
      expect(request['nonce'], matches(_hex32));
      expect(request['distinctId'], postHogDevice.distinctId);
      expect(request['flavor'], '{{default_flavor}}');
      expect(
        [
          for (final event in _checks)
            (
              event.properties['smf_check'],
              event.properties['app_flavor'],
              event.distinctId,
            ),
        ],
        [(request['nonce'], '{{default_flavor}}', request['distinctId'])],
      );
      expect(
        postHogDevice.methods,
        containsAllInOrder(['capture', 'flush']),
        reason: 'PostHog sends the event at once, rather than with the next '
            'batch, which leaves 30 seconds after the start.',
      );

      final second = Directory('${directory.path}/again')..createSync();
      final again = jsonDecode(
        (await checkDelivery(directory: second, release: false))!,
      ) as Map<String, Object?>;
      expect(again['nonce'], isNot(request['nonce']));
    });

    test(
        'the check writes its verdict while PostHog collects nothing, and '
        'records nothing', () async {
      await service.setAnalyticsCollectionEnabled(false);

      final written = await checkDelivery(directory: directory, release: false);

      expect(files(), ['smf_start_report_posthog']);
      expect(
        written,
        'failed: PostHog collects nothing on this device, so the event of the '
        'check would reach nobody: the app collects nothing before its code '
        'chose, or its code turned collection off.',
      );
      expect(_checks, isEmpty);
    });

    test('the check of a release build writes nothing', () async {
      expect(await checkDelivery(directory: directory, release: true), isNull);

      expect(files(), isEmpty);
      expect(_checks, isEmpty);
    });

    test(
        'the check waits for each answer of PostHog at most a second, and '
        'writes its verdict when one does not come', () async {
      await service.setAnalyticsCollectionEnabled(true);
      postHogDevice.hold = Completer<void>().future;
      const methods = ['isOptOut', 'capture', 'flush', 'getDistinctId'];
      final verdicts = <String?>[];

      for (final method in methods) {
        postHogDevice.held = {method};
        verdicts.add(
          await checkDelivery(
            directory: Directory('${directory.path}/$method')..createSync(),
            release: false,
          ).timeout(
            const Duration(seconds: 5),
            onTimeout: () => 'no verdict after 5 seconds',
          ),
        );
      }

      expect(
        verdicts,
        [
          'failed: PostHog did not answer within a second when the check '
              'asked whether it is opted out.',
          'failed: PostHog did not answer within a second when the check '
              'asked it to record the event.',
          'failed: PostHog did not answer within a second when the check '
              'asked it to send the event at once.',
          'failed: PostHog did not answer within a second when the check '
              'asked for the distinct id of the user.',
        ],
        reason: 'The check never waits for PostHog for good, so the script of '
            'CI gets a verdict rather than waiting until its time is over.',
      );
      for (final method in methods) {
        expect(
          File('${directory.path}/$method/smf_start_report_posthog')
              .readAsStringSync(),
          startsWith('failed: PostHog did not answer within a second'),
          reason: method,
        );
      }
    });

    test(
        'the probe reports a setting of collection that is not the one of a '
        'new install', () async {
      await service.setAnalyticsCollectionEnabled(!_collectedFromFirstStart);

      expect(await probePostHog(() async {}), [
        if (_collectedFromFirstStart)
          'PostHog is opted out, though the app collects from its first start '
              'and the code never chose on a new install.'
        else
          'PostHog is opted in, though the app collects nothing before its '
              'code chose: the default of the app did not reach the SDK of '
              'PostHog.',
      ]);
    });

    test(
        'the probe waits for the reads of PostHog at most a second, and '
        'reports a read that did not come', () async {
      postHogDevice.hold = Completer<void>().future;
      final took = Stopwatch()..start();

      final problems = await probePostHog(() async {});
      took.stop();

      expect(problems, [
        'PostHog did not tell whether it is opted out within a second.',
        'PostHog did not tell the distinct id within a second.',
      ]);
      expect(took.elapsed, lessThan(const Duration(milliseconds: 1500)));
    });
  }, skip: hasToken ? false : withoutToken);

  group('Without a project token', () {
    setUp(mockPostHog);

    test(
        'the probe finds no problem, and starts its check once, which writes '
        'one verdict and no request', () async {
      exchangeDirectory = directory;

      expect(await probePostHog(() async {}), isEmpty);
      expect(await probePostHog(() async {}), isEmpty);

      expect(
        await _fileIn(directory, 'smf_start_report_posthog'),
        startsWith('failed: POSTHOG_PROJECT_TOKEN has no value in this build'),
      );
      expect(files(), ['smf_start_report_posthog']);
      expect(postHogDevice.calls, isEmpty);
    });

    test(
        'the check writes its verdict, which names the key, in place of a '
        'request', () async {
      final written = await checkDelivery(directory: directory, release: false);

      expect(files(), ['smf_start_report_posthog']);
      expect(
        written,
        'failed: POSTHOG_PROJECT_TOKEN has no value in this build, so no event '
        'reaches PostHog: give .env of the app the project token of the '
        'PostHog project of CI.',
      );
      expect(
        File('${directory.path}/smf_start_report_posthog').readAsStringSync(),
        '$written\n',
      );
    });

    test('the check of a release build writes nothing', () async {
      expect(await checkDelivery(directory: directory, release: true), isNull);

      expect(files(), isEmpty);
    });
  }, skip: hasToken ? withToken : false);
}
