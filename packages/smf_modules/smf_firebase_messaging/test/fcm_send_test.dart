// What the test that sends a push message to the app that CI starts
// (push_delivery_test.dart) knows of Firebase Cloud Messaging, without
// Google: the request of the app, the message that it sends, when it sends
// again, and what each failure means, never with the address of the device
// or a part of the key of the service account.
import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'support/fcm_send.dart';

/// An address of a device, which no text of a failure may have.
const _address = 'the-address-of-the-device:APA91b';

/// The request of the probe of the start check, as the app writes it.
final String _asked = jsonEncode({
  'address': _address,
  'title': 'SMF start check',
  'body': 'A push message that the start check asked for.',
  'data': {'smf_start_nonce': '0123'},
});

/// The answer of Google to a failure with [status], [code], [message] and
/// [details], as the HTTP v1 API of Firebase Cloud Messaging writes it.
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

Map<String, Object?> _fcmError(String code) => {
      '@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError',
      'errorCode': code,
    };

Map<String, Object?> _info(String reason, Map<String, String> metadata) => {
      '@type': 'type.googleapis.com/google.rpc.ErrorInfo',
      'reason': reason,
      'domain': 'googleapis.com',
      'metadata': metadata,
    };

void main() {
  final request = PushRequest.parse(_asked);

  group('PushRequest', () {
    test('takes the address, the title, the text and the data of the app', () {
      expect(request.address, _address);
      expect(request.message, {
        'message': {
          'token': _address,
          'notification': {
            'title': 'SMF start check',
            'body': 'A push message that the start check asked for.',
          },
          'data': {'smf_start_nonce': '0123'},
        },
      });
    });

    test(
        'refuses a request that is not what the app writes, without its '
        'address', () {
      for (final text in [
        '$_address {',
        jsonEncode({'address': _address, 'title': 'T', 'body': 'B'}),
        jsonEncode({
          'address': '',
          'title': 'T',
          'body': 'B',
          'data': <String, String>{},
        }),
        jsonEncode({
          'address': _address,
          'title': 'T',
          'body': 'B',
          'data': {'count': 1},
        }),
        jsonEncode([_address]),
      ]) {
        expect(
          () => PushRequest.parse(text),
          throwsA(
            isA<PushNotSent>().having(
              (error) => error.meaning,
              'meaning',
              allOf(
                startsWith('The request of the app is '),
                isNot(contains(_address)),
              ),
            ),
          ),
          reason: text,
        );
      }
    });
  });

  group('send', () {
    test('posts the message to the project and returns its name', () async {
      final requests = <http.Request>[];
      final client = MockClient((sent) async {
        requests.add(sent);
        return http.Response(
          '{"name": "projects/a-project/messages/0:1"}',
          200,
        );
      });

      final name = await send(client, project: 'a-project', request: request);

      expect(name, 'projects/a-project/messages/0:1');
      expect(requests, hasLength(1));
      expect(
        requests.single.url,
        Uri.parse(
          'https://fcm.googleapis.com/v1/projects/a-project/messages:send',
        ),
      );
      expect(requests.single.method, 'POST');
      expect(
        requests.single.headers['content-type'],
        startsWith('application/json'),
      );
      expect(jsonDecode(requests.single.body), request.message);
    });

    test(
        'sends again after a quota, a server that failed or a network that '
        'broke, three times in all', () async {
      var sent = 0;
      final answers = [
        () => http.Response(_error(503, 'UNAVAILABLE', 'Busy.'), 503),
        () => throw http.ClientException('Connection reset'),
        () => http.Response('{"name": "projects/p/messages/2"}', 200),
      ];
      final client = MockClient((_) async => answers[sent++]());

      final name = await send(
        client,
        project: 'p',
        request: request,
        retryDelay: Duration.zero,
      );

      expect(name, 'projects/p/messages/2');
      expect(sent, 3);
    });

    test('tells what the last failure means once it sent three times',
        () async {
      var sent = 0;
      final client = MockClient((_) async {
        sent++;
        return http.Response(
          _error(500, 'INTERNAL', 'Internal error encountered.', [
            _fcmError('INTERNAL'),
          ]),
          500,
        );
      });
      final unreachable = MockClient(
        (_) async =>
            throw const SocketException('Failed host lookup: $_address'),
      );

      final failed = send(
        client,
        project: 'p',
        request: request,
        retryDelay: Duration.zero,
      );
      await expectLater(
        failed,
        throwsA(
          isA<PushNotSent>().having(
            (error) => error.meaning,
            'meaning',
            'Firebase Cloud Messaging failed to take the message, 3 times, '
                'with HTTP 500: run the job again later. Firebase Cloud '
                'Messaging says: Internal error encountered.',
          ),
        ),
      );
      expect(sent, 3);
      await expectLater(
        send(
          unreachable,
          project: 'p',
          request: request,
          retryDelay: Duration.zero,
        ),
        throwsA(
          isA<PushNotSent>().having(
            (error) => error.meaning,
            'meaning',
            allOf(
              startsWith(
                'Firebase Cloud Messaging could not be reached, 3 times: ',
              ),
              contains('<the address of the device>'),
              isNot(contains(_address)),
            ),
          ),
        ),
      );
    });

    test('does not send again a message that Firebase refuses', () async {
      var sent = 0;
      final client = MockClient((_) async {
        sent++;
        return http.Response(
          _error(404, 'NOT_FOUND', 'Requested entity was not found.', [
            _fcmError('UNREGISTERED'),
          ]),
          404,
        );
      });

      await expectLater(
        send(client, project: 'p', request: request),
        throwsA(isA<PushNotSent>()),
      );
      expect(sent, 1);
    });
  });

  group('meaningOf', () {
    String meaning(int status, String body) => meaningOf(
          project: 'saymyframe-app-cli',
          status: status,
          body: body,
          request: request,
        );

    test('tells of an API that is not enabled, with its page', () {
      expect(
        meaning(
          403,
          _error(
            403,
            'PERMISSION_DENIED',
            'Firebase Cloud Messaging API has not been used in project 1 '
                'before or it is disabled.',
            [
              _info('SERVICE_DISABLED', {
                'service': 'fcm.googleapis.com',
                'activationUrl': 'https://console.developers.google.com/apis/'
                    'api/fcm.googleapis.com/overview?project=1',
              }),
            ],
          ),
        ),
        startsWith(
          'The Firebase Cloud Messaging API (fcm.googleapis.com) is not '
          'enabled in the project saymyframe-app-cli, or was enabled only a '
          'few minutes ago. Enable it at '
          'https://console.developers.google.com/apis/api/fcm.googleapis.com/'
          'overview?project=1 and run the job '
          'again a few minutes later. Firebase Cloud Messaging says: ',
        ),
      );
    });

    test(
        'tells of a permission that the service account lacks, with the roles '
        'that grant it', () {
      final denied = meaning(
        403,
        _error(
          403,
          'PERMISSION_DENIED',
          "Permission 'cloudmessaging.messages.create' denied on resource "
              "'//cloudresourcemanager.googleapis.com/projects/"
              "saymyframe-app-cli' (or it may not exist).",
          [
            _info('IAM_PERMISSION_DENIED', {
              'permission': 'cloudmessaging.messages.create',
            }),
          ],
        ),
      );
      final withoutDetails = meaning(403, _error(403, 'PERMISSION_DENIED', ''));

      expect(
        denied,
        startsWith(
          'The service account may not send messages in the project '
          'saymyframe-app-cli (PERMISSION_DENIED): it lacks the permission '
          'cloudmessaging.messages.create, which the role Firebase Cloud '
          'Messaging Admin or Firebase Admin grants at '
          'https://console.cloud.google.com/iam-admin/iam?project='
          'saymyframe-app-cli. Firebase Cloud Messaging says: Permission ',
        ),
      );
      expect(
        withoutDetails,
        contains('it lacks the permission cloudmessaging.messages.create,'),
      );
    });

    test(
        'tells of each failure of Firebase Cloud Messaging, with what it says '
        'without the address', () {
      String failure(int status, String code, String fcm) => meaning(
            status,
            _error(
              status,
              code,
              'The registration token $_address is not valid.',
              [_fcmError(fcm)],
            ),
          );

      final meanings = {
        'SENDER_ID_MISMATCH':
            failure(403, 'PERMISSION_DENIED', 'SENDER_ID_MISMATCH'),
        'UNREGISTERED': failure(404, 'NOT_FOUND', 'UNREGISTERED'),
        'INVALID_ARGUMENT':
            failure(400, 'INVALID_ARGUMENT', 'INVALID_ARGUMENT'),
        'THIRD_PARTY_AUTH_ERROR':
            failure(401, 'UNAUTHENTICATED', 'THIRD_PARTY_AUTH_ERROR'),
        'QUOTA_EXCEEDED': failure(429, 'RESOURCE_EXHAUSTED', 'QUOTA_EXCEEDED'),
      };

      expect(
        meanings['SENDER_ID_MISMATCH'],
        startsWith(
          'The address of the device belongs to another Firebase project '
          'than saymyframe-app-cli (SENDER_ID_MISMATCH): flutterfire '
          'configured the app for another project, or SMF_FIREBASE_PROJECT '
          'names another one.',
        ),
      );
      expect(
        meanings['UNREGISTERED'],
        startsWith(
          'Firebase Cloud Messaging knows the address of the device no more '
          '(UNREGISTERED): the app was removed from the device, or the '
          'device got a new address.',
        ),
      );
      expect(
        meanings['INVALID_ARGUMENT'],
        startsWith(
          'Firebase Cloud Messaging takes the message as invalid '
          '(INVALID_ARGUMENT): the address of the device is not one of '
          'Firebase Cloud Messaging, or the message is malformed.',
        ),
      );
      expect(
        meanings['THIRD_PARTY_AUTH_ERROR'],
        startsWith(
          'Firebase Cloud Messaging cannot send to the Apple Push '
          'Notification service for the app (THIRD_PARTY_AUTH_ERROR): the '
          'project saymyframe-app-cli has no valid key of that service for '
          'the app,',
        ),
      );
      expect(
        meanings['QUOTA_EXCEEDED'],
        startsWith(
          'Firebase Cloud Messaging takes no more messages for now '
          '(QUOTA_EXCEEDED), once:',
        ),
      );
      for (final MapEntry(:key, :value) in meanings.entries) {
        expect(
          value,
          endsWith(
            'Firebase Cloud Messaging says: The registration token <the '
            'address of the device> is not valid.',
          ),
          reason: key,
        );
      }
    });

    test(
        'tells of an access token that Firebase Cloud Messaging does not '
        'take, and of any other answer', () {
      expect(
        meaning(
          401,
          _error(
            401,
            'UNAUTHENTICATED',
            'Request had invalid authentication credentials.',
          ),
        ),
        'Firebase Cloud Messaging does not take the access token of the '
        'service account (UNAUTHENTICATED). Firebase Cloud Messaging says: '
        'Request had invalid authentication credentials.',
      );
      expect(
        meaning(502, '<html>Bad gateway for $_address</html>'),
        'Firebase Cloud Messaging failed to take the message, once, with '
        'HTTP 502: run the job again later. Firebase Cloud Messaging says: '
        '<html>Bad gateway for <the address of the device></html>',
      );
      expect(
        meaning(
          404,
          _error(404, 'NOT_FOUND', 'Requested entity was not found.', [
            _fcmError('UNSPECIFIED_ERROR'),
          ]),
        ),
        'Firebase Cloud Messaging answered the message with HTTP 404 '
        '(UNSPECIFIED_ERROR). Firebase Cloud Messaging says: Requested '
        'entity was not found.',
      );
    });
  });

  group('the key of the service account', () {
    test('that is not the JSON key of a service account, without its text',
        () async {
      for (final key in [
        '{"private_key": "-----BEGIN PRIVATE KEY-----\nSECRETPART',
        jsonEncode({'type': 'authorized_user', 'client_id': 'SECRETPART'}),
        jsonEncode({
          'type': 'service_account',
          'client_id': '1',
          'client_email': 'ci@p.iam.gserviceaccount.com',
          'private_key': '-----BEGIN PRIVATE KEY-----\n'
              'SECRETPART\n-----END PRIVATE KEY-----\n',
        }),
      ]) {
        await expectLater(
          clientOf(key),
          throwsA(
            isA<PushNotSent>().having(
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
        'Google gives the service account of SMF_FIREBASE_SERVICE_ACCOUNT no '
        'access token (Failed to obtain access credentials. Error: '
        'invalid_grant Invalid JWT Signature.): its key was deleted or '
        'disabled, the service account was, or the clock of this machine is '
        'wrong. Create a new key of the service account in the Google Cloud '
        'console (IAM & Admin, Service accounts, Keys) and keep it in the '
        'secret FIREBASE_SERVICE_ACCOUNT.',
      );
      expect(
        credentialsMeaningOf(
          ServerRequestFailedException(
            'Failed to obtain access credentials. Error: unauthorized_client',
            statusCode: 401,
            responseContent: null,
          ),
        ),
        'Google gives the service account of SMF_FIREBASE_SERVICE_ACCOUNT no '
        'access token: Failed to obtain access credentials. Error: '
        'unauthorized_client',
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
