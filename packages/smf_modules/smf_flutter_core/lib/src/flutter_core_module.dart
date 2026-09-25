import 'package:smf_contracts/lego.dart';
import 'package:smf_flutter_core/bundles/flutter_core_bundle.dart';

/// The module that creates the app itself, and so provides the app entry
/// role.
///
/// Its brick has the files of `flutter create` for Android and iOS, and:
/// - `lib/main.dart`, whose `main()` awaits `bootstrap()` and runs `App`
///   inside the root wrappers of the modules;
/// - `lib/bootstrap.dart`, with the start-up code of the modules in the
///   order of its phases;
/// - `lib/app.dart`, the root widget `App`: a `MaterialApp.router` with the
///   router's configuration when a router is present, or else a
///   `MaterialApp` that shows the `FallbackStartScreen`;
/// - `lib/core/app/fallback_start_screen.dart` and a widget test of it;
/// - `pubspec.yaml` with the dependencies of all modules, and the lints of
///   a new Flutter app.
///
/// Every socket of the app entry role has its tag in these files. The native
/// projects follow `flutter create` of Flutter 3.44, so the app needs
/// Flutter 3.44 or newer, and iOS [minimumIosVersion] or newer.
final class FlutterCoreModule extends SmfModule {
  /// Creates the module.
  const FlutterCoreModule();

  /// The id of the module.
  static const id = ModuleId('flutter_core');

  /// The minimum iOS version of the app unless a module needs a higher one
  /// through [AppEntryRole.iosDeploymentTarget].
  ///
  /// It is the lowest version Xcode 27 builds for, and the one of the
  /// template of Flutter 3.47; the template of Flutter 3.44 still has 13.0.
  static const minimumIosVersion = '15.0';

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Flutter app for Android and iOS',
        kind: ModuleKinds.scaffold,
        uses: {routerRole},
        providers: [RoleProvider.plain(appEntryRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) {
    final identity = context.appIdentity;
    return [
      BrickContribution(
        flutterCoreBundle,
        vars: {
          'android_namespace': identity.androidNamespace,
          'android_application_id': identity.androidApplicationId,
          // The directory of MainActivity.kt; the brick reads it in three
          // braces, so mustache does not escape the slashes.
          'android_package_path':
              identity.androidNamespace.replaceAll('.', '/'),
          'ios_bundle_id': identity.iosBundleId,
        },
      ),
      AppEntryRole.iosDeploymentTarget.value(minimumIosVersion),
      const PubspecContribution.environment(
        sdk: '^3.12.0',
        flutter: '>=3.44.0',
      ),
      const PubspecContribution.sdk('flutter'),
      const PubspecContribution.sdk('flutter_test', dev: true),
      const PubspecContribution.hosted('flutter_lints', '^6.0.0', dev: true),
      const PubspecContribution.flutter(usesMaterialDesign: true),
    ];
  }
}
