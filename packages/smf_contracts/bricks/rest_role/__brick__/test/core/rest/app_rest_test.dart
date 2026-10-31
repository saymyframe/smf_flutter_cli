import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/rest/app_rest.dart';

import 'rest_test_server.dart';

void main() {
  late RestTestServer server;
  late AppRestClient client;

  setUp(() async {
    server = await RestTestServer.start();
    client = AppRestClient(
      transport: createRestTransport(),
      baseAddress: '${server.address}/v1',
    );
  });

  tearDown(() => server.close());

  test('a relative path reaches the address, and the body is decoded',
      () async {
    server.answerJson('GET', '/v1/notes', ['a', 'b']);

    final notes = await client.get('notes', query: {'page': '1'});

    expect(notes.decoded((List<Object?> json) => json.length), 2);
    expect(server.requests.single.uri.toString(), '/v1/notes?page=1');
  });

  test('a 404 fails with notFound', () async {
    await expectLater(
      client.get('notes'),
      throwsA(
        isA<RestFailure>()
            .having((failure) => failure.reason, 'reason', RestFailureReason.notFound)
            .having((failure) => failure.status, 'status', 404),
      ),
    );
  });
}
