// A test that continuous integration runs in the apps with the REST role,
// whichever module provides it: a request of the transport of the app reaches a
// RestTestServer, also when the transport made a request before the server
// started, which on dart:io went to the stand-in of the binding of the tests,
// and when it keeps a client of its stack.
//
// It knows only the role. It has a file of its own since the transport of the
// app lasts for a whole test file, and this test needs it to have seen the
// stand-in first.
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/rest/app_rest.dart';

import 'rest_role.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'a request reaches a server that starts after a request went to the '
      'stand-in of the binding, and none reaches it once it closed', () async {
    // The answer does not matter, since a stack that does not use HttpClient
    // of dart:io does not meet the stand-in: only that the transport has made
    // a request.
    final before = AppRestClient(
      transport: createRestTransport(),
      baseAddress: await closedAddress(),
    );
    await outcomeOf(before.post('notes'));

    final server = await RestTestServer.start();
    addTearDown(server.close);
    server.answerJson('POST', '$apiPath/notes', ['a']);
    final client = clientOf(server);

    expect(
      await outcomeOf(client.post('notes')),
      answers(200),
      reason: 'RestTestServer.start() takes the stand-in away, so a provider '
          'that keeps a client of its stack makes a new one then.',
    );
    expect(server.requests, hasLength(1));

    await server.close();

    await outcomeOf(client.post('notes'));

    expect(
      server.requests,
      hasLength(1),
      reason: 'The last close puts the stand-in back, so no request of a later '
          'test leaves for the network.',
    );
  });
}
