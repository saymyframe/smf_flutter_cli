import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:sentry_flutter/sentry_flutter.dart';

import 'crash_reporter.dart';

/// Changes the options of Sentry before it starts, for the tests of the app
/// only: their mocks keep the events and drop them, so that no test sends
/// any.
@visibleForTesting
void Function(SentryFlutterOptions options)? configureSentryForTests;

/// Starts Sentry with the DSN of `.env` and returns a crash reporter that
/// reports to it. `bootstrap()` awaits it before it installs the handlers of
/// the crash reporting.
///
/// The handlers of the errors that nothing catches belong to the crash
/// reporting of the app, which reports each error to every crash reporter.
/// So Sentry gets no handler of its own: the start removes the integration
/// with which Sentry would take `PlatformDispatcher.instance.onError`, and
/// puts back the handler of `FlutterError.onError` that Sentry replaces, or
/// an error of Flutter would reach Sentry twice. Native crashes stay with
/// the SDKs of Sentry for Android and iOS.
///
/// The environment of the events is the flavor of the build. A debug build
/// sends its events too.
///
/// On Windows, where the app runs only in `flutter test`, Sentry processes
/// the events without the processor that adds the device, the system and
/// the runtime, whose read of the arguments of flutter_tester fails there
/// once a path among them has a letter beyond ASCII.
///
/// Throws a [StateError] when the build has no DSN, has a value that is no
/// DSN of Sentry, or when Sentry does not start with it: the app then reports
/// nothing to Sentry, and a debug build prints why, without the value.
Future<CrashReporter> initSentryCrashReporter() async {
  final dsn = {{{env_sentry_dsn}}};
  if (dsn == null) {
    throw StateError(
      'SENTRY_DSN has no value in this build, so the app reports nothing to '
      'Sentry. In .env, give it the DSN of your Sentry project, and build the '
      'app as the section "{{values_heading}}" of its README says. The section '
      '"{{readme_heading}}" tells more.',
    );
  }
  final flutterErrors = FlutterError.onError;
  late final SentryFlutterOptions started;
  try {
    await SentryFlutter.init((options) {
      started = options;
      options
        ..dsn = dsn
        ..environment = appFlavor ?? '{{default_flavor}}'
        // Sentry logs what it does in a debug build; the crash reporting of
        // the app shows the errors, and Sentry logs nothing.
        ..debug = false
        ..sendDefaultPii = false
        ..attachScreenshot = false
        ..attachViewHierarchy = false
        // An event of the app carries what it logged with log(), not what it
        // printed, which may hold what nobody meant to send.
        ..enablePrintBreadcrumbs = false;
      // By type, which a build with --obfuscate keeps, unlike a name.
      for (final integration
          in options.integrations.whereType<OnErrorIntegration>().toList()) {
        options.removeIntegration(integration);
      }
      configureSentryForTests?.call(options);
    });
  } on ArgumentError {
    // The errors of Sentry about a DSN that it does not take quote the DSN,
    // which a debug build would print.
    throw StateError(_noDsnOfSentry);
  } on FormatException {
    throw StateError(_noDsnOfSentry);
  } finally {
    FlutterError.onError = flutterErrors;
  }
  if (!Sentry.isEnabled) {
    throw StateError(
      'Sentry did not start with the SENTRY_DSN of this build, so the app '
      'reports nothing to Sentry: copy the DSN of your Sentry project into '
      '.env again.',
    );
  }
  _withoutEnricherOnWindows(started);
  return const SentryCrashReporter();
}

/// The class of the processor of Sentry that adds the device, the system,
/// the runtimes and the context of Dart to each event.
const _enricherClass = 'IoEnricherEventProcessor';

/// Leaves out the processor [_enricherClass] of Sentry, which [options]
/// has once Sentry started, on Windows, where the app runs only in
/// `flutter test`. There flutter_tester gives Dart its arguments in the code
/// page of Windows rather than in UTF-8, and the processor reads them
/// (`Platform.executableArguments`) for each event: when a path among them
/// has a letter beyond ASCII, such as the directory of the app, the read
/// fails with an error of the engine that no `catch` takes, so the event
/// never reaches Sentry and the call that reported it never completes. The
/// app is never obfuscated in `flutter test`, so the name of the class holds
/// there. On Android and iOS, the events keep the processor.
void _withoutEnricherOnWindows(SentryFlutterOptions options) {
  if (!Platform.isWindows) return;
  for (final processor in options.eventProcessors) {
    if ('${processor.runtimeType}' == _enricherClass) {
      options.removeEventProcessor(processor);
    }
  }
}

/// Why the app reports nothing to Sentry when Sentry does not take the
/// value of SENTRY_DSN, which it does not quote.
const _noDsnOfSentry = 'SENTRY_DSN of this build is no DSN of Sentry, so the '
    'app reports nothing to Sentry: copy the DSN of your Sentry project into '
    '.env again, as the section "{{readme_heading}}" of its README tells.';

/// Reports the errors of the app to Sentry.
///
/// It prints nothing. Of the errors that `installCrashReporting()` reports,
/// Flutter already presents those it catches, in every mode, and in debug
/// mode the engine prints the others.
final class SentryCrashReporter implements CrashReporter {
  /// Creates the reporter, which reports to the Sentry that
  /// [initSentryCrashReporter] started.
  const SentryCrashReporter();

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
    String? reason,
  }) async {
    await Sentry.captureException(
      ThrowableMechanism(
        Mechanism(type: 'CrashReporter.recordError', handled: !fatal),
        error,
      ),
      stackTrace: stackTrace,
      withScope: (scope) async {
        scope.level = fatal ? SentryLevel.fatal : SentryLevel.error;
        if (reason != null) {
          await scope.setContexts('reason', {'reason': reason});
        }
      },
    );
  }

  /// Reports what the integration of Sentry for the errors of Flutter
  /// reports, without presenting the error, which the crash reporting of the
  /// app does.
  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) async {
    final context = details.context?.toDescription();
    final information = details.informationCollector?.call() ?? const [];
    final library = details.library;
    await Sentry.captureException(
      ThrowableMechanism(
        Mechanism(type: 'CrashReporter.recordFlutterError', handled: !fatal),
        details.exception,
      ),
      stackTrace: details.stack,
      withScope: (scope) async {
        scope.level = fatal ? SentryLevel.fatal : SentryLevel.error;
        await scope.setContexts('flutter_error_details', {
          if (context != null) 'context': 'thrown $context',
          if (information.isNotEmpty) 'information': information.join('\n'),
          'library': ?library,
        });
      },
    );
  }

  @override
  Future<void> log(String message) =>
      Sentry.addBreadcrumb(Breadcrumb(message: message, category: 'log'));

  @override
  Future<void> setUserId(String? userId) async {
    await Sentry.configureScope(
      (scope) => scope.setUser(userId == null ? null : SentryUser(id: userId)),
    );
  }
}
