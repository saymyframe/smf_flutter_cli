import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_sentry/bundles/sentry_bundle.dart';
import 'package:smf_sentry/src/agents.dart';
import 'package:smf_sentry/src/readme.dart';

/// The module that reports the errors of the app to
/// [Sentry](https://sentry.io) with the sentry_flutter package, and so
/// provides the crash reporting role.
///
/// The template of the role generates the `CrashReporter` interface,
/// `createCrashReporter()`, which returns the one reporter of the app that
/// forwards every report to the reporters of all its providers, and
/// `installCrashReporting()`, which reports the errors of the main isolate
/// that the app does not handle. This module adds `sentry_flutter` to the
/// dependencies of the app and implements the reporter in [reporterFile] on
/// `Sentry`. Sentry starts asynchronously, so the role awaits
/// `initSentryCrashReporter()` in `bootstrap()` before it installs the
/// handlers.
///
/// The handlers of the errors that nothing catches belong to the role, so
/// the start of Sentry turns off those that Sentry installs itself: it
/// removes `OnErrorIntegration`, by type, which a build with `--obfuscate`
/// keeps, and puts back `FlutterError.onError`, which the integration of
/// Sentry for the errors of Flutter replaces and which sentry_flutter does
/// not export. Kept, they would report each error of Flutter twice. The
/// native crashes stay with the SDKs of Sentry for Android and iOS, next to
/// those of any other crash reporter of the app.
///
/// The module requires the env role for its key, the DSN of the Sentry
/// project, which the developer of the app fills in in `.env`: [dsnKey].
/// Without a value of it, the start throws, and the role leaves Sentry out,
/// with the reason in a debug build. The environment of the events is the
/// flavor of the build, and debug builds send their events too.
///
/// The module adds the section [readmeHeading] to the README of the app, with
/// what reaches Sentry and how the stack traces of a release become
/// readable, a note to the section of the crash reporting in the guide for
/// coding agents, and its step by hand, [dsnStep].
final class SentryModule extends SmfModule {
  /// Creates the module.
  const SentryModule();

  /// The id of the module.
  static const id = ModuleId('sentry');

  /// The key of the DSN of the Sentry project in `.env`.
  static const dsnKey = EnvKey(
    'SENTRY_DSN',
    description: 'The DSN of your Sentry project, which the crash reports go '
        'to',
  );

  /// The step by hand in which the developer creates a Flutter project in
  /// Sentry and copies its DSN into `.env`.
  static const dsnStep = ManualStep(
    ManualStepId(id, 'dsn'),
    'Create a Flutter project in Sentry and copy its DSN into .env',
  );

  static const _file = ImportRef.app('core/crash_reporting/$reporterFileName');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Sentry with sentry_flutter',
        kind: ModuleKinds.infrastructure,
        requires: {envRole},
        providers: [RoleProvider.plain(crashReportingRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          sentryBundle,
          vars: {
            ...envRole.varsOf(id, const [dsnKey]),
            'default_flavor': AppEntryRole.defaultFlavor.name,
            'values_heading': EnvRole.readmeHeading,
            'readme_heading': readmeHeading,
          },
        ),
        // The reporter of the brick removes the integrations of this version
        // that take the handlers of the errors: check them when moving to a
        // newer version.
        const PubspecContribution.hosted('sentry_flutter', '^10.4.0'),
        crashReportingRole.data(
          const RoleImplementation.async(
            type: TypeRef('SentryCrashReporter', import: _file),
            init: FactoryRef('initSentryCrashReporter', import: _file),
          ),
        ),
        envRole.data(dsnKey),
        dsnStep,
        AppEntryRole.readmeSections.entry(readmeHeading, readmeSection),
        AppEntryRole.agentSections.entry(
          crashReportingRole.description,
          AgentNote(agentNote),
        ),
      ];
}
