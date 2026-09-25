/// A fake app scaffold for the tests of the SMF pipeline. Not a module to
/// use.
///
/// It provides the app entry of the fixture apps in place of the
/// flutter_core module: the Dart entry point with every socket of the app
/// entry, the pubspec with the sockets of the pipeline, and native files
/// that only hold the tags of the native sockets and, in the Gradle files,
/// the lines that flutterfire looks for. They are not a buildable Android
/// or iOS project, and the minimum iOS version appears only in the Podfile.
library;

import 'package:fake_scaffold/bundles/fake_scaffold_bundle.dart';
import 'package:smf_contracts/lego.dart';

/// The provider of the app entry of the fixture apps.
final class FakeScaffoldModule extends SmfModule {
  /// Creates the module.
  const FakeScaffoldModule();

  /// The id of the module.
  static const id = ModuleId('fake_scaffold');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'The app entry of the fixture apps (fixture)',
        kind: ModuleKinds.scaffold,
        uses: {routerRole},
        providers: [RoleProvider.plain(appEntryRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(fakeScaffoldBundle),
        AppEntryRole.iosDeploymentTarget.value('13.0'),
        const PubspecContribution.environment(sdk: '^3.8.1'),
        const PubspecContribution.sdk('flutter'),
        const PubspecContribution.sdk('flutter_test', dev: true),
        const PubspecContribution.hosted('flutter_lints', '^6.0.0', dev: true),
        const PubspecContribution.flutter(usesMaterialDesign: true),
      ];
}
