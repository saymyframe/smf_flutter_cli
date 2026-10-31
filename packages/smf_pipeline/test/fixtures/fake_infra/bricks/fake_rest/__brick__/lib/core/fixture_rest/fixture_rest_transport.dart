import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../rest/rest_transport.dart';

/// Creates the transport of the fixture.
RestTransport createFixtureRestTransport() => const FixtureRestTransport();

/// One exchange on `HttpClient` of `dart:io`, with nothing but what the
/// contract of [RestTransport] asks.
final class FixtureRestTransport implements RestTransport {
  /// Creates the transport.
  const FixtureRestTransport();

  @override
  Future<RestReply> send(RestExchange exchange) async {
    // A client for each exchange, so nothing stays between two calls.
    final client = HttpClient();
    HttpClientRequest? opened;
    unawaited(
      exchange.stop.then((_) {
        opened?.abort();
        // This also closes a connection that is being made, or that is in the
        // middle of the body of a reply, which a request can no longer abort.
        client.close(force: true);
      }),
    );
    try {
      final request = opened = await client.openUrl(
        exchange.method,
        exchange.uri,
      );
      request.followRedirects = false;
      exchange.headers.forEach(request.headers.set);
      if (exchange.body case final body?) {
        request.add(Uint8List.fromList(body));
      }
      final response = await request.close();
      final body = await response.fold(
        BytesBuilder(copy: false),
        (all, part) => all..add(part),
      );
      final headers = <String, String>{};
      response.headers.forEach(
        (name, values) => headers[name] = values.join(', '),
      );
      return RestReply(
        status: response.statusCode,
        headers: headers,
        bytes: body.takeBytes(),
      );
    } on IOException catch (error) {
      // SocketException, HttpException and TlsException. Their text may quote
      // the address with its query, so the hint has the type alone.
      throw RestConnectionFailed(
        'The connection failed with a ${error.runtimeType}.',
      );
    } finally {
      client.close();
    }
  }
}
