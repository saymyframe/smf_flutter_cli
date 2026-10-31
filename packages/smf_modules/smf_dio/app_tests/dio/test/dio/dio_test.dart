// The test that continuous integration runs in the apps with the dio module:
// what only this provider of the REST role does, which is one exchange on a Dio,
// on the real package. What every provider keeps to is for the tests of the
// role.
//
// An adapter of the test stands in for the stack of Dio, so the test sees what
// the transport asks of Dio and scripts what comes back, whichever error of
// which type. The tests of what happens on a socket take a local server.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/rest/app_rest.dart';
import 'package:{{app_name}}/core/rest/dio_rest_transport.dart';
import 'package:{{app_name}}/core/rest/rest_transport.dart';

import '../core/rest/rest_test_server.dart';

/// The stack of a Dio of a test: it notes what it is asked, and answers with
/// [reply] or throws [failure].
final class _Stack implements HttpClientAdapter {
  _Stack({this.failure});

  final Object? failure;
  ResponseBody Function() reply = () => ResponseBody.fromString('', 200);

  /// What an exchange waits for once it reached the stack, if anything.
  Future<void>? hold;
  final List<RequestOptions> asked = [];
  final List<List<int>?> bodies = [];
  final List<Future<void>?> cancels = [];

  /// Whether Dio closed the stack and let what is on its way end.
  bool closedGently = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    asked.add(options);
    cancels.add(cancelFuture);
    bodies.add(
      requestStream == null
          ? null
          : await requestStream.fold<List<int>>(
              [],
              (all, part) => all..addAll(part),
            ),
    );
    await hold;
    if (failure case final failure?) throw failure;
    return reply();
  }

  @override
  void close({bool force = false}) => closedGently = !force;
}

/// Overrides that change nothing of what `HttpClient` does.
final class _OtherOverrides extends HttpOverrides {}

/// A transport over [stack], with the Dio that the app creates.
DioRestTransport _transportOver(_Stack stack) =>
    DioRestTransport(() => createDio()..httpClientAdapter = stack);

/// An exchange that does not stop.
RestExchange _exchange({
  String method = 'POST',
  String address = 'https://api.example.com/v1/notes?page=1&key=a%20b',
  Map<String, String> headers = const {},
  List<int>? body,
  Future<void>? stop,
}) =>
    RestExchange(
      method: method,
      uri: Uri.parse(address),
      headers: headers,
      body: body,
      stop: stop ?? Completer<void>().future,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('an exchange', () {
    test('gets to Dio as it is, and no more than that', () async {
      final stack = _Stack();

      await _transportOver(stack).send(
        _exchange(
          method: 'PATCH',
          headers: {'x-mine': 'a', 'content-length': '3'},
          body: const [0, 200, 255],
        ),
      );

      final asked = stack.asked.single;
      expect(asked.method, 'PATCH');
      expect(
        asked.uri.toString(),
        'https://api.example.com/v1/notes?page=1&key=a%20b',
      );
      expect(
        {...asked.headers},
        {'x-mine': 'a', 'content-length': '3'},
        reason: 'The transport sends those headers: Dio adds no type of its '
            'own to a body.',
      );
      expect(asked.followRedirects, isFalse);
      expect(asked.responseType, ResponseType.bytes);
      expect(asked.validateStatus(500), isTrue);
      expect(asked.validateStatus(302), isTrue);
      expect(asked.connectTimeout, isNull);
      expect(asked.receiveTimeout, isNull);
      expect(asked.sendTimeout, isNull);
    });

    test('sends a body of a plain list byte by byte', () async {
      final stack = _Stack();

      await _transportOver(stack).send(
        _exchange(body: const [0, 200, 255]),
      );
      await _transportOver(stack).send(
        _exchange(body: Uint8List.fromList(const [1, 2])),
      );
      await _transportOver(stack).send(
        _exchange(body: const []),
      );
      await _transportOver(stack).send(_exchange());

      expect(
        stack.bodies,
        [
          [0, 200, 255],
          [1, 2],
          <int>[],
          null,
        ],
        reason: 'Dio writes any list that is no Uint8List as the text of its '
            'JSON.',
      );
    });

    test('takes the reply as it came', () async {
      final stack = _Stack()
        ..reply = () => ResponseBody.fromBytes(
              const [1, 2, 3],
              418,
              headers: {
                'x-several': ['one', 'two'],
                'X-Mixed-Case': ['kept'],
              },
            );

      final reply = await _transportOver(stack).send(_exchange());

      expect(reply.status, 418);
      expect(reply.bytes, const [1, 2, 3]);
      expect(reply.headers, {'x-several': 'one, two', 'x-mixed-case': 'kept'});
    });

    test('takes a redirect as a reply', () async {
      final stack = _Stack()
        ..reply = () => ResponseBody.fromBytes(
              const [],
              302,
              headers: {
                'location': ['/elsewhere'],
              },
            );

      final reply = await _transportOver(stack).send(_exchange());

      expect(reply.status, 302);
      expect(reply.headers['location'], '/elsewhere');
      expect(stack.asked, hasLength(1));
    });

    test('stops when the exchange has to stop', () async {
      final stack = _Stack();
      final stop = Completer<void>();

      await _transportOver(stack).send(_exchange(stop: stop.future));
      final cancelled = stack.cancels.single!;
      var isCancelled = false;
      unawaited(cancelled.whenComplete(() => isCancelled = true));
      await Future<void>.delayed(Duration.zero);
      expect(isCancelled, isFalse);

      stop.complete();
      await cancelled.timeout(const Duration(seconds: 3));
    });
  });

  group('an error', () {
    const secret = 'secret-of-the-query';
    const address = 'https://api.example.com/v1/notes?key=$secret';
    final options = RequestOptions(path: address);

    /// What [failure] of the stack of Dio ends the exchange with.
    Future<Object> endOf(Object failure) async {
      try {
        await _transportOver(_Stack(failure: failure))
            .send(_exchange(address: address));
        return 'an answer';
      } on Object catch (error) {
        return error;
      }
    }

    final failsTheConnection = <String, Object>{
      'a connection that failed': DioException.connectionError(
        requestOptions: options,
        reason: 'Failed host lookup: $address',
        error: const SocketException('Failed host lookup: $address'),
      ),
      'a connection that timed out': DioException.connectionTimeout(
        requestOptions: options,
        timeout: const Duration(seconds: 1),
      ),
      'a send that timed out': DioException.sendTimeout(
        requestOptions: options,
        timeout: const Duration(seconds: 1),
      ),
      'a receive that timed out': DioException.receiveTimeout(
        requestOptions: options,
        timeout: const Duration(seconds: 1),
      ),
      'a bad certificate': DioException.badCertificate(
        requestOptions: options,
        error: address,
      ),
      'a TLS handshake that failed': const HandshakeException(
        'Handshake error at $address',
      ),
      'a certificate that failed': const CertificateException(
        'Bad certificate at $address',
      ),
      'a connection that broke in a body': HttpException(
        'Connection closed while receiving data',
        uri: Uri.parse(address),
      ),
      'a connection that broke at once': const SocketException(
        'Connection reset by peer at $address',
      ),
    };
    failsTheConnection.forEach((name, failure) {
      test('$name is a failed connection, with no query in its hint', () async {
        final end = await endOf(failure);

        expect(end, isA<RestConnectionFailed>());
        expect('$end', isNot(contains(secret)));
        expect((end as RestConnectionFailed).hint, isNot(contains(secret)));
      });
    });

    test('of another kind reaches the caller as what it is', () async {
      expect(
        await endOf(const FormatException('Filter error')),
        isA<FormatException>(),
      );
      expect(await endOf(StateError('No way.')), isA<StateError>());
      expect(
        await endOf(DioException.badResponse(
          statusCode: 500,
          requestOptions: options,
          response: Response<void>(requestOptions: options),
        )),
        isA<DioException>(),
      );
    });

    test('that an interceptor throws reaches the client as its type', () async {
      final transport = DioRestTransport(
        () => createDio()
          ..httpClientAdapter = _Stack()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) => throw StateError('No way.'),
            ),
          ),
      );
      final client = AppRestClient(
        transport: transport,
        baseAddress: 'https://api.example.com',
      );

      await expectLater(
        client.post('notes'),
        throwsA(
          isA<RestFailure>()
              .having((failure) => failure.reason, 'reason',
                  RestFailureReason.unknown)
              .having((failure) => failure.developerHint, 'hint',
                  contains('StateError')),
        ),
      );
    });
  });

  group('the Dio of the app', () {
    test('takes an interceptor that createDio() adds', () async {
      final seen = <String>[];
      final transport = DioRestTransport(
        () => createDio()
          ..httpClientAdapter = _Stack()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                seen.add('${options.method} ${options.uri.path}');
                handler.next(options);
              },
            ),
          ),
      );

      await transport.send(_exchange());

      expect(seen, ['POST /v1/notes']);
    });

    test('is one for as long as nothing changes the overrides', () async {
      var created = 0;
      final stack = _Stack();
      final transport = DioRestTransport(() {
        created++;
        return createDio()..httpClientAdapter = stack;
      });

      expect(created, 0, reason: 'An app that makes no request has no Dio.');
      await transport.send(_exchange());
      await transport.send(_exchange());
      await transport.send(_exchange());

      expect(created, 1);
      expect(stack.closedGently, isFalse);
    });

    test(
        'is a new one when the overrides change, and the one before lets the '
        'exchanges that are on their way end', () async {
      final stacks = <_Stack>[];
      final transport = DioRestTransport(() {
        final stack = _Stack();
        stacks.add(stack);
        return createDio()..httpClientAdapter = stack;
      });
      final before = HttpOverrides.current;
      addTearDown(() => HttpOverrides.global = before);

      await transport.send(_exchange());
      HttpOverrides.global = null;
      await transport.send(_exchange());
      await transport.send(_exchange());
      HttpOverrides.global = before;
      await transport.send(_exchange());

      expect(stacks, hasLength(3));
      expect([for (final stack in stacks) stack.closedGently],
          [true, true, false]);
      expect([for (final stack in stacks) stack.asked.length], [1, 2, 1]);
    });

    test(
        'is closed once the overrides changed and its last exchange ended, and '
        'not before', () async {
      final stacks = <_Stack>[];
      final held = Completer<void>();
      final transport = DioRestTransport(() {
        final stack = _Stack()..hold = stacks.isEmpty ? held.future : null;
        stacks.add(stack);
        return createDio()..httpClientAdapter = stack;
      });
      final before = HttpOverrides.current;
      addTearDown(() => HttpOverrides.global = before);

      final first = transport.send(_exchange());
      await Future<void>.delayed(Duration.zero);
      HttpOverrides.global = null;
      await transport.send(_exchange());

      expect(stacks, hasLength(2));
      expect(
        stacks.first.closedGently,
        isFalse,
        reason: 'An exchange is on its way on the Dio before.',
      );

      held.complete();
      await first;

      expect(stacks.first.closedGently, isTrue);
      expect(stacks.last.closedGently, isFalse);
    });

    test('is what the transport of the app uses', () {
      expect(createRestTransport(), isA<DioRestTransport>());
    });
  });

  group('on a socket', () {
    late RestTestServer server;

    setUp(() async {
      server = await RestTestServer.start();
    });

    tearDown(() => server.close());

    test('two requests share one connection', () async {
      final ports = <int?>[];
      server.answer('GET', '/one', (request) async {
        ports.add(request.connectionInfo?.remotePort);
        await request.response.close();
      });
      final transport = createDioRestTransport();
      Future<void> send() => transport.send(
            _exchange(method: 'GET', address: '${server.address}/one'),
          );

      await send();
      await send();

      expect(ports, hasLength(2));
      expect(
        ports.toSet(),
        hasLength(1),
        reason: 'One Dio for each request would take a new TLS handshake for '
            'each request.',
      );
    });

    test('a plain list arrives byte by byte, with its length', () async {
      server.answer('POST', '/bytes', (request) async {
        await request.response.close();
      });

      await createDioRestTransport().send(
        _exchange(
          address: '${server.address}/bytes',
          headers: {'content-length': '4'},
          body: utf8.encode('ab') + const [0, 255],
        ),
      );

      final request = server.requests.single;
      expect(request.bytes, [97, 98, 0, 255]);
      expect(request.headers['content-length'], '4');
      expect(request.headers, isNot(contains('content-type')));
    });

    test(
        'an exchange that has not reached the stack of Dio when the overrides '
        'change still reaches the server', () async {
      server
        ..answerJson('POST', '/first', 'first')
        ..answerJson('GET', '/second', 'second');
      final transport = createDioRestTransport();
      final before = HttpOverrides.current;
      addTearDown(() => HttpOverrides.global = before);

      final first = transport.send(
        _exchange(address: '${server.address}/first'),
      );
      await Future<void>.value();
      HttpOverrides.global = _OtherOverrides();
      final second = transport.send(
        _exchange(method: 'GET', address: '${server.address}/second'),
      );

      expect((await first).status, 200);
      expect((await second).status, 200);
      expect(
        [for (final request in server.requests) request.uri.path],
        unorderedEquals(['/first', '/second']),
      );
    });

    test('a body in gzip comes decoded, without the headers of its coding',
        () async {
      final coded = gzip.encode(utf8.encode('decoded'));
      server.answer('GET', '/coded', (request) async {
        request.response
          ..headers.set('content-encoding', 'gzip')
          ..headers.contentLength = coded.length
          ..add(coded);
        await request.response.close();
      });

      final reply = await createDioRestTransport().send(
        _exchange(method: 'GET', address: '${server.address}/coded'),
      );

      expect(utf8.decode(reply.bytes), 'decoded');
      expect(reply.headers, isNot(contains('content-encoding')));
      expect(reply.headers, isNot(contains('content-length')));
    });

    for (final coding in const [
      'br',
      'deflate',
      'GZIP',
      'x-gzip',
      'identity'
    ]) {
      test(
          'a body in $coding, which the stack does not decode, keeps its '
          'bytes and the headers that tell of them', () async {
        const bytes = [1, 2, 3, 4];
        server.answer('GET', '/coded', (request) async {
          request.response
            ..headers.set('content-encoding', coding)
            ..headers.contentLength = bytes.length
            ..add(bytes);
          await request.response.close();
        });
        final client = AppRestClient(
          transport: createRestTransport(),
          baseAddress: server.address,
        );

        final response = await client.get('coded');

        expect(response.bytes, bytes);
        expect(response.headers['content-encoding'], coding);
        expect(response.headers['content-length'], '${bytes.length}');
      });
    }

    for (final delay in const [0, 1, 2, 5, 10]) {
      test(
          'an exchange that stops $delay ms after it began leaves no '
          'connection behind', () async {
        final closed = Completer<void>();
        final socket = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        final accepted = <Socket>[];
        var connections = 0;
        socket.listen((connection) {
          connections++;
          accepted.add(connection);
          connection.done.ignore();
          void close([Object? _]) {
            if (!closed.isCompleted) closed.complete();
          }

          connection.listen((_) {}, onDone: close, onError: close);
        });
        addTearDown(() async {
          await socket.close();
          for (final connection in accepted) {
            connection.destroy();
          }
        });
        final stop = Completer<void>();

        final ended = createDioRestTransport()
            .send(
              _exchange(
                address: 'http://127.0.0.1:${socket.port}/held',
                stop: stop.future,
              ),
            )
            .then<void>((_) {}, onError: (Object _) {});
        await Future<void>.delayed(Duration(milliseconds: delay));
        stop.complete();
        await ended.timeout(const Duration(seconds: 3));
        // A connection that was being made reaches the server a moment later.
        await Future<void>.delayed(const Duration(milliseconds: 100));

        if (connections > 0) {
          await closed.future.timeout(const Duration(seconds: 3));
        }
      });
    }

    test('an exchange that stops during a TLS handshake closes its connection',
        () async {
      final closed = Completer<void>();
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      Socket? accepted;
      socket.listen((connection) {
        accepted = connection;
        connection.done.ignore();
        void close([Object? _]) {
          if (!closed.isCompleted) closed.complete();
        }

        connection.listen((_) {}, onDone: close, onError: close);
      });
      addTearDown(() async {
        await socket.close();
        accepted?.destroy();
      });
      final stop = Completer<void>();

      final ended = createDioRestTransport()
          .send(
            _exchange(
              address: 'https://127.0.0.1:${socket.port}/held',
              stop: stop.future,
            ),
          )
          .then<void>((_) {}, onError: (Object _) {});
      await Future<void>.delayed(const Duration(milliseconds: 100));
      stop.complete();
      await ended.timeout(const Duration(seconds: 3));

      await closed.future.timeout(const Duration(seconds: 3));
    },
        skip: 'Bug: HttpClient of dart:io gives no way to end a TLS handshake '
            'that is on its way, not even close(force: true), so the socket '
            'stays until the server closes it or the handshake ends.');
  });
}
