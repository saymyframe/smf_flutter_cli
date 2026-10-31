// A test that continuous integration runs in the apps with the REST role,
// whichever module provides it: a timeout covers the whole of an attempt, also
// a body that comes bit by bit, a cancel ends a call at once, and each closes
// the connection, which is what a provider does when the exchange has to stop.
//
// It knows only the role. It looks at the socket of a server that holds the
// request, and only at upper bounds of seconds, so that a slow machine does not
// fail it.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/rest/app_rest.dart';

import 'rest_role.dart';

/// The reason of the expectations that the connection closes.
const _closes = 'When RestExchange.stop completes, a provider closes the '
    'connection at once.';

void main() {
  late RestTestServer server;

  setUp(() async {
    server = await RestTestServer.start();
  });

  tearDown(() => server.close());

  test(
      'no answer within the timeout is the reason timeout, and the connection '
      'closes', () async {
    final silent = await RawServer.start((socket, head) {});
    addTearDown(silent.close);
    final client = clientOf(
      server,
      timeout: const Duration(milliseconds: 300),
    );

    final outcome = await outcomeOf(client.post('${silent.address}/notes'));

    expect(
      outcome,
      failsWith(RestFailureReason.timeout),
      reason: 'The client ends a call at its timeout, whatever the provider '
          'does.',
    );
    expect(await silent.sawClose(), isTrue, reason: _closes);
  });

  test(
      'a body that comes bit by bit past the timeout is the reason timeout, '
      'and the connection closes', () async {
    Timer? drip;
    final slow = await RawServer.start((socket, head) {
      socket.write('HTTP/1.1 200 OK\r\ncontent-length: 1000\r\n\r\n');
      drip = Timer.periodic(
        const Duration(milliseconds: 50),
        (_) => socket.write('x'),
      );
    });
    addTearDown(() async {
      drip?.cancel();
      await slow.close();
    });
    final client = clientOf(
      server,
      timeout: const Duration(milliseconds: 500),
    );

    final outcome = await outcomeOf(client.post('${slow.address}/notes'));

    expect(
      outcome,
      failsWith(RestFailureReason.timeout),
      reason: 'The timeout covers the whole of an attempt, not the time '
          'between two parts of a body.',
    );
    expect(await slow.sawClose(), isTrue, reason: _closes);
  });

  test(
      'a cancel while the server holds the request ends the call at once, and '
      'the connection closes', () async {
    final heard = Completer<void>();
    final silent = await RawServer.start((socket, head) {
      if (!heard.isCompleted) heard.complete();
    });
    addTearDown(silent.close);
    final cancel = RestCancel();

    final call = outcomeOf(
      clientOf(server).post('${silent.address}/notes', cancel: cancel),
    );
    await heard.future;
    cancel.cancel();
    final outcome = await call.timeout(const Duration(seconds: 3));

    expect(outcome, failsWith(RestFailureReason.cancelled));
    expect(await silent.sawClose(), isTrue, reason: _closes);
  });

  test(
      'a cancel in the middle of a body ends the call at once, and the '
      'connection closes', () async {
    final heard = Completer<void>();
    final slow = await RawServer.start((socket, head) {
      unawaited(
        RawServer.send(
          socket,
          'HTTP/1.1 200 OK\r\ncontent-length: 1000\r\n\r\nthe start',
          () {
            if (!heard.isCompleted) heard.complete();
          },
        ),
      );
    });
    addTearDown(slow.close);
    final cancel = RestCancel();

    final call = outcomeOf(
      clientOf(server).post('${slow.address}/notes', cancel: cancel),
    );
    await heard.future;
    // The start of the body reaches the client.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    cancel.cancel();
    final outcome = await call.timeout(const Duration(seconds: 3));

    expect(outcome, failsWith(RestFailureReason.cancelled));
    expect(await slow.sawClose(), isTrue, reason: _closes);
  });

  test('a cancel before the call sends nothing', () async {
    final cancel = RestCancel()..cancel();
    server.answerJson('POST', '$apiPath/notes', ['a']);

    expect(
      await outcomeOf(clientOf(server).post('notes', cancel: cancel)),
      failsWith(RestFailureReason.cancelled),
    );
    expect(server.requests, isEmpty);
  });

  test('a cancel wakes the wait for a repeat at once', () async {
    final asked = Completer<void>();
    server.answer('GET', '$apiPath/flaky', (request) async {
      request.response
        ..statusCode = 503
        ..headers.set('retry-after', '20');
      await request.response.close();
      if (!asked.isCompleted) asked.complete();
    });
    final cancel = RestCancel();

    final call = outcomeOf(clientOf(server).get('flaky', cancel: cancel));
    await asked.future;
    // The reply reaches the client, which starts to wait.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    cancel.cancel();
    final outcome = await call.timeout(const Duration(seconds: 3));

    expect(outcome, failsWith(RestFailureReason.cancelled));
    expect(
      server.requests,
      hasLength(1),
      reason: 'The client waits for the Retry-After, and a provider repeats '
          'nothing itself.',
    );
  });
}
