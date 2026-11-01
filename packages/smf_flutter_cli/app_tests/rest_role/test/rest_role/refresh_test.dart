// A test that continuous integration runs in the apps with the REST role,
// whichever module provides it: a 401 of a request with the token of the user
// gets a new token once and repeats once, for any method and with the same
// body. A provider that kept a header of an earlier call would send the token
// that the server refused.
//
// It knows only the role, and gives the client the tokens of the test. That
// requests at the same time share one refresh is the work of the session, for
// the test rest_session.
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/rest/app_rest.dart';

import 'rest_role.dart';

void main() {
  late RestTestServer server;

  /// Answers a POST of [path] with 401 while it has another token than
  /// [accepted], and with the JSON of `true` to one with it.
  void acceptOnly(String accepted, {String path = '$apiPath/notes'}) =>
      server.answer('POST', path, (request) async {
        final isAccepted =
            request.headers.value('authorization') == 'Bearer $accepted';
        request.response
          ..statusCode = isAccepted ? 200 : 401
          ..write('true');
        await request.response.close();
      });

  setUp(() async {
    server = await RestTestServer.start();
  });

  tearDown(() => server.close());

  test(
      'a 401 gets a new token once, and repeats once with it and with the '
      'same body', () async {
    final tokens = ScriptedTokens('first', refreshed: ['second']);
    final client = clientOf(server, tokens: tokens);
    acceptOnly('second');

    final outcome = await outcomeOf(
      client.post('notes', json: {'text': 'once'}),
    );

    expect(
      outcome,
      answers(200),
      reason: 'The repeat after a refresh has the new token, in place of the '
          'token of the call before: a provider keeps no header between two '
          'calls.',
    );
    expect(tokens.rejected, ['first']);
    expect(
      [
        for (final request in server.requests)
          (request.headers['authorization'], request.body),
      ],
      [
        ('Bearer first', '{"text":"once"}'),
        ('Bearer second', '{"text":"once"}'),
      ],
      reason: 'The repeat has the new token and the same body.',
    );
  });

  test('a second 401 fails with unauthorized, with no second refresh',
      () async {
    final tokens = ScriptedTokens('first', refreshed: ['second', 'third']);
    final client = clientOf(server, tokens: tokens);
    acceptOnly('third');

    expect(
      await outcomeOf(client.post('notes')),
      failsWith(RestFailureReason.unauthorized),
      reason: 'A call refreshes once.',
    );
    expect(tokens.rejected, ['first']);
    expect(server.requests, hasLength(2));
  });

  test('a 401 of a request without a token of the client gets no refresh',
      () async {
    final tokens = ScriptedTokens(null, refreshed: ['second']);
    acceptOnly('second');

    expect(
      await outcomeOf(clientOf(server, tokens: tokens).post('notes')),
      failsWith(RestFailureReason.unauthorized),
      reason: 'The client refreshes only the token that it added.',
    );
    expect(tokens.rejected, isEmpty);
    expect(server.requests, hasLength(1));
  });

  test(
      'a refresh that gives no token fails with unauthorized, and does not '
      'repeat', () async {
    final tokens = ScriptedTokens('first');
    acceptOnly('second');

    expect(
      await outcomeOf(clientOf(server, tokens: tokens).post('notes')),
      failsWith(RestFailureReason.unauthorized),
      reason: 'Nobody is signed in any more.',
    );
    expect(server.requests, hasLength(1));
  });

  test('a request of one user does not repeat for another', () async {
    late ScriptedTokens tokens;
    tokens = ScriptedTokens(
      'first',
      refreshed: ['of-another'],
      onRefresh: () => tokens.owner = 'another-user',
    );
    acceptOnly('of-another');

    expect(
      await outcomeOf(clientOf(server, tokens: tokens).post('notes')),
      failsWith(RestFailureReason.unauthorized),
      reason: 'The user changed while the request waited for a refresh.',
    );
    expect(server.requests, hasLength(1));
  });
}
