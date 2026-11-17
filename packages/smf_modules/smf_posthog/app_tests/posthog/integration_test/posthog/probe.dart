// The probe of the posthog module, which the start check runs on a device
// once the first screen of the app settled, the only place where the native
// side of PostHog runs, and which the tests of the module run too
// (probe_test.dart): PostHog started exactly when the build of the app has a
// project token, its SDK has the setting of collection that the app starts
// with on a new install, and it has a distinct id for the user of the
// device. It reads PostHog twice at once, and each read waits at most a
// second, so the probe takes little more than a second at worst.
//
// It uses no test framework. It also starts a check that outlives it and the
// start check, once in a run of a debug build of the app: whether an event
// that the analytics service of the module records reaches PostHog
// (checkDelivery). Only PostHog sees what arrived, so the check asks the
// script of CI that started the app, .github/scripts/start_app.sh of the
// repository of SMF, to answer once the start check passed, and the exit code
// of the answer is the verdict. The check records the event
// smf_start_check with a nonce of its own in its property smf_check, has
// PostHog send it at once, rather than with the next batch, which leaves
// after 30 seconds, and writes a request, smf_start_request_posthog, into the
// temporary directory of the app: the nonce, the distinct id of the user of
// the device and the flavor of the build. The script copies the request and
// runs the command that it was given for posthog, a test of the module that
// asks the query API of PostHog for that event in the project of CI. Without
// a project token, when PostHog did not start, while it collects nothing or
// when PostHog does not answer one of its calls within a second, the check
// writes its verdict instead, smf_start_report_posthog there: `failed: `
// and the problem. So it never waits for PostHog for good, and the script
// gets a request or a verdict. A release build writes neither, since the
// script reads no file of one. Each file is written next to its place and
// renamed, so that it is there only whole. Neither file has the token.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:{{app_name}}/core/analytics/analytics_service.dart';
import 'package:{{app_name}}/core/analytics/posthog_analytics_service.dart';
import 'package:{{app_name}}/core/env/app_env.dart';

/// The name of the exchange of the check of the event with start_app.sh, in
/// the names of its files and of the answer that the script is given.
const String exchangeName = 'posthog';

/// How long the probe, and the check that it starts, wait for each answer
/// of PostHog.
const Duration readWait = Duration(seconds: 1);

/// The check of the event that the probe started, if it started one.
Future<String?>? _delivery;

/// Where the check that the probe starts writes its files: the temporary
/// directory of the app, which start_app.sh reads, unless a test gives
/// another.
Directory? exchangeDirectory;

/// The probe of the start check: what is wrong with PostHog in the app as
/// the start-up left it. It also starts [checkDelivery] the first time,
/// without waiting for it. It waits for no screen, so it leaves [settle]
/// out.
Future<List<String>> probePostHog(Future<void> Function() settle) async {
  _delivery ??= checkDelivery();
  final hasToken = AppEnv.posthogProjectToken != null;
  if (!postHogStarted) return problemsOf(started: false, hasToken: hasToken);
  final problems = <String>[];
  // Both at once, so that the probe waits at most a second.
  final (optOut, distinctId) = await (
    _read('whether it is opted out', Posthog().isOptOut, problems),
    _read('the distinct id', Posthog().getDistinctId, problems),
  ).wait;
  return [
    ...problemsOf(
      started: true,
      hasToken: hasToken,
      optOut: optOut,
      distinctId: distinctId,
    ),
    ...problems,
  ];
}

/// [read] of PostHog, or `null` with a problem in [problems] when PostHog
/// does not answer within [readWait] or fails.
Future<T?> _read<T>(
  String what,
  Future<T> Function() read,
  List<String> problems,
) async {
  try {
    return await read().timeout(readWait);
  } on TimeoutException {
    problems.add('PostHog did not tell $what within a second.');
  } on Object catch (error) {
    problems.add(
      'PostHog failed to tell $what: '
      '${'$error'.trim().split('\n').first}',
    );
  }
  return null;
}

/// What is wrong with PostHog, which [started] or not, in a build that
/// [hasToken] or not: PostHog runs exactly when the build has a project
/// token. Once it started, it is opted out, [optOut], exactly when the app
/// collects nothing from its first start, since CI starts a new install, on
/// which the code never chose, and it has a [distinctId] for the user of the
/// device. A read that PostHog did not answer is `null`, which the probe
/// reports on its own.
List<String> problemsOf({
  required bool started,
  required bool hasToken,
  bool? optOut,
  String? distinctId,
}) =>
    [
      if (started && !hasToken)
        'PostHog started, though the app has no POSTHOG_PROJECT_TOKEN in this '
            'build.',
      if (!started && hasToken)
        'The app has a POSTHOG_PROJECT_TOKEN in this build, but PostHog did '
            'not start: initPostHogAnalytics() failed, as the log of a debug '
            'build tells.',
      if (started &&
          optOut != null &&
          optOut == analyticsCollectedFromFirstStart)
        optOut
            ? 'PostHog is opted out, though the app collects from its first '
                'start and the code never chose on a new install.'
            : 'PostHog is opted in, though the app collects nothing before '
                'its code chose: the default of the app did not reach the SDK '
                'of PostHog.',
      if (started && distinctId != null && distinctId.isEmpty)
        'PostHog has no distinct id for the user of the device.',
    ];

/// Checks that an event of the analytics service of the module reaches
/// PostHog, with start_app.sh and the query API of PostHog as its server:
/// records the event `smf_start_check` with a new nonce through
/// `PostHogAnalyticsService`, has PostHog send it at once, and writes the
/// request of the check into [directory], or into [exchangeDirectory]
/// without one. Returns what it wrote: the request, or the verdict
/// `failed: ` and the problem when the app has no project token, PostHog did
/// not start, it collects nothing or it did not answer a call of the check
/// within [readWait], which it writes in place of a request.
///
/// A [release] build writes nothing and returns `null`, since the script of
/// CI reads no file of one.
Future<String?> checkDelivery({
  Directory? directory,
  bool release = kReleaseMode,
}) async {
  if (release) return null;
  final files = directory ?? exchangeDirectory ?? Directory.systemTemp;
  String? problem;
  String? request;
  try {
    if (AppEnv.posthogProjectToken == null) {
      problem = 'POSTHOG_PROJECT_TOKEN has no value in this build, so no event '
          'reaches PostHog: give .env of the app the project token of the '
          'PostHog project of CI.';
    } else if (!postHogStarted) {
      problem = 'PostHog did not start with the POSTHOG_PROJECT_TOKEN of this '
          'build, so no event reaches it: initPostHogAnalytics() failed, as '
          'the log of the app tells.';
    } else if (await _answer(
        'whether it is opted out', () => Posthog().isOptOut())) {
      problem = 'PostHog collects nothing on this device, so the event of the '
          'check would reach nobody: the app collects nothing before its code '
          'chose, or its code turned collection off.';
    } else {
      final nonce = _nonce();
      await _answer(
        'it to record the event',
        () => const PostHogAnalyticsService()
            .logEvent('smf_start_check', parameters: {'smf_check': nonce}),
      );
      await _answer('it to send the event at once', () => Posthog().flush());
      final distinctId = await _answer(
        'for the distinct id of the user',
        () => Posthog().getDistinctId(),
      );
      if (distinctId.isEmpty) {
        problem = 'PostHog has no distinct id for the user of the device, so '
            'the event of the check cannot be found.';
      } else {
        request = jsonEncode({
          'nonce': nonce,
          'distinctId': distinctId,
          'flavor': appFlavor ?? '{{default_flavor}}',
        });
      }
    }
  } on _NoAnswer catch (noAnswer) {
    problem = 'PostHog did not answer within a second when the check asked '
        '${noAnswer.what}.';
  } on Object catch (error) {
    problem = 'the check threw ${'$error'.trim().split('\n').first}';
  }
  try {
    if (request != null) {
      _write(files, 'smf_start_request_$exchangeName', request);
      debugPrint('The check of PostHog sent its event and asked for the check '
          'of it: $request');
      return request;
    }
    final verdict = 'failed: $problem';
    _write(files, 'smf_start_report_$exchangeName', verdict);
    debugPrint('The check of PostHog $verdict');
    return verdict;
  } on Object catch (error) {
    debugPrint('The check of PostHog wrote nothing: $error');
    return null;
  }
}

/// What [call] of PostHog answers, which the check waits for at most
/// [readWait]: throws a [_NoAnswer] with [what] the check asked once that
/// time is over.
Future<T> _answer<T>(String what, Future<T> Function() call) =>
    call().timeout(readWait, onTimeout: () => throw _NoAnswer(what));

/// That PostHog did not answer within [readWait] when the check asked [what].
final class _NoAnswer implements Exception {
  const _NoAnswer(this.what);

  /// What the check asked PostHog, such as `whether it is opted out`.
  final String what;
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
