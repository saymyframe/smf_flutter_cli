/// What the test that grants premium access to the app that CI starts
/// knows of RevenueCat: the request of the app, how a server grants an
/// entitlement to a customer with the REST API v2 of RevenueCat, and what
/// each failure means. Nothing here reaches RevenueCat, so the tests of this
/// file run everywhere.
///
/// The secret key of the project is for servers alone, so no text here has
/// it: a text from RevenueCat that names it gets a placeholder in its place.
/// The app user id of the request, which the SDK made up for the device, may
/// show in a text.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Where the REST API v2 of RevenueCat is.
const apiOfRevenueCat = 'https://api.revenuecat.com/v2';

/// The permissions that the secret key of CI needs: to find the project, to
/// find the entitlement by its identifier, and to read the customer and
/// grant the entitlement to it.
const neededPermissions = [
  'project_configuration:projects:read',
  'project_configuration:entitlements:read',
  'customer_information:customers:read_write',
];

/// How many times [grantAccess] sends a request in all, for one that
/// RevenueCat may take later, and how many times it asks for a customer
/// that RevenueCat does not know yet.
const attempts = 3;

/// What a text from RevenueCat has in place of the secret key.
const _placeholder = '<the secret key>';

/// The premium access that the check of the start of the app asks for, from
/// the request that it wrote: the app user id of the device in RevenueCat,
/// the identifier of the entitlement, and when the access is to end, in
/// milliseconds since the epoch.
final class AccessRequest {
  AccessRequest._(this.appUserId, this.entitlement, this.expiresAt);

  /// The request in [text], the JSON that the app wrote. Throws an
  /// [AccessNotGranted] that tells what the request lacks.
  factory AccessRequest.parse(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw const AccessNotGranted('The request of the app is no JSON.');
    }
    return switch (json) {
      {
        'appUserId': final String appUserId,
        'entitlement': final String entitlement,
        'expiresAt': final int expiresAt,
      }
          when appUserId.isNotEmpty &&
              entitlement.isNotEmpty &&
              expiresAt > 0 =>
        AccessRequest._(appUserId, entitlement, expiresAt),
      _ => throw const AccessNotGranted(
          'The request of the app is not an object with an app user id and '
          'the identifier of an entitlement that are texts that are not '
          'empty, and the end of the access in milliseconds since the epoch.',
        ),
    };
  }

  /// The app user id of the device in RevenueCat, such as the one that the
  /// SDK made up for an anonymous user, `$RCAnonymousID:<id>`.
  final String appUserId;

  /// The identifier of the entitlement, its lookup key in RevenueCat.
  final String entitlement;

  /// When the access is to end, in milliseconds since the epoch.
  final int expiresAt;
}

/// Why RevenueCat did not grant the access, as a reader of the log of CI
/// needs it: what RevenueCat answered, what that means and what to do.
final class AccessNotGranted implements Exception {
  /// Creates the failure that [meaning] tells.
  const AccessNotGranted(this.meaning);

  /// What went wrong, what it means and what to do.
  final String meaning;

  @override
  String toString() => meaning;
}

/// Grants the premium access of [request] in the RevenueCat project of
/// [secretKey], a V2 secret key, through [client], and returns what it did,
/// for the log of CI, without the key.
///
/// It finds the one project that the key sees, the entitlement whose lookup
/// key the request names, and the customer of the app user id of the
/// request, which it asks for again, [pause] apart, while RevenueCat does
/// not know it yet. It grants the entitlement to the customer until the end
/// of the request, unless the customer has it until then already, as after
/// an earlier answer to the same request, which the script of CI runs again
/// when the app gives no verdict in time. A request that RevenueCat may take
/// later, after it limited the requests, failed itself or was not reached,
/// goes again, [attempts] times in all, once [wait] waited for the time that
/// RevenueCat asks for or [pause].
///
/// Throws an [AccessNotGranted] that tells what RevenueCat answered and what
/// that means.
Future<String> grantAccess(
  http.Client client, {
  required String secretKey,
  required AccessRequest request,
  Duration pause = const Duration(seconds: 5),
  Future<void> Function(Duration) wait = _wait,
}) async {
  final api = _Api(client, secretKey, pause, wait);
  final projects = await api.get('/projects?limit=100', 'the projects');
  final listed = _itemsOf(projects);
  final more = projects['next_page'] != null;
  if (listed.length != 1 || more) {
    throw AccessNotGranted(
      'The secret key sees ${listed.length}${more ? ' or more' : ''} '
      'projects of RevenueCat rather than one: the test grants the access in '
      'the one project of the key, so REVENUECAT_SECRET_KEY needs a secret '
      'key of the project of CI.',
    );
  }
  final project = listed.single;
  final projectId = '${project['id']}';
  final name = 'the project ${project['name']} of RevenueCat';
  final entitlements = await api.items(
    '/projects/${Uri.encodeComponent(projectId)}/entitlements?limit=100',
    'the entitlements of $name',
  );
  final entitlement = entitlements
      .where((item) => item['lookup_key'] == request.entitlement)
      .firstOrNull;
  if (entitlement == null) {
    final keys = [for (final item in entitlements) '${item['lookup_key']}'];
    throw AccessNotGranted(
      '$name has no entitlement with the identifier ${request.entitlement}, '
      'only ${keys.isEmpty ? 'none' : keys.join(', ')}: create it there, '
      'and attach the products of the current offering to it.',
    );
  }
  final entitlementId = '${entitlement['id']}';
  final customer = '/projects/${Uri.encodeComponent(projectId)}/customers/'
      '${Uri.encodeComponent(request.appUserId)}';
  final until = DateTime.fromMillisecondsSinceEpoch(
    request.expiresAt,
    isUtc: true,
  ).toIso8601String();
  final known = await api.get(
    customer,
    'the customer ${request.appUserId} in $name',
    unknownCustomer: true,
  );
  final active = switch (known['active_entitlements']) {
    final Map<String, Object?> list => _itemsOf(list),
    _ => const <Map<String, Object?>>[],
  };
  if (active.any(
    (item) =>
        item['entitlement_id'] == entitlementId &&
        item['expires_at'] == request.expiresAt,
  )) {
    return 'The customer ${request.appUserId} has ${request.entitlement} '
        'until $until in $name already, from an earlier answer to the same '
        'request.';
  }
  await api.post(
    '$customer/actions/grant_entitlement',
    {'entitlement_id': entitlementId, 'expires_at': request.expiresAt},
    'the grant of ${request.entitlement} to the customer '
        '${request.appUserId} in $name',
  );
  return 'RevenueCat granted ${request.entitlement} to the customer '
      '${request.appUserId} until $until in $name.';
}

Future<void> _wait(Duration duration) => Future<void>.delayed(duration);

/// The items of a list of the REST API v2 of RevenueCat, such as the
/// projects of a key.
List<Map<String, Object?>> _itemsOf(Map<String, Object?> list) => [
      if (list['items'] case final List<Object?> items)
        for (final item in items)
          if (item case final Map<String, Object?> map) map,
    ];

/// How long a request waits for RevenueCat before it counts as one that did
/// not reach it.
const _requestTimeout = Duration(seconds: 20);

/// The longest that a request waits before it goes again after RevenueCat
/// limited the requests, so that the answer stays within the time that the
/// script of CI gives it.
const _longestWait = Duration(seconds: 60);

/// The REST API v2 of RevenueCat with a secret key.
final class _Api {
  _Api(this._client, this._key, this._pause, this._wait);

  final http.Client _client;
  final String _key;
  final Duration _pause;
  final Future<void> Function(Duration) _wait;

  /// The object at [path] of the API, which [what] names in a failure; see
  /// [_send].
  Future<Map<String, Object?>> get(
    String path,
    String what, {
    bool unknownCustomer = false,
  }) =>
      _send('GET', path, null, what, unknownCustomer: unknownCustomer);

  /// The items of the list at [path] of the API and of its next pages.
  Future<List<Map<String, Object?>>> items(String path, String what) async {
    final items = <Map<String, Object?>>[];
    String? next = path;
    while (next != null) {
      final list = await get(next, what);
      items.addAll(_itemsOf(list));
      next = switch (list['next_page']) {
        final String page when page.startsWith('/v2/') => page.substring(3),
        _ => null,
      };
    }
    return items;
  }

  /// Posts [body] to [path] of the API.
  Future<Map<String, Object?>> post(
    String path,
    Map<String, Object?> body,
    String what,
  ) =>
      _send('POST', path, body, what);

  /// Sends a request to [path] of the API, with [body] as JSON if it has
  /// one, and returns the object of the answer. A request that RevenueCat
  /// may take later goes again, [attempts] times in all: one that RevenueCat
  /// limited, after the time that it asks for, one that it failed itself or
  /// says may go again, and one that did not reach it. With
  /// [unknownCustomer], so does a request for a customer that RevenueCat
  /// does not know yet.
  Future<Map<String, Object?>> _send(
    String method,
    String path,
    Map<String, Object?>? body,
    String what, {
    bool unknownCustomer = false,
  }) async {
    final uri = Uri.parse('$apiOfRevenueCat$path');
    for (var attempt = 1;; attempt++) {
      final last = attempt == attempts;
      final http.Response response;
      try {
        final request = http.Request(method, uri)
          ..headers['Authorization'] = 'Bearer $_key'
          ..headers['Accept'] = 'application/json';
        if (body != null) {
          request
            ..headers['Content-Type'] = 'application/json'
            ..body = jsonEncode(body);
        }
        response = await http.Response.fromStream(
          await _client.send(request).timeout(_requestTimeout),
        ).timeout(_requestTimeout);
      } on Object catch (error) {
        if (error is! TimeoutException &&
            error is! SocketException &&
            error is! http.ClientException) {
          rethrow;
        }
        if (!last) {
          await _wait(_pause);
          continue;
        }
        throw AccessNotGranted(
          'The test did not reach RevenueCat for $what in $attempts attempts: '
          '${_clean('$error')}.',
        );
      }
      final status = response.statusCode;
      if (status >= 200 && status < 300) {
        return switch (_jsonOf(response.body)) {
          final Map<String, Object?> object => object,
          _ => const {},
        };
      }
      final error = _ErrorOfApi.of(_jsonOf(response.body));
      final again = switch (status) {
        404 => unknownCustomer,
        429 => true,
        _ => status >= 500 || error.retryable,
      };
      if (again && !last) {
        await _wait(status == 429 ? _retryAfter(response, error) : _pause);
        continue;
      }
      throw AccessNotGranted(
        _meaningOf(status, error, what, unknownCustomer: unknownCustomer),
      );
    }
  }

  /// How long to wait after RevenueCat limited the requests: what its
  /// `Retry-After` or its `backoff_ms` asks for, at most [_longestWait], or
  /// [_pause] when it asks for nothing.
  Duration _retryAfter(http.Response response, _ErrorOfApi error) {
    final seconds = int.tryParse(response.headers['retry-after'] ?? '');
    final asked =
        seconds != null ? Duration(seconds: seconds) : error.backoff ?? _pause;
    return asked > _longestWait ? _longestWait : asked;
  }

  /// What the answer [status] to the request for [what] means, with the
  /// [error] of RevenueCat.
  String _meaningOf(
    int status,
    _ErrorOfApi error,
    String what, {
    required bool unknownCustomer,
  }) {
    final answered = '$status${error.text(_clean)}';
    return switch (status) {
      401 => 'RevenueCat did not take the secret key for $what ($answered): '
          'REVENUECAT_SECRET_KEY needs a V2 secret key of the RevenueCat '
          'project of CI that is not revoked.',
      403 => 'The secret key may not read or change $what ($answered): give '
          'it the permissions ${neededPermissions.join(', ')} in the API keys '
          'of the project in RevenueCat.',
      404 when unknownCustomer => 'RevenueCat does not know $what '
          '($answered), also after $attempts requests ${_pause.inSeconds} s '
          'apart, though the app read its customer info before it asked for '
          'the access: the test key of the app in CI_APP_ENV and the secret '
          'key in REVENUECAT_SECRET_KEY are of different projects of '
          'RevenueCat.',
      429 => 'RevenueCat limited the requests of the secret key for $what '
          '($answered), also after $attempts requests: run the job again '
          'later.',
      _ when status >= 500 || error.retryable => 'RevenueCat failed $what '
          '($answered), also after $attempts requests: run the job again '
          'later.',
      _ => 'RevenueCat refused $what ($answered).',
    };
  }

  /// [text] without the secret key, which a text from RevenueCat may name.
  String _clean(String text) =>
      _key.isEmpty ? text : text.replaceAll(_key, _placeholder);
}

/// The JSON of [text], or `null` if it is none.
Object? _jsonOf(String text) {
  try {
    return jsonDecode(text);
  } on FormatException {
    return null;
  }
}

/// What the body of an error of the REST API v2 of RevenueCat says: its
/// `type`, its `message`, whether the request may go again (`retryable`),
/// and how long to wait before it does (`backoff_ms`).
final class _ErrorOfApi {
  const _ErrorOfApi({
    this.type,
    this.message,
    this.retryable = false,
    this.backoff,
  });

  factory _ErrorOfApi.of(Object? json) => switch (json) {
        final Map<String, Object?> body => _ErrorOfApi(
            type: switch (body['type']) {
              final String type => type,
              _ => null,
            },
            message: switch (body['message']) {
              final String message => message,
              _ => null,
            },
            retryable: body['retryable'] == true,
            backoff: switch (body['backoff_ms']) {
              final int ms => Duration(milliseconds: ms),
              _ => null,
            },
          ),
        _ => const _ErrorOfApi(),
      };

  final String? type;
  final String? message;
  final bool retryable;
  final Duration? backoff;

  /// The type and the message after a colon, as [clean] leaves them, or
  /// nothing without them.
  String text(String Function(String) clean) {
    final said = [
      for (final part in [type, message])
        if (part != null) part,
    ].join(': ');
    return said.isEmpty ? '' : ', ${clean(said)}';
  }
}
