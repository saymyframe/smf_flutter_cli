import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_material_theme/bundles/material_theme_bundle.dart';
import 'package:smf_material_theme/src/agents.dart';

/// The module of the Material 3 theme of the app, which provides the theme
/// role: how the app looks in a light and in a dark theme.
///
/// It generates `lib/core/theme/app_theme.dart`, the file to edit for
/// another look, with the two functions that the role requires of its
/// provider, `createLightTheme` and `createDarkTheme`. Both themes have the
/// colours of one palette, the text styles of one font and the same look of
/// the components, such as cards, buttons, text fields and sheets. The look
/// is fixed, so the functions leave their context alone.
///
/// The font is part of the app: the module generates its files, with their
/// licence, in [fontDirectory], and declares its family in `pubspec.yaml`.
/// The app loads no font from the network, and the module adds no package
/// to the app: the themes are those of the material library of Flutter.
///
/// The template of the role owns the rest, whichever module provides the
/// role: the theme mode that the user selects and the app remembers in its
/// preferences, the arguments that the root `MaterialApp` takes the themes
/// and the mode from, and, in an app with a settings screen, the entry in
/// which the user selects the mode. So the module keeps no mode, has no
/// setting of its own and takes no option.
///
/// In the guide for coding agents, the module adds to the section of the
/// theme where its file creates the two themes, how to change their
/// colours, their font and what they share by hand, where a text field
/// takes its look from, and what a change must keep for the role.
final class MaterialThemeModule extends SmfModule {
  /// Creates the module.
  const MaterialThemeModule();

  /// The id of the module.
  static const id = ModuleId('material_theme');

  /// The family of the font of the themes, as `pubspec.yaml` of the app
  /// declares it.
  static const fontFamily = 'Geist';

  /// The directory of the app with the files of the font and their licence.
  static const fontDirectory = 'assets/fonts/geist';

  /// The licence of the font, the SIL Open Font License. The app bundles it
  /// as an asset, so that each copy of the app has it with the font.
  static const fontLicenseFile = '$fontDirectory/OFL.txt';

  /// The files of the font in the app, by their weight.
  static const fontFiles = {
    400: '$fontDirectory/Geist-Regular.ttf',
    500: '$fontDirectory/Geist-Medium.ttf',
    600: '$fontDirectory/Geist-SemiBold.ttf',
  };

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Light and dark Material 3 themes with a palette and a '
            'bundled font',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(themeRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(materialThemeBundle),
        PubspecContribution.flutter(
          assets: const [fontLicenseFile],
          fonts: [
            PubspecFont(fontFamily, [
              for (final MapEntry(key: weight, value: file)
                  in fontFiles.entries)
                PubspecFontAsset(file, weight: weight),
            ]),
          ],
        ),
        AppEntryRole.agentSections.entry(
          themeRole.description,
          AgentNote(agentNote),
        ),
      ];
}
