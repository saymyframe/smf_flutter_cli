/// What the test that sends a push message to the app that CI starts knows
/// of Firebase Cloud Messaging: the request of the app, how a server sends
/// a message with the HTTP v1 API of Firebase Cloud Messaging, and what
/// each failure means. Nothing here reaches Google, so the tests of this
/// file run everywhere.
///
/// The request has the address of the device, which is for the backend of
/// the app alone, so no text here has it: a text from Google that names it
/// gets a placeholder in its place.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

/// The OAuth scope with which a service account sends messages through
/// Firebase Cloud Messaging.
const fcmScope = 'https://www.googleapis.com/auth/firebase.messaging';

/// Where a server sends a message to a device of an app of the Firebase
/// project [project].
Uri sendUriOf(String project) =>
    Uri.https('fcm.googleapis.com', '/v1/projects/$project/messages:send');

/// The page of the Google Cloud console with the members of [project] and
/// their roles.
String _iamOf(String project) =>
    'https://console.cloud.google.com/iam-admin/iam?project=$project';

/// What a text from Google has in place of the address of the device.
const _placeholder = '<the address of the device>';

/// The answers of Firebase Cloud Messaging after which a server sends the
/// message again: a quota, and a server that failed or is busy.
const _sendAgain = {429, 500, 503};

/// How many times [send] sends a message in all.
const attempts = 3;

/// A push message that the probe of the start check asks for, from the
/// request that it wrote: the address of the device, and the title, the
/// text and the data of the message.
final class PushRequest {
  PushRequest._(this.address, this.title, this.body, this.data);

  /// The request in [text], the JSON that the app wrote. Throws a
  /// [PushNotSent] that tells what the request lacks, without the address.
  factory PushRequest.parse(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw const PushNotSent('The request of the app is no JSON.');
    }
    return switch (json) {
      {
        'address': final String address,
        'title': final String title,
        'body': final String body,
        'data': final Map<String, Object?> data,
      }
          when address.isNotEmpty &&
              data.values.every((value) => value is String) =>
        PushRequest._(address, title, body, data.cast<String, String>()),
      _ => throw const PushNotSent(
          'The request of the app is not an object with an address that is '
          'not empty, a title and a body that are texts, and data whose '
          'values are texts.',
        ),
    };
  }

  /// The address of the device, the registration token of Firebase Cloud
  /// Messaging there.
  final String address;

  /// The title and the text of the notification of the message.
  final String title;
  final String body;

  /// The data of the message, which the app reads.
  final Map<String, String> data;

  /// The body of the request to [sendUriOf]: a message to the device with a
  /// notification and data.
  Map<String, Object?> get message => {
        'message': {
          'token': address,
          'notification': {'title': title, 'body': body},
          'data': data,
        },
      };

  /// [text] with [_placeholder] in place of the address.
  String withoutAddress(String text) => text.replaceAll(address, _placeholder);
}

/// Firebase Cloud Messaging did not take the message, or the test could not
/// ask it to, for the reason in [meaning], which has no secret.
final class PushNotSent implements Exception {
  const PushNotSent(this.meaning);

  /// Why, and what to do about it.
  final String meaning;

  @override
  String toString() => meaning;
}

/// An HTTP client that sends with an access token of the service account
/// whose JSON key is [key], for [fcmScope], through [baseClient] if it is
/// given. Throws a [PushNotSent] that tells why Google gives none, without
/// a part of the key.
Future<http.Client> clientOf(String key, {http.Client? baseClient}) async {
  final ServiceAccountCredentials credentials;
  try {
    credentials = ServiceAccountCredentials.fromJson(key);
  } on Object {
    // The error may quote a part of the key.
    throw const PushNotSent(
      'The file in SMF_FIREBASE_SERVICE_ACCOUNT is not the JSON key of a '
      'service account: one with the type service_account, client_email, '
      'client_id and private_key, an RSA key in PEM. Create a key of the '
      'service account in the Google Cloud console (IAM & Admin, Service '
      'accounts, Keys) and keep it whole in the secret '
      'FIREBASE_SERVICE_ACCOUNT.',
    );
  }
  try {
    return await clientViaServiceAccount(
      credentials,
      const [fcmScope],
      baseClient: baseClient,
    );
  } on Object catch (error) {
    throw PushNotSent(credentialsMeaningOf(error));
  }
}

/// Why Google gave the service account no access token, from the [error]
/// of googleapis_auth.
String credentialsMeaningOf(Object error) {
  const create = 'Create a new key of the service account in the Google '
      'Cloud console (IAM & Admin, Service accounts, Keys) and keep it in '
      'the secret FIREBASE_SERVICE_ACCOUNT.';
  return switch (error) {
    ServerRequestFailedException(:final message)
        when message.contains('invalid_grant') =>
      'Google gives the service account of SMF_FIREBASE_SERVICE_ACCOUNT no '
          'access token ($message): its key was deleted or disabled, the '
          'service account was, or the clock of this machine is wrong. '
          '$create',
    ServerRequestFailedException(:final message) =>
      'Google gives the service account of SMF_FIREBASE_SERVICE_ACCOUNT no '
          'access token: $message',
    IOException() ||
    http.ClientException() =>
      'The access token of the service account of '
          'SMF_FIREBASE_SERVICE_ACCOUNT could not be asked for: $error',
    _ => 'Google gives the service account of SMF_FIREBASE_SERVICE_ACCOUNT '
        'no access token: ${error.runtimeType}.',
  };
}

/// Sends the message of [request] to its device through [client], which
/// sends with an access token for [fcmScope], in the Firebase project
/// [project], and returns the name that Firebase Cloud Messaging gave the
/// message. Sends it again after [retryDelay], twice as long the next time,
/// when Firebase Cloud Messaging answers with a quota or a server that
/// failed, or cannot be reached, [attempts] times in all. Throws a
/// [PushNotSent] with what the last failure means.
Future<String> send(
  http.Client client, {
  required String project,
  required PushRequest request,
  Duration retryDelay = const Duration(seconds: 5),
}) async {
  for (var attempt = 1;; attempt++) {
    final http.Response response;
    try {
      response = await client.post(
        sendUriOf(project),
        headers: {'content-type': 'application/json; charset=utf-8'},
        body: jsonEncode(request.message),
      );
    } on Object catch (error) {
      if (error is! IOException && error is! http.ClientException) rethrow;
      if (attempt < attempts) {
        await Future<void>.delayed(retryDelay * attempt);
        continue;
      }
      throw PushNotSent(
        'Firebase Cloud Messaging could not be reached, ${_times(attempts)}: '
        '${request.withoutAddress('$error')}',
      );
    }
    if (response.statusCode == 200) {
      return switch (_jsonOf(response.body)) {
        {'name': final String name} => name,
        _ => 'a message without a name',
      };
    }
    if (_sendAgain.contains(response.statusCode) && attempt < attempts) {
      await Future<void>.delayed(retryDelay * attempt);
      continue;
    }
    throw PushNotSent(
      meaningOf(
        project: project,
        status: response.statusCode,
        body: response.body,
        request: request,
        tries: attempt,
      ),
    );
  }
}

/// What it means that Firebase Cloud Messaging answered the message of
/// [request] in the Firebase project [project] with [status] and [body],
/// the last of [tries], and what to do about it.
///
/// Firebase Cloud Messaging tells its own failures with an `FcmError` among
/// the details of the error, and Google tells an API that is not enabled
/// and a permission that is denied with an `ErrorInfo` there.
String meaningOf({
  required String project,
  required int status,
  required String body,
  required PushRequest request,
  int tries = 1,
}) {
  final error = switch (_jsonOf(body)) {
    {'error': final Map<String, Object?> error} => error,
    _ => const <String, Object?>{},
  };
  final message = request.withoutAddress(
    switch (error['message']) {
      final String message when message.isNotEmpty => message,
      _ => body.trim(),
    },
  );
  final details = [
    if (error['details'] case final List<Object?> details)
      for (final detail in details)
        if (detail is Map<String, Object?>) detail,
  ];
  Map<String, Object?>? detailOf(String type) => [
        for (final detail in details)
          if (detail['@type'] == 'type.googleapis.com/$type') detail,
      ].firstOrNull;
  final fcm = detailOf('google.firebase.fcm.v1.FcmError')?['errorCode'];
  final info = detailOf('google.rpc.ErrorInfo');
  final metadata = switch (info?['metadata']) {
    final Map<String, Object?> metadata => metadata,
    _ => const <String, Object?>{},
  };
  final says = 'Firebase Cloud Messaging says: $message';
  final activation = metadata['activationUrl'] ??
      'https://console.cloud.google.com/apis/library/fcm.googleapis.com'
          '?project=$project';
  return switch ((fcm, info?['reason'])) {
    (_, 'SERVICE_DISABLED') =>
      'The Firebase Cloud Messaging API (fcm.googleapis.com) is not enabled '
          'in the project $project, or was enabled only a few minutes ago. '
          'Enable it at $activation and run the job again a few minutes '
          'later. $says',
    ('SENDER_ID_MISMATCH', _) =>
      'The address of the device belongs to another Firebase project than '
          '$project (SENDER_ID_MISMATCH): flutterfire configured the app for '
          'another project, or SMF_FIREBASE_PROJECT names another one. $says',
    ('UNREGISTERED', _) =>
      'Firebase Cloud Messaging knows the address of the device no more '
          '(UNREGISTERED): the app was removed from the device, or the '
          'device got a new address. $says',
    ('INVALID_ARGUMENT', _) =>
      'Firebase Cloud Messaging takes the message as invalid '
          '(INVALID_ARGUMENT): the address of the device is not one of '
          'Firebase Cloud Messaging, or the message is malformed. $says',
    ('THIRD_PARTY_AUTH_ERROR', _) =>
      'Firebase Cloud Messaging cannot send to the Apple Push Notification '
          'service for the app (THIRD_PARTY_AUTH_ERROR): the project $project '
          'has no valid key of that service for the app, which its Project '
          'settings take in Cloud Messaging, Apple app configuration. $says',
    ('QUOTA_EXCEEDED', _) =>
      'Firebase Cloud Messaging takes no more messages for now '
          '(QUOTA_EXCEEDED), ${_times(tries)}: the project or the device '
          'sent too many. $says',
    _ when status == 403 =>
      'The service account may not send messages in the project $project '
          '(PERMISSION_DENIED): it lacks the permission '
          '${metadata['permission'] ?? 'cloudmessaging.messages.create'}, '
          'which the role Firebase Cloud Messaging Admin or Firebase Admin '
          'grants at ${_iamOf(project)}. $says',
    _ when status == 401 =>
      'Firebase Cloud Messaging does not take the access token of the '
          'service account (UNAUTHENTICATED). $says',
    _ when status >= 500 =>
      'Firebase Cloud Messaging failed to take the message, '
          '${_times(tries)}, with HTTP $status: run the job again later. '
          '$says',
    _ => 'Firebase Cloud Messaging answered the message with HTTP $status'
        '${fcm is String ? ' ($fcm)' : ''}. $says',
  };
}

/// How many times something happened: [count] times, or once.
String _times(int count) => count == 1 ? 'once' : '$count times';

/// What the JSON [text] holds, or `null` if it is no JSON.
Object? _jsonOf(String text) {
  try {
    return jsonDecode(text);
  } on FormatException {
    return null;
  }
}
