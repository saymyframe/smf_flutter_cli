import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'rest_transport.dart';

/// Creates the [Dio] of the app. An interceptor goes here, such as one of a
/// tracing service. One that logs leaves out the header `authorization` and the
/// query of the address, and none repeats a request or follows a redirect:
/// `appRest` does both. What this function adds to a request goes to every
/// address, also after a redirect and to a full address such as a presigned
/// upload. A credential goes through the token of the session or `headers:` of
/// the call.
Dio createDio() => Dio();

/// Creates the transport of the app. It creates its [Dio] at the first request.
RestTransport createDioRestTransport() => DioRestTransport(createDio);

/// A [Dio] of the transport, and the exchanges on it.
final class _DioInUse {
  _DioInUse(this.dio, this.overrides);

  final Dio dio;

  /// The overrides that its `HttpClient` is created under.
  final HttpOverrides? overrides;

  int _exchanges = 0;
  bool _isRetired = false;

  void begin() => _exchanges++;

  void end() {
    _exchanges--;
    _closeIfDone();
  }

  /// No exchange starts on it from now on.
  void retire() {
    _isRetired = true;
    _closeIfDone();
  }

  // A closed adapter refuses an exchange that has not reached it yet, which an
  // exchange does only after a turn of the event loop.
  void _closeIfDone() {
    if (_isRetired && _exchanges == 0) dio.close();
  }
}

/// One exchange of `appRest` on a [Dio], which keeps a connection open while
/// requests follow within seconds, so that those requests need no new TLS
/// handshake.
final class DioRestTransport implements RestTransport {
  /// Creates the transport over what [createDio] creates.
  DioRestTransport(this._createDio);

  final Dio Function() _createDio;
  _DioInUse? _inUse;

  /// The [Dio] for the [HttpOverrides] of now. A [Dio] keeps the `HttpClient`
  /// that it created under the overrides of that time, so a change of them, such
  /// as what `RestTestServer` does in a test, takes a new one. In an app that
  /// sets none, this is one [Dio].
  _DioInUse _current() {
    final overrides = HttpOverrides.current;
    final inUse = _inUse;
    if (inUse != null && identical(overrides, inUse.overrides)) return inUse;
    inUse?.retire();
    return _inUse = _DioInUse(_createDio(), overrides);
  }

  @override
  Future<RestReply> send(RestExchange exchange) async {
    final cancel = CancelToken();
    unawaited(exchange.stop.then((_) => cancel.cancel()));
    final inUse = _current()..begin();
    try {
      final response = await inUse.dio.requestUri<List<int>>(
        exchange.uri,
        data: switch (exchange.body) {
          final Uint8List bytes => bytes,
          // Dio writes any other list as the text of its JSON.
          final List<int> list => Uint8List.fromList(list),
          null => null,
        },
        cancelToken: cancel,
        options: Options(
          method: exchange.method,
          headers: exchange.headers,
          followRedirects: false,
          validateStatus: (_) => true,
          responseType: ResponseType.bytes,
        ),
      );
      final headers = {
        for (final MapEntry(:key, :value) in response.headers.map.entries)
          key.toLowerCase(): value.join(', '),
      };
      // HttpClient of dart:io decodes this coding alone, and leaves its headers,
      // which no longer tell of the bytes. Any other coding stays as it came.
      if (headers['content-encoding'] == 'gzip') {
        headers
          ..remove('content-encoding')
          ..remove('content-length');
      }
      return RestReply(
        status: response.statusCode!,
        headers: headers,
        bytes: response.data ?? const [],
      );
    } on DioException catch (error, stackTrace) {
      final cause = error.error;
      if (_isOfTheConnection(error)) {
        // The text of an error may quote the address with its query, so the
        // hint has the type alone.
        throw RestConnectionFailed(
          'The connection failed with a ${cause?.runtimeType ?? error.type.name}.',
        );
      }
      // Such as what an interceptor threw. It reaches the caller by its type.
      Error.throwWithStackTrace(cause ?? error, stackTrace);
    } finally {
      inUse.end();
    }
  }

  /// Whether [error] tells of a connection that failed or broke: on `dart:io`,
  /// a failed TLS handshake and a connection that breaks in a body come as
  /// [DioExceptionType.unknown], with what `dart:io` threw.
  static bool _isOfTheConnection(DioException error) => switch (error.type) {
        DioExceptionType.connectionError ||
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.badCertificate =>
          true,
        DioExceptionType.unknown => error.error is IOException,
        // Not the types by name: a later release of dio may add one, which must
        // not stop an app from compiling.
        _ => false,
      };
}
