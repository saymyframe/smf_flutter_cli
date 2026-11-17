// What the tests of the posthog module share: whether the app has a project
// token of PostHog in this build, and what a call printed.
//
// The mocks give posthog_flutter a device in memory (posthog_mocks.dart),
// whose calls complete at once, so the tests may start PostHog in the fake
// time of a widget test too.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:{{app_name}}/core/env/app_env.dart';

/// Whether this build of the app has a project token of PostHog: the matrix
/// gives one to some apps of the module and none to the others.
final bool hasToken = AppEnv.posthogProjectToken != null;

/// Why a test of an app with a project token does not run in this one.
const String withoutToken = 'The app has no POSTHOG_PROJECT_TOKEN in .env, '
    'so PostHog does not start: posthog_no_token_test.dart checks that.';

/// Why a test of an app without a project token does not run in this one.
const String withToken = 'The app has a POSTHOG_PROJECT_TOKEN in .env, so '
    'PostHog starts: posthog_test.dart checks that.';

/// Runs [body] and returns what it printed, with print or debugPrint.
Future<List<String>> printed(FutureOr<void> Function() body) async {
  final lines = <String>[];
  final debugPrintBefore = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) =>
      lines.addAll((message ?? '').split('\n'));
  try {
    await runZoned(
      () async => body(),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => lines.addAll(line.split('\n')),
      ),
    );
  } finally {
    debugPrint = debugPrintBefore;
  }
  return lines;
}
