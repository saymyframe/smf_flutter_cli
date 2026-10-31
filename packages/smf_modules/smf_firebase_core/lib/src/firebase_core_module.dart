import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/bundles/firebase_core_bundle.dart';
import 'package:smf_firebase_core/src/agents.dart';
import 'package:smf_firebase_core/src/configure.dart';
import 'package:smf_firebase_core/src/preflight/firebase_cli.dart';
import 'package:smf_firebase_core/src/preflight/firebase_login.dart';
import 'package:smf_firebase_core/src/preflight/flutterfire_cli.dart';
import 'package:smf_firebase_core/src/preflight/xcode_project_tools.dart';
import 'package:smf_firebase_core/src/readme.dart';

/// The module that sets up Firebase in the app with the firebase_core
/// package.
///
/// It adds `firebase_core` to the dependencies of the app, and for each flavor
/// of [AppEntryRole.flavors] a file of options, `lib/firebase_options_dev.dart`
/// and so on, with its `DefaultFirebaseOptions`, the options of the Firebase
/// app of each platform. `firebaseOptionsOfFlavor` of [optionsSelectorFile]
/// takes those of the flavor of the build by `appFlavor`, and `bootstrap()`
/// initializes Firebase with them, among the platform services, so the
/// services of the app can use it.
///
/// [configureScript], a script of the app, runs `flutterfire configure` of the
/// FlutterFire CLI for one flavor, and that writes its options. Until it runs,
/// the file is a placeholder: the file that flutterfire_cli 1.4 writes for an
/// app with no platform configured, where each platform throws an
/// `UnsupportedError` that gives the command, so the app compiles but stops at
/// start-up. The FlutterFire CLI fills the placeholder in place. Each flavor
/// may have a Firebase project of its own or share one.
///
/// A module that depends on this one and has something that must follow every
/// run of flutterfire, such as a change of a file that flutterfire writes,
/// adds a Dart file to [configuredHooksDirectory], which the script runs by
/// the order of the names and without knowing the module.
///
/// Before generation, the module checks that the machine can run
/// `flutterfire configure`: the Firebase CLI with a logged-in account, the
/// FlutterFire CLI, and, on macOS, the Ruby gem that changes the Xcode
/// project; elsewhere, it warns that the Xcode project is left for a Mac.
/// In a run with a terminal, it offers to install the two CLIs and to log
/// in; otherwise it tells how.
///
/// After generation, in a run with a terminal, the module runs the script for
/// [AppEntryRole.defaultFlavor], which asks the user for the Firebase project.
/// A run without one, or that skips external setup, prints the command to run
/// later, and so does a run that lacks what the checks look for, since
/// flutterfire would fail without it. The modules that depend on this one
/// may continue the step, as [configureStep]. One whose command needs a
/// later Firebase CLI than flutterfire does checks the version with
/// `FirebaseCliVersionCheck` of this package, in its own [Preflight]. The
/// README of the app tells how to configure the other flavors and to configure
/// a flavor again, such as on another machine, and its guide for coding agents
/// that the options are placeholders which the script writes, and that only a
/// person can run it.
///
/// Firebase supports iOS [minimumIosVersion] or newer, so the module raises
/// the minimum iOS version of the app to it.
final class FirebaseCoreModule extends SmfModule {
  /// Creates the module.
  const FirebaseCoreModule();

  /// The id of the module.
  static const id = ModuleId('firebase_core');

  /// The id of the step that configures Firebase for the default flavor after
  /// generation, with [configureScript], which the steps of the modules that
  /// depend on this one may continue; see [PostGenStep.followUpOf].
  static const configureStep = PostGenStepId(id, 'configure');

  /// The script of the app that configures Firebase for a flavor with
  /// `flutterfire configure`.
  static const String configureScript = configureScriptPath;

  /// The directory of the Dart files that [configureScript] runs after its
  /// last run of flutterfire, by the order of their names. A module that
  /// depends on this one generates a file there for what has to follow every
  /// run of flutterfire. An app without such a module has no such directory.
  static const configuredHooksDirectory = 'tool/firebase_configured';

  /// The file of the app with `firebaseOptionsOfFlavor`, the options of the
  /// Firebase apps of the flavor of the build.
  static const optionsSelectorFile = 'lib/firebase_options_of_flavor.dart';

  /// The minimum iOS version of the Firebase SDKs.
  static const minimumIosVersion = '15.0';

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Firebase with firebase_core',
        kind: ModuleKinds.infrastructure,
      );

  @override
  List<Contribution> contribute(ModuleContext context) {
    final identity = context.appIdentity;
    // flutterfire fails without any of them.
    const needed = [
      FirebaseCliCheck(),
      FirebaseLoginCheck(),
      FlutterfireCliCheck(),
      XcodeProjectToolsCheck(),
    ];
    return [
      BrickContribution(
        firebaseCoreBundle,
        vars: {
          'flavor_ids': flavorIdsCode(identity),
          'platforms': identity.platforms.join(','),
          'hooks_directory': configuredHooksDirectory,
        },
      ),
      const PubspecContribution.hosted('firebase_core', '^4.15.0'),
      const SocketContribution.code(
        AppEntryRole.bootstrapPlatform,
        Fragment(
          'await Firebase.initializeApp(options: firebaseOptionsOfFlavor);',
          imports: [
            ImportRef('package:firebase_core/firebase_core.dart'),
            ImportRef.app('firebase_options_of_flavor.dart'),
          ],
        ),
      ),
      AppEntryRole.iosDeploymentTarget.value(minimumIosVersion),
      const Preflight([...needed, XcodeProjectOnMacCheck()]),
      // flutterfire writes paths relative to the app, so the script can run
      // in the temporary directory of the app.
      PostGenStep(
        const ToolRef('dart'),
        [configureScript, AppEntryRole.defaultFlavor.name],
        id: configureStep,
        description: 'Configuring Firebase with flutterfire',
        interactive: true,
        skippable: true,
        external: true,
        needs: [for (final check in needed) check.id],
      ),
      AppEntryRole.readmeSections.entry(readmeHeading, readmeSection),
      AppEntryRole.agentSections.entry(agentHeading, AgentNote(agentNote)),
    ];
  }
}
