// A test that continuous integration runs in the apps with the REST role,
// whichever module provides it: GET and HEAD repeat twice at most after a
// connection that failed and after 429, 502, 503 and 504, keeping to
// Retry-After, and other methods never repeat, since the server may have done
// what they asked. A provider repeats nothing itself, and keeps the headers of
// a reply, from which the client reads the wait.
//
// It knows only the role. It takes about fifteen seconds of real waiting, from the
// waits of the repeats, and looks only at a lower bound of a wait, so that a
// slow machine does not fail it.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/rest/app_rest.dart';

import 'rest_role.dart';

void main() {
  late RestTestServer server;
  late AppRestClient client;

  /// Answers each request of [method] for [path] with the next of [statuses]
  /// and then with the last of them, with the headers [headers].
  void answerWith(
    String method,
    List<int> statuses, {
    String path = '$apiPath/flaky',
    Map<String, String> headers = const {},
  }) {
    var next = 0;
    server.answer(method, path, (request) async {
      final status = statuses[next < statuses.length ? next : next - 1];
      if (next < statuses.length) next++;
      request.response.statusCode = status;
      headers.forEach(request.response.headers.set);
      await request.response.close();
    });
  }

  setUp(() async {
    server = await RestTestServer.start();
    client = clientOf(server);
  });

  tearDown(() => server.close());

  test(
      'a GET repeats after a 503, and comes back with what the server then '
      'answered', () async {
    answerWith('GET', [503, 503, 200]);

    expect(
      await outcomeOf(client.get('flaky')),
      answers(200),
      reason: 'A GET repeats twice at most.',
    );
    expect(
      server.requests,
      hasLength(3),
      reason: 'The client makes each repeat, and a provider makes one attempt '
          'for each.',
    );
  });

  test('a GET stops after two repeats, with the reason of the status',
      () async {
    answerWith('GET', [503]);

    expect(
      await outcomeOf(client.get('flaky')),
      failsWith(RestFailureReason.server),
      reason: 'A GET repeats twice at most.',
    );
    expect(
      server.requests,
      hasLength(3),
      reason: 'The client makes each repeat, and a provider makes one attempt '
          'for each.',
    );
  });

  for (final method in ['POST', 'PUT', 'PATCH', 'DELETE']) {
    test('a $method does not repeat after a 503', () async {
      answerWith(method, [503]);
      final call = switch (method) {
        'POST' => client.post,
        'PUT' => client.put,
        'PATCH' => client.patch,
        _ => client.delete,
      };

      expect(
        await outcomeOf(call('flaky')),
        failsWith(RestFailureReason.server),
        reason: 'The server may have done what the call asked.',
      );
      expect(
        server.requests,
        hasLength(1),
        reason: 'A method that may have done what it asked does not repeat, '
            'so a provider makes one attempt for each exchange.',
      );
    });
  }

  test('a connection that breaks repeats a GET, and not a POST', () async {
    final breaking = await RawServer.start((socket, head) => socket.destroy());
    addTearDown(breaking.close);

    expect(
      await outcomeOf(client.get('${breaking.address}/notes')),
      failsWith(RestFailureReason.network),
      reason: 'A connection that breaks is RestConnectionFailed.',
    );
    expect(
      breaking.heads,
      hasLength(3),
      reason: 'A GET repeats twice at most, and a provider makes one attempt '
          'for each.',
    );

    breaking.heads.clear();
    expect(
      await outcomeOf(client.post('${breaking.address}/notes')),
      failsWith(RestFailureReason.network),
      reason: 'A connection that breaks is RestConnectionFailed.',
    );
    expect(
      breaking.heads,
      hasLength(1),
      reason: 'A method that may have done what it asked does not repeat, so '
          'a provider makes one attempt for each exchange.',
    );
  });

  test('a GET waits for the Retry-After of a reply, in seconds', () async {
    answerWith('GET', [429, 200], headers: {'Retry-After': '2'});
    final watch = Stopwatch()..start();

    final outcome = await outcomeOf(client.get('flaky'));

    expect(outcome, answers(200), reason: 'A GET repeats after a 429.');
    expect(
      watch.elapsed,
      greaterThanOrEqualTo(const Duration(milliseconds: 1950)),
      reason: 'A provider keeps the headers of a reply, and the client waits '
          'for the Retry-After in them.',
    );
  });

  test('a GET waits for the Retry-After of a reply, as a date', () async {
    final date = HttpDate.format(
      DateTime.now().toUtc().add(const Duration(seconds: 4)),
    );
    answerWith('GET', [503, 200], headers: {'Retry-After': date});
    final watch = Stopwatch()..start();

    final outcome = await outcomeOf(client.get('flaky'));

    expect(outcome, answers(200), reason: 'A GET repeats after a 503.');
    // The date has whole seconds, so the wait may be a second less.
    expect(
      watch.elapsed,
      greaterThanOrEqualTo(const Duration(milliseconds: 2500)),
      reason: 'A provider keeps the headers of a reply, and the client waits '
          'for the date of the Retry-After in them.',
    );
  });

  test(
      'a Retry-After over the longest wait gives no repeat, and the failure '
      'has it', () async {
    answerWith('GET', [503], headers: {'Retry-After': '60'});

    final outcome = await outcomeOf(client.get('flaky'));

    expect(
      outcome,
      isA<RestFailure>().having(
        (failure) => failure.retryAfter,
        'retryAfter',
        const Duration(seconds: 60),
      ),
      reason: 'A provider keeps the headers of a reply, and the failure has '
          'the wait that the client did not take.',
    );
    expect(
      server.requests,
      hasLength(1),
      reason: 'The client takes no wait that long, and a provider repeats '
          'nothing itself.',
    );
  });

  test('a POST does not wait, and the failure has the Retry-After', () async {
    answerWith('POST', [429], headers: {'Retry-After': '20'});
    final watch = Stopwatch()..start();

    final outcome = await outcomeOf(client.post('flaky'));

    expect(
      outcome,
      isA<RestFailure>().having(
        (failure) => failure.retryAfter,
        'retryAfter',
        const Duration(seconds: 20),
      ),
      reason: 'A provider keeps the headers of a reply, and the failure has '
          'the wait that the client did not take.',
    );
    expect(watch.elapsed, lessThan(const Duration(seconds: 10)));
    expect(server.requests, hasLength(1));
  });
}
