/// One exchange with a server, as the provider of the REST role sends it.
final class RestExchange {
  /// Creates the exchange; only the client of the app does.
  const RestExchange({
    required this.method,
    required this.uri,
    required this.headers,
    required this.stop,
    this.body,
  });

  /// The method, in upper case.
  final String method;

  /// The whole address, with its query.
  final Uri uri;

  /// The headers, each name in lower case, with `content-length` for a body.
  /// They may hold a token.
  final Map<String, String> headers;

  /// The body, or `null` for none.
  final List<int>? body;

  /// Completes when the exchange has to stop: a timeout, or a cancel.
  final Future<void> stop;

  /// Names no header and no query, so that a token never reaches a log.
  @override
  String toString() => 'RestExchange($method ${uri.origin}${uri.path})';
}

/// What a server answered.
final class RestReply {
  /// Creates the reply; a provider does, from what the server answered.
  const RestReply({
    required this.status,
    required this.headers,
    required this.bytes,
  });

  /// The status of the answer.
  final int status;

  /// The headers, each name in lower case, and several values of one header
  /// joined by `, `.
  final Map<String, String> headers;

  /// The body, decoded of its `content-encoding`.
  final List<int> bytes;
}

/// The request did not reach a server, or the connection broke. No other
/// exception of a provider tells that.
final class RestConnectionFailed implements Exception {
  /// Creates the failure with [hint], for the developer of the app.
  const RestConnectionFailed(this.hint);

  /// What went wrong. It has no header, no query and no body.
  final String hint;

  @override
  String toString() => 'RestConnectionFailed: $hint';
}

/// One exchange on the wire, which is all that a provider of the REST role
/// does. `appRest` does the rest with what the provider reports, so every
/// provider keeps the same guarantees.
///
/// Every provider keeps to this. Only a running app shows whether it does:
/// - [send] makes one attempt. A provider repeats nothing.
/// - It follows no redirect: a 3xx is a reply. `appRest` follows them, since
///   it knows which header may go where.
/// - Any status is a reply, and it keeps the headers of the reply, with their
///   names in lower case. [RestReply.bytes] are decoded of `content-encoding`,
///   so a stack that asks for gzip decodes what it gets.
/// - A failure to connect, a TLS handshake or a certificate that fails, and a
///   connection that breaks are [RestConnectionFailed]. On `dart:io` those are
///   `SocketException`, `HttpException` and `TlsException`. Any other error is
///   a bug of the provider, which reaches the caller as the reason `unknown`.
/// - When [RestExchange.stop] completes, it closes the connection at once. It
///   needs no timeout of its own: `appRest` stops every exchange. On `dart:io`,
///   only a TLS handshake that is on its way stays until the server ends it,
///   since `HttpClient` has no way to end one.
/// - On `dart:io`, one that keeps an `HttpClient` makes a new one when
///   `HttpOverrides` change, as they do when a test starts or closes a
///   `RestTestServer`.
/// - It sends [RestExchange.uri] as it is, with those headers and that body.
///   Its stack may add the headers of the transport itself, such as `host`,
///   `user-agent` and `accept-encoding`. It adds no credential or cookie, and
///   keeps none between two calls.
/// - It writes no header, no query and no body to a log or a hint.
/// - Its function takes no arguments, never throws and does not wait, and the
///   implementation works from the first call.
abstract interface class RestTransport {
  /// Sends [exchange] and completes with what the server answered.
  Future<RestReply> send(RestExchange exchange);
}
