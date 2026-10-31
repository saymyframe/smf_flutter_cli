import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'rest_transport.dart';

/// Creates the [Dio] of the app. An interceptor goes here, such as one of a
/// tracing service. One that logs leaves out the header `authorization` and the
/// query of the address, and none repeats a request or follows a redirect:
/// `appRest` does both.
Dio createDio() => Dio();

/// Creates the transport of the app. It creates its [Dio] at the first request.
RestTransport createDioRestTransport() => DioRestTransport(createDio);

/// One exchange of `appRest` on a [Dio], which keeps its connections open
/// between two exchanges, so that a request needs no new TLS handshake.
final class DioRestTransport implements RestTransport {
  /// Creates the transport over what [createDio] creates.
  DioRestTransport(this._createDio);

  final Dio Function() _createDio;
  Dio? _dio;
  HttpOverrides? _overrides;

  /// The [Dio] for the [HttpOverrides] of now. A [Dio] keeps the `HttpClient`
  /// that it created under the overrides of that time, so a change of them, such
  /// as what `RestTestServer` does in a test, takes a new one. In an app that
  /// sets none, this is one [Dio] for as long as the app runs.
  Dio get _current {
    final overrides = HttpOverrides.current;
    final dio = _dio;
    if (dio != null && identical(overrides, _overrides)) return dio;
    // An exchange that is on its way ends as it would have.
    dio?.close();
    _overrides = overrides;
    return _dio = _createDio();
  }

  @override
  Future<RestReply> send(RestExchange exchange) async {
    final cancel = CancelToken();
    unawaited(exchange.stop.then((_) => cancel.cancel()));
    final body = exchange.body;
    try {
      final response = await _current.requestUri<List<int>>(
        exchange.uri,
        // Dio writes any other list as the text of its JSON.
        data: body == null ? null : Uint8List.fromList(body),
        cancelToken: cancel,
        options: Options(
          method: exchange.method,
          headers: exchange.headers,
          followRedirects: false,
          validateStatus: (_) => true,
          responseType: ResponseType.bytes,
        ),
      );
      return RestReply(
        status: response.statusCode!,
        headers: {
          for (final MapEntry(:key, :value) in response.headers.map.entries)
            key.toLowerCase(): value.join(', '),
        },
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
