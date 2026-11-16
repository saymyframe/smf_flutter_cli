// What the tests that publish a value in Remote Config of the Firebase
// project of CI and remove it again (publish_value_test.dart and
// remove_values_test.dart) know of the REST API of Remote Config, without
// Google: the request of the app, the parameters that a change adds and
// removes, how a change reads and publishes the template with its ETag,
// when it sends again, and what each failure means, never with the access
// token or a part of the key of the service account.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'support/remote_config_template.dart';

/// The nonce of the request of the tests.
const _nonce = '0123456789abcdef0123456789abcdef';

/// The request of the probe of the start check, as the app writes it.
final String _asked = jsonEncode({
  'parameter': 'remote_config_ci_$_nonce',
  'value': _nonce,
});

/// The time of the tests.
final DateTime _now = DateTime.utc(2026, 11, 17, 12);

/// A parameter of the check published at [time], with [value].
Map<String, Object?> _checkParameter(DateTime time, String value) => {
      'defaultValue': {'value': value},
      'description': descriptionAt(time),
      'valueType': 'STRING',
    };

/// The name of another parameter of the check than the one of the tests.
String _other(String digit) => 'remote_config_ci_${digit * 32}';

/// The parameters of the template of the tests: one of the developer of the
/// project, the minimum version of the app, a parameter of the check of
/// another job a minute old, one of a cancelled job three hours old, and a
/// parameter with the name of the check whose description tells no time.
Map<String, Object?> get _parameters => {
      'welcome_text': {
        'defaultValue': {'value': 'Hello'},
        'conditionalValues': {
          'ios': {
            'value': {'value': 'Hi'},
          },
        },
        'valueType': 'STRING',
      },
      'update_required_minimum_version': {
        'defaultValue': {'value': '1.2.0'},
        'valueType': 'STRING',
      },
      _other('1'): _checkParameter(
        _now.subtract(const Duration(minutes: 1)),
        '1' * 32,
      ),
      _other('2'): _checkParameter(
        _now.subtract(const Duration(hours: 3)),
        '2' * 32,
      ),
      _other('3'): {
        'defaultValue': {'value': '3' * 32},
        'description': 'Made by hand',
        'valueType': 'STRING',
      },
    };

/// The template of the tests as the REST API gives it.
Map<String, Object?> get _template => {
      'conditions': [
        {'name': 'ios', 'expression': "device.os == 'ios'"},
      ],
      'parameters': _parameters,
      'parameterGroups': {
        'Group': {
          'parameters': {
            'grouped_parameter': {
              'defaultValue': {'value': 'in a group'},
            },
          },
        },
      },
      'version': {
        'versionNumber': '41',
        'updateTime': '2026-11-17T11:00:00.000Z',
        'updateUser': {'email': 'someone@example.com'},
      },
    };

/// The answer of Google to a failure with [status], [code], [message] and
/// [details], as the REST API of Remote Config writes it.
String _error(
  int status,
  String code,
  String message, [
  List<Map<String, Object?>> details = const [],
]) =>
    jsonEncode({
      'error': {
        'code': status,
        'message': message,
        'status': code,
        'details': details,
      },
    });

Map<String, Object?> _info(String reason, Map<String, String> metadata) => {
      '@type': 'type.googleapis.com/google.rpc.ErrorInfo',
      'reason': reason,
      'domain': 'googleapis.com',
      'metadata': metadata,
    };

/// An answer of the REST API with the template [template] and the ETag
/// [etag].
http.Response _templateAnswer(Map<String, Object?> template, String etag) =>
    http.Response(
      jsonEncode(template),
      200,
      headers: {'etag': etag, 'content-type': 'application/json'},
    );

/// A Remote Config in memory: a template that each GET gives with the ETag
/// of its version, and that a PUT replaces when its `If-Match` is that ETag,
/// before which [beforePut] may change the template, as another job does.
/// It records each request.
final class _RemoteConfig {
  _RemoteConfig(this.template);

  Map<String, Object?> template;
  int version = 41;
  final List<http.Request> requests = [];

  /// What happens before each PUT, by its number, such as another publish.
  final Map<int, void Function()> beforePut = {};

  String get etag => 'etag-$version';

  late final http.Client client = MockClient((request) async {
    requests.add(request);
    if (request.method == 'GET') return _templateAnswer(template, etag);
    final puts = requests.where((sent) => sent.method == 'PUT').length;
    beforePut[puts]?.call();
    if (request.headers['if-match'] != etag) {
      return http.Response(
        _error(409, 'ABORTED', 'The ETag does not match the template.'),
        409,
      );
    }
    template = jsonDecode(request.body) as Map<String, Object?>;
    version++;
    return _templateAnswer(
      {
        ...template,
        'version': {'versionNumber': '$version'},
      },
      etag,
    );
  });
}

/// A random of the tests, whose waits are none since the delay is zero.
final Random _random = Random(1);

/// A block of PEM with [label] and [body], as the private key of a key of a
/// service account has one.
String _pem(String label, String body) =>
    '-----BEGIN $label-----\n$body\n-----END $label-----\n';

/// The PEM of an RSA private key that only parses: its modulus has the 1024
/// bits that googleapis_auth asks for, and its other numbers are made up, so
/// the signatures made with it prove nothing. The token endpoint of the
/// tests does not check them. q is the prime 2^1279 - 1, above every block
/// of a modulus of 1024 bits, so no signature is 0, which googleapis_auth
/// refuses.
String _keyThatParses() {
  // The lengths of DER, all below 65536 here.
  List<int> length(int count) => switch (count) {
        < 128 => [count],
        < 256 => [0x81, count],
        _ => [0x82, count >> 8, count & 0xff],
      };
  List<int> integer(BigInt value) {
    final hex = value.toRadixString(16);
    final even = hex.length.isOdd ? '0$hex' : hex;
    final bytes = [
      for (var at = 0; at < even.length; at += 2)
        int.parse(even.substring(at, at + 2), radix: 16),
    ];
    if (bytes.first >= 0x80) bytes.insert(0, 0);
    return [0x02, ...length(bytes.length), ...bytes];
  }

  // version, n, e, d, p, q, d mod (p - 1), d mod (q - 1), q^-1 mod p
  final numbers = [
    BigInt.zero,
    (BigInt.one << 1023) + BigInt.one,
    BigInt.from(65537),
    BigInt.from(3),
    BigInt.from(5),
    (BigInt.one << 1279) - BigInt.one,
    for (final number in [3, 3, 1]) BigInt.from(number),
  ];
  final body = [for (final number in numbers) ...integer(number)];
  return _pem(
    'RSA PRIVATE KEY',
    base64Encode([0x30, ...length(body.length), ...body]),
  );
}

void main() {
  final request = ValueRequest.parse(_asked);

  group('ValueRequest', () {
    test('takes the parameter and the value that the app asks for', () {
      expect(request.parameter, 'remote_config_ci_$_nonce');
      expect(request.value, _nonce);
    });

    test(
        'refuses a request that is not what the app writes, and any name of '
        'a parameter but one of the check', () {
      for (final text in [
        '{',
        jsonEncode({'parameter': 'remote_config_ci_$_nonce'}),
        jsonEncode({
          'parameter': 'update_required_minimum_version',
          'value': _nonce,
        }),
        jsonEncode({
          'parameter': 'remote_config_ci_${_nonce.toUpperCase()}',
          'value': _nonce,
        }),
        jsonEncode({
          'parameter': 'remote_config_ci_$_nonce',
          'value': 'a text of the app',
        }),
      ]) {
        expect(
          () => ValueRequest.parse(text),
          throwsA(isA<TemplateNotChanged>()),
          reason: text,
        );
      }
    });
  });

  group('the parameters of a change', () {
    test(
        'have the value of the request, described with the time of its '
        'publish, without the stale parameters of the check, and every other '
        'parameter as it was', () {
      final changed = withValue(_parameters, request, _now);

      expect(changed.keys, [
        'welcome_text',
        'update_required_minimum_version',
        _other('1'),
        _other('3'),
        request.parameter,
      ]);
      expect(changed[request.parameter], {
        'defaultValue': {'value': _nonce},
        'description': 'SMF start check, 2026-11-17T12:00:00.000Z',
        'valueType': 'STRING',
      });
      for (final name in [
        'welcome_text',
        'update_required_minimum_version',
        _other('1'),
        _other('3'),
      ]) {
        expect(changed[name], _parameters[name], reason: name);
      }
    });

    test(
        'publish the parameter of the request again with a new time when it '
        'is there already', () {
      final later = _now.add(const Duration(minutes: 3));
      final again = withValue(
        withValue(_parameters, request, _now),
        request,
        later,
      );

      expect(
        again[request.parameter],
        _checkParameter(later, _nonce),
      );
      expect(
        again.keys.where((name) => name == request.parameter),
        hasLength(1),
      );
    });

    test(
        'remove the parameters of the run and the stale ones of the check, '
        'and are none when nothing is to go', () {
      final published = withValue(_parameters, request, _now);
      final removed = withoutValues(
        published,
        {request.parameter, 'welcome_text'},
        _now,
      );

      expect(removed!.keys, [
        'welcome_text',
        'update_required_minimum_version',
        _other('1'),
        _other('3'),
      ]);
      expect(
        withoutValues(removed, {request.parameter}, _now),
        isNull,
        reason: 'Nothing is to go, so nothing is published.',
      );
      expect(
        withoutValues(
          _parameters,
          const {},
          _now.add(const Duration(hours: 3)),
        )!
            .keys,
        ['welcome_text', 'update_required_minimum_version', _other('3')],
        reason: 'Once a parameter of the check is more than two hours old, '
            'as one that a cancelled job left, it goes.',
      );
    });
  });

  group('changeTemplate', () {
    test(
        'reads the template with its ETag, and publishes it with If-Match, '
        'with the parameters of the change and every other part as it was',
        () async {
      final remoteConfig = _RemoteConfig(_template);

      final version = await changeTemplate(
        remoteConfig.client,
        project: 'a-project',
        change: (parameters) => withValue(parameters, request, _now),
        retryDelay: Duration.zero,
        random: _random,
      );

      expect(version, '42');
      final [read, put] = remoteConfig.requests;
      expect(read.method, 'GET');
      expect(read.url, templateUriOf('a-project'));
      expect(
        read.url.toString(),
        'https://firebaseremoteconfig.googleapis.com/v1/projects/a-project/'
        'remoteConfig',
      );
      expect(read.headers['accept-encoding'], 'gzip');
      expect(put.method, 'PUT');
      expect(put.url, templateUriOf('a-project'));
      expect(put.headers['if-match'], 'etag-41');
      expect(put.headers['content-type'], startsWith('application/json'));
      final published = jsonDecode(put.body) as Map<String, Object?>;
      expect(published['conditions'], _template['conditions']);
      expect(published['parameterGroups'], _template['parameterGroups']);
      expect(
        published['parameters'],
        withValue(_parameters, request, _now),
      );
      expect(
        published['version'],
        {'description': 'SMF start check'},
        reason: "The version of a template is the API's, but for its "
            'description.',
      );
    });

    test('publishes nothing when nothing is to change', () async {
      final remoteConfig = _RemoteConfig({
        ..._template,
        'parameters': withoutValues(_parameters, const {}, _now),
      });

      final version = await changeTemplate(
        remoteConfig.client,
        project: 'p',
        change: (parameters) => withoutValues(parameters, const {}, _now),
        retryDelay: Duration.zero,
        random: _random,
      );

      expect(version, isNull);
      expect([for (final sent in remoteConfig.requests) sent.method], ['GET']);
    });

    test(
        'reads the template again and changes it again when another job '
        'published between the read and the publish, and keeps what the '
        'other job published', () async {
      final remoteConfig = _RemoteConfig(_template);
      remoteConfig.beforePut[1] = () {
        remoteConfig
          ..template = {
            ...remoteConfig.template,
            'parameters': {
              ...remoteConfig.template['parameters']! as Map<String, Object?>,
              _other('4'): _checkParameter(_now, '4' * 32),
            },
          }
          ..version += 1;
      };

      final version = await changeTemplate(
        remoteConfig.client,
        project: 'p',
        change: (parameters) => withValue(parameters, request, _now),
        retryDelay: Duration.zero,
        random: _random,
      );

      expect(version, '43');
      expect(
        [for (final sent in remoteConfig.requests) sent.method],
        ['GET', 'PUT', 'GET', 'PUT'],
      );
      final parameters =
          remoteConfig.template['parameters']! as Map<String, Object?>;
      expect(parameters.keys, containsAll([_other('4'), request.parameter]));
    });

    test(
        'takes a 412 and a 400 that names a version that does not match for '
        'a template that changed too, and tells once five publishes failed',
        () async {
      for (final conflict in [
        http.Response(_error(412, 'FAILED_PRECONDITION', 'Stale.'), 412),
        http.Response(
          _error(
            400,
            'INVALID_ARGUMENT',
            'The version of the template does not match the ETag.',
          ),
          400,
        ),
      ]) {
        var puts = 0;
        final client = MockClient((sent) async {
          if (sent.method == 'GET') return _templateAnswer(_template, 'e');
          puts++;
          return conflict;
        });

        await expectLater(
          changeTemplate(
            client,
            project: 'p',
            change: (parameters) => withValue(parameters, request, _now),
            retryDelay: Duration.zero,
            random: _random,
          ),
          throwsA(
            isA<TemplateNotChanged>().having(
              (error) => error.meaning,
              'meaning',
              startsWith(
                'The template of Remote Config of the project p changed '
                'between each read and its publish, 5 times: other jobs '
                'publish in it at the same time. Run the job again.',
              ),
            ),
          ),
        );
        expect(puts, conflictAttempts);
      }
    });

    test(
        'sends again after a quota, a server that failed or a network that '
        'broke, three times in all, and tells what the last failure means',
        () async {
      var sent = 0;
      final answers = <http.Response Function()>[
        () => http.Response(_error(429, 'RESOURCE_EXHAUSTED', 'Quota.'), 429),
        () => throw http.ClientException('Connection reset'),
        () => _templateAnswer(_template, 'e'),
        () => http.Response(_error(503, 'UNAVAILABLE', 'Busy.'), 503),
        () => _templateAnswer(
              {
                'version': {'versionNumber': '42'},
              },
              'f',
            ),
      ];
      final flaky = MockClient((_) async => answers[sent++]());
      final failing = MockClient(
        (_) async => http.Response(_error(500, 'INTERNAL', 'Failed.'), 500),
      );

      final version = await changeTemplate(
        flaky,
        project: 'p',
        change: (parameters) => withValue(parameters, request, _now),
        retryDelay: Duration.zero,
        random: _random,
      );

      expect(version, '42');
      expect(sent, 5);
      await expectLater(
        changeTemplate(
          failing,
          project: 'p',
          change: (parameters) => withValue(parameters, request, _now),
          retryDelay: Duration.zero,
          random: _random,
        ),
        throwsA(
          isA<TemplateNotChanged>().having(
            (error) => error.meaning,
            'meaning',
            'Remote Config failed, 3 times, with HTTP 500: run the job again '
                'later. Remote Config says: Failed.',
          ),
        ),
      );
    });

    test(
        'does not send again a request that Remote Config refuses, and tells '
        'of a template without its ETag', () async {
      var sent = 0;
      final refusing = MockClient((_) async {
        sent++;
        return http.Response(_error(404, 'NOT_FOUND', 'No project.'), 404);
      });
      final withoutEtag = MockClient(
        (_) async => http.Response(jsonEncode(_template), 200),
      );

      await expectLater(
        changeTemplate(
          refusing,
          project: 'p',
          change: (parameters) => parameters,
        ),
        throwsA(isA<TemplateNotChanged>()),
      );
      expect(sent, 1);
      await expectLater(
        changeTemplate(
          withoutEtag,
          project: 'p',
          change: (parameters) => parameters,
        ),
        throwsA(
          isA<TemplateNotChanged>().having(
            (error) => error.meaning,
            'meaning',
            'Remote Config gave the template of the project p without its '
                'ETag, which a publish needs.',
          ),
        ),
      );
    });
  });

  group('meaningOf', () {
    String meaning(int status, String body) =>
        meaningOf(project: 'saymyframe-app-cli', status: status, body: body);

    test('tells of an API that is not enabled, with its page', () {
      expect(
        meaning(
          403,
          _error(
            403,
            'PERMISSION_DENIED',
            'Firebase Remote Config API has not been used in project 1 '
                'before or it is disabled.',
            [
              _info('SERVICE_DISABLED', {
                'activationUrl': 'https://console.developers.google.com/apis/'
                    'api/firebaseremoteconfig.googleapis.com/overview?'
                    'project=1',
              }),
            ],
          ),
        ),
        'The Firebase Remote Config API (firebaseremoteconfig.googleapis.com) '
        'is not enabled in the project saymyframe-app-cli, or was enabled '
        'only a few minutes ago. Enable it at '
        'https://console.developers.google.com/apis/api/'
        'firebaseremoteconfig.googleapis.com/overview?project=1 and run the '
        'job again a few minutes later. Remote Config '
        'says: Firebase Remote Config API has not been used in project 1 '
        'before or it is disabled.',
      );
    });

    test(
        'tells of a permission that the service account lacks, with the role '
        'that grants it', () {
      expect(
        meaning(
          403,
          _error(403, 'PERMISSION_DENIED', 'Permission denied.', [
            _info('IAM_PERMISSION_DENIED', {
              'permission': 'cloudconfig.configs.update',
            }),
          ]),
        ),
        'The service account may not read or publish the template of Remote '
        'Config of the project saymyframe-app-cli (PERMISSION_DENIED): it '
        'lacks cloudconfig.configs.update, which the role Firebase Remote '
        'Config Admin or Firebase Admin grants at '
        'https://console.cloud.google.com/iam-admin/iam?project='
        'saymyframe-app-cli. Remote Config says: Permission denied.',
      );
      expect(
        meaning(403, _error(403, 'PERMISSION_DENIED', 'Denied.')),
        contains('it lacks cloudconfig.configs.get or '
            'cloudconfig.configs.update, which the role'),
      );
    });

    test(
        'tells of an access token that Remote Config does not take, of a '
        'project that it does not know, of a template that it refuses, of a '
        'quota and of any other answer', () {
      expect(
        meaning(401, _error(401, 'UNAUTHENTICATED', 'Invalid credentials.')),
        'Remote Config does not take the access token of the service account '
        '(UNAUTHENTICATED). Remote Config says: Invalid credentials.',
      );
      expect(
        meaning(404, _error(404, 'NOT_FOUND', 'Not found.')),
        startsWith('Remote Config has no project saymyframe-app-cli: '
            'SMF_FIREBASE_PROJECT names another project'),
      );
      expect(
        meaning(400, _error(400, 'INVALID_ARGUMENT', 'Bad condition.')),
        'Remote Config refuses the template of the project saymyframe-app-cli '
        '(INVALID_ARGUMENT). Remote Config says: Bad condition.',
      );
      expect(
        meaningOf(
          project: 'p',
          status: 429,
          body: _error(429, 'RESOURCE_EXHAUSTED', 'Quota.'),
          tries: 3,
        ),
        'Remote Config takes no more requests for now, 3 times: run the job '
        'again later. Remote Config says: Quota.',
      );
      expect(
        meaning(418, '<html>Teapot</html>'),
        'Remote Config answered with HTTP 418. Remote Config says: '
        '<html>Teapot</html>',
      );
    });
  });

  group('the file of the run', () {
    late Directory directory;

    setUp(() => directory = Directory.systemTemp.createTempSync('smf_rc_'));
    tearDown(() => directory.deleteSync(recursive: true));

    test(
        'has each parameter of the check that the run published once, and no '
        'other line', () {
      final file = File('${directory.path}/published');

      expect(publishedNamesIn(file), isEmpty);
      notePublished(file, request.parameter);
      notePublished(file, request.parameter);
      notePublished(file, _other('1'));
      file.writeAsStringSync('welcome_text\n', mode: FileMode.append);

      expect(file.readAsLinesSync(), [
        request.parameter,
        _other('1'),
        'welcome_text',
      ]);
      expect(publishedNamesIn(file), {request.parameter, _other('1')});
    });
  });

  group('the key of the service account', () {
    test('that is not the JSON key of a service account, without its text',
        () async {
      for (final key in [
        '{"private_key": "${_pem('PRIVATE KEY', 'SECRETPART')}',
        jsonEncode({'type': 'authorized_user', 'client_id': 'SECRETPART'}),
      ]) {
        await expectLater(
          clientOf(key),
          throwsA(
            isA<TemplateNotChanged>().having(
              (error) => error.meaning,
              'meaning',
              allOf(
                startsWith(
                  'The file in SMF_FIREBASE_SERVICE_ACCOUNT is not the JSON '
                  'key of a service account: ',
                ),
                isNot(contains('SECRETPART')),
              ),
            ),
          ),
          reason: key,
        );
      }
    });

    test(
        'gets an access token for the scope of Remote Config, with which the '
        'requests go, and no meaning has the token', () async {
      const token = 'an-access-token-of-the-test';
      final requests = <http.Request>[];
      final google = MockClient((sent) async {
        requests.add(sent);
        if (sent.url.host == 'oauth2.googleapis.com') {
          return http.Response(
            jsonEncode({
              'access_token': token,
              'token_type': 'Bearer',
              'expires_in': 3600,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          _error(403, 'PERMISSION_DENIED', 'Denied.'),
          403,
        );
      });

      final client = await clientOf(
        jsonEncode({
          'type': 'service_account',
          'client_id': '1',
          'client_email': 'ci@p.iam.gserviceaccount.com',
          'private_key': _keyThatParses(),
        }),
        baseClient: google,
      );
      Object? failure;
      try {
        await changeTemplate(
          client,
          project: 'p',
          change: (parameters) => parameters,
        );
      } on TemplateNotChanged catch (error) {
        failure = error;
      } finally {
        client.close();
      }

      final assertion =
          Uri.splitQueryString(requests.first.body)['assertion']!.split('.');
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(assertion[1]))),
      ) as Map<String, Object?>;
      expect(
        claims['scope'],
        'https://www.googleapis.com/auth/firebase.remoteconfig',
      );
      expect(requests.last.url, templateUriOf('p'));
      expect(requests.last.headers['authorization'], 'Bearer $token');
      expect('$failure', startsWith('The service account may not read'));
      expect('$failure', isNot(contains(token)));
    });

    test('that Google gives no access token for', () {
      expect(
        credentialsMeaningOf(
          ServerRequestFailedException(
            'Failed to obtain access credentials. Error: invalid_grant '
            'Invalid JWT Signature.',
            statusCode: 400,
            responseContent: const {'error': 'invalid_grant'},
          ),
        ),
        startsWith(
          'Google gives the service account of SMF_FIREBASE_SERVICE_ACCOUNT '
          'no access token (Failed to obtain access credentials. Error: '
          'invalid_grant Invalid JWT Signature.): its key was deleted or '
          'disabled',
        ),
      );
      expect(
        credentialsMeaningOf(const SocketException('Failed host lookup')),
        startsWith(
          'The access token of the service account of '
          'SMF_FIREBASE_SERVICE_ACCOUNT could not be asked for: ',
        ),
      );
      expect(
        credentialsMeaningOf(StateError('no')),
        'Google gives the service account of SMF_FIREBASE_SERVICE_ACCOUNT no '
        'access token: StateError.',
      );
    });
  });
}
