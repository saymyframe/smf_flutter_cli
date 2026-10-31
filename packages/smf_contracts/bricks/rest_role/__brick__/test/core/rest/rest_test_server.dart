import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A request that a [RestTestServer] got.
final class RestTestRequest {
  /// Creates the note of a request.
  const RestTestRequest({
    required this.method,
    required this.uri,
    required this.headers,
    required this.bytes,
  });

  /// The method.
  final String method;

  /// The path and the query.
  final Uri uri;

  /// The headers, each name in lower case.
  final Map<String, String> headers;

  /// The body.
  final List<int> bytes;

  /// The body as UTF-8.
  String get body => utf8.decode(bytes);
}

/// A local server for the tests of the app, for code that makes requests
/// through `appRest`.
///
/// `flutter test` has two traps for a request, and this server is the answer
/// to the first:
/// - The binding of the tests gives every `HttpClient` a stand-in that answers
///   400 to everything, which would reach the code as the reason `rejected`.
///   [start] takes the stand-in away, and [close] puts it back.
/// - Inside `testWidgets`, the time is fake, and a real socket never completes
///   there. Make the request in `tester.runAsync`. A plain `test()` runs in
///   real time and needs nothing.
///
/// Files of tests run at once, so a server takes a free port: give the client
/// [address].
final class RestTestServer {
  RestTestServer._(this._server, this._overrides) {
    _server.listen(_serve);
  }

  /// Starts a server on a free port of this machine.
  static Future<RestTestServer> start() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final overrides = HttpOverrides.current;
    HttpOverrides.global = null;
    return RestTestServer._(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
      overrides,
    );
  }

  final HttpServer _server;
  final HttpOverrides? _overrides;
  final Map<String, Future<void> Function(HttpRequest request)> _answers = {};

  /// The requests that the server got, in order.
  final List<RestTestRequest> requests = [];

  /// The address of the server.
  String get address => 'http://${_server.address.address}:${_server.port}';

  /// Answers a request of [method] for [path] with [handler], which closes the
  /// response. Any other request gets a 404.
  void answer(
    String method,
    String path,
    Future<void> Function(HttpRequest request) handler,
  ) =>
      _answers['$method $path'] = handler;

  /// Answers a request of [method] for [path] with [value] as JSON.
  void answerJson(
    String method,
    String path,
    Object? value, {
    int status = 200,
  }) =>
      answer(method, path, (request) async {
        request.response
          ..statusCode = status
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(value));
        await request.response.close();
      });

  /// Stops the server and puts back what [start] took away.
  Future<void> close() async {
    await _server.close(force: true);
    HttpOverrides.global = _overrides;
  }

  Future<void> _serve(HttpRequest request) async {
    final bytes = await request.fold<List<int>>(
      [],
      (all, part) => all..addAll(part),
    );
    final headers = <String, String>{};
    request.headers.forEach(
      (name, values) => headers[name] = values.join(', '),
    );
    requests.add(
      RestTestRequest(
        method: request.method,
        uri: request.uri,
        headers: headers,
        bytes: bytes,
      ),
    );
    final answer = _answers['${request.method} ${request.uri.path}'];
    if (answer != null) return answer(request);
    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  }
}
