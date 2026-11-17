// What the tests of the sentry module share: whether the app has a DSN of
// Sentry in this build, the events of an error among those that reached the
// mocks of Sentry, and what a call presented or printed.
//
// The mocks keep the events (sentry_mocks.dart). Sentry captures an event
// after the call that reported it has returned, and SentryFlutter.init never
// completes in the fake time of a widget test, so the tests start Sentry and
// wait for its events in real time, in plain tests.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:{{app_name}}/core/env/app_env.dart';

import '../sentry_mocks.dart';

/// Whether this build of the app has a DSN of Sentry: the matrix gives one
/// to some apps of the module and none to the others.
final bool hasDsn = AppEnv.sentryDsn != null;

/// Why a test of an app with a DSN does not run in this one.
const String withoutDsn = 'The app has no SENTRY_DSN in .env, so Sentry does '
    'not start: sentry_no_dsn_test.dart checks that.';

/// Why a test of an app without a DSN does not run in this one.
const String withDsn = 'The app has a SENTRY_DSN in .env, so Sentry starts: '
    'sentry_test.dart checks that.';

/// The events that reached Sentry with an exception whose text is [value],
/// once one has come, waiting for at most [wait], and then a moment longer,
/// so that a second event of the same error has come too.
Future<List<SentryEvent>> eventsOf(
  String value, {
  Duration wait = const Duration(seconds: 10),
}) async {
  List<SentryEvent> found() => [
        for (final event in sentryEvents)
          if ((event.exceptions ?? const <SentryException>[])
              .any((exception) => exception.value == value))
            event,
      ];
  final until = DateTime.now().add(wait);
  while (found().isEmpty && DateTime.now().isBefore(until)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  await Future<void>.delayed(const Duration(milliseconds: 500));
  return found();
}

/// The one exception of [event].
SentryException exceptionOf(SentryEvent event) => event.exceptions!.single;

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

/// Runs [body] and returns the errors that Flutter presented meanwhile.
Future<List<FlutterErrorDetails>> presented(
  FutureOr<void> Function() body,
) async {
  final errors = <FlutterErrorDetails>[];
  final presentErrorBefore = FlutterError.presentError;
  FlutterError.presentError = errors.add;
  try {
    await body();
  } finally {
    FlutterError.presentError = presentErrorBefore;
  }
  return errors;
}
