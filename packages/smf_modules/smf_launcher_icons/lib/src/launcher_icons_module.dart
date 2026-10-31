import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_launcher_icons/bundles/launcher_icons_bundle.dart';
import 'package:smf_launcher_icons/src/agents.dart';
import 'package:smf_launcher_icons/src/brand.dart';
import 'package:smf_launcher_icons/src/readme.dart';

/// The module that makes the icon of the app with the flutter_launcher_icons
/// package, and so provides the app icon role: an opaque icon on iOS and an
/// adaptive icon with a themed variant on Android, in place of the logo of
/// Flutter.
///
/// Its brick has the two sources of the role, which show the logo of Say My
/// Frame, the configuration of the tool, `flutter_launcher_icons.yaml`, and
/// `tool/update_app_icon.dart`, the script that runs the tool. The package is
/// only a dev dependency of the app: no code of the app imports it but that
/// script.
///
/// The step after generation runs the script, so that the native projects
/// have the icon, and a developer runs it again after a change of an image.
/// flutter_launcher_icons 0.14.4 writes the name of the icon into every build
/// setting of the Xcode project whose name has `ASSETCATALOG`, one of which
/// takes `YES` or `NO`. The script runs the tool and repairs that setting, so
/// the fix is not a second step that a developer would have to remember.
///
/// A step that fails only warns and prints its command, since it is skippable:
/// an app with the logo of Flutter is still an app, and it must not be lost
/// for an icon.
final class LauncherIconsModule extends SmfModule {
  /// Creates the module.
  const LauncherIconsModule();

  /// The id of the module.
  static const id = ModuleId('launcher_icons');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'App icon with flutter_launcher_icons',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(appIconRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          launcherIconsBundle,
          vars: const {
            'icon_background': iconBackground,
            'xcode_project': AppEntryRole.xcodeProjectFile,
          },
        ),
        const PubspecContribution.hosted(
          'flutter_launcher_icons',
          '^0.14.4',
          dev: true,
        ),
        const PostGenStep(
          ToolRef('dart'),
          [updateScript],
          description: 'Making the app icon from assets/branding',
          skippable: true,
        ),
        AppEntryRole.readmeSections.entry(readmeHeading, readmeSection),
        AppEntryRole.agentSections.entry(
          appIconRole.description,
          AgentNote(agentNote),
        ),
      ];
}
