// A test that continuous integration runs in the apps with the REST role,
// whichever module provides it: the token of the user goes only to the origin
// of the address of the client, the same scheme, host and port, and a redirect
// to another origin takes it away with the credentials of the caller. A
// provider that follows a redirect itself would take every header along.
//
// It knows only the role, and gives the client the tokens of the test. That the
// client gets those of the session is for the test rest_session.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/rest/app_rest.dart';

import 'rest_role.dart';

/// The header of a request with the token of the tests.
const _bearer = 'Bearer the-token';

void main() {
  late RestTestServer server;
  late RestTestServer other;
  late AppRestClient client;

  /// Answers a GET for [path] of [server] with a redirect to [location].
  void redirect(RestTestServer server, String path, String location) =>
      server.answer('GET', path, (request) async {
        request.response
          ..statusCode = HttpStatus.found
          ..headers.set('location', location);
        await request.response.close();
      });

  /// The address of [path] of [server] under the other name of this machine,
  /// which is another host for a client.
  String underOtherName(RestTestServer server, String path) =>
      server.address.replaceFirst('127.0.0.1', 'localhost') + path;

  setUp(() async {
    server = await RestTestServer.start();
    other = await RestTestServer.start();
    client = clientOf(server, tokens: ScriptedTokens('the-token'));
    server.answerJson('GET', '$apiPath/notes', ['a']);
    other.answerJson('GET', '/target', ['b']);
  });

  tearDown(() async {
    await server.close();
    await other.close();
  });

  test('a request to the origin of the address has the token', () async {
    final outcome = await outcomeOf(client.get('notes'));

    expect(outcome, answers(200), reason: 'The server has the path.');
    expect(
      server.requests.single.headers['authorization'],
      _bearer,
      reason: 'A provider sends the headers of the exchange.',
    );
  });

  test('a request to another port or another host has no token', () async {
    await outcomeOf(client.get('${other.address}/target'));
    await outcomeOf(client.get(underOtherName(server, '$apiPath/notes')));

    expect(
      [
        for (final request in [...other.requests, ...server.requests])
          request.headers['authorization'],
      ],
      [null, null],
      reason: 'The token goes only to the origin of the address: another port '
          'and another host are other origins.',
    );
  });

  test('a redirect on the origin of the address keeps the token', () async {
    redirect(server, '$apiPath/moved', '$apiPath/notes');

    final outcome = await outcomeOf(client.get('moved'));

    expect(
      outcome,
      answers(200),
      reason: 'A GET follows a redirect, whose location is a header of the '
          'reply.',
    );
    expect(
      [
        for (final request in server.requests)
          (request.uri.path, request.headers['authorization']),
      ],
      [('$apiPath/moved', _bearer), ('$apiPath/notes', _bearer)],
      reason: 'The client follows a redirect, and a hop on the origin of the '
          'address has the token.',
    );
  });

  test(
      'a redirect to another host takes the token and the credentials of the '
      'caller away', () async {
    redirect(server, '$apiPath/moved', underOtherName(other, '/target'));

    final outcome = await outcomeOf(
      client.get(
        'moved',
        headers: {'Cookie': 'of=caller', 'X-Of-The-Call': 'stays'},
      ),
    );

    expect(
      outcome,
      answers(200),
      reason: 'A GET follows a redirect, whose location is a header of the '
          'reply.',
    );
    expect(
      server.requests,
      hasLength(1),
      reason: 'The first hop reaches the server of the app once.',
    );
    final target = other.requests.single.headers;
    expect(
      [target['authorization'], target['cookie'], target['x-of-the-call']],
      [null, null, 'stays'],
      reason: 'The client decides which header goes where, so a provider '
          'follows no redirect: at another origin, the token and the cookie '
          'of the caller are gone.',
    );
  });

  test(
      'a redirect to another port takes the token away, and a hop back gets '
      'it again', () async {
    redirect(server, '$apiPath/moved', '${other.address}/back');
    redirect(other, '/back', '${server.address}$apiPath/notes');

    final outcome = await outcomeOf(client.get('moved'));

    expect(
      outcome,
      answers(200),
      reason: 'A GET follows a redirect, whose location is a header of the '
          'reply.',
    );
    expect(
      [
        other.requests.single.headers['authorization'],
        server.requests.last.headers['authorization'],
      ],
      [null, _bearer],
      reason: 'The client decides which header goes where, so a provider '
          'follows no redirect: another port gets no token, and only a hop '
          'back to the origin of the address does.',
    );
  });

  test('a header authorization of the caller stays, in place of the token',
      () async {
    await outcomeOf(
      client.get('notes', headers: {'Authorization': 'Basic of-the-caller'}),
    );

    expect(
      server.requests.single.headers['authorization'],
      'Basic of-the-caller',
      reason: 'A header of the caller takes precedence over the token.',
    );
  });
}
