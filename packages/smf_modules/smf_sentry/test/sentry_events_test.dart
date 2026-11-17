// Tests what the test that checks the event of the app that CI starts knows
// of Sentry (support/sentry_events.dart): the request of the app, the
// requests that it sends to the API of Sentry, what an event of the app has,
// and what it says of each answer, without the token. A client in memory
// stands in for Sentry, so the tests need no network.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'support/sentry_events.dart';

/// A token of the tests, which no text may have.
const _token = 'sntrys_tests_0123456789abcdef';

/// The id of the event that the app sent.
const _eventId = '0123456789abcdef0123456789abcdef';

/// The nonce in the text of the error of the event.
const _nonce = 'fedcba9876543210fedcba9876543210';

/// The request of the app.
final _request = EventRequest.parse(
  jsonEncode({'eventId': _eventId, 'nonce': _nonce, 'environment': 'dev'}),
);

/// The path of the project of CI.
const _project = '/api/0/projects/smf-ci/start-app/';

/// The path of the event of the request.
const _event = '${_project}events/$_eventId/';

/// The event of the app as the API of Sentry gives it, with the values given
/// in place of those that it has.
Map<String, Object?> _eventJson({
  String environment = 'dev',
  String sdk = 'sentry.dart.flutter',
  String value = 'SentryStartCheck: the start check of the app sent this '
      'event ($_nonce).',
  Map<String, Object?> mechanism = const {
    'type': 'CrashReporter.recordError',
    'handled': true,
  },
  List<Map<String, Object?>>? frames,
}) =>
    {
      'eventID': _eventId,
      'tags': [
        {'key': 'level', 'value': 'error'},
        {'key': 'environment', 'value': environment},
      ],
      'sdk': {'name': sdk, 'version': '10.4.0'},
      'entries': [
        {'type': 'breadcrumbs', 'data': <String, Object?>{}},
        {
          'type': 'exception',
          'data': {
            'values': [
              {
                'type': 'SentryStartCheck',
                'value': value,
                'mechanism': mechanism,
                'stacktrace': {
                  'frames': frames ??
                      [
                        {
                          'function': '_RawReceivePort._handleMessage',
                          'filename': 'isolate_patch.dart',
                          'absPath': 'dart:isolate-patch/isolate_patch.dart',
                          'inApp': false,
                        },
                        {
                          'function': 'checkDelivery',
                          'filename': 'probe.dart',
                          'absPath': 'probe.dart',
                          'inApp': true,
                        },
                      ],
                },
              },
            ],
          },
        },
      ],
    };

/// Sentry in memory, as its API answers a token of the organization of CI:
/// the project, and the event once Sentry has processed it, after
/// [unprocessedFor] requests for it. A test scripts other answers with
/// [script].
final class _Sentry {
  /// How many requests for the event Sentry answers with 404 before it has
  /// the event.
  int unprocessedFor = 0;

  /// The event that Sentry gives once it has it.
  Map<String, Object?> event = _eventJson();

  /// The requests that reached Sentry, in their order.
  final List<http.Request> requests = [];

  /// The scripted answers to the path, each used once, in order: a response,
  /// or an exception that the client throws.
  final Map<String, List<Object>> _scripted = {};

  /// Answers the next requests for [path] with [answers].
  void script(String path, List<Object> answers) =>
      (_scripted[path] ??= []).addAll(answers);

  /// The paths of the requests, in their order.
  List<String> get paths => [for (final request in requests) request.url.path];

  late final client = MockClient((request) async {
    requests.add(request);
    final scripted = _scripted[request.url.path];
    if (scripted != null && scripted.isNotEmpty) {
      final answer = scripted.removeAt(0);
      if (answer is http.Response) return answer;
      throw answer as Exception;
    }
    return switch (request.url.path) {
      _project => _json(200, {'slug': 'start-app'}),
      _event => unprocessedFor-- > 0
          ? _json(404, {'detail': 'Event not found'})
          : _json(200, event),
      _ => _json(404, {'detail': 'The requested resource does not exist'}),
    };
  });
}

http.Response _json(int status, Object body) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

/// A clock that the waits of the test move on, and the waits.
final class _Time {
  DateTime current = DateTime.utc(2026, 11, 17, 12);
  final List<Duration> waits = [];

  DateTime now() => current;

  Future<void> wait(Duration duration) async {
    waits.add(duration);
    current = current.add(duration);
  }
}

/// Checks the event of [_request] in the project of CI on [sentry], with the
/// times of [time], and returns what it found or the meaning of its failure.
Future<String> _check(
  _Sentry sentry,
  _Time time, {
  String api = 'https://sentry.io',
}) async {
  try {
    return await checkEvent(
      sentry.client,
      api: api,
      org: 'smf-ci',
      project: 'start-app',
      token: _token,
      request: _request,
      wait: time.wait,
      now: time.now,
    );
  } on EventNotReceived catch (error) {
    return 'failed: ${error.meaning}';
  }
}

void main() {
  group('the request of the app', () {
    test('has the id of the event, the nonce and the environment', () {
      expect(
        (_request.eventId, _request.nonce, _request.environment),
        (_eventId, _nonce, 'dev'),
      );
    });

    test('is refused when it is no JSON or lacks what the test needs', () {
      String refusal(String text) {
        try {
          EventRequest.parse(text);
          return 'parsed';
        } on EventNotReceived catch (error) {
          return error.meaning;
        }
      }

      expect(refusal('not json'), 'The request of the app is no JSON.');
      for (final request in [
        {'eventId': _eventId, 'nonce': _nonce},
        {
          'eventId': _eventId.toUpperCase(),
          'nonce': _nonce,
          'environment': 'dev',
        },
        {'eventId': _eventId, 'nonce': 'short', 'environment': 'dev'},
        {'eventId': _eventId, 'nonce': _nonce, 'environment': ''},
        {'eventId': 1, 'nonce': _nonce, 'environment': 'dev'},
      ]) {
        expect(
          refusal(jsonEncode(request)),
          startsWith('The request of the app is not an object with the id of '
              'an event and a nonce, each of 32 hexadecimal digits'),
          reason: '$request',
        );
      }
    });
  });

  group('checkEvent', () {
    late _Sentry sentry;
    late _Time time;

    setUp(() {
      sentry = _Sentry();
      time = _Time();
    });

    test(
        'reads the project with the token, and the event once Sentry has '
        'processed it, every 5 s', () async {
      sentry.unprocessedFor = 3;

      final found = await _check(sentry, time);

      expect(
        found,
        'Sentry has the event $_eventId in the project smf-ci/start-app of '
        'Sentry at https://sentry.io, which the app sent through its '
        'reporter, with the environment dev and its nonce.',
      );
      expect(sentry.paths, [_project, _event, _event, _event, _event]);
      expect(time.waits, List.filled(3, const Duration(seconds: 5)));
      for (final request in sentry.requests) {
        expect(request.method, 'GET');
        expect(request.url.host, 'sentry.io');
        expect(request.headers['Authorization'], 'Bearer $_token');
        expect(request.headers['Accept'], 'application/json');
      }
    });

    test('asks the host of the region of the organization', () async {
      await _check(sentry, time, api: 'https://de.sentry.io/');

      expect(
        [for (final request in sentry.requests) '${request.url}'],
        [
          'https://de.sentry.io$_project',
          'https://de.sentry.io$_event',
        ],
      );
    });

    test(
        'tells a token that Sentry does not take, one without the scope and '
        'a project that it does not see at once, without the token', () async {
      final meanings = <int, String>{};
      for (final status in [401, 403, 404]) {
        final scripted = _Sentry()
          ..script(_project, [
            _json(status, {'detail': 'No access for $_token.'}),
          ]);
        meanings[status] = await _check(scripted, _Time());
        expect(scripted.paths, [_project], reason: '$status');
      }

      expect(
        meanings[401],
        allOf(
          startsWith('failed: Sentry did not take the token for the project '
              'smf-ci/start-app of Sentry at https://sentry.io (it answered '
              '401, No access for <the token>.)'),
          contains('SMF_SENTRY_TOKEN needs the path of a file with a token'),
        ),
      );
      expect(
        meanings[403],
        allOf(
          contains('The token may not read the project'),
          contains('the scope project:read'),
        ),
      );
      expect(
        meanings[404],
        allOf(
          contains('Sentry does not see the project'),
          contains('SMF_SENTRY_ORG and SMF_SENTRY_PROJECT need the slugs'),
          contains('SMF_SENTRY_API the host of its region'),
        ),
      );
      for (final meaning in meanings.values) {
        expect(meaning, isNot(contains(_token)));
      }
    });

    test(
        'asks again for the project after an answer that Sentry may take '
        'later, 3 times in all', () async {
      sentry.script(_project, [
        _json(429, {'detail': 'Slow down.'}),
        http.ClientException('Connection reset.'),
      ]);

      final found = await _check(sentry, time);

      expect(found, startsWith('Sentry has the event'));
      expect(sentry.paths, [_project, _project, _project, _event]);

      final failing = _Sentry()
        ..script(_project, [
          for (var i = 0; i < 3; i++) _json(503, {'detail': 'Down.'}),
        ]);
      expect(
        await _check(failing, _Time()),
        'failed: Sentry failed the project smf-ci/start-app of Sentry at '
        'https://sentry.io (it answered 503, Down.), also after 3 requests: '
        'run the job again later.',
      );
      final unreached = _Sentry()
        ..script(_project, [
          for (var i = 0; i < 3; i++) http.ClientException('No route.'),
        ]);
      expect(
        await _check(unreached, _Time()),
        allOf(
          startsWith('failed: The test did not reach Sentry for the project'),
          contains('No route.'),
        ),
      );
    });

    test(
        'waits for the event for at most 240 s, and then tells what its '
        'absence means', () async {
      sentry.unprocessedFor = 1000;

      final failure = await _check(sentry, time);

      expect(
        failure,
        allOf(
          startsWith('failed: Sentry does not have the event $_eventId in the '
              'project smf-ci/start-app of Sentry at https://sentry.io 240 s '
              'after the check of the app sent it'),
          contains('the DSN of the app in CI_APP_ENV is of another project'),
          contains('a rate limit of the key of the DSN'),
        ),
      );
      expect(time.waits, List.filled(47, const Duration(seconds: 5)));
      expect(sentry.paths.where((path) => path == _event), hasLength(48));
    });

    test(
        'goes on after a failure of Sentry for the event, and stops at once at '
        'a refusal', () async {
      sentry.script(_event, [
        _json(500, {'detail': 'Oops.'}),
        http.ClientException('Reset.'),
      ]);
      expect(await _check(sentry, time), startsWith('Sentry has the event'));

      final refused = _Sentry()
        ..script(_event, [
          _json(404, {'detail': 'Event not found'}),
          _json(403, {'detail': 'You do not have permission.'}),
        ]);
      expect(
        await _check(refused, _Time()),
        allOf(
          startsWith('failed: The token may not read the event $_eventId'),
          contains('You do not have permission.'),
        ),
      );
      expect(refused.paths, [_project, _event, _event]);

      final down = _Sentry()
        ..script(_event, [
          for (var i = 0; i < 100; i++) _json(502, {'detail': 'Bad gateway.'}),
        ]);
      expect(
        await _check(down, _Time()),
        'failed: Sentry did not answer for the event $_eventId in the project '
        'smf-ci/start-app of Sentry at https://sentry.io in 240 s (it answered '
        '502, Bad gateway.): run the job again later.',
      );
    });

    test('fails on an event that is not the one that the app sent', () async {
      sentry.event = _eventJson(
        environment: 'prod',
        mechanism: const {'type': 'FlutterError', 'handled': false},
      );

      expect(
        await _check(sentry, time),
        'failed: Sentry has the event $_eventId in the project '
        'smf-ci/start-app of Sentry at https://sentry.io, but it is not the '
        'event that the app sent: Its environment is prod, not dev, the '
        'flavor of the build. The mechanism of its exception is '
        'FlutterError, not CrashReporter.recordError, the call of the '
        'reporter of the app. Its exception is not handled, though the app '
        'reported it with recordError() and not as fatal.',
      );
    });
  });

  group('checkEvent within its time', () {
    test(
        'counts the read of the project, and the waits after it, against the '
        '240 s', () async {
      final sentry = _Sentry()
        ..unprocessedFor = 1000
        ..script(_project, [
          _json(503, {'detail': 'Down.'}),
          _json(503, {'detail': 'Down.'}),
        ]);
      final time = _Time();

      final failure = await _check(sentry, time);

      expect(failure, startsWith('failed: Sentry does not have the event'));
      expect(
        sentry.paths,
        [
          for (var i = 0; i < 3; i++) _project,
          for (var i = 0; i < 46; i++) _event,
        ],
        reason: 'The two waits of 5 s of the read of the project leave 230 s '
            'for the event.',
      );
      expect(
        time.waits.fold(Duration.zero, (all, wait) => all + wait),
        lessThanOrEqualTo(const Duration(seconds: 240)),
      );
    });

    test(
        'cuts a request that Sentry does not answer when its time is up, and '
        'tells what that was', () async {
      final hanging =
          MockClient((request) => Completer<http.Response>().future);
      final took = Stopwatch()..start();

      Object? failure;
      try {
        await checkEvent(
          hanging,
          api: 'https://sentry.io',
          org: 'smf-ci',
          project: 'start-app',
          token: _token,
          request: _request,
          timeout: const Duration(milliseconds: 300),
        );
      } on EventNotReceived catch (error) {
        failure = error.meaning;
      }
      took.stop();

      expect(took.elapsed, lessThan(const Duration(seconds: 5)));
      expect(
        failure,
        allOf(
          startsWith('The test did not reach Sentry for the project '
              'smf-ci/start-app'),
          contains('TimeoutException'),
        ),
      );
    });
  });

  group('the settings of the answer', () {
    test('take the variables that CI sets, and the API of sentry.io by default',
        () {
      final settings = AnswerSettings.of({
        'SMF_START_REQUEST': '/tmp/request',
        'SMF_SENTRY_ORG': 'smf-ci',
        'SMF_SENTRY_PROJECT': 'start-app',
        'SMF_SENTRY_TOKEN': '/tmp/token',
      });

      expect(
        (
          settings.request,
          settings.api,
          settings.org,
          settings.project,
          settings.tokenFile,
        ),
        (
          '/tmp/request',
          'https://sentry.io',
          'smf-ci',
          'start-app',
          '/tmp/token'
        ),
      );
      expect(settings.missing, isEmpty);
      expect(
        AnswerSettings.of({'SMF_SENTRY_API': 'https://de.sentry.io'}).api,
        'https://de.sentry.io',
      );
    });

    test(
        'take an empty variable for a missing one, as an unset variable of '
        'GitHub Actions comes', () {
      final settings = AnswerSettings.of({
        'SMF_START_REQUEST': '',
        'SMF_SENTRY_API': '',
        'SMF_SENTRY_ORG': '',
        'SMF_SENTRY_PROJECT': ' ',
        'SMF_SENTRY_TOKEN': '',
      });

      expect(settings.request, isNull);
      expect(settings.api, 'https://sentry.io');
      expect(settings.missing, [
        'SMF_SENTRY_ORG, the slug of the Sentry organization of CI',
        'SMF_SENTRY_PROJECT, the slug of the Sentry project of CI',
        startsWith('SMF_SENTRY_TOKEN, the path of a file with a token'),
      ]);
    });
  });

  group('problemsOfEvent', () {
    test('finds nothing wrong with the event of the app', () {
      expect(problemsOfEvent(_eventJson(), _request), isEmpty);
    });

    test(
        'tells an event of another SDK, without the nonce, or with frames that '
        'are addresses', () {
      expect(problemsOfEvent('event', _request), ['The event is no object.']);
      expect(
        problemsOfEvent(_eventJson(sdk: 'sentry.java.android'), _request),
        ['Its SDK is sentry.java.android, not sentry.dart.flutter.'],
      );
      expect(
        problemsOfEvent(_eventJson(value: 'SentryStartCheck: other'), _request),
        ['No exception of it has the nonce of the request in its text.'],
      );
      expect(
        problemsOfEvent(<String, Object?>{}, _request),
        [
          'Its environment is none, not dev, the flavor of the build.',
          'Its SDK is none, not sentry.dart.flutter.',
          'No exception of it has the nonce of the request in its text.',
        ],
      );
      // A build with --obfuscate gives frames with addresses alone.
      expect(
        problemsOfEvent(
          _eventJson(
            frames: [
              {'instructionAddr': '0x7a2b3c', 'inApp': true},
              {'function': 'main', 'filename': 'main.dart', 'inApp': false},
            ],
          ),
          _request,
        ),
        [contains('the stack trace is not readable.')],
      );
    });
  });
}
