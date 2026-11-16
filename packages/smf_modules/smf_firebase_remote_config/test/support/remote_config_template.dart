/// What the tests that publish a value in Remote Config of the Firebase
/// project of CI, and remove it again, know of the REST API of Remote
/// Config: the request of the app, how a server changes the template of a
/// project with its ETag, which parameters are the check's, and what each
/// failure means. Nothing here reaches Google, so the tests of this file run
/// everywhere.
///
/// A change keeps every other parameter, condition and group of the
/// template as the API gave them, and touches only parameters whose name is
/// that of a parameter of the check, `remote_config_ci_` and a nonce of 32
/// hexadecimal digits. No text here has the access token of the service
/// account or a part of its key.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

/// The OAuth scope with which a service account reads and publishes the
/// template of Remote Config of a project.
const remoteConfigScope =
    'https://www.googleapis.com/auth/firebase.remoteconfig';

/// The template of Remote Config of the Firebase project [project].
Uri templateUriOf(String project) => Uri.https(
      'firebaseremoteconfig.googleapis.com',
      '/v1/projects/$project/remoteConfig',
    );

/// The name of a parameter of the check: `remote_config_ci_` and a nonce of
/// 32 hexadecimal digits. The tests change no other parameter.
final RegExp checkParameterName = RegExp(r'^remote_config_ci_[0-9a-f]{32}$');

/// The value that the check asks for: its nonce.
final RegExp _checkValue = RegExp(r'^[0-9a-f]{32}$');

/// The start of the description of a parameter of the check, which the time
/// of its publish follows, in UTC.
const descriptionPrefix = 'SMF start check, ';

/// How old a parameter of the check is when the tests remove it with those
/// of the run, as one that a job left when it was cancelled. A job publishes
/// its parameter minutes before it removes it.
const staleAfter = Duration(hours: 2);

/// The page of the Google Cloud console with the members of [project] and
/// their roles.
String _iamOf(String project) =>
    'https://console.cloud.google.com/iam-admin/iam?project=$project';

/// How many times [changeTemplate] sends a request after a quota, a server
/// that failed or a network that broke, in all.
const attempts = 3;

/// How many times [changeTemplate] publishes in all while the template
/// changes between its read and its publish.
const conflictAttempts = 5;

/// A value of remote config that the probe of the start check asks for, from
/// the request that it wrote: the name of a parameter of the check, and the
/// value, the nonce of the name.
final class ValueRequest {
  ValueRequest._(this.parameter, this.value);

  /// The request in [text], the JSON that the app wrote. Throws a
  /// [TemplateNotChanged] that tells what is wrong with it.
  factory ValueRequest.parse(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw const TemplateNotChanged('The request of the app is no JSON.');
    }
    return switch (json) {
      {'parameter': final String parameter, 'value': final String value}
          when checkParameterName.hasMatch(parameter) &&
              _checkValue.hasMatch(value) =>
        ValueRequest._(parameter, value),
      _ => throw const TemplateNotChanged(
          'The request of the app is not an object with a parameter whose '
          'name is remote_config_ci_ and 32 hexadecimal digits, and a value '
          'of 32 hexadecimal digits: the tests change no other parameter.',
        ),
    };
  }

  /// The name of the parameter of the check.
  final String parameter;

  /// The value to publish.
  final String value;
}

/// Remote Config did not take the change, or the test could not ask it to,
/// for the reason in [meaning], which has no secret.
final class TemplateNotChanged implements Exception {
  const TemplateNotChanged(this.meaning);

  /// Why, and what to do about it.
  final String meaning;

  @override
  String toString() => meaning;
}

/// An HTTP client that sends with an access token of the service account
/// whose JSON key is [key], for [remoteConfigScope], through [baseClient] if
/// it is given. Throws a [TemplateNotChanged] that tells why Google gives
/// none, without a part of the key.
Future<http.Client> clientOf(String key, {http.Client? baseClient}) async {
  final ServiceAccountCredentials credentials;
  try {
    credentials = ServiceAccountCredentials.fromJson(key);
  } on Object {
    // The error may quote a part of the key.
    throw const TemplateNotChanged(
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
      const [remoteConfigScope],
      baseClient: baseClient,
    );
  } on Object catch (error) {
    throw TemplateNotChanged(credentialsMeaningOf(error));
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

/// The description of a parameter of the check that is published at [time].
String descriptionAt(DateTime time) =>
    '$descriptionPrefix${time.toUtc().toIso8601String()}';

/// When the parameter [parameter] of the check, as the template has it, was
/// published, or `null` when it is no parameter of the check or its
/// description tells no time.
DateTime? _publishedAt(String name, Object? parameter) {
  if (!checkParameterName.hasMatch(name)) return null;
  if (parameter case {'description': final String description}
      when description.startsWith(descriptionPrefix)) {
    return DateTime.tryParse(description.substring(descriptionPrefix.length));
  }
  return null;
}

/// Whether the parameter [name], as the template has it in [parameter], is a
/// parameter of the check published more than [staleAfter] before [now].
bool isStale(String name, Object? parameter, DateTime now) {
  final published = _publishedAt(name, parameter);
  return published != null && now.difference(published) > staleAfter;
}

/// The parameters of a template with the parameter of [request], published
/// at [now] with its value, and without the stale parameters of the check.
/// A parameter of the request that is there already is published again with
/// the new time, so that Firebase tells the app of a new version again, as
/// when start_app.sh runs the answer again because no verdict came.
Map<String, Object?> withValue(
  Map<String, Object?> parameters,
  ValueRequest request,
  DateTime now,
) =>
    {
      for (final MapEntry(key: name, value: parameter) in parameters.entries)
        if (name != request.parameter && !isStale(name, parameter, now))
          name: parameter,
      request.parameter: {
        'defaultValue': {'value': request.value},
        'description': descriptionAt(now),
        'valueType': 'STRING',
      },
    };

/// The parameters of a template without the parameters of the check named
/// in [names] and without the stale ones, or `null` when the template has
/// none of them, so that nothing is published.
Map<String, Object?>? withoutValues(
  Map<String, Object?> parameters,
  Set<String> names,
  DateTime now,
) {
  bool goes(String name, Object? parameter) =>
      (names.contains(name) && checkParameterName.hasMatch(name)) ||
      isStale(name, parameter, now);
  if (!parameters.entries.any((entry) => goes(entry.key, entry.value))) {
    return null;
  }
  return {
    for (final MapEntry(key: name, value: parameter) in parameters.entries)
      if (!goes(name, parameter)) name: parameter,
  };
}

/// What [changeTemplate] does to the parameters of the template: the
/// parameters after the change, or `null` when nothing is to change.
typedef TemplateChange = Map<String, Object?>? Function(
  Map<String, Object?> parameters,
);

/// Changes the template of Remote Config of [project] through [client],
/// which sends with an access token for [remoteConfigScope]: reads it with
/// its ETag, gives its parameters to [change], and publishes the template
/// with the parameters that [change] returns, with `If-Match` and the ETag,
/// unless it returns `null`. Every other part of the template stays as the
/// API gave it. Returns the number of the version that it published, or
/// `null` when nothing was to change.
///
/// When the template changed between the read and the publish, as when
/// another job published meanwhile, it reads it again and changes it again,
/// [conflictAttempts] times in all, after a wait of [retryDelay] to four
/// times as long. After a quota, a server that failed or a network that
/// broke, it sends the request again after [retryDelay], twice as long the
/// next time, [attempts] times in all. Throws a [TemplateNotChanged] with
/// what the last failure means.
Future<String?> changeTemplate(
  http.Client client, {
  required String project,
  required TemplateChange change,
  Duration retryDelay = const Duration(seconds: 1),
  Random? random,
}) async {
  final jitter = random ?? Random();
  for (var conflict = 1;; conflict++) {
    final read = await _send(
      client,
      project: project,
      retryDelay: retryDelay,
      request: () => http.Request('GET', templateUriOf(project))
        ..headers['accept-encoding'] = 'gzip',
    );
    final template = switch (_jsonOf(read.body)) {
      final Map<String, Object?> template => template,
      _ => throw TemplateNotChanged(
          'Remote Config gave a template of the project $project that is no '
          'JSON object.',
        ),
    };
    final etag = read.headers['etag'];
    if (etag == null || etag.isEmpty) {
      throw TemplateNotChanged(
        'Remote Config gave the template of the project $project without its '
        'ETag, which a publish needs.',
      );
    }
    final parameters = switch (template['parameters']) {
      final Map<String, Object?> parameters => parameters,
      _ => const <String, Object?>{},
    };
    final changed = change(parameters);
    if (changed == null) return null;
    final published = {
      for (final MapEntry(:key, :value) in template.entries)
        // The version is the API's, but for its description.
        if (key != 'version') key: value,
      'parameters': changed,
      'version': {'description': 'SMF start check'},
    };
    final answer = await _send(
      client,
      project: project,
      retryDelay: retryDelay,
      conflictsFail: false,
      request: () => http.Request('PUT', templateUriOf(project))
        ..headers.addAll({
          'content-type': 'application/json; charset=utf-8',
          'if-match': etag,
          'accept-encoding': 'gzip',
        })
        ..body = jsonEncode(published),
    );
    if (answer.statusCode == 200) {
      return switch (_jsonOf(answer.body)) {
        {'version': {'versionNumber': final String number}} => number,
        _ => 'of no number',
      };
    }
    if (conflict >= conflictAttempts) {
      throw TemplateNotChanged(
        'The template of Remote Config of the project $project changed '
        'between each read and its publish, ${_times(conflictAttempts)}: '
        'other jobs publish in it at the same time. Run the job again. '
        'Remote Config says: ${_messageOf(answer.body)}',
      );
    }
    await Future<void>.delayed(
      retryDelay * (1 + jitter.nextInt(4)),
    );
  }
}

/// Sends the request that [request] makes through [client] and returns the
/// answer of Remote Config when it is a success, or, unless
/// [conflictsFail], a conflict of the version of the template. Sends it again
/// after a quota, a server that failed or a network that broke, [attempts]
/// times in all. Throws a [TemplateNotChanged] with what any other answer
/// means.
Future<http.Response> _send(
  http.Client client, {
  required String project,
  required http.Request Function() request,
  required Duration retryDelay,
  bool conflictsFail = true,
}) async {
  for (var attempt = 1;; attempt++) {
    final http.Response response;
    try {
      response = await http.Response.fromStream(await client.send(request()));
    } on Object catch (error) {
      if (error is! IOException && error is! http.ClientException) rethrow;
      if (attempt < attempts) {
        await Future<void>.delayed(retryDelay * attempt);
        continue;
      }
      throw TemplateNotChanged(
        'Remote Config could not be reached, ${_times(attempts)}: $error',
      );
    }
    if (response.statusCode == 200) return response;
    if (!conflictsFail && isVersionConflict(response)) return response;
    if (_sendAgain(response.statusCode) && attempt < attempts) {
      await Future<void>.delayed(retryDelay * attempt);
      continue;
    }
    throw TemplateNotChanged(
      meaningOf(
        project: project,
        status: response.statusCode,
        body: response.body,
        tries: attempt,
      ),
    );
  }
}

/// Whether a request is sent again after [status]: a quota, and a server
/// that failed or is busy.
bool _sendAgain(int status) => status == 429 || status >= 500;

/// Whether [response] tells that the template changed since it was read,
/// so that its ETag is no longer the one of the template: 409 or 412, or 400
/// with a message of a version or an ETag that does not match.
bool isVersionConflict(http.Response response) =>
    response.statusCode == 409 ||
    response.statusCode == 412 ||
    (response.statusCode == 400 &&
        RegExp(
          r'(etag|version)\b.{0,60}\b(mismatch|match|matches|stale|outdated)',
          caseSensitive: false,
        ).hasMatch(_messageOf(response.body)));

/// What it means that Remote Config answered a request about the template
/// of the project [project] with [status] and [body], the last of [tries],
/// and what to do about it.
///
/// Google tells an API that is not enabled and a permission that is denied
/// with an `ErrorInfo` among the details of the error.
String meaningOf({
  required String project,
  required int status,
  required String body,
  int tries = 1,
}) {
  final error = switch (_jsonOf(body)) {
    {'error': final Map<String, Object?> error} => error,
    _ => const <String, Object?>{},
  };
  final details = [
    if (error['details'] case final List<Object?> details)
      for (final detail in details)
        if (detail is Map<String, Object?>) detail,
  ];
  final info = [
    for (final detail in details)
      if (detail['@type'] == 'type.googleapis.com/google.rpc.ErrorInfo') detail,
  ].firstOrNull;
  final metadata = switch (info?['metadata']) {
    final Map<String, Object?> metadata => metadata,
    _ => const <String, Object?>{},
  };
  final says = 'Remote Config says: ${_messageOf(body)}';
  final permission = metadata['permission'] ??
      'cloudconfig.configs.get or cloudconfig.configs.update';
  final activation = metadata['activationUrl'] ??
      'https://console.cloud.google.com/apis/library/'
          'firebaseremoteconfig.googleapis.com?project=$project';
  return switch (status) {
    403 when info?['reason'] == 'SERVICE_DISABLED' =>
      'The Firebase Remote Config API (firebaseremoteconfig.googleapis.com) '
          'is not enabled in the project $project, or was enabled only a few '
          'minutes ago. Enable it at $activation and run the job again a few '
          'minutes later. $says',
    403 => 'The service account may not read or publish the template of '
        'Remote Config of the project $project (PERMISSION_DENIED): it lacks '
        '$permission, '
        'which the role Firebase Remote Config Admin or Firebase Admin grants '
        'at ${_iamOf(project)}. $says',
    401 => 'Remote Config does not take the access token of the service '
        'account (UNAUTHENTICATED). $says',
    404 => 'Remote Config has no project $project: SMF_FIREBASE_PROJECT names '
        'another project than the one of the key of the service account, or '
        'one that does not exist. $says',
    400 => 'Remote Config refuses the template of the project $project '
        '(INVALID_ARGUMENT). $says',
    429 => 'Remote Config takes no more requests for now, ${_times(tries)}: '
        'run the job again later. $says',
    >= 500 => 'Remote Config failed, ${_times(tries)}, with HTTP $status: '
        'run the job again later. $says',
    _ => 'Remote Config answered with HTTP $status. $says',
  };
}

/// The message of the error in [body], or the body itself.
String _messageOf(String body) => switch (_jsonOf(body)) {
      {'error': {'message': final String message}} when message.isNotEmpty =>
        message,
      _ => body.trim(),
    };

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

/// The names of the parameters of the check in the file of the run,
/// [file], one on each line: none when the file is not there.
Set<String> publishedNamesIn(File file) => file.existsSync()
    ? {
        for (final line in file.readAsLinesSync())
          if (checkParameterName.hasMatch(line.trim())) line.trim(),
      }
    : const {};

/// Notes [name], a parameter of the check, in the file of the run, [file],
/// unless it is there already, so that the step that removes the values of
/// the run finds it.
void notePublished(File file, String name) {
  if (publishedNamesIn(file).contains(name)) return;
  file
    ..createSync(recursive: true)
    ..writeAsStringSync('$name\n', mode: FileMode.append, flush: true);
}
