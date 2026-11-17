// Tests what the test that checks the event of the app that CI starts knows
// of PostHog (support/posthog_query.dart): the request of the app, the
// queries that it sends to the API of PostHog, what the event of the app
// has, and what it says of each answer, without the key. A client in memory
// stands in for PostHog, so the tests need no network.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'support/posthog_query.dart';

/// A key of the tests, which no text may have.
const _key = 'phx_tests_0123456789abcdef';

/// The nonce of the event of the check.
const _nonce = 'fedcba9876543210fedcba9876543210';

/// The distinct id of the user of the device.
const _distinctId = '019a3c5e-7d1f-7e4b-9c2a-5d6e7f8a9b0c';

/// The request of the app.
final _request = EventRequest.parse(
  jsonEncode({'nonce': _nonce, 'distinctId': _distinctId, 'flavor': 'dev'}),
);

/// The path of the query API of the project of CI.
const _query = '/api/projects/12345/query/';

/// The HogQL query of the check of the request.
const _hogql = 'SELECT distinct_id, properties.app_flavor FROM events '
    "WHERE event = 'smf_start_check' "
    "AND properties.smf_check = '$_nonce' "
    'AND timestamp > now() - INTERVAL 1 DAY';

/// PostHog in memory, as its query API answers a key of the project of CI:
/// no row until it has taken the event, after [untakenFor] queries, and then
/// [rows]. A test scripts other answers with [script].
final class _PostHog {
  /// How many queries PostHog answers without a row before it has the
  /// event.
  int untakenFor = 0;

  /// The rows that PostHog gives once it has the event.
  List<Object?> rows = [
    [_distinctId, 'dev'],
  ];

  /// The queries that reached PostHog, in their order.
  final List<http.Request> requests = [];

  /// The scripted answers, each used once, in order: a response, or an
  /// exception that the client throws.
  final List<Object> _scripted = [];

  /// Answers the next queries with [answers].
  void script(List<Object> answers) => _scripted.addAll(answers);

  late final client = MockClient((request) async {
    requests.add(request);
    if (_scripted.isNotEmpty) {
      final answer = _scripted.removeAt(0);
      if (answer is http.Response) return answer;
      throw answer as Exception;
    }
    if (request.url.path != _query) {
      return _json(404, {'detail': 'Not found.'});
    }
    return _json(200, {
      'columns': ['distinct_id', 'properties.app_flavor'],
      'results': untakenFor-- > 0 ? <Object?>[] : rows,
    });
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

/// Checks the event of [_request] in the project of CI on [posthog], with
/// the times of [time], and returns what it found or the meaning of its
/// failure.
Future<String> _check(
  _PostHog posthog,
  _Time time, {
  String api = 'https://us.posthog.com',
}) async {
  try {
    return await checkEvent(
      posthog.client,
      api: api,
      projectId: '12345',
      key: _key,
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
    test('has the nonce, the distinct id and the flavor', () {
      expect(
        (_request.nonce, _request.distinctId, _request.flavor),
        (_nonce, _distinctId, 'dev'),
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
        {'nonce': _nonce, 'distinctId': _distinctId},
        {
          'nonce': _nonce.toUpperCase(),
          'distinctId': _distinctId,
          'flavor': 'dev',
        },
        // A nonce that would change the query.
        {
          'nonce': "' OR 1 = 1 --",
          'distinctId': _distinctId,
          'flavor': 'dev',
        },
        {'nonce': _nonce, 'distinctId': '', 'flavor': 'dev'},
        {'nonce': _nonce, 'distinctId': _distinctId, 'flavor': ''},
        {'nonce': 1, 'distinctId': _distinctId, 'flavor': 'dev'},
      ]) {
        expect(
          refusal(jsonEncode(request)),
          startsWith('The request of the app is not an object with a nonce '
              'of 32 hexadecimal digits'),
          reason: '$request',
        );
      }
    });
  });

  group('queryOf', () {
    test('asks for the events of the check with the nonce, of the last day',
        () {
      expect(queryOf(_nonce), _hogql);
    });

    test('takes no text that is no nonce, which would change the query', () {
      expect(() => queryOf("x' OR '1' = '1"), throwsArgumentError);
    });
  });

  group('checkEvent', () {
    late _PostHog posthog;
    late _Time time;

    setUp(() {
      posthog = _PostHog();
      time = _Time();
    });

    test(
        'queries the events of the check with the key, every 15 s, until '
        'PostHog has the event', () async {
      posthog.untakenFor = 3;

      final found = await _check(posthog, time);

      expect(
        found,
        'PostHog has the event smf_start_check with the nonce of the request '
        'in the PostHog project 12345 at https://us.posthog.com, of the user '
        'of the device and with app_flavor dev.',
      );
      expect(posthog.requests, hasLength(4));
      expect(time.waits, List.filled(3, const Duration(seconds: 15)));
      for (final request in posthog.requests) {
        expect(request.method, 'POST');
        expect('${request.url}', 'https://us.posthog.com$_query');
        expect(request.headers['Authorization'], 'Bearer $_key');
        expect(request.headers['Content-Type'], startsWith('application/json'));
        expect(request.headers['Accept'], 'application/json');
        expect(jsonDecode(request.body), {
          'query': {'kind': 'HogQLQuery', 'query': _hogql},
        });
      }
    });

    test('asks the host of the region of the project', () async {
      await _check(posthog, time, api: 'https://eu.posthog.com/');

      expect(
        [for (final request in posthog.requests) '${request.url}'],
        ['https://eu.posthog.com$_query'],
      );
    });

    test(
        'tells a key that PostHog does not take, one without the scope, a '
        'project that it does not see and a query that it refuses at once, '
        'without the key', () async {
      final meanings = <int, String>{};
      for (final status in [400, 401, 403, 404]) {
        final scripted = _PostHog()
          ..script([
            _json(status, {'detail': 'No access for $_key.'}),
          ]);
        meanings[status] = await _check(scripted, _Time());
        expect(scripted.requests, hasLength(1), reason: '$status');
      }

      expect(
        meanings[401],
        allOf(
          startsWith('failed: PostHog did not take the key for the PostHog '
              'project 12345 at https://us.posthog.com (it answered 401, No '
              'access for <the key>.)'),
          contains('SMF_POSTHOG_KEY needs the path of a file with a personal '
              'API key'),
        ),
      );
      expect(
        meanings[403],
        allOf(
          contains('The key may not query the PostHog project'),
          contains('the scope query:read'),
        ),
      );
      expect(
        meanings[404],
        allOf(
          contains('PostHog does not see the PostHog project'),
          contains('SMF_POSTHOG_PROJECT_ID needs the id of the project'),
          contains('SMF_POSTHOG_API the host of its region'),
        ),
      );
      expect(
        meanings[400],
        startsWith('failed: PostHog refused the query in the PostHog project '
            '12345'),
      );
      for (final meaning in meanings.values) {
        expect(meaning, isNot(contains(_key)));
      }
    });

    test(
        'queries again after a limit of PostHog, a timeout of its queue of '
        'queries, a failure of PostHog and a query that did not reach it',
        () async {
      posthog.script([
        _json(429, {'detail': 'Request was throttled.'}),
        _json(400, {'code': 'query_wait_timeout', 'detail': 'Wait.'}),
        _json(400, {'detail': 'The query timed out in the queue.'}),
        _json(503, {'detail': 'Down.'}),
        http.ClientException('Connection reset.'),
      ]);

      final found = await _check(posthog, time);

      expect(found, startsWith('PostHog has the event'));
      expect(posthog.requests, hasLength(6));
      expect(time.waits, List.filled(5, const Duration(seconds: 15)));
    });

    test(
        'waits for the event for at most 270 s, and then tells what its '
        'absence means', () async {
      posthog.untakenFor = 1000;

      final failure = await _check(posthog, time);

      expect(
        failure,
        allOf(
          startsWith('failed: PostHog has no event smf_start_check with the '
              'nonce of the request in the PostHog project 12345 at '
              'https://us.posthog.com 270 s after the check of the app sent '
              'it'),
          contains('the project token of the app in CI_APP_ENV'),
          contains('or the device did not send its batch of events'),
        ),
      );
      expect(time.waits, List.filled(17, const Duration(seconds: 15)));
      expect(posthog.requests, hasLength(18));
    });

    test(
        'tells a PostHog that did not answer within the time, and an answer '
        'without results', () async {
      final down = _PostHog()
        ..script([
          for (var i = 0; i < 100; i++) _json(502, {'detail': 'Bad gateway.'}),
        ]);
      expect(
        await _check(down, _Time()),
        'failed: PostHog did not answer the query in the PostHog project '
        '12345 at https://us.posthog.com in 270 s (it answered 502, Bad '
        'gateway.): run the job again later.',
      );

      final odd = _PostHog()
        ..script([
          _json(200, {'detail': 'Something else.'}),
        ]);
      expect(
        await _check(odd, _Time()),
        'failed: PostHog answered the query in the PostHog project 12345 at '
        'https://us.posthog.com without its results: it answered 200, '
        'Something else..',
      );
    });

    test('fails on an event that is not the one that the app sent', () async {
      posthog.rows = [
        ['another-user', 'prod'],
      ];

      expect(
        await _check(posthog, time),
        'failed: PostHog has the event of the check with the nonce of the '
        'request in the PostHog project 12345 at https://us.posthog.com, but '
        'not as the app sent it: Its distinct id is another-user, not '
        '$_distinctId, the user of the device. Its app_flavor is prod, not '
        'dev, the flavor of the build.',
      );
    });
  });

  group('checkEvent within its time', () {
    test(
        'cuts a query that PostHog does not answer when its time is up, and '
        'tells what that was', () async {
      final hanging =
          MockClient((request) => Completer<http.Response>().future);
      final took = Stopwatch()..start();

      Object? failure;
      try {
        await checkEvent(
          hanging,
          api: 'https://us.posthog.com',
          projectId: '12345',
          key: _key,
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
          startsWith('PostHog did not answer the query in the PostHog project '
              '12345'),
          contains('TimeoutException'),
        ),
      );
    });
  });

  group('the settings of the answer', () {
    test(
        'take the variables that CI sets, and the API of the US Cloud by '
        'default', () {
      final settings = AnswerSettings.of({
        'SMF_START_REQUEST': '/tmp/request',
        'SMF_POSTHOG_PROJECT_ID': '12345',
        'SMF_POSTHOG_KEY': '/tmp/key',
      });

      expect(
        (
          settings.request,
          settings.api,
          settings.projectId,
          settings.keyFile,
        ),
        ('/tmp/request', 'https://us.posthog.com', '12345', '/tmp/key'),
      );
      expect(settings.missing, isEmpty);
      expect(
        AnswerSettings.of({'SMF_POSTHOG_API': 'https://eu.posthog.com'}).api,
        'https://eu.posthog.com',
      );
    });

    test(
        'name what is missing, and take an empty variable for a missing one, '
        'as GitHub Actions gives an unset variable of its settings', () {
      final settings = AnswerSettings.of({
        'SMF_START_REQUEST': '',
        'SMF_POSTHOG_API': ' ',
        'SMF_POSTHOG_PROJECT_ID': '',
      });

      expect(settings.request, isNull);
      expect(settings.api, 'https://us.posthog.com');
      const key = 'SMF_POSTHOG_KEY, the path of a file with a personal API '
          'key that may query that project';
      expect(settings.missing, [
        'SMF_POSTHOG_PROJECT_ID, the id of the PostHog project of CI',
        key,
      ]);
    });
  });

  group('problemsOfRows', () {
    test('finds nothing wrong with the one event of the app', () {
      expect(
        problemsOfRows(
          [
            [_distinctId, 'dev'],
          ],
          _request,
        ),
        isEmpty,
      );
    });

    test('tells events of the nonce that are not the one of the check', () {
      expect(
        problemsOfRows(
          [
            [_distinctId, 'dev'],
            [_distinctId, 'dev'],
          ],
          _request,
        ),
        ['PostHog has 2 events with the nonce, though the check sends one.'],
      );
      expect(
        problemsOfRows(['not a row'], _request),
        ['The row of the event is not its distinct id and its flavor.'],
      );
      expect(
        problemsOfRows(
          [
            [_distinctId, null],
          ],
          _request,
        ),
        ['Its app_flavor is none, not dev, the flavor of the build.'],
      );
    });
  });
}
