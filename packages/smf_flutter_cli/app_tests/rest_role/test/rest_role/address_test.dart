// A test that continuous integration runs in the apps with the REST role,
// whichever module provides it: the client of the app takes its address from
// .env, and a request reaches the server as the code asked, with its path, its
// query, its headers and its body, and with no credential that the code did
// not give. With no address, a relative path fails before anything is sent.
//
// It knows only the role. The value of the address comes from the test itself
// (MatrixAppTest.envValues), a port with no listener, so no test binds a fixed
// port. The tokens of the client of the app are those of the test, so that it
// waits for no session, which it never starts.
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/env/app_env.dart';
import 'package:{{app_name}}/core/rest/app_rest.dart';
import 'package:{{app_name}}/core/rest/rest_transport.dart';

import 'rest_role.dart';

/// A transport that notes the exchanges, and answers each with a 200.
final class _Recording implements RestTransport {
  final List<RestExchange> exchanges = [];

  @override
  Future<RestReply> send(RestExchange exchange) async {
    exchanges.add(exchange);
    return const RestReply(status: 200, headers: {}, bytes: []);
  }
}

void main() {
  late RestTestServer server;
  late AppRestClient client;

  setUp(() async {
    server = await RestTestServer.start();
    client = clientOf(server);
    server.answerJson('GET', '$apiPath/notes', ['a']);
    server.answerJson('POST', '$apiPath/notes', ['a']);
  });

  tearDown(() => server.close());

  test('the client of the app takes its address from .env', () async {
    final transport = _Recording();
    appRest.use(transport: transport, tokens: ScriptedTokens(null));

    expect(
      AppEnv.restBaseUrl,
      '{{base_address}}',
      reason: 'The test gives the key this value in .env.',
    );
    await appRest.get('notes');
    await appRest.get('/notes');

    expect(
      [for (final exchange in transport.exchanges) '${exchange.uri}'],
      ['{{base_address}}/notes', '{{base_address}}/notes'],
      reason: 'A path of the client of the app joins the value of .env, with '
          'or without a leading slash.',
    );
  });

  test('a request reaches the path of the address, with its query', () async {
    final outcome = await outcomeOf(
      client.get('notes', query: {'x': 'a b', 'y': '1&2'}),
    );

    expect(outcome, answers(200), reason: 'The server has the path.');
    expect(
      '${server.requests.single.uri}',
      '$apiPath/notes?x=a%20b&y=1%262',
      reason: 'A provider sends the address as it is, with its query.',
    );
  });

  test('a query in the path stays, next to the query of the call', () async {
    await outcomeOf(client.get('/notes?page=2', query: {'x': '1'}));

    expect(
      '${server.requests.single.uri}',
      '$apiPath/notes?page=2&x=1',
      reason: 'A provider sends the address as it is, with its query.',
    );
  });

  test('a path with two slashes stays on the server of the app', () async {
    await outcomeOf(client.get('//other.example/x'));

    expect(
      server.requests.single.uri.path,
      '$apiPath/other.example/x',
      reason: 'Only http:// and https:// make a path an address of its own.',
    );
  });

  test(
      'an address of its own goes where it says, also without an address '
      'of the client', () async {
    final client = AppRestClient(
      transport: createRestTransport(),
      baseAddress: null,
    );

    final outcome = await outcomeOf(
      client.get('${server.address}$apiPath/notes?page=3'),
    );

    expect(outcome, answers(200), reason: 'The server has the path.');
    expect(
      '${server.requests.single.uri}',
      '$apiPath/notes?page=3',
      reason: 'A full address goes where it says.',
    );
  });

  for (final (what, address) in [
    ('no value', null),
    ('an empty value', ''),
    ('a value without a scheme', 'api.example.com/v1'),
    ('a value with a query', 'https://api.example.com/v1?key=a'),
  ]) {
    test(
        'with $what, a relative path fails with notConfigured, which names '
        'the key, and nothing is sent', () async {
      final transport = _Recording();
      final client = AppRestClient(transport: transport, baseAddress: address);

      final outcome = await outcomeOf(client.get('notes'));

      expect(
        outcome,
        failsWith(RestFailureReason.notConfigured),
        reason: 'A relative path needs an address.',
      );
      expect((outcome as RestFailure).developerHint, contains('{{base_key}}'));
      expect(transport.exchanges, isEmpty, reason: 'Nothing is sent.');
    });
  }

  test('the method, the headers and the body of a call reach the server',
      () async {
    for (final method in ['POST', 'PUT', 'PATCH', 'DELETE']) {
      server.answerJson(method, '$apiPath/sent', {'ok': true});
    }

    final calls = {
      'POST': client.post,
      'PUT': client.put,
      'PATCH': client.patch,
      'DELETE': client.delete,
    };
    for (final MapEntry(key: method, value: call) in calls.entries) {
      final outcome = await outcomeOf(
        call(
          'sent',
          json: {'method': method},
          headers: {'X-Of-The-Call': 'a'},
        ),
      );
      expect(outcome, answers(200), reason: 'The server has $method.');
      final request = server.requests.last;
      expect(request.method, method, reason: 'The method reaches the server.');
      expect(
        request.body,
        '{"method":"$method"}',
        reason: 'The body of $method reaches the server.',
      );
      expect(
        [
          request.headers['x-of-the-call'],
          request.headers['content-type'],
          request.headers['content-length'],
        ],
        ['a', startsWith('application/json'), '${request.bytes.length}'],
        reason: 'A provider sends the headers of the exchange, with the '
            'content-length of the body.',
      );
    }
  });

  test('a body of plain integers reaches the server byte by byte', () async {
    // A growable list, and not a typed one, as most code that has bytes has.
    final bytes = [for (var byte = 0; byte < 256; byte++) byte];

    final outcome = await outcomeOf(client.post('notes', bytes: bytes));

    expect(outcome, answers(200), reason: 'The server has the path.');
    expect(
      server.requests.single.bytes,
      bytes,
      reason: 'A provider sends the bytes of a body as they are.',
    );
    expect(
      server.requests.single.headers['content-length'],
      '256',
      reason: 'The client gives a body its length, and a provider sends it.',
    );
  });

  test('a HEAD reaches the server, and the answer has no body', () async {
    server.answer('HEAD', '$apiPath/notes', (request) async {
      await request.response.close();
    });

    final outcome = await outcomeOf(client.head('notes'));

    expect(outcome, answers(200), reason: 'The server has the path.');
    expect((outcome as RestResponse).bytes, isEmpty);
    expect(server.requests.single.method, 'HEAD');
  });

  test(
      'a request has no credential that the code did not give, and no cookie '
      'of an answer before it', () async {
    server.answer('GET', '$apiPath/cookie', (request) async {
      request.response.headers.add('set-cookie', 'session=of-the-server');
      await request.response.close();
    });

    await outcomeOf(client.get('cookie'));
    await outcomeOf(client.get('cookie'));

    for (final request in server.requests) {
      expect(
        [request.headers['authorization'], request.headers['cookie']],
        [null, null],
        reason: 'A provider adds no credential or cookie, and keeps none '
            'between two calls.',
      );
    }
  });
}
