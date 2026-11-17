// The probe of the sentry module, which the start check runs on a device
// once the first screen of the app settled, the only place where the native
// side of Sentry runs, and which the tests of the module run too
// (probe_test.dart): Sentry is enabled exactly when the build of the app has
// a DSN of Sentry.
//
// It uses no test framework, and takes far less than a second. It also
// starts a check that outlives it and the start check, once in a run of a
// debug build of the app: whether an event that the reporter of the module
// sends reaches Sentry (checkDelivery). Only Sentry sees what arrived, so the
// check asks the script of CI that started the app,
// .github/scripts/start_app.sh of the repository of SMF, to answer once the
// start check passed, and the exit code of the answer is the verdict. The
// check reports an error with the reporter of the module, whose text has a
// nonce of its own, and writes a request, smf_start_request_sentry, into the
// temporary directory of the app: the id of the event in Sentry, the nonce
// and the environment of the event. The script copies the request and runs
// the command that it was given for sentry, a test of the module that asks
// the API of Sentry for that event in the project of CI. Without a DSN, or
// when Sentry did not start, the check writes its verdict instead,
// smf_start_report_sentry there: `failed: ` and the problem. A release build
// writes neither, since the script reads no file of one. Each file is
// written next to its place and renamed, so that it is there only whole.
// Neither file has the DSN.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:{{app_name}}/core/crash_reporting/sentry_crash_reporter.dart';
import 'package:{{app_name}}/core/env/app_env.dart';

/// The name of the exchange of the check of the event with start_app.sh, in
/// the names of its files and of the answer that the script is given.
const String exchangeName = 'sentry';

/// The check of the event that the probe started, if it started one.
Future<String?>? _delivery;

/// The probe of the start check: what is wrong with Sentry in the app as the
/// start-up left it. It also starts [checkDelivery] the first time, without
/// waiting for it. It waits for no screen, so it leaves [settle] out.
Future<List<String>> probeSentry(Future<void> Function() settle) async {
  _delivery ??= checkDelivery();
  return problemsOf(
      enabled: Sentry.isEnabled, hasDsn: AppEnv.sentryDsn != null);
}

/// What is wrong with Sentry, which is [enabled] or not, in a build that
/// [hasDsn] or not: Sentry runs exactly when the build has a DSN.
List<String> problemsOf({required bool enabled, required bool hasDsn}) => [
      if (enabled && !hasDsn)
        'Sentry is enabled, though the app has no SENTRY_DSN in this build.',
      if (!enabled && hasDsn)
        'The app has a SENTRY_DSN in this build, but Sentry is not enabled: '
            'initSentryCrashReporter() failed, as the log of a debug build '
            'tells.',
    ];

/// An error of the check, whose text has the [nonce] of its event.
final class SentryStartCheck implements Exception {
  /// Creates the error of the event with [nonce].
  const SentryStartCheck(this.nonce);

  /// The nonce of the event of the check.
  final String nonce;

  @override
  String toString() =>
      'SentryStartCheck: the start check of the app sent this event ($nonce).';
}

/// Checks that an event of the reporter of the module reaches Sentry, with
/// start_app.sh and the API of Sentry as its server: reports a
/// [SentryStartCheck] with a new nonce through `SentryCrashReporter`, as an
/// error that the code of the app caught, and writes the request of the
/// check into [directory], the temporary directory of the app unless a test
/// gives another. Returns what it wrote: the request, or the verdict
/// `failed: ` and the problem when the app has no DSN or Sentry did not
/// start, which it writes in place of a request.
///
/// A [release] build writes nothing and returns `null`, since the script of
/// CI reads no file of one.
Future<String?> checkDelivery({
  Directory? directory,
  bool release = kReleaseMode,
}) async {
  if (release) return null;
  final files = directory ?? Directory.systemTemp;
  String? problem;
  String? request;
  try {
    if (AppEnv.sentryDsn == null) {
      problem = 'SENTRY_DSN has no value in this build, so no event reaches '
          'Sentry: give .env of the app the DSN of the Sentry project of CI.';
    } else if (!Sentry.isEnabled) {
      problem = 'Sentry did not start with the SENTRY_DSN of this build, so no '
          'event reaches it: initSentryCrashReporter() failed, as the log of '
          'the app tells.';
    } else {
      final nonce = _nonce();
      await const SentryCrashReporter().recordError(
        SentryStartCheck(nonce),
        StackTrace.current,
      );
      final eventId = Sentry.lastEventId;
      if (eventId == const SentryId.empty()) {
        problem = 'Sentry gave the event of the check no id, so it did not '
            'send it.';
      } else {
        request = jsonEncode({
          'eventId': '$eventId',
          'nonce': nonce,
          'environment': appFlavor ?? '{{default_flavor}}',
        });
      }
    }
  } on Object catch (error) {
    problem = 'the check threw ${'$error'.trim().split('\n').first}';
  }
  try {
    if (request != null) {
      _write(files, 'smf_start_request_$exchangeName', request);
      debugPrint('The check of Sentry sent its event and asked for the check '
          'of it: $request');
      return request;
    }
    final verdict = 'failed: $problem';
    _write(files, 'smf_start_report_$exchangeName', verdict);
    debugPrint('The check of Sentry $verdict');
    return verdict;
  } on Object catch (error) {
    debugPrint('The check of Sentry wrote nothing: $error');
    return null;
  }
}

/// 32 random hexadecimal digits.
String _nonce() {
  final random = Random.secure();
  return [
    for (var i = 0; i < 16; i++)
      random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}

/// Writes [text] as one line into the file [name] in [directory], next to
/// it first and then renamed, so that the file is there only whole.
void _write(Directory directory, String name, String text) {
  final file = File('${directory.path}/$name');
  File('${file.path}.part')
    ..writeAsStringSync('$text\n', flush: true)
    ..renameSync(file.path);
}
