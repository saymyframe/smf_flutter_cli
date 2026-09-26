import 'package:smf_contracts/lego.dart';
import 'package:smf_firebase_core/bundles/firebase_core_bundle.dart';
import 'package:smf_firebase_core/src/preflight/firebase_cli.dart';
import 'package:smf_firebase_core/src/preflight/firebase_login.dart';
import 'package:smf_firebase_core/src/preflight/flutterfire_cli.dart';
import 'package:smf_firebase_core/src/preflight/xcode_project_tools.dart';
import 'package:smf_firebase_core/src/readme.dart';

/// The module that sets up Firebase in the app with the firebase_core
/// package.
///
/// It adds `firebase_core` to the dependencies of the app, and
/// `lib/firebase_options.dart` with `DefaultFirebaseOptions`, the options of
/// the Firebase app of each platform. `bootstrap()` initializes Firebase with
/// the options of the platform that runs the app, among the platform
/// services, so the services of the app can use it.
///
/// `flutterfire configure` of the FlutterFire CLI writes the options. Until
/// it runs, the file is a placeholder in the form that the FlutterFire CLI
/// writes for platforms it has not configured: each platform throws an
/// `UnsupportedError`, so the app compiles but stops at start-up. The
/// FlutterFire CLI fills the placeholder in place.
///
/// Before generation, the module checks that the machine can run
/// `flutterfire configure`: the Firebase CLI with a logged-in account, the
/// FlutterFire CLI, and, on macOS, the Ruby gem that changes the Xcode
/// project. In a run with a terminal, it offers to install the two CLIs and
/// to log in; otherwise it tells how.
///
/// After generation, in a run with a terminal, the module runs
/// `flutterfire configure` for the platforms of the app, which asks the user
/// for the Firebase project; a run without one, or that skips external
/// setup, prints the command to run later. The README of the app tells how
/// to configure it again, such as on another machine.
///
/// Firebase supports iOS [minimumIosVersion] or newer, so the module raises
/// the minimum iOS version of the app to it.
final class FirebaseCoreModule extends SmfModule {
  /// Creates the module.
  const FirebaseCoreModule();

  /// The id of the module.
  static const id = ModuleId('firebase_core');

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
    final configure = [
      'configure',
      '--platforms=${AppEntryRole.platforms.join(',')}',
      '--overwrite-firebase-options',
    ];
    return [
      BrickContribution(firebaseCoreBundle),
      const PubspecContribution.hosted('firebase_core', '^4.15.0'),
      const SocketContribution.code(
        AppEntryRole.bootstrapPlatform,
        Fragment(
          'await Firebase.initializeApp(options: '
          'DefaultFirebaseOptions.currentPlatform);',
          imports: [
            ImportRef('package:firebase_core/firebase_core.dart'),
            ImportRef.app('firebase_options.dart'),
          ],
        ),
      ),
      AppEntryRole.iosDeploymentTarget.value(minimumIosVersion),
      const Preflight([
        FirebaseCliCheck(),
        FirebaseLoginCheck(),
        FlutterfireCliCheck(),
        XcodeProjectToolsCheck(),
      ]),
      // flutterfire writes paths relative to the app, so it can run in the
      // temporary directory of the app.
      PostGenStep(
        flutterfireTool,
        configure,
        description: 'Configuring Firebase with flutterfire',
        interactive: true,
        skippable: true,
        external: true,
      ),
      AppEntryRole.readmeSections.entry(
        readmeHeading,
        readmeSection(['flutterfire', ...configure].join(' ')),
      ),
    ];
  }
}
