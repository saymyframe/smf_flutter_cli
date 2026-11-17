/// What the test that checks the event of the app that CI starts knows of
/// Sentry: the request of the app, how a client with a token reads an event
/// of a project with the API of Sentry, what the event must have, and what
/// each answer means. Nothing here reaches Sentry, so the tests of this file
/// run everywhere.
///
/// The token is a secret of CI, so no text here has it: a text from Sentry
/// that names it gets a placeholder in its place.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Where the API of Sentry is, unless CI names another host, such as that
/// of the region of the organization.
const defaultApiOfSentry = 'https://sentry.io';

/// The scope that the token of CI needs: to read the project and its events.
const neededScope = 'project:read';

/// The name of the SDK of Sentry for Flutter, which an event of the app has.
const sdkOfFlutter = 'sentry.dart.flutter';

/// The type of the mechanism with which the reporter of the app reports an
/// error that its code reports, which the check of the app sends.
const mechanismOfRecordError = 'CrashReporter.recordError';

/// How many times a request that Sentry may take later goes, in all, before
/// the project is known.
const attempts = 3;

/// What a text from Sentry has in place of the token.
const _placeholder = '<the token>';

/// A value of the request: 32 hexadecimal digits in lower case, as Sentry
/// writes the id of an event and as the check of the app writes its nonce.
final _hex32 = RegExp(r'^[0-9a-f]{32}$');

/// The event that the check of the start of the app sent, from the request
/// that it wrote: the id of the event in Sentry, the nonce in the text of its
/// error, and its environment, the flavor of the build.
final class EventRequest {
  EventRequest._(this.eventId, this.nonce, this.environment);

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
        'eventId': final String eventId,
        'nonce': final String nonce,
        'environment': final String environment,
      }
          when _hex32.hasMatch(eventId) &&
              _hex32.hasMatch(nonce) &&
              environment.isNotEmpty =>
        EventRequest._(eventId, nonce, environment),
      _ => throw const EventNotReceived(
          'The request of the app is not an object with the id of an event and '
          'a nonce, each of 32 hexadecimal digits in lower case, and an '
          'environment that is not empty.',
        ),
    };
  }

  /// The id of the event in Sentry, which the SDK gave it.
  final String eventId;

  /// The nonce that the text of the error of the event has.
  final String nonce;

  /// The environment of the event: the flavor of the build of the app.
  final String environment;
}

/// Why the test does not find the event that the app sent, as a reader of
/// the log of CI needs it: what Sentry answered, what that means and what to
/// do.
final class EventNotReceived implements Exception {
  /// Creates the failure that [meaning] tells.
  const EventNotReceived(this.meaning);

  /// What went wrong, what it means and what to do.
  final String meaning;

  @override
  String toString() => meaning;
}

/// Finds the event of [request] in the project [project] of the organization
/// [org] of Sentry, at [api], with [token], through [client], and returns
/// what it found, for the log of CI, without the token.
///
/// It reads the project first, so that a token that Sentry does not take, or
/// a project that it does not see, fails at once with what that means. A
/// request for it that Sentry may take later goes again, [attempts] times in
/// all, [pause] apart. Then it asks for the event every [interval] until
/// Sentry has it, for at most [timeout]: until Sentry has processed an event,
/// it answers 404 for it. Once Sentry has the event, it checks that the event
/// is the one that the app sent, through the reporter of the app, from a
/// build whose stack traces are readable (see [problemsOfEvent]).
///
/// Throws an [EventNotReceived] that tells what Sentry answered and what that
/// means.
Future<String> checkEvent(
  http.Client client, {
  required String api,
  required String org,
  required String project,
  required String token,
  required EventRequest request,
  Duration interval = const Duration(seconds: 5),
  Duration timeout = const Duration(seconds: 240),
  Duration pause = const Duration(seconds: 5),
  Future<void> Function(Duration) wait = _wait,
  DateTime Function() now = DateTime.now,
}) async {
  final base = api.endsWith('/') ? api.substring(0, api.length - 1) : api;
  final projectPath = '/api/0/projects/${Uri.encodeComponent(org)}/'
      '${Uri.encodeComponent(project)}/';
  final named = 'the project $org/$project of Sentry at $base';
  final sentry = _Sentry(client, base, token);
  for (var attempt = 1;; attempt++) {
    final answer = await sentry.get(projectPath);
    if (answer.status == 200) break;
    if (answer.mayGoAgain && attempt < attempts) {
      await wait(pause);
      continue;
    }
    throw EventNotReceived(sentry.meaningOf(answer, named, project: true));
  }
  final eventPath = '${projectPath}events/${request.eventId}/';
  final event = 'the event ${request.eventId} in $named';
  final until = now().add(timeout);
  _Answer last;
  while (true) {
    last = await sentry.get(eventPath);
    if (last.status == 200) {
      final problems = problemsOfEvent(last.json, request);
      if (problems.isNotEmpty) {
        throw EventNotReceived(
          'Sentry has $event, but it is not the event that the app sent: '
          '${problems.join(' ')}',
        );
      }
      return 'Sentry has $event, which the app sent through its reporter, '
          'with the environment ${request.environment} and its nonce.';
    }
    if (last.status != 404 && !last.mayGoAgain) {
      throw EventNotReceived(sentry.meaningOf(last, event, project: false));
    }
    if (!now().add(interval).isBefore(until)) break;
    await wait(interval);
  }
  throw EventNotReceived(
    last.status == 404
        ? 'Sentry does not have $event ${_secondsOf(timeout)} after the check '
            'of the '
            'app sent it: the event did not reach the project. Either the '
            'DSN of the app in CI_APP_ENV is of another project than '
            'SMF_SENTRY_ORG and SMF_SENTRY_PROJECT name, or Sentry dropped '
            'the event, as for a rate limit of the key of the DSN or a quota '
            'that is used up: the stats of the project tell.'
        : 'Sentry did not answer for $event in ${_secondsOf(timeout)} '
            '(${sentry.answered(last)}): run the job again later.',
  );
}

/// What is wrong with [event], the JSON of an event that the API of Sentry
/// gave, for the event of [request]: its environment, an exception whose
/// text has the nonce, with the mechanism of `recordError()` of the reporter
/// of the app and handled, the SDK of Sentry for Flutter, and an in-app frame
/// with a function and a file, which a build without `--obfuscate` has.
List<String> problemsOfEvent(Object? event, EventRequest request) {
  if (event is! Map<String, Object?>) return ['The event is no object.'];
  final environment = [
    if (event['tags'] case final List<Object?> tags)
      for (final tag in tags)
        if (tag case {'key': 'environment', 'value': final String value}) value,
  ];
  final exceptions = [
    if (event['entries'] case final List<Object?> entries)
      for (final entry in entries)
        if (entry
            case {
              'type': 'exception',
              'data': {'values': final List<Object?> values},
            })
          for (final value in values)
            if (value case final Map<String, Object?> exception) exception,
  ];
  final ofNonce = [
    for (final exception in exceptions)
      if (exception['value'] case final String text
          when text.contains(request.nonce))
        exception,
  ];
  final sdk = switch (event['sdk']) {
    {'name': final String name} => name,
    _ => null,
  };
  final environments = environment.isEmpty ? 'none' : environment.join(', ');
  final problems = <String>[];
  if (!environment.contains(request.environment)) {
    problems.add(
      'Its environment is $environments, not ${request.environment}, the '
      'flavor of the build.',
    );
  }
  if (sdk != sdkOfFlutter) {
    problems.add('Its SDK is ${sdk ?? 'none'}, not $sdkOfFlutter.');
  }
  if (ofNonce.isEmpty) {
    return problems
      ..add('No exception of it has the nonce of the request in its text.');
  }
  final exception = ofNonce.first;
  final mechanism = switch (exception['mechanism']) {
    final Map<String, Object?> mechanism => mechanism,
    _ => const <String, Object?>{},
  };
  final frames = [
    if (exception case {'stacktrace': {'frames': final List<Object?> frames}})
      for (final frame in frames)
        if (frame case final Map<String, Object?> map) map,
  ];
  if (mechanism['type'] != mechanismOfRecordError) {
    problems.add(
      'The mechanism of its exception is ${mechanism['type'] ?? 'none'}, not '
      '$mechanismOfRecordError, the call of the reporter of the app.',
    );
  }
  if (mechanism['handled'] != true) {
    problems.add(
      'Its exception is not handled, though the app reported it with '
      'recordError() and not as fatal.',
    );
  }
  if (!frames.any(_isReadable)) {
    problems.add(
      'Its exception has no frame of the app with a function and a Dart '
      'file, as a build without --obfuscate has: the stack trace is not '
      'readable.',
    );
  }
  return problems;
}

/// Whether [frame] is a frame of the app with a function and a Dart file.
bool _isReadable(Map<String, Object?> frame) =>
    frame['inApp'] == true &&
    frame['function'] is String &&
    (frame['function']! as String).isNotEmpty &&
    frame['filename'] is String &&
    (frame['filename']! as String).endsWith('.dart');

Future<void> _wait(Duration duration) => Future<void>.delayed(duration);

/// [duration] in seconds.
String _secondsOf(Duration duration) => '${duration.inSeconds} s';

/// How long a request waits for Sentry before it counts as one that did not
/// reach it.
const _requestTimeout = Duration(seconds: 20);

/// The status of an answer, with its JSON, or `null` for a request that did
/// not reach Sentry, with the error.
typedef _Answer = ({int? status, Object? json, String? error});

extension on _Answer {
  /// Whether Sentry may take the request later: it limited the requests,
  /// failed itself, or was not reached.
  bool get mayGoAgain {
    final code = status;
    return code == null || code == 429 || code >= 500;
  }
}

/// The API of Sentry at [_base], with a bearer token.
final class _Sentry {
  _Sentry(this._client, this._base, this._token);

  final http.Client _client;
  final String _base;
  final String _token;

  /// The answer to a GET of [path] of the API.
  Future<_Answer> get(String path) async {
    final http.Response response;
    try {
      final request = http.Request('GET', Uri.parse('$_base$path'))
        ..headers['Authorization'] = 'Bearer $_token'
        ..headers['Accept'] = 'application/json';
      response = await http.Response.fromStream(
        await _client.send(request).timeout(_requestTimeout),
      ).timeout(_requestTimeout);
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

  /// What [answer] tells, without the token: the status and the detail of
  /// Sentry, or the error of a request that did not reach it.
  String answered(_Answer answer) {
    if (answer.status == null) return 'the request failed, ${answer.error}';
    final detail = switch (answer.json) {
      {'detail': final String detail} => ', ${_clean(detail)}',
      _ => '',
    };
    return 'it answered ${answer.status}$detail';
  }

  /// What [answer] to the request for [what] means: for the [project]
  /// itself, or for an event of it.
  String meaningOf(_Answer answer, String what, {required bool project}) {
    final said = answered(answer);
    return switch (answer.status) {
      401 => 'Sentry did not take the token for $what ($said): '
          'SMF_SENTRY_TOKEN needs the path of a file with a token of the '
          'organization that is not revoked.',
      403 => 'The token may not read $what ($said): give it the scope '
          '$neededScope, such as the permission Project: Read of an internal '
          'integration of the organization.',
      404 when project => 'Sentry does not see $what ($said): '
          'SMF_SENTRY_ORG and SMF_SENTRY_PROJECT need the slugs of the '
          'organization and of the project of CI, SMF_SENTRY_API the host of '
          'its region, and the token one of that organization.',
      null => 'The test did not reach Sentry for $what in $attempts attempts: '
          '${answer.error}. Run the job again later.',
      final int status when status == 429 || status >= 500 =>
        'Sentry failed $what ($said), also after $attempts requests: run the '
            'job again later.',
      _ => 'Sentry refused $what ($said).',
    };
  }

  /// [text] without the token, which a text from Sentry may name.
  String _clean(String text) =>
      _token.isEmpty ? text : text.replaceAll(_token, _placeholder);
}
