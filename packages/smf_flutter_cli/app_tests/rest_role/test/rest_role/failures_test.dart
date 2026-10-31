// A test that continuous integration runs in the apps with the REST role,
// whichever module provides it: any status is a reply of the provider, which
// the client turns into a response or into a failure of a closed set of
// reasons. A connection that fails or breaks, also in TLS, is the reason
// network, whose hint has neither the query nor the body.
//
// It knows only the role. It uses POST where it can, which does not repeat, so
// that it waits for nothing.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/rest/app_rest.dart';

import 'rest_role.dart';

void main() {
  late RestTestServer server;
  late AppRestClient client;

  setUp(() async {
    server = await RestTestServer.start();
    client = clientOf(server);
  });

  tearDown(() => server.close());

  for (final (status, reason) in [
    (400, RestFailureReason.rejected),
    (401, RestFailureReason.unauthorized),
    (403, RestFailureReason.forbidden),
    (404, RestFailureReason.notFound),
    (409, RestFailureReason.conflict),
    (422, RestFailureReason.rejected),
    (429, RestFailureReason.tooManyRequests),
    (500, RestFailureReason.server),
    (503, RestFailureReason.server),
  ]) {
    test('a $status fails with ${reason.name}, with the body of the refusal',
        () async {
      server.answerJson(
        'POST',
        '$apiPath/refused',
        {'why': 'of the server'},
        status: status,
      );

      final outcome = await outcomeOf(client.post('refused'));

      expect(
        outcome,
        failsWith(reason),
        reason: 'A provider reports any status as a reply, and the client '
            'gives each its reason.',
      );
      final failure = outcome as RestFailure;
      expect(failure.status, status);
      expect(failure.response?.status, status);
      expect(
        failure.response?.decoded((Map<String, dynamic> json) => json['why']),
        'of the server',
        reason: 'The failure has the body of the refusal.',
      );
    });
  }

  for (final status in [200, 201, 204, 304]) {
    test('a $status is a response', () async {
      server.answer('POST', '$apiPath/fine', (request) async {
        request.response.statusCode = status;
        await request.response.close();
      });

      expect(
        await outcomeOf(client.post('fine')),
        answers(status),
        reason: 'A provider reports any status as a reply.',
      );
    });
  }

  test('a redirect of a POST fails with unknown, and goes nowhere', () async {
    server.answer('POST', '$apiPath/moved', (request) async {
      request.response
        ..statusCode = HttpStatus.found
        ..headers.set('location', '$apiPath/elsewhere');
      await request.response.close();
    });

    expect(
      await outcomeOf(client.post('moved')),
      failsWith(RestFailureReason.unknown),
      reason: 'Only GET and HEAD follow a redirect.',
    );
    expect(server.requests, hasLength(1));
  });

  test(
      'the headers of a reply come with their names in lower case, and the '
      'values of one header together', () async {
    server.answer('POST', '$apiPath/headers', (request) async {
      request.response.headers
        ..set('X-Mixed-Case', 'kept', preserveHeaderCase: true)
        ..add('x-several', 'one')
        ..add('x-several', 'two');
      await request.response.close();
    });

    final outcome = await outcomeOf(client.post('headers'));

    expect(outcome, answers(200), reason: 'The server has the path.');
    final headers = (outcome as RestResponse).headers;
    expect(
      [headers['x-mixed-case'], headers['x-several']],
      ['kept', 'one, two'],
      reason: 'A provider keeps the headers of a reply, with their names in '
          'lower case and several values joined by a comma and a space.',
    );
  });

  test('a body that a server compressed comes decoded', () async {
    const text = '{"note":"compressed"}';
    server.answer('POST', '$apiPath/compressed', (request) async {
      request.response
        ..headers.set('content-encoding', 'gzip')
        ..add(gzip.encode(utf8.encode(text)));
      await request.response.close();
    });

    final outcome = await outcomeOf(client.post('compressed'));

    expect(outcome, answers(200), reason: 'The server has the path.');
    expect(
      (outcome as RestResponse).text,
      text,
      reason: 'A provider gives the body decoded of its content-encoding.',
    );
  });

  group('decoded', () {
    setUp(() => server.answer('POST', '$apiPath/odd', (request) async {
          request.response.write('this is no JSON');
          await request.response.close();
        }));

    test('a body that is no JSON fails with invalidResponse', () async {
      final response = await client.post('odd');

      expect(
        () => response.decoded((Object? json) => json),
        throwsA(failsWith(RestFailureReason.invalidResponse)),
      );
    });

    test('a parse that does not take the body fails with invalidResponse',
        () async {
      server.answerJson('POST', '$apiPath/list', ['a']);
      final response = await client.post('list');

      expect(
        () => response.decoded((Map<String, dynamic> json) => json),
        throwsA(failsWith(RestFailureReason.invalidResponse)),
      );
      expect(
        () => response.decoded((List<dynamic> json) => json.first as int),
        throwsA(failsWith(RestFailureReason.invalidResponse)),
      );
      expect(
        response.decoded((List<dynamic> json) => json.first as String),
        'a',
      );
    });
  });

  test('a port where nothing listens is the reason network, for each method',
      () async {
    final address = await closedAddress();

    expect(
      await outcomeOf(client.post('$address/notes')),
      failsWith(RestFailureReason.network),
      reason: 'A failure to connect is RestConnectionFailed.',
    );
    expect(
      await outcomeOf(client.get('$address/notes')),
      failsWith(RestFailureReason.network),
      reason: 'A failure to connect is RestConnectionFailed, also once the '
          'repeats of a GET are over.',
    );
  });

  test('a TLS handshake that fails is the reason network', () async {
    // A server that answers in plain text, which is no TLS.
    final plain = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(plain.close);
    plain.listen((socket) {
      socket
        ..done.ignore()
        ..write('HTTP/1.1 200 OK\r\n\r\n');
      unawaited(RawServer.send(socket, '', socket.destroy));
    });

    expect(
      await outcomeOf(client.post('https://127.0.0.1:${plain.port}/notes')),
      failsWith(RestFailureReason.network),
      reason: 'A TLS handshake that fails is RestConnectionFailed: on dart:io '
          'a HandshakeException, which is a TlsException.',
    );
  });

  test(
      'a connection that breaks in a body is the reason network, and the '
      'hint has no query', () async {
    final breaking = await RawServer.start((socket, head) {
      unawaited(
        RawServer.send(
          socket,
          'HTTP/1.1 200 OK\r\ncontent-length: 100\r\n\r\nthe start',
          socket.destroy,
        ),
      );
    });
    addTearDown(breaking.close);

    final outcome = await outcomeOf(
      client.post('${breaking.address}/notes?key=the-secret'),
    );

    expect(
      outcome,
      failsWith(RestFailureReason.network),
      reason: 'A connection that breaks in the body of a reply is '
          'RestConnectionFailed.',
    );
    expect(
      '$outcome ${(outcome as RestFailure).developerHint}',
      isNot(contains('the-secret')),
      reason: 'The hint of a provider has no query: on dart:io the text of '
          'an error may quote the address, so a hint has the type of the '
          'error alone.',
    );
  });
}
