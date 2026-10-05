import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_material_theme/bundles/material_theme_bundle.dart';
import 'package:smf_material_theme/src/agents.dart';

/// The module of the Material 3 theme of the app, which provides the theme
/// role: how the app looks in a light and in a dark theme.
///
/// It generates `lib/core/theme/app_theme.dart`, the file to edit for
/// another look, with `seedColor`, the colour that both themes derive their
/// colours from with `ColorScheme.fromSeed`, and the two functions that the
/// role requires of its provider, `createLightTheme` and `createDarkTheme`.
/// The look is fixed, so the functions leave their context alone. The themes
/// are those of the material library of Flutter, so the module adds no
/// package to the app.
///
/// The template of the role owns the rest, whichever module provides the
/// role: the theme mode that the user selects and the app remembers in its
/// preferences, the arguments that the root `MaterialApp` takes the themes
/// and the mode from, and, in an app with a settings screen, the entry in
/// which the user selects the mode. So the module keeps no mode, has no
/// setting of its own and takes no option.
///
/// In the guide for coding agents, the module adds to the section of the
/// theme where its file creates the two themes, how to change their colours
/// and what they share by hand, and what a change must keep for the role.
final class MaterialThemeModule extends SmfModule {
  /// Creates the module.
  const MaterialThemeModule();

  /// The id of the module.
  static const id = ModuleId('material_theme');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Light and dark Material 3 themes from one seed colour',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(themeRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(materialThemeBundle),
        AppEntryRole.agentSections.entry(
          themeRole.description,
          AgentNote(agentNote),
        ),
      ];
}
