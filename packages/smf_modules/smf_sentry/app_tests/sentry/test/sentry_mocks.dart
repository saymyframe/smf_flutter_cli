// The mocks of Sentry for the tests that continuous integration runs in the
// apps with the sentry module. They change the options of Sentry before it
// starts, through configureSentryForTests of the reporter of the module: each
// event goes to a transport that keeps it and sends nothing, so that Sentry
// still gives the event its id, and the tests read the events in
// sentryEvents. The matrix sets them up before the tests of every module of
// such an app (MatrixAppTest.mocks), so that any of them may run the start-up
// of the app, which starts Sentry. The tests have no native side of Sentry,
// so the native SDK does not start, and neither do the sessions of Sentry.
// Sentry would drop an event like the one before it, which would hide an
// error that reaches it twice, so the mocks turn that off.
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:{{app_name}}/core/crash_reporting/sentry_crash_reporter.dart';

/// The events that reached Sentry in the tests of a test file, in their
/// order, which the mocks keep and send nowhere.
final List<SentryEvent> sentryEvents = [];

/// Changes the options of Sentry before it starts in a test: see the top of
/// the file.
void mockSentry() {
  configureSentryForTests = (options) {
    options
      ..beforeSend = (event, hint) {
        sentryEvents.add(event);
        return event;
      }
      ..transport = const _NoTransport()
      ..autoInitializeNativeSdk = false
      ..enableDeduplication = false
      ..enableAutoSessionTracking = false;
  };
}

/// A transport that sends nothing, and gives Sentry the id of each event as
/// a transport does once the event is sent.
final class _NoTransport implements Transport {
  const _NoTransport();

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async =>
      envelope.header.eventId;
}
