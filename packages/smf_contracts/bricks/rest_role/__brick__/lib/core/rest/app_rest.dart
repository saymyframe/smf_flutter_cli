import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../env/app_env.dart';
import 'rest_transport.dart';

/// The REST client of the app. The code of the app makes its requests here,
/// and gets each answer or a [RestFailure].
final AppRestClient appRest = AppRestClient(
  transport: createRestTransport(),
  baseAddress: AppEnv.restBaseUrl,
  tokens: {{{rest_tokens}}},
);

/// Why a call failed.
enum RestFailureReason {
  /// A relative path, and no address to join it to:
  /// `REST_BASE_URL` in `.env` is empty, or is no address of a server.
  notConfigured,

  /// The request did not reach a server, or the connection broke.
  network,

  /// No complete answer within the timeout of the attempt, or no token of the
  /// user within [AppRestClient.tokenWait]. It is never repeated: the user
  /// has waited long enough.
  timeout,

  /// The caller cancelled the call with a [RestCancel].
  cancelled,

  /// A 401, after one refresh of the token where the client added one. It
  /// signs nobody out, since a server may refuse for other reasons: the app
  /// decides what it means.
  unauthorized,

  /// A 403.
  forbidden,

  /// A 404.
  notFound,

  /// A 409.
  conflict,

  /// Any other 4xx.
  rejected,

  /// A 429.
  tooManyRequests,

  /// A 5xx.
  server,

  /// A body that [RestResponse.decoded] does not take.
  invalidResponse,

  /// Anything else, such as a redirect of a `POST`.
  unknown,
}

/// The only thing that a call of [AppRestClient] throws.
final class RestFailure implements Exception {
  /// Creates the failure.
  const RestFailure(
    this.reason, {
    this.status,
    this.response,
    this.retryAfter,
    this.developerHint,
  });

  /// Why the call failed, which the app shows in a text of its own.
  final RestFailureReason reason;

  /// The status of the answer, if a server answered.
  final int? status;

  /// The answer of a server that refused, whose body may say why:
  /// `failure.response?.decoded(...)`.
  final RestResponse? response;

  /// The wait that the server named, which the client did not take: the
  /// method does not repeat, the wait is too long, or the repeats are over.
  final Duration? retryAfter;

  /// For the developer, in debug mode only. It never has a token.
  final String? developerHint;

  @override
  String toString() => [
        'RestFailure(${reason.name}',
        if (status != null) ', $status',
        if (developerHint != null) ': $developerHint',
        ')',
      ].join();
}

/// What a server answered with a status of success, or with 304.
final class RestResponse {
  /// Creates the response; a test of the code of the app may too.
  const RestResponse({
    required this.status,
    required this.headers,
    required this.bytes,
  });

  /// The status of the answer.
  final int status;

  /// The headers, each name in lower case.
  final Map<String, String> headers;

  /// The body.
  final List<int> bytes;

  /// The body as UTF-8.
  String get text => utf8.decode(bytes, allowMalformed: true);

  /// [parse] applied to the JSON of the body, such as
  /// `response.decoded(Note.fromJson)`.
  ///
  /// A body that is no JSON, a body of another type than [parse] takes, and
  /// any error of [parse] fail with [RestFailureReason.invalidResponse].
  T decoded<T, J>(T Function(J json) parse) {
    try {
      return parse(jsonDecode(text) as J);
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        RestFailure(
          RestFailureReason.invalidResponse,
          status: status,
          response: this,
          // The text of the error may quote the body.
          developerHint: 'The body does not fit: ${error.runtimeType}.',
        ),
        stackTrace,
      );
    }
  }

  @override
  String toString() => 'RestResponse($status)';
}

/// Ends a call, such as one of a screen that the user left: the call fails
/// with [RestFailureReason.cancelled] at once and its connection closes.
final class RestCancel {
  final List<void Function()> _listeners = [];
  bool _isCancelled = false;

  /// Whether [cancel] was called.
  bool get isCancelled => _isCancelled;

  /// Ends the calls that were given this object.
  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    for (final listener in [..._listeners]) {
      listener();
    }
  }
}

/// Who the requests of the app are made for. In an app without sign-in, the
/// client has none.
abstract interface class RestTokens {
  /// The id of the user right now, or `null` when nobody is signed in. A
  /// request of one user never repeats as another.
  String? get owner;

  /// The token of the user, or `null` for no header.
  ///
  /// It fails with a [RestFailure].
  Future<String?> current();

  /// A token to use in place of [rejected], which a server refused, or `null`
  /// when nobody is signed in. Calls at the same time share one refresh.
  ///
  /// It fails with a [RestFailure].
  Future<String?> after(String rejected);
}

/// The headers that go only to the origin they were given for.
const List<String> _originHeaders = [
  'authorization',
  'cookie',
  'proxy-authorization',
];

/// How many times a call repeats after a connection that failed, or after
/// one of [_repeatedStatuses].
const int _maxRepeats = 2;

/// The waits before the repeats, for a server that names none.
const List<Duration> _repeatWaits = [
  Duration(milliseconds: 500),
  Duration(seconds: 1),
];

/// How much a wait of [_repeatWaits] grows at most, so that the devices of
/// many users do not repeat at the same moment.
const int _maxJitterMilliseconds = 250;

/// The longest wait that a server can make a call take before it repeats.
const Duration _maxWait = Duration(seconds: 30);

/// The statuses after which `GET` and `HEAD` repeat.
const Set<int> _repeatedStatuses = {429, 502, 503, 504};

/// The statuses of a redirect that `GET` and `HEAD` follow.
const Set<int> _redirects = {301, 302, 303, 307, 308};

/// How many redirects a call follows at most.
const int _maxRedirects = 5;

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// The form of an HTTP date that a server sends today, such as
/// `Sun, 06 Nov 1994 08:49:37 GMT`.
final RegExp _httpDate = RegExp(
  r'^[A-Za-z]{3}, (\d{2}) ([A-Za-z]{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
);

/// A path that is an address of its own: only `http://` and `https://` make
/// one, so `//other.example/x` stays a path on the server of the app.
final RegExp _absolute = RegExp(r'^https?://', caseSensitive: false);

final Random _random = Random();

/// The REST client of the app, [appRest], over the transport of the provider
/// of the REST role.
///
/// What it guarantees is here, so it is the same with every provider:
/// - A path is relative to [baseAddress], with or without a leading slash, and
///   an address with `http://` or `https://` goes where it says.
/// - A call fails only with a [RestFailure].
/// - The token of the user goes only to the origin of [baseAddress], and a
///   redirect to another origin takes it away, with the cookies of the caller.
/// - A 401 of a request with that token gets a new token once and repeats
///   once, whatever the method, for the same user only.
/// - `GET` and `HEAD` repeat twice at most after a connection that failed and
///   after 429, 502, 503 and 504, keeping to `Retry-After`. Other methods
///   never repeat, since the server may have done what they asked.
/// - The timeout is per attempt, so a `GET` with its repeats may take longer,
///   and a [RestCancel] ends a call at once.
/// - A debug build prints one line for each attempt, with no token and no
///   query.
final class AppRestClient {
  /// Creates a client. The app has one, [appRest], and a test creates one over
  /// a transport of its own.
  AppRestClient({
    required this._transport,
    required this._baseAddress,
    this._tokens,
    this.timeout = const Duration(seconds: 30),
    this.tokenWait = const Duration(seconds: 10),
  });

  /// How long one attempt of a call takes at most, unless the call names
  /// another time.
  final Duration timeout;

  /// How long the client waits for the token of the user at most. A forced
  /// refresh on a device without a network may take a minute before it fails,
  /// and a request does not wait for that.
  final Duration tokenWait;

  RestTransport _transport;
  String? _baseAddress;
  RestTokens? _tokens;

  /// For a test: replaces what is given. The code of the app never calls it.
  void use({
    RestTransport? transport,
    String? baseAddress,
    RestTokens? tokens,
  }) {
    _transport = transport ?? _transport;
    _baseAddress = baseAddress ?? _baseAddress;
    _tokens = tokens ?? _tokens;
  }

  /// Sends a `GET`, which the client repeats as [AppRestClient] tells.
  Future<RestResponse> get(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
    Duration? timeout,
    RestCancel? cancel,
  }) =>
      _request(
        'GET',
        path,
        query: query,
        headers: headers,
        timeout: timeout,
        cancel: cancel,
      );

  /// Sends a `HEAD`, which the client repeats as [AppRestClient] tells.
  Future<RestResponse> head(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
    Duration? timeout,
    RestCancel? cancel,
  }) =>
      _request(
        'HEAD',
        path,
        query: query,
        headers: headers,
        timeout: timeout,
        cancel: cancel,
      );

  /// Sends a `POST` with [json] as its body, or with [bytes].
  Future<RestResponse> post(
    String path, {
    Object? json,
    List<int>? bytes,
    Map<String, String>? query,
    Map<String, String>? headers,
    Duration? timeout,
    RestCancel? cancel,
  }) =>
      _request(
        'POST',
        path,
        json: json,
        bytes: bytes,
        query: query,
        headers: headers,
        timeout: timeout,
        cancel: cancel,
      );

  /// Sends a `PUT` with [json] as its body, or with [bytes].
  Future<RestResponse> put(
    String path, {
    Object? json,
    List<int>? bytes,
    Map<String, String>? query,
    Map<String, String>? headers,
    Duration? timeout,
    RestCancel? cancel,
  }) =>
      _request(
        'PUT',
        path,
        json: json,
        bytes: bytes,
        query: query,
        headers: headers,
        timeout: timeout,
        cancel: cancel,
      );

  /// Sends a `PATCH` with [json] as its body, or with [bytes].
  Future<RestResponse> patch(
    String path, {
    Object? json,
    List<int>? bytes,
    Map<String, String>? query,
    Map<String, String>? headers,
    Duration? timeout,
    RestCancel? cancel,
  }) =>
      _request(
        'PATCH',
        path,
        json: json,
        bytes: bytes,
        query: query,
        headers: headers,
        timeout: timeout,
        cancel: cancel,
      );

  /// Sends a `DELETE`, with [json] as its body or with [bytes] if it has one.
  Future<RestResponse> delete(
    String path, {
    Object? json,
    List<int>? bytes,
    Map<String, String>? query,
    Map<String, String>? headers,
    Duration? timeout,
    RestCancel? cancel,
  }) =>
      _request(
        'DELETE',
        path,
        json: json,
        bytes: bytes,
        query: query,
        headers: headers,
        timeout: timeout,
        cancel: cancel,
      );

  /// Makes the call, and turns any error of another kind into a failure with
  /// the reason [RestFailureReason.unknown]. Its hint has the type of the
  /// error and not its text, which may quote a header.
  Future<RestResponse> _request(
    String method,
    String path, {
    Object? json,
    List<int>? bytes,
    Map<String, String>? query,
    Map<String, String>? headers,
    Duration? timeout,
    RestCancel? cancel,
  }) async {
    try {
      if (json != null && bytes != null) {
        throw const RestFailure(
          RestFailureReason.unknown,
          developerHint: 'A call takes json or bytes, not both.',
        );
      }
      final base = _baseOf(_baseAddress);
      return await _Call(
        client: this,
        method: method,
        base: base,
        target: _addressOf(path, query, base),
        headers: {
          for (final MapEntry(:key, :value) in (headers ?? const {}).entries)
            key.toLowerCase(): value,
          if (json != null && _hasNoContentType(headers))
            'content-type': 'application/json',
        },
        body: json != null ? utf8.encode(jsonEncode(json)) : bytes,
        timeout: timeout ?? this.timeout,
        cancel: cancel,
      ).run();
    } on RestFailure {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        RestFailure(
          RestFailureReason.unknown,
          developerHint: 'The call ended with a ${error.runtimeType}.',
        ),
        stackTrace,
      );
    }
  }

  bool _hasNoContentType(Map<String, String>? headers) =>
      headers == null ||
      !headers.keys.any((name) => name.toLowerCase() == 'content-type');

  /// The address of [path] with [query]; see [AppRestClient].
  Uri _addressOf(String path, Map<String, String>? query, Uri? base) {
    final Uri address;
    if (_absolute.hasMatch(path)) {
      address = Uri.parse(path);
    } else {
      if (base == null) {
        throw RestFailure(
          RestFailureReason.notConfigured,
          developerHint: _baseProblem(_baseAddress),
        );
      }
      final root = base.toString().replaceFirst(RegExp(r'/+$'), '');
      final relative = path.replaceFirst(RegExp('^/+'), '');
      address = Uri.parse(relative.isEmpty ? root : '$root/$relative');
    }
    final added = [
      for (final MapEntry(:key, :value) in (query ?? const {}).entries)
        '${Uri.encodeComponent(key)}=${Uri.encodeComponent(value)}',
    ];
    if (added.isEmpty) return address.removeFragment();
    return address.removeFragment().replace(
          query: [if (address.query.isNotEmpty) address.query, ...added]
              .join('&'),
        );
  }

  /// The address in [value] that paths are relative to, or `null` when it is
  /// none: it has no value, is no address of an `http` or `https` server, or
  /// has a query, a fragment or a user.
  Uri? _baseOf(String? value) {
    final uri = value == null ? null : Uri.tryParse(value);
    if (uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https')) ||
        uri.host.isEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri;
  }

  /// What the hint of a relative path says for [value], which [_baseOf] did
  /// not take. It does not quote the value, which may have a user.
  String _baseProblem(String? value) => value == null || value.isEmpty
      ? 'REST_BASE_URL in .env is empty, and the path is relative. Put the '
          'address of your REST API there, such as '
          'https://api.example.com/v1, and start flutter run again. The '
          'section "Values in .env" of the README tells how.'
      : 'REST_BASE_URL in .env is no address of a server: it needs http:// or '
          'https://, a host, and no query, fragment or user.';
}

/// One call of [AppRestClient], over its attempts.
final class _Call {
  _Call({
    required this.client,
    required this.method,
    required this.base,
    required this.target,
    required this.headers,
    required this.body,
    required this.timeout,
    required this.cancel,
  }) : _callerHasAuthorization = headers.containsKey('authorization');

  final AppRestClient client;
  final String method;

  /// The address that paths are relative to, whose origin gets the token.
  final Uri? base;

  /// The address of the next attempt, which a redirect changes.
  Uri target;

  /// The headers that the caller gave, which a redirect to another origin
  /// takes away from.
  final Map<String, String> headers;

  final List<int>? body;
  final Duration timeout;
  final RestCancel? cancel;

  /// A header `authorization` of the caller stays, and the token stays out.
  final bool _callerHasAuthorization;

  /// The user whom the call is made for, once a read of the token told.
  String? _owner;

  /// The token that the last attempt sent, if any.
  String? _sent;

  /// The token of a refresh, for the attempt after it.
  String? _refreshed;

  /// Whether the call has made its one refresh.
  bool _didRefresh = false;

  bool get _isSafe => method == 'GET' || method == 'HEAD';

  /// The attempts of the call; see [AppRestClient].
  Future<RestResponse> run() async {
    var repeats = 0;
    var hops = 0;
    for (;;) {
      final RestReply reply;
      try {
        reply = await _attempt();
      } on RestConnectionFailed catch (failure) {
        if (!_isSafe || repeats == _maxRepeats) {
          throw RestFailure(
            RestFailureReason.network,
            developerHint: failure.hint,
          );
        }
        await _wait(_repeatWait(repeats++));
        continue;
      }

      final status = reply.status;
      final response = RestResponse(
        status: status,
        headers: reply.headers,
        bytes: reply.bytes,
      );
      if (status == 401 && _sent != null && !_didRefresh) {
        await _refresh(_sent!, response);
        continue;
      }
      if (_redirects.contains(status)) {
        _follow(response, hops++);
        continue;
      }
      if (status == 304 || (status >= 200 && status < 300)) return response;

      final retryAfter = _retryAfterOf(reply.headers);
      if (_isSafe &&
          _repeatedStatuses.contains(status) &&
          repeats < _maxRepeats &&
          (retryAfter == null || retryAfter <= _maxWait)) {
        await _wait(retryAfter ?? _repeatWait(repeats));
        repeats++;
        continue;
      }
      throw RestFailure(
        _reasonOf(status),
        status: status,
        response: response,
        retryAfter: retryAfter,
        developerHint: _reasonOf(status) == RestFailureReason.unknown
            ? 'The server answered with the status $status.'
            : null,
      );
    }
  }

  /// One attempt: the token of the user where it may go, and one exchange,
  /// within the timeout. A debug build prints one line for it.
  Future<RestReply> _attempt() async {
    final limit = _Limit(timeout, cancel);
    final watch = Stopwatch()..start();
    var outcome = RestFailureReason.unknown.name;
    try {
      final sent = await _tokenFor(limit);
      _sent = sent;
      final exchange = RestExchange(
        method: method,
        uri: target,
        headers: {
          ...headers,
          if (sent != null) 'authorization': 'Bearer $sent',
        },
        body: body,
        stop: limit.stop,
      );
      final reply = await limit.race(() => client._transport.send(exchange));
      outcome = '${reply.status}';
      return reply;
    } on RestConnectionFailed {
      outcome = RestFailureReason.network.name;
      rethrow;
    } on RestFailure catch (failure) {
      outcome = failure.reason.name;
      rethrow;
    } finally {
      limit.close();
      if (kDebugMode) {
        // The origin and the path alone: the query may have a key.
        debugPrint(
          'REST $method ${target.origin}${target.path} $outcome '
          '(${watch.elapsedMilliseconds} ms)',
        );
      }
    }
  }

  /// The token for the next attempt, or `null` for none: an attempt to
  /// another origin gets none, and neither does a call with a header
  /// `authorization` of its own.
  Future<String?> _tokenFor(_Limit limit) async {
    final tokens = client._tokens;
    final origin = base?.origin;
    if (tokens == null ||
        _callerHasAuthorization ||
        origin == null ||
        target.origin != origin) {
      return null;
    }
    if (_refreshed case final refreshed?) {
      _refreshed = null;
      return refreshed;
    }
    Future<String?> read() => limit.race(
          tokens.current,
          within: client.tokenWait,
        );
    var owner = tokens.owner;
    var token = await read();
    // The user changed during the read, as when the app starts, so the token
    // may be of the user before.
    if (tokens.owner != owner) {
      owner = tokens.owner;
      token = await read();
    }
    final before = _owner;
    if (before != null && owner != before) throw _otherUser();
    _owner = owner;
    return token;
  }

  /// Gets the token that replaces [rejected], once in a call, for the same
  /// user. The server that refused it did nothing yet, so every method
  /// repeats after it.
  Future<void> _refresh(String rejected, RestResponse response) async {
    _didRefresh = true;
    final tokens = client._tokens!;
    final limit = _Limit(timeout, cancel);
    try {
      final token = await limit.race(
        () => tokens.after(rejected),
        within: client.tokenWait,
      );
      if (token == null || tokens.owner != _owner) {
        throw _otherUser(response: response);
      }
      _refreshed = token;
    } finally {
      limit.close();
    }
  }

  RestFailure _otherUser({RestResponse? response}) => RestFailure(
        RestFailureReason.unauthorized,
        status: response?.status,
        response: response,
        developerHint: 'The user of the session changed during the call, so '
            'it did not repeat for the new user.',
      );

  /// Goes on to the address that the redirect in [response] names: for `GET`
  /// and `HEAD` only, since the server may have done what another method
  /// asked. A hop to another origin takes the headers of the caller that are
  /// only for the origin they were given for.
  void _follow(RestResponse response, int hops) {
    RestFailure refused(String hint) => RestFailure(
          RestFailureReason.unknown,
          status: response.status,
          response: response,
          developerHint: hint,
        );
    if (!_isSafe) {
      throw refused(
        'The server answered a $method with a redirect, which only GET and '
        'HEAD follow. Call the address that it names yourself, if you mean to.',
      );
    }
    if (hops == _maxRedirects) {
      throw refused('More than $_maxRedirects redirects.');
    }
    final location = response.headers['location'];
    if (location == null) throw refused('A redirect without a location.');
    final next = target.resolve(location).removeFragment();
    if (!(next.isScheme('http') || next.isScheme('https'))) {
      throw refused('A redirect to an address that is no http or https one.');
    }
    if (next.origin != target.origin) _originHeaders.forEach(headers.remove);
    target = next;
  }

  /// Waits for [duration], which a cancel ends at once.
  Future<void> _wait(Duration duration) async {
    final limit = _Limit(null, cancel);
    final waited = Completer<void>();
    final timer = Timer(duration, waited.complete);
    try {
      await limit.race(() => waited.future);
    } finally {
      timer.cancel();
      limit.close();
    }
  }

  static Duration _repeatWait(int repeats) =>
      _repeatWaits[repeats] +
      Duration(milliseconds: _random.nextInt(_maxJitterMilliseconds));

  /// The wait that [headers] name, in seconds or as an HTTP date, or `null`
  /// without one that the client can read.
  static Duration? _retryAfterOf(Map<String, String> headers) {
    final value = headers['retry-after']?.trim();
    if (value == null) return null;
    final seconds = int.tryParse(value);
    if (seconds != null) return seconds < 0 ? null : Duration(seconds: seconds);
    final match = _httpDate.firstMatch(value);
    final month = match == null ? -1 : _months.indexOf(match[2]!);
    if (match == null || month < 0) return null;
    final wait = DateTime.utc(
      int.parse(match[3]!),
      month + 1,
      int.parse(match[1]!),
      int.parse(match[4]!),
      int.parse(match[5]!),
      int.parse(match[6]!),
    ).difference(DateTime.now());
    return wait.isNegative ? Duration.zero : wait;
  }

  static RestFailureReason _reasonOf(int status) => switch (status) {
        401 => RestFailureReason.unauthorized,
        403 => RestFailureReason.forbidden,
        404 => RestFailureReason.notFound,
        409 => RestFailureReason.conflict,
        429 => RestFailureReason.tooManyRequests,
        >= 400 && < 500 => RestFailureReason.rejected,
        >= 500 && < 600 => RestFailureReason.server,
        _ => RestFailureReason.unknown,
      };
}

/// What ends an attempt or a wait: its timeout, if it has one, and the cancel
/// of the caller. The call ends then, also when a provider does not stop.
final class _Limit {
  _Limit(Duration? timeout, this._cancel) {
    final cancel = _cancel;
    if (cancel != null) {
      if (cancel.isCancelled) {
        _cancelled();
      } else {
        cancel._listeners.add(_cancelled);
      }
    }
    if (timeout != null) {
      _timer = Timer(
        timeout,
        () => _end(
          RestFailure(
            RestFailureReason.timeout,
            developerHint:
                'No complete answer within ${timeout.inMilliseconds} ms.',
          ),
        ),
      );
    }
  }

  final RestCancel? _cancel;
  final Completer<void> _stop = Completer();
  Timer? _timer;
  RestFailure? _ended;
  void Function(RestFailure failure)? _racing;

  /// Completes when the attempt has to stop.
  Future<void> get stop => _stop.future;

  void _cancelled() => _end(const RestFailure(RestFailureReason.cancelled));

  void _end(RestFailure failure) {
    if (_ended != null) return;
    _ended = failure;
    _stop.complete();
    _racing?.call(failure);
  }

  /// What [work] gives, unless the limit ends first or [within] is over.
  /// Whatever [work] does after that goes nowhere.
  Future<T> race<T>(Future<T> Function() work, {Duration? within}) async {
    if (_ended case final failure?) throw failure;
    final result = Completer<T>();
    void end(RestFailure failure) {
      if (!result.isCompleted) result.completeError(failure);
    }

    _racing = end;
    final wait = within == null
        ? null
        : Timer(
            within,
            () => end(
              RestFailure(
                RestFailureReason.timeout,
                developerHint: 'The token of the user did not come within '
                    '${within.inMilliseconds} ms.',
              ),
            ),
          );
    unawaited(
      Future<T>.sync(work).then(
        (value) {
          if (!result.isCompleted) result.complete(value);
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!result.isCompleted) result.completeError(error, stackTrace);
        },
      ),
    );
    try {
      return await result.future;
    } finally {
      wait?.cancel();
      _racing = null;
    }
  }

  /// Ends the timer of the limit, once what it limits is over.
  void close() {
    _timer?.cancel();
    _cancel?._listeners.remove(_cancelled);
  }
}

/// The transport of the provider of the REST role. Only the client of the app
/// and a test of the provider call this.
RestTransport createRestTransport() => _restTransport;

{{{smf_rest__implementations}}}
