// The probe of the REST role, whichever module provides it, which the start
// check runs on a device once the first screen of the app settled, the only
// place where the stack of the provider is the one of the device, also in a
// release build. The test of the role runs it too (probe_test.dart).
//
// It uses no test framework, and its requests reach no machine off the device:
// it makes them to servers of its own on the loopback address of the device,
// with a client of its own, and one to an address that no machine has, which
// must end as a request that fails. So a release build shows that it may use
// the network, a build for a device that its stack works there, and a release
// of Flutter that starts to refuse http:// shows in the nightly run. Whether
// the app has an address does not matter: an app of CI has an empty .env, and
// then the client of the app must say so.
//
// A request has 10 seconds and a connection 3 seconds to close, since a debug
// build on an emulator or a simulator of CI can be slow. Only a provider with a
// problem takes that long, at most about 34 seconds in all, and in a healthy app
// the probe takes about a second of the 60 seconds of all the probes.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:{{app_name}}/core/env/app_env.dart';
import 'package:{{app_name}}/core/rest/app_rest.dart';
import 'package:{{app_name}}/core/rest/rest_transport.dart';

/// How long a request of the probe to a server on the device takes at most.
const Duration _requestTime = Duration(seconds: 10);

/// The probe of the start check: what is wrong with the requests of the app.
/// It waits for no screen, so it leaves [settle] out.
Future<List<String>> probeRest(Future<void> Function() settle) async => [
      ...await problemsOfStack(createRestTransport()),
      ...await problemsOfAddress(appRest, AppEnv.restBaseUrl),
    ];

/// What is wrong with [transport] on this device: a GET and a POST reach a
/// server on the device and come back, an exchange that has to stop closes its
/// connection, a port where nothing listens is the reason network, and an
/// `http://` address that no machine has fails as a connection fails.
Future<List<String>> problemsOfStack(RestTransport transport) async {
  try {
    return [
      ...await _problemsOfExchanges(transport),
      ...await _problemsOfStop(transport),
      ...await _problemsOfClosedPort(transport),
      ...await _problemsOfCleartext(transport),
    ];
  } on SocketException catch (error) {
    // A provider reports its own such errors as a failed connection, so this
    // is a server of the probe, as in a release build without the permission.
    return ['The app cannot open a port of the device: ${error.message}.'];
  }
}

/// What is wrong with [client] for [address], the value of `.env`: while it has
/// none, a relative path fails with `notConfigured`, whose hint names the key.
/// With a value, nothing: such a request would go to the server of the app.
Future<List<String>> problemsOfAddress(
  AppRestClient client,
  String? address,
) async {
  if (address != null) return const [];
  try {
    await client.get('probe');
    return const ['A relative path went out with no address in .env.'];
  } on RestFailure catch (failure) {
    final isTold = failure.reason == RestFailureReason.notConfigured &&
        (failure.developerHint ?? '').contains('{{base_key}}');
    return [
      if (!isTold)
        'With no address in .env, a relative path failed with '
            '${failure.reason.name}, and not with a hint that names the key.',
    ];
  }
}

Future<List<String>> _problemsOfExchanges(RestTransport transport) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final body = await utf8.decodeStream(request);
    request.response
      ..headers.contentType = ContentType.json
      ..write(request.method == 'POST' ? body : '{"probe":true}');
    await request.response.close();
  });
  final client = AppRestClient(
    transport: transport,
    baseAddress: 'http://127.0.0.1:${server.port}/probe',
    timeout: _requestTime,
  );
  try {
    final got = await client.get('get', query: {'a': 'b'});
    final posted = await client.post('post', json: {'probe': 'sent'});
    return [
      if (got.decoded((Map<String, dynamic> json) => json['probe']) != true)
        'A GET did not come back with the body of the server.',
      if (posted.decoded((Map<String, dynamic> json) => json['probe']) !=
          'sent')
        'A POST did not reach the server with its body.',
    ];
  } on RestFailure catch (failure) {
    return ['A request to a server on the device failed with $failure.'];
  } finally {
    await server.close(force: true);
  }
}

Future<List<String>> _problemsOfStop(RestTransport transport) async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final closed = Completer<void>();
  void close([Object? _]) {
    if (!closed.isCompleted) closed.complete();
  }

  final sockets = <Socket>[];
  server.listen((socket) {
    sockets.add(socket);
    socket.listen((_) {}, onDone: close, onError: close);
  });
  final client = AppRestClient(
    transport: transport,
    baseAddress: 'http://127.0.0.1:${server.port}/probe',
    timeout: const Duration(milliseconds: 300),
  );
  try {
    await client.post('silent');
    return const ['A server that does not answer gave an answer.'];
  } on RestFailure catch (failure) {
    final isClosed = await closed.future
        .then((_) => true)
        .timeout(const Duration(seconds: 3), onTimeout: () => false);
    return [
      if (failure.reason != RestFailureReason.timeout)
        'A server that does not answer ended in ${failure.reason.name}, and '
            'not in timeout.',
      if (!isClosed)
        'An exchange that had to stop did not close its connection.',
    ];
  } finally {
    await server.close();
    for (final socket in sockets) {
      socket.destroy();
    }
  }
}

Future<List<String>> _problemsOfClosedPort(RestTransport transport) async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  final client = AppRestClient(
    transport: transport,
    baseAddress: 'http://127.0.0.1:$port/probe',
    timeout: _requestTime,
  );
  try {
    await client.post('closed');
    return const ['A port where nothing listens gave an answer.'];
  } on RestFailure catch (failure) {
    return [
      if (failure.reason != RestFailureReason.network)
        'A port where nothing listens ended in ${failure.reason.name}, and '
            'not in network.',
    ];
  }
}

/// What is wrong with a request over `http://` to an address for documentation,
/// which no machine has. A platform that refuses `http://` says so with an error
/// of another kind, which reaches the code as `unknown` with no status, and a
/// local server stops working. Anything else is no problem: the attempt may fail
/// in any way, and a proxy of the network may answer in its place.
Future<List<String>> _problemsOfCleartext(RestTransport transport) async {
  final client = AppRestClient(
    transport: transport,
    baseAddress: 'http://192.0.2.1:9/',
    timeout: const Duration(milliseconds: 300),
  );
  try {
    await client.post('probe');
    return const [];
  } on RestFailure catch (failure) {
    return [
      if (failure.reason == RestFailureReason.unknown && failure.status == null)
        'A request over http:// ended in unknown, and not as a request that '
            'fails: $failure.',
    ];
  }
}
