// What the tests of the REST role share, in the apps with the role, whichever
// module provides it: a client of its own over the transport of the provider,
// tokens that a test scripts, what a call ended with, and a server that does
// what no RestTestServer does, such as to hold a request or to break a
// connection.
//
// It knows only the role. A test makes a client of its own, so it needs no
// start-up of the app and meets no session, and its server takes a free port,
// since the files of tests run at once.
//
// Each call that a provider may break goes through outcomeOf and an expect with
// a reason, since that reason is what a provider with a known bug fails the
// test with (brokenProviders of the fixture registry).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/rest/app_rest.dart';

import '../core/rest/rest_test_server.dart';

export '../core/rest/rest_test_server.dart';

/// The path below which [clientOf] puts the requests of a test.
const String apiPath = '/api/v1';

/// A client over the transport of the provider of the role, for [server], with
/// the [tokens] of a test.
AppRestClient clientOf(
  RestTestServer server, {
  RestTokens? tokens,
  Duration timeout = const Duration(seconds: 20),
}) =>
    AppRestClient(
      transport: createRestTransport(),
      baseAddress: '${server.address}$apiPath',
      tokens: tokens,
      timeout: timeout,
    );

/// What [call] ended with: a [RestResponse], or what it threw.
Future<Object> outcomeOf(Future<RestResponse> call) async {
  try {
    return await call;
  } on Object catch (error) {
    return error;
  }
}

/// Matches a response with [status].
Matcher answers(int status) =>
    isA<RestResponse>().having((reply) => reply.status, 'status', status);

/// Matches a failure with [reason].
Matcher failsWith(RestFailureReason reason) =>
    isA<RestFailure>().having((failure) => failure.reason, 'reason', reason);

/// Tokens that a test scripts: [token] is the token of [owner], and a refresh
/// gives the next of [refreshed] and notes the token that it replaces. Each
/// call counts.
final class ScriptedTokens implements RestTokens {
  /// Creates the tokens of a user with [token].
  ScriptedTokens(this.token, {this.refreshed = const [], this.onRefresh});

  /// The token of the user.
  String? token;

  /// What the refreshes give, in order; `null` after the last of them.
  final List<String?> refreshed;

  /// What a refresh does first, such as to change the user.
  final void Function()? onRefresh;

  /// The tokens that a refresh was asked to replace.
  final List<String> rejected = [];

  @override
  String? owner = 'user-of-the-test';

  @override
  Future<String?> current() async => token;

  @override
  Future<String?> after(String rejected) async {
    this.rejected.add(rejected);
    onRefresh?.call();
    final next = this.rejected.length > refreshed.length
        ? null
        : refreshed[this.rejected.length - 1];
    if (next != null) token = next;
    return next;
  }
}

/// The address of a port of this machine where nothing listens.
Future<String> closedAddress() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final address = 'http://${socket.address.address}:${socket.port}';
  await socket.close();
  return address;
}

/// A server for what a [RestTestServer] does not do: it reads no more than the
/// head of a request, and answers as [answer] says, on the socket itself.
final class RawServer {
  RawServer._(this._socket, this._answer) {
    _socket.listen(_serve);
  }

  /// Starts a server on a free port of this machine. RestTestServer.start()
  /// must have taken away the stand-in of the binding of the tests.
  static Future<RawServer> start(
    void Function(Socket socket, String head) answer,
  ) async =>
      RawServer._(
        await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
        answer,
      );

  final ServerSocket _socket;
  final void Function(Socket socket, String head) _answer;
  final List<Socket> _sockets = [];

  /// The heads of the requests that the server got, in order.
  final List<String> heads = [];

  /// How many connections were closed by the client.
  int closedByClient = 0;

  /// The address of the server.
  String get address => 'http://${_socket.address.address}:${_socket.port}';

  void _serve(Socket socket) {
    _sockets.add(socket);
    // A write to a client that has left fails here, and that is no failure of a
    // test.
    socket.done.ignore();
    final head = StringBuffer();
    var answered = false;
    socket.listen(
      (bytes) {
        head.write(latin1.decode(bytes));
        if (!answered && head.toString().contains('\r\n\r\n')) {
          answered = true;
          heads.add(head.toString());
          _answer(socket, head.toString());
        }
      },
      onDone: () => closedByClient++,
      onError: (Object _) => closedByClient++,
    );
  }

  /// Sends [text] on [socket], and then [then] whether it got there or not,
  /// since a client may have left.
  static Future<void> send(
    Socket socket,
    String text,
    void Function() then,
  ) async {
    socket.write(text);
    try {
      await socket.flush();
    } on IOException {
      // The client left.
    }
    then();
  }

  /// Waits in real time, for [within] at most, until the client has closed
  /// [connections] connections: a connection that the client closed once it
  /// had to stop.
  Future<bool> sawClose({
    int connections = 1,
    Duration within = const Duration(seconds: 3),
  }) async {
    final watch = Stopwatch()..start();
    while (closedByClient < connections && watch.elapsed < within) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return closedByClient >= connections;
  }

  /// Stops the server.
  Future<void> close() async {
    await _socket.close();
    for (final socket in _sockets) {
      socket.destroy();
    }
  }
}
