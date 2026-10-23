// Tests what the test that grants premium access to the app that CI starts
// knows of RevenueCat (support/revenuecat_grant.dart): the request of the
// app, the requests that it sends to the REST API v2 of RevenueCat, and what
// it says of each answer, without the secret key. A client in memory stands
// in for RevenueCat, so the tests need no network.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'support/revenuecat_grant.dart';

/// A secret key of the tests, which no text may have.
const _key = 'sk_tests_0123456789abcdef';

/// The app user id that the SDK makes up for an anonymous user.
const _user = r'$RCAnonymousID:0a1b2c3d';

/// The end of the access that the app asks for, in milliseconds.
const _expiresAt = 1792000000000;

/// The request of the app.
final _request = AccessRequest.parse(
  jsonEncode({
    'appUserId': _user,
    'entitlement': 'premium',
    'expiresAt': _expiresAt,
  }),
);

/// The path of the customer of [_user], as the test asks for it.
const _customer = '/v2/projects/proj1a2b/customers/%24RCAnonymousID%3A0a1b2c3d';

/// RevenueCat in memory, as the REST API v2 answers a secret key of one
/// project: its [projects], its [entitlements], a customer whose active
/// entitlements are [active] once RevenueCat knows it, and the grants. A
/// test scripts other answers with [script].
final class _RevenueCat {
  List<Map<String, Object?>> projects = [
    {'object': 'project', 'id': 'proj1a2b', 'name': 'SMF CI'},
  ];

  List<Map<String, Object?>> entitlements = [
    {'object': 'entitlement', 'id': 'entl0002', 'lookup_key': 'pro'},
    {'object': 'entitlement', 'id': 'entl0001', 'lookup_key': 'premium'},
  ];

  /// How many requests for the customer RevenueCat answers with 404 before
  /// it knows the customer.
  int unknownFor = 0;

  /// The active entitlements of the customer.
  final List<Map<String, Object?>> active = [];

  /// What RevenueCat answers to a grant that it applies, in place of the
  /// customer, such as an error after it applied the grant; and whether
  /// the client then gets no answer at all, as when its request runs out
  /// of time after RevenueCat applied the grant.
  http.Response? answerToGrant;
  bool grantUnanswered = false;

  /// The requests that reached RevenueCat, in their order.
  final List<http.Request> requests = [];

  /// The scripted answers to `<method> <path>`, each used once, in order.
  final Map<String, List<http.Response>> _scripted = {};

  /// Answers the next requests of [method] to [path] with [answers].
  void script(String method, String path, List<http.Response> answers) =>
      (_scripted['$method $path'] ??= []).addAll(answers);

  /// The requests as `<method> <path and query>`.
  List<String> get calls => [
        for (final request in requests) _call(request),
      ];

  /// [request] as `<method> <path and query>`.
  static String _call(http.Request request) {
    final query = request.url.hasQuery ? '?${request.url.query}' : '';
    return '${request.method} ${request.url.path}$query';
  }

  late final client = MockClient((request) async {
    requests.add(request);
    final scripted = _scripted['${request.method} ${request.url.path}'];
    if (scripted != null && scripted.isNotEmpty) return scripted.removeAt(0);
    return switch ((request.method, request.url.path)) {
      ('GET', '/v2/projects') => _list(projects),
      ('GET', '/v2/projects/proj1a2b/entitlements') => _list(entitlements),
      ('GET', _customer) => unknownFor-- > 0
          ? _error(404, 'resource_missing', 'Customer not found.')
          : _json(200, _customerObject()),
      ('POST', '$_customer/actions/grant_entitlement') => _grant(request),
      _ => _error(404, 'resource_missing', 'No such path.'),
    };
  });

  http.Response _grant(http.Request request) {
    final body = jsonDecode(request.body) as Map<String, Object?>;
    active.add({
      'object': 'customer.active_entitlement',
      'entitlement_id': body['entitlement_id'],
      'expires_at': body['expires_at'],
    });
    if (grantUnanswered) {
      throw http.ClientException('The request timed out.', request.url);
    }
    return answerToGrant ?? _json(201, _customerObject());
  }

  Map<String, Object?> _customerObject() => {
        'object': 'customer',
        'id': _user,
        'project_id': 'proj1a2b',
        'active_entitlements': {
          'object': 'list',
          'items': active,
          'next_page': null,
          'url': '$_customer/active_entitlements',
        },
      };
}

/// An answer of [status] with [body] as JSON.
http.Response _json(
  int status,
  Object? body, {
  Map<String, String> headers = const {},
}) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json', ...headers},
    );

/// A list of the API with [items] and no next page.
http.Response _list(List<Map<String, Object?>> items) => _json(200, {
      'object': 'list',
      'items': items,
      'next_page': null,
      'url': '/v2/list',
    });

/// An error of the API.
http.Response _error(
  int status,
  String type,
  String message, {
  bool retryable = false,
  int? backoffMs,
  Map<String, String> headers = const {},
}) =>
    _json(
      status,
      {
        'object': 'error',
        'type': type,
        'message': message,
        'retryable': retryable,
        if (backoffMs != null) 'backoff_ms': backoffMs,
      },
      headers: headers,
    );

void main() {
  group('the request of the app', () {
    test('has the app user id, the entitlement and the end of the access', () {
      expect(_request.appUserId, _user);
      expect(_request.entitlement, 'premium');
      expect(_request.expiresAt, _expiresAt);
    });

    test('fails on JSON that has not each of them as it should be', () {
      for (final text in [
        'not json',
        '[]',
        '{"appUserId": "", "entitlement": "premium", "expiresAt": 1}',
        '{"appUserId": "a", "entitlement": "", "expiresAt": 1}',
        '{"appUserId": "a", "entitlement": "premium", "expiresAt": 0}',
        '{"appUserId": "a", "entitlement": "premium", "expiresAt": "1"}',
        '{"appUserId": "a", "entitlement": "premium"}',
      ]) {
        expect(
          () => AccessRequest.parse(text),
          throwsA(isA<AccessNotGranted>()),
          reason: text,
        );
      }
      expect(
        () => AccessRequest.parse('not json'),
        throwsA(
          isA<AccessNotGranted>().having(
            (error) => error.meaning,
            'meaning',
            'The request of the app is no JSON.',
          ),
        ),
      );
    });
  });

  group('the grant', () {
    late _RevenueCat revenueCat;
    late List<Duration> waits;

    setUp(() {
      revenueCat = _RevenueCat();
      waits = [];
    });

    Future<String> grant() => grantAccess(
          revenueCat.client,
          secretKey: _key,
          request: _request,
          wait: (duration) async => waits.add(duration),
        );

    /// What [grant] fails with.
    Future<String> failure() async {
      try {
        await grant();
      } on AccessNotGranted catch (error) {
        expect(error.meaning, isNot(contains(_key)));
        return error.meaning;
      }
      fail('The grant did not fail.');
    }

    test(
        'finds the one project of the key and the entitlement by its lookup '
        'key, and grants it to the customer of the app user id, URL-encoded, '
        'until the end of the request, with the key in no text', () async {
      final done = await grant();

      expect(revenueCat.calls, [
        'GET /v2/projects?limit=100',
        'GET /v2/projects/proj1a2b/entitlements?limit=100',
        'GET $_customer',
        'POST $_customer/actions/grant_entitlement',
      ]);
      expect(
        revenueCat.requests.last.url.toString(),
        'https://api.revenuecat.com$_customer/actions/grant_entitlement',
      );
      for (final request in revenueCat.requests) {
        expect(request.headers['Authorization'], 'Bearer $_key');
      }
      expect(jsonDecode(revenueCat.requests.last.body), {
        'entitlement_id': 'entl0001',
        'expires_at': _expiresAt,
      });
      expect(
        revenueCat.requests.last.headers['Content-Type'],
        startsWith('application/json'),
      );
      expect(
        done,
        'RevenueCat granted premium to the customer $_user until '
        '2026-10-14T17:46:40.000Z in the project SMF CI of RevenueCat.',
      );
      expect(waits, isEmpty);
    });

    test(
        'grants nothing to a customer that has the entitlement until two '
        'hours or less from the end of the request already, which RevenueCat '
        'takes for the same grant, as after an earlier answer to the request, '
        'and grants it to one that has it until a time further off, or has '
        'another entitlement', () async {
      const hour = 3600000;
      for (final end in [
        _expiresAt,
        _expiresAt + 1000,
        _expiresAt - 2 * hour,
        _expiresAt + 2 * hour,
      ]) {
        revenueCat
          ..requests.clear()
          ..active.clear()
          ..active.add({'entitlement_id': 'entl0001', 'expires_at': end});

        final ends = DateTime.fromMillisecondsSinceEpoch(end, isUtc: true);
        expect(
          await grant(),
          'The customer $_user has premium until ${ends.toIso8601String()} '
          'in the project SMF CI of RevenueCat already, two hours or less from '
          'the end that the request asks for, 2026-10-14T17:46:40.000Z, which '
          'RevenueCat takes for the same grant, as after an earlier answer to '
          'the same request.',
          reason: '$end',
        );
        expect(revenueCat.calls.last, 'GET $_customer', reason: '$end');
      }

      for (final (id, end) in [
        ('entl0001', _expiresAt + 2 * hour + 1),
        ('entl0001', _expiresAt - 2 * hour - 1),
        ('entl0002', _expiresAt),
      ]) {
        revenueCat
          ..requests.clear()
          ..active.clear()
          ..active.add({'entitlement_id': id, 'expires_at': end});
        await grant();
        expect(
          revenueCat.calls.last,
          'POST $_customer/actions/grant_entitlement',
          reason: '$id $end',
        );
      }
    });

    test(
        'takes a grant that RevenueCat applied for done, though it answered '
        'the request with an error or with no answer at all, once it reads '
        'the customer again', () async {
      revenueCat.answerToGrant =
          _error(422, 'invalid_request', 'The grant is a duplicate.');

      expect(
        await grant(),
        'RevenueCat refused the grant of premium to the customer $_user in '
        'the project SMF CI of RevenueCat (422, invalid_request: The grant is '
        'a duplicate.). But the customer has premium until '
        '2026-10-14T17:46:40.000Z now, so RevenueCat applied the grant.',
      );
      expect(revenueCat.calls.last, 'GET $_customer');

      revenueCat
        ..requests.clear()
        ..active.clear()
        ..answerToGrant = null
        ..grantUnanswered = true;
      expect(
        await grant(),
        allOf(
          startsWith(
            'The test did not reach RevenueCat for the grant of premium to the '
            'customer $_user in the project SMF CI of RevenueCat in 3 '
            'attempts: ',
          ),
          endsWith(
            'But the customer has premium until 2026-10-14T17:46:40.000Z now, '
            'so RevenueCat applied the grant.',
          ),
        ),
      );
      expect(
        revenueCat.calls.where((call) => call.startsWith('POST')),
        hasLength(3),
      );

      // An error after which the customer has no such grant stays one.
      revenueCat
        ..requests.clear()
        ..active.clear()
        ..grantUnanswered = false
        ..script('POST', '$_customer/actions/grant_entitlement', [
          _error(422, 'invalid_request', 'expires_at must be in the future.'),
        ]);
      expect(
        await failure(),
        'RevenueCat refused the grant of premium to the customer $_user in '
        'the project SMF CI of RevenueCat (422, invalid_request: expires_at '
        'must be in the future.).',
      );
    });

    test(
        'asks again for a customer that RevenueCat does not know yet, and '
        'fails when it does not know it after three requests', () async {
      revenueCat.unknownFor = 2;

      await grant();
      expect(waits, [const Duration(seconds: 5), const Duration(seconds: 5)]);
      expect(
        revenueCat.calls.where((call) => call == 'GET $_customer'),
        hasLength(3),
      );

      revenueCat.unknownFor = 3;
      expect(
        await failure(),
        'RevenueCat does not know the customer $_user in the project SMF CI '
        'of RevenueCat (404, resource_missing: Customer not found.), also '
        'after 3 requests 5 s apart, though the app read its customer info '
        'before it asked for the access: the test key of the app in '
        'CI_APP_ENV and the secret key in REVENUECAT_SECRET_KEY are of '
        'different projects '
        'of RevenueCat.',
      );
    });

    test(
        'says what a key that RevenueCat does not take, or that lacks a '
        'permission, means, without the key, also when RevenueCat names it',
        () async {
      revenueCat.script('GET', '/v2/projects', [
        _error(401, 'authentication_error', 'Invalid API key $_key.'),
      ]);
      expect(
        await failure(),
        'RevenueCat did not take the secret key for the projects (401, '
        'authentication_error: Invalid API key <the secret key>.): '
        'REVENUECAT_SECRET_KEY needs a V2 secret key of the RevenueCat '
        'project of CI that is not revoked.',
      );

      revenueCat.script('GET', '/v2/projects/proj1a2b/entitlements', [
        _error(403, 'authorization_error', 'Missing permission.'),
      ]);
      expect(
        await failure(),
        'The secret key may not read or change the entitlements of the '
        'project SMF CI of RevenueCat (403, authorization_error: Missing '
        'permission.): give it the permissions '
        'project_configuration:projects:read, '
        'project_configuration:entitlements:read, '
        'customer_information:customers:read_write in the API keys of the '
        'project in RevenueCat.',
      );
      expect(waits, isEmpty);
    });

    test(
        'sends a request that RevenueCat limited again after the time that it '
        'asks for, at most a minute, and fails after three', () async {
      http.Response limited({String? retryAfter, int? backoffMs}) => _error(
            429,
            'rate_limit_error',
            'Slow down.',
            backoffMs: backoffMs,
            headers: {if (retryAfter != null) 'retry-after': retryAfter},
          );
      revenueCat
        ..script('GET', '/v2/projects', [
          limited(retryAfter: '7'),
          limited(backoffMs: 3000),
        ])
        ..script('GET', '/v2/projects/proj1a2b/entitlements', [
          limited(retryAfter: '600'),
          limited(),
        ]);

      await grant();
      expect(waits, const [
        Duration(seconds: 7),
        Duration(seconds: 3),
        Duration(minutes: 1),
        Duration(seconds: 5),
      ]);

      revenueCat.script('GET', '/v2/projects', [
        for (var i = 0; i < 3; i++)
          _error(429, 'rate_limit_error', 'Slow down.'),
      ]);
      expect(
        await failure(),
        'RevenueCat limited the requests of the secret key for the projects '
        '(429, rate_limit_error: Slow down.), also after 3 requests: run the '
        'job again later.',
      );
    });

    test(
        'sends a request again that RevenueCat failed itself, or that it says '
        'may go again, or that did not reach it, and fails after three',
        () async {
      revenueCat
        ..script('POST', '$_customer/actions/grant_entitlement', [
          _error(500, 'server_error', 'Oops.'),
          _error(423, 'resource_locked_error', 'Busy.', retryable: true),
        ])
        ..script('GET', _customer, [http.Response('not json', 503)]);

      await grant();
      expect(waits, List.filled(3, const Duration(seconds: 5)));
      expect(revenueCat.active, hasLength(1));

      revenueCat.script('POST', '$_customer/actions/grant_entitlement', [
        for (var i = 0; i < 3; i++) _error(502, 'server_error', 'Bad gateway.'),
      ]);
      revenueCat.active.clear();
      expect(
        await failure(),
        'RevenueCat failed the grant of premium to the customer $_user in the '
        'project SMF CI of RevenueCat (502, server_error: Bad gateway.), also '
        'after 3 requests: run the job again later.',
      );
    });

    test(
        'fails on an answer that a request again would not change, with what '
        'RevenueCat said', () async {
      revenueCat.script('POST', '$_customer/actions/grant_entitlement', [
        _error(422, 'invalid_request', 'expires_at must be in the future.'),
      ]);

      expect(
        await failure(),
        'RevenueCat refused the grant of premium to the customer $_user in '
        'the project SMF CI of RevenueCat (422, invalid_request: expires_at '
        'must be in the future.).',
      );
      expect(waits, isEmpty);
    });

    test(
        'fails when the key sees no project, or more than one, and when the '
        'project has no entitlement with the lookup key of the request, which '
        'it looks for on every page of the entitlements', () async {
      revenueCat.projects = [];
      expect(
        await failure(),
        'The secret key sees 0 projects of RevenueCat rather than one: the '
        'test grants the access in the one project of the key, so '
        'REVENUECAT_SECRET_KEY needs a secret key of the project of CI.',
      );
      revenueCat.script('GET', '/v2/projects', [
        _json(200, {
          'object': 'list',
          'items': [
            {'id': 'proj1a2b', 'name': 'SMF CI'},
          ],
          'next_page': '/v2/projects?starting_after=proj1a2b',
        }),
      ]);
      expect(await failure(), startsWith('The secret key sees 1 or more '));

      revenueCat
        ..projects = [
          {'object': 'project', 'id': 'proj1a2b', 'name': 'SMF CI'},
        ]
        ..entitlements = [
          {'id': 'entl0002', 'lookup_key': 'pro'},
        ];
      expect(
        await failure(),
        'the project SMF CI of RevenueCat has no entitlement with the '
        'identifier premium, only pro: create it there, and attach the '
        'products of the current offering to it.',
      );

      revenueCat.script('GET', '/v2/projects/proj1a2b/entitlements', [
        _json(200, {
          'object': 'list',
          'items': [
            {'id': 'entl0002', 'lookup_key': 'pro'},
          ],
          'next_page':
              '/v2/projects/proj1a2b/entitlements?starting_after=entl0002',
        }),
        _list([
          {'id': 'entl0003', 'lookup_key': 'premium'},
        ]),
      ]);
      await grant();
      expect(
        revenueCat.calls,
        contains(
          'GET /v2/projects/proj1a2b/entitlements?starting_after=entl0002',
        ),
      );
      expect(
        jsonDecode(revenueCat.requests.last.body),
        containsPair('entitlement_id', 'entl0003'),
      );
    });

    test('fails when no request reaches RevenueCat, without the key', () async {
      final failing = MockClient(
        (request) async => throw http.ClientException(
          'Connection refused, with the key $_key',
          request.url,
        ),
      );

      final error = await grantAccess(
        failing,
        secretKey: _key,
        request: _request,
        wait: (duration) async => waits.add(duration),
      ).then<Object?>((_) => null, onError: (Object error) => error);

      expect(
        error,
        isA<AccessNotGranted>().having(
          (error) => error.meaning,
          'meaning',
          allOf(
            startsWith(
              'The test did not reach RevenueCat for the projects in 3 '
              'attempts: ',
            ),
            contains('<the secret key>'),
            isNot(contains(_key)),
          ),
        ),
      );
      expect(waits, List.filled(2, const Duration(seconds: 5)));
    });
  });
}
