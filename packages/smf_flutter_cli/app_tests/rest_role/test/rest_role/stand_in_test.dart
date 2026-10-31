// A test that continuous integration runs in the apps with the REST role,
// whichever module provides it: a request of the transport of the app follows
// what RestTestServer does to the stand-in of the binding of the tests, also
// when the transport made a request before and keeps a client of its stack.
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
    // The address of a server that is not there yet does not matter: the
    // stand-in answers every request.
    final before = AppRestClient(
      transport: createRestTransport(),
      baseAddress: await closedAddress(),
    );
    await expectLater(
      outcomeOf(before.post('notes')),
      completion(failsWith(RestFailureReason.rejected)),
    );

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

    await expectLater(
      outcomeOf(client.post('notes')),
      completion(failsWith(RestFailureReason.rejected)),
    );
    expect(
      server.requests,
      hasLength(1),
      reason: 'The last close puts the stand-in back, so no request of a later '
          'test leaves for the network.',
    );
  });
}
