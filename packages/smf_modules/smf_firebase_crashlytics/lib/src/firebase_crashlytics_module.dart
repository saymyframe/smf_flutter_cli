import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_crashlytics/bundles/firebase_crashlytics_bundle.dart';
import 'package:smf_firebase_crashlytics/src/agents.dart';
import 'package:smf_firebase_crashlytics/src/crashlytics_phase.dart';
import 'package:smf_firebase_crashlytics/src/readme.dart';

/// The module that reports the errors of the app to Firebase Crashlytics
/// with the firebase_crashlytics package, and so provides the crash
/// reporting role.
///
/// The template of the role generates the `CrashReporter` interface,
/// `createCrashReporter()`, which returns the one reporter of the app that
/// forwards every report to the reporters of all its providers, and
/// `installCrashReporting()`, which reports the errors of the main isolate
/// that the app does not handle. This module adds `firebase_crashlytics` to
/// the dependencies of the app and implements the reporter in
/// `lib/core/crash_reporting/crashlytics_crash_reporter.dart` on
/// `FirebaseCrashlytics`. Flutter presents the errors it catches, and in
/// debug mode the engine prints the others, so the reporter prints nothing,
/// as Crashlytics otherwise would.
///
/// Crashlytics works on the Firebase app, so the module depends on
/// [FirebaseCoreModule], which initializes Firebase in `bootstrap()`, and
/// `bootstrap()` installs the handlers after that. The reporter is created
/// on first use, without waiting. When the app has a DI container, the role
/// registers the reporter in it.
///
/// On macOS, `flutterfire configure`, which the script of [FirebaseCoreModule]
/// runs for each flavor, adds a build phase for Crashlytics to the Xcode
/// project, and writes it again in each of its runs. So the module adds a
/// script to [FirebaseCoreModule.configuredHooksDirectory], which that script
/// runs after flutterfire, and it points the phase at the upload script of
/// Crashlytics where Flutter puts it, so that `flutter build ipa` finds it for
/// every flavor. The README of the app tells how to fix the phase after
/// `flutterfire configure` by hand, and its guide for coding agents names the
/// script. The guide also
/// says to report through the reporter of the app rather than through
/// Crashlytics itself.
final class FirebaseCrashlyticsModule extends SmfModule {
  /// Creates the module.
  const FirebaseCrashlyticsModule();

  /// The id of the module.
  static const id = ModuleId('firebase_crashlytics');

  static const _file = ImportRef.app(
    'core/crash_reporting/crashlytics_crash_reporter.dart',
  );

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Firebase Crashlytics with firebase_crashlytics',
        kind: ModuleKinds.infrastructure,
        dependsOn: {FirebaseCoreModule.id},
        providers: [RoleProvider.plain(crashReportingRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          firebaseCrashlyticsBundle,
          vars: const {
            'script_path': crashlyticsPhaseFixScript,
            'xcode_project': AppEntryRole.xcodeProjectFile,
            'script_in_build_directory': crashlyticsScriptInBuildDirectory,
            'script_in_app': crashlyticsScriptInApp,
          },
        ),
        // The reporter of the brick reports an error of Flutter as
        // recordFlutterError of this version does, but without presenting
        // it: compare the two when moving to a newer version.
        const PubspecContribution.hosted('firebase_crashlytics', '^5.4.0'),
        crashReportingRole.data(
          const RoleImplementation(
            type: TypeRef('CrashlyticsCrashReporter', import: _file),
            create: FactoryRef(
              'createCrashlyticsCrashReporter',
              import: _file,
            ),
          ),
        ),
        AppEntryRole.readmeSections.entry(readmeHeading, readmeSection),
        AppEntryRole.agentSections.entry(
          crashReportingRole.description,
          AgentNote(agentNote),
        ),
      ];
}
