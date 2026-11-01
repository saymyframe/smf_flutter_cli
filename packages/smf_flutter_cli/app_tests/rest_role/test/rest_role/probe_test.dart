// A test that continuous integration runs in the apps with the REST role,
// whichever module provides it: the probe of the role, which the start check
// runs on a device, finds no problem under flutter test, and it says when the
// client of an app without an address does not keep to what the role says.
//
// It knows only the role.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/rest/app_rest.dart';
import 'package:{{app_name}}/core/rest/rest_transport.dart';

import '../../integration_test/rest_role/probe.dart';
import 'rest_role.dart';

/// A transport that answers each exchange with a 200.
final class _Answering implements RestTransport {
  @override
  Future<RestReply> send(RestExchange exchange) async =>
      const RestReply(status: 200, headers: {}, bytes: []);
}

/// A transport that works on dart:io, on a platform that refuses http:// to
/// anything but this machine, as a release of Flutter may start to.
final class _RefusingCleartext implements RestTransport {
  @override
  Future<RestReply> send(RestExchange exchange) async {
    if (exchange.uri.host == '192.0.2.1') {
      throw UnsupportedError('Insecure HTTP is not allowed by platform.');
    }
    final client = HttpClient();
    unawaited(exchange.stop.then((_) => client.close(force: true)));
    try {
      final request = await client.openUrl(exchange.method, exchange.uri);
      exchange.headers.forEach(request.headers.set);
      if (exchange.body case final body?) request.add(body);
      final response = await request.close();
      return RestReply(
        status: response.statusCode,
        headers: const {},
        bytes: await response.fold<List<int>>(
          [],
          (all, part) => all..addAll(part),
        ),
      );
    } on IOException {
      throw const RestConnectionFailed('The connection failed.');
    } finally {
      client.close();
    }
  }
}

void main() {
  late RestTestServer server;

  setUp(() async {
    // Takes away the stand-in of the binding of the tests, which a device has
    // no such thing as.
    server = await RestTestServer.start();
  });

  tearDown(() => server.close());

  test('the probe of the role finds no problem', () async {
    expect(
      await probeRest(() async {}),
      isEmpty,
      reason: 'The stack of a provider reaches a server on the device, stops '
          'an exchange, and fails as a connection fails for a closed port and '
          'for a request over http:// to an address that no machine has.',
    );
  });

  test('the probe finds no problem in an app whose client has no address',
      () async {
    final client = AppRestClient(
      transport: createRestTransport(),
      baseAddress: null,
    );

    expect(await problemsOfAddress(client, null), isEmpty);
  });

  test('the probe says when a relative path went out with no address',
      () async {
    final client = AppRestClient(
      transport: _Answering(),
      baseAddress: 'http://127.0.0.1:9',
    );

    expect(await problemsOfAddress(client, null), isNotEmpty);
    expect(await problemsOfAddress(client, 'http://127.0.0.1:9'), isEmpty);
  });

  test('the probe says when a platform refuses http://, and nothing else',
      () async {
    expect(
      await problemsOfStack(_RefusingCleartext()),
      [contains('http://')],
      reason: 'A refusal of http:// reaches the code as unknown, and the stack '
          'passes the other checks of the probe.',
    );
  });
}
