/// What the test that checks the event of the app that CI starts knows of
/// PostHog: the request of the app, how a client with a personal API key
/// asks the query API of PostHog for the event, what the event must have,
/// and what each answer means. Nothing here reaches PostHog, so the tests of
/// this file run everywhere.
///
/// The key is a secret of CI, so no text here has it: a text from PostHog
/// that names it gets a placeholder in its place.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Where the API of PostHog is, unless CI names another host, such as that
/// of the EU Cloud, `https://eu.posthog.com`.
const defaultApiOfPostHog = 'https://us.posthog.com';

/// The scope that the personal API key of CI needs: to query the events of
/// the project.
const neededScope = 'query:read';

/// The event that the check of the app sends.
const startCheckEvent = 'smf_start_check';

/// The property of the event of the check with its nonce.
const nonceProperty = 'smf_check';

/// The property of every event of the app with the flavor of its build.
const flavorProperty = 'app_flavor';

/// What a text from PostHog has in place of the key.
const _placeholder = '<the key>';

/// A nonce of the request: 32 hexadecimal digits in lower case, as the check
/// of the app writes it. Only such a nonce goes into the query.
final _hex32 = RegExp(r'^[0-9a-f]{32}$');

/// What the answer takes from the environment of its process, as CI gives
/// it: the path of the request of the app, `SMF_START_REQUEST`, and what
/// reads the event in PostHog. A variable whose value is empty counts as
/// missing, since an unset variable of the settings of GitHub Actions comes
/// as an empty one.
final class AnswerSettings {
  /// The settings in [environment], such as `Platform.environment`.
  AnswerSettings.of(Map<String, String> environment)
      : request = _valueOf(environment['SMF_START_REQUEST']),
        api = _valueOf(environment['SMF_POSTHOG_API']) ?? defaultApiOfPostHog,
        projectId = _valueOf(environment['SMF_POSTHOG_PROJECT_ID']),
        keyFile = _valueOf(environment['SMF_POSTHOG_KEY']);

  /// The path of the request of the app, or `null` without one: then there is
  /// nothing to answer.
  final String? request;

  /// The host of the API of PostHog, of the region of the project.
  final String api;

  /// The id of the PostHog project of CI.
  final String? projectId;

  /// The path of a file with a personal API key that may query the project.
  final String? keyFile;

  /// What the answer needs and the environment lacks, each with what it is.
  List<String> get missing => [
        if (projectId == null) _projectIdIs,
        if (keyFile == null) _keyIs,
      ];

  static const _projectIdIs =
      'SMF_POSTHOG_PROJECT_ID, the id of the PostHog project of CI';

  static const _keyIs = 'SMF_POSTHOG_KEY, the path of a file with a personal '
      'API key that may query that project';

  /// [value], or `null` when it is missing or empty.
  static String? _valueOf(String? value) =>
      value == null || value.trim().isEmpty ? null : value;
}

/// The event that the check of the start of the app sent, from the request
/// that it wrote: the nonce in its property [nonceProperty], the distinct id
/// of the user of the device, and the flavor of the build.
final class EventRequest {
  EventRequest._(this.nonce, this.distinctId, this.flavor);

  /// The request in [text], the JSON that the app wrote. Throws an
  /// [EventNotReceived] that tells what the request lacks.
  factory EventRequest.parse(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw const EventNotReceived('The request of the app is no JSON.');
    }
    return switch (json) {
      {
        'nonce': final String nonce,
        'distinctId': final String distinctId,
        'flavor': final String flavor,
      }
          when _hex32.hasMatch(nonce) &&
              distinctId.isNotEmpty &&
              flavor.isNotEmpty =>
        EventRequest._(nonce, distinctId, flavor),
      _ => throw const EventNotReceived(
          'The request of the app is not an object with a nonce of 32 '
          'hexadecimal digits in lower case, and a distinct id and a flavor '
          'that are not empty.',
        ),
    };
  }

  /// The nonce in the property [nonceProperty] of the event.
  final String nonce;

  /// The distinct id of the user of the device, whom the event belongs to.
  final String distinctId;

  /// The flavor of the build of the app, which every event of it has.
  final String flavor;
}

/// Why the test does not find the event that the app sent, as a reader of
/// the log of CI needs it: what PostHog answered, what that means and what
/// to do.
final class EventNotReceived implements Exception {
  /// Creates the failure that [meaning] tells.
  const EventNotReceived(this.meaning);

  /// What went wrong, what it means and what to do.
  final String meaning;

  @override
  String toString() => meaning;
}

/// The HogQL query for the events of the check with [nonce], of the last
/// day: the distinct id and the flavor of each. [nonce] has only hexadecimal
/// digits, which [EventRequest.parse] checked.
String queryOf(String nonce) {
  if (!_hex32.hasMatch(nonce)) {
    throw ArgumentError.value(nonce, 'nonce', 'is no nonce of the check');
  }
  return 'SELECT distinct_id, properties.$flavorProperty FROM events '
      "WHERE event = '$startCheckEvent' "
      "AND properties.$nonceProperty = '$nonce' "
      'AND timestamp > now() - INTERVAL 1 DAY';
}

/// Finds the event of [request] in the PostHog project [projectId], at
/// [api], with the personal API key [key], through [client], and returns
/// what it found, for the log of CI, without the key.
///
/// It asks the query API of PostHog for the events of the check with the
/// nonce of the request every [interval] until PostHog has one: PostHog takes
/// an event in some seconds, and has none of it until then. A query that
/// PostHog may take later, as when it limits the queries, its queue of
/// queries timed out or it failed itself, goes again at the next interval.
/// Once PostHog has the event, it checks that it is the one event of the
/// check, of the user and of the flavor of the request (see
/// [problemsOfRows]).
///
/// It is done within [timeout] of its start: each query waits for PostHog at
/// most 30 seconds and never past that time, so that the test fails with
/// what PostHog answered last, within the time that the test and the script
/// of CI give it. At most one query in [interval] keeps it far below the
/// limit of PostHog on queries in an hour.
///
/// Throws an [EventNotReceived] that tells what PostHog answered and what
/// that means.
Future<String> checkEvent(
  http.Client client, {
  required String api,
  required String projectId,
  required String key,
  required EventRequest request,
  Duration interval = const Duration(seconds: 15),
  Duration timeout = const Duration(seconds: 270),
  Future<void> Function(Duration) wait = _wait,
  DateTime Function() now = DateTime.now,
}) async {
  final base = api.endsWith('/') ? api.substring(0, api.length - 1) : api;
  final path = '/api/projects/${Uri.encodeComponent(projectId)}/query/';
  final project = 'the PostHog project $projectId at $base';
  final posthog = _PostHog(client, base, key);
  final query = jsonEncode({
    'query': {'kind': 'HogQLQuery', 'query': queryOf(request.nonce)},
  });
  final until = now().add(timeout);
  Duration left() => until.difference(now());
  _Answer last;
  while (true) {
    last = await posthog.post(path, query, within: left());
    if (last.status == 200) {
      final rows = _rowsOf(last.json);
      if (rows == null) {
        throw EventNotReceived(
          'PostHog answered the query in $project without its results: '
          '${posthog.answered(last)}.',
        );
      }
      if (rows.isNotEmpty) {
        final problems = problemsOfRows(rows, request);
        if (problems.isNotEmpty) {
          throw EventNotReceived(
            'PostHog has the event of the check with the nonce of the '
            'request in $project, but not as the app sent it: '
            '${problems.join(' ')}',
          );
        }
        return 'PostHog has the event $startCheckEvent with the nonce of the '
            'request in $project, of the user of the device and with '
            '$flavorProperty ${request.flavor}.';
      }
    } else if (!last.mayGoAgain) {
      throw EventNotReceived(posthog.meaningOf(last, project));
    }
    if (left() <= interval) break;
    await wait(interval);
  }
  throw EventNotReceived(
    last.status == 200
        ? 'PostHog has no event $startCheckEvent with the nonce of the request '
            'in $project ${_secondsOf(timeout)} after the check of the app '
            'sent it: the event did not reach the project. Either the '
            'project token of the app in CI_APP_ENV, or its POSTHOG_HOST, is '
            'of another project than SMF_POSTHOG_PROJECT_ID and '
            'SMF_POSTHOG_API name, or the device did not send its batch of '
            'events, as the log of the app tells.'
        : 'PostHog did not answer the query in $project in '
            '${_secondsOf(timeout)} (${posthog.answered(last)}): run the job '
            'again later.',
  );
}

/// What is wrong with [rows], the results of the query of the check, each a
/// list of the distinct id and the flavor of an event, for the event of
/// [request]: the check sends one event, of the user of the device, with the
/// flavor of the build.
List<String> problemsOfRows(List<Object?> rows, EventRequest request) {
  if (rows.length != 1) {
    final count = 'PostHog has ${rows.length} events with the nonce, though '
        'the check sends one.';
    return [count];
  }
  final row = rows.single;
  if (row is! List<Object?> || row.length != 2) {
    return ['The row of the event is not its distinct id and its flavor.'];
  }
  final [distinctId, flavor] = row;
  final problems = <String>[];
  if (distinctId != request.distinctId) {
    problems.add(
      'Its distinct id is $distinctId, not ${request.distinctId}, the user '
      'of the device.',
    );
  }
  if (flavor != request.flavor) {
    problems.add(
      'Its $flavorProperty is ${flavor ?? 'none'}, not ${request.flavor}, '
      'the flavor of the build.',
    );
  }
  return problems;
}

/// The rows of [json], the answer of the query API, or `null` when it has
/// none.
List<Object?>? _rowsOf(Object? json) => switch (json) {
      {'results': final List<Object?> rows} => rows,
      _ => null,
    };

Future<void> _wait(Duration duration) => Future<void>.delayed(duration);

/// [duration] in seconds.
String _secondsOf(Duration duration) => '${duration.inSeconds} s';

/// How long a query waits for PostHog at most before it counts as one that
/// did not reach it.
const _requestTimeout = Duration(seconds: 30);

/// The status of an answer, with its JSON, or `null` for a query that did
/// not reach PostHog, with the error.
typedef _Answer = ({int? status, Object? json, String? error});

extension on _Answer {
  /// Whether PostHog may take the query later: it limited the queries, its
  /// queue of queries timed out, it failed itself, or it was not reached.
  bool get mayGoAgain {
    final code = status;
    return code == null || code == 429 || code >= 500 || _timedOut;
  }

  /// Whether PostHog says that the query timed out in its queue, which it
  /// may answer with a status of a client.
  bool get _timedOut {
    final text = switch (this.json) {
      final Map<String, Object?> map =>
        '${map['code'] ?? ''} ${map['detail'] ?? ''} ${map['error'] ?? ''}',
      _ => '',
    }
        .toLowerCase();
    return text.contains('timeout') || text.contains('timed out');
  }
}

/// The API of PostHog at [_base], with a personal API key as a bearer
/// token.
final class _PostHog {
  _PostHog(this._client, this._base, this._key);

  final http.Client _client;
  final String _base;
  final String _key;

  /// The answer to a POST of [body] to [path] of the API, which waits for
  /// PostHog at most [_requestTimeout] and never longer than [within].
  Future<_Answer> post(
    String path,
    String body, {
    required Duration within,
  }) async {
    final limit = within < _requestTimeout ? within : _requestTimeout;
    if (limit <= Duration.zero) {
      return (status: null, json: null, error: 'no time was left for it');
    }
    final http.Response response;
    try {
      final request = http.Request('POST', Uri.parse('$_base$path'))
        ..headers['Authorization'] = 'Bearer $_key'
        ..headers['Content-Type'] = 'application/json'
        ..headers['Accept'] = 'application/json'
        ..body = body;
      response = await Future(
        () async => http.Response.fromStream(await _client.send(request)),
      ).timeout(limit);
    } on Object catch (error) {
      if (error is! TimeoutException &&
          error is! SocketException &&
          error is! http.ClientException) {
        rethrow;
      }
      return (status: null, json: null, error: _clean('$error'));
    }
    Object? json;
    try {
      json = jsonDecode(response.body);
    } on FormatException {
      json = null;
    }
    return (status: response.statusCode, json: json, error: null);
  }

  /// What [answer] tells, without the key: the status and the detail of
  /// PostHog, or the error of a query that did not reach it.
  String answered(_Answer answer) {
    if (answer.status == null) return 'the query failed, ${answer.error}';
    final detail = switch (answer.json) {
      {'detail': final String detail} => ', ${_clean(detail)}',
      _ => '',
    };
    return 'it answered ${answer.status}$detail';
  }

  /// What [answer] to the query in [project] means.
  String meaningOf(_Answer answer, String project) {
    final said = answered(answer);
    return switch (answer.status) {
      401 => 'PostHog did not take the key for $project ($said): '
          'SMF_POSTHOG_KEY needs the path of a file with a personal API key '
          'of PostHog that is not revoked.',
      403 => 'The key may not query $project ($said): give it the scope '
          '$neededScope, and the project among those that it may use.',
      404 => 'PostHog does not see $project ($said): SMF_POSTHOG_PROJECT_ID '
          'needs the id of the project of CI, SMF_POSTHOG_API the host of '
          'its region, and the key one that may use that project.',
      _ => 'PostHog refused the query in $project ($said).',
    };
  }

  /// [text] without the key, which a text from PostHog may name.
  String _clean(String text) =>
      _key.isEmpty ? text : text.replaceAll(_key, _placeholder);
}
