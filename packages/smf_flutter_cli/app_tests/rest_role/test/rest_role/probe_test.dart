// A test that continuous integration runs in the apps with the REST role,
// whichever module provides it: the probe of the role, which the start check
// runs on a device, finds no problem under flutter test, and it says when the
// client of an app without an address does not keep to what the role says.
//
// It knows only the role.
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
}
