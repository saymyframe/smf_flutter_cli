import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_settings/bundles/settings_bundle.dart';

/// The module of the settings screen of the app: a feature with one route,
/// whose screen, `SettingsScreen`, shows the settings that the modules of
/// the app have, and so a provider of the settings screen role.
///
/// The screen is a list. It has an entry for each setting that a module of
/// the app, or the template of a role, gives the role, such as the theme or
/// the language: the widget of the entry, in the order of the entries of
/// the role, created as a constant through an import of its file with a
/// prefix of its own, `entry0` for the first file. After them comes the
/// row of the module itself, About with the name of the app, which opens
/// the about dialog of Flutter, and from there the licenses of the packages
/// of the app. An app whose modules have no settings has that row alone.
///
/// The label of the destination of the screen in the main navigation is
/// the title of the screen, a text of the module, in English and in
/// Ukrainian, which the module gives the localization role, a role that it
/// uses. With the role, the main navigation reads the label from the texts
/// of the app, in the language of the app; without it, the label is the
/// English text.
///
/// The route is `/` of the module, so its full path is `/settings`. The
/// main navigation of the app, when a module provides it, shows the route
/// as Settings with the settings icon, after the destinations of the
/// features before it. Without a main navigation, nothing that SMF
/// generates opens the screen: code of the app shows it on top of the
/// current screen with `context.nav.settings.settings().push<void>()`, so
/// that its back button leads back. `go()` would replace the stack with
/// the screen alone, and nothing would lead back from it.
///
/// The route is not a start candidate, so the app starts on the screen
/// only when it is chosen as the start, as `--start /settings` does. An
/// app with no other screen starts on the fallback screen of the app
/// entry, also when it has a main navigation, which that screen is outside
/// of.
///
/// As a feature, the module requires the router role, whichever module
/// provides it, and keeps its file in `lib/features/settings/`. The screen
/// has no state of its own, since each entry keeps the state of its
/// setting, so the module has no variants for the modules that manage
/// state, and it adds no package to the app.
final class SettingsModule extends SmfModule {
  /// Creates the module.
  const SettingsModule();

  /// The id of the module.
  static const id = ModuleId('settings');

  /// The name of the route of the screen.
  static const _route = 'settings';

  /// The title of the screen in English, which is the label of its
  /// destination in the main navigation too.
  static const _title = 'Settings';

  /// The text of the title of the screen, which the main navigation reads
  /// as the label of its destination from the texts of the app, in an app
  /// with the localization role.
  static const _titleText = LocalizedText(
    'title',
    en: _title,
    translations: {'uk': 'Налаштування'},
  );

  /// The texts of the module, which it gives the localization role.
  static const _texts = TextsData([_titleText]);

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Settings screen with the settings of the modules',
        kind: ModuleKinds.feature,
        providers: [_SettingsProvider()],
        uses: {localizationRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          settingsBundle,
          vars: {'title': SmfNames.dartString(_title)},
        ),
        localizationRole.data(_texts),
        routerRole.data(
          const RoutesData([
            Route(
              '/',
              name: _route,
              screen: ScreenRef(
                'SettingsScreen',
                import: ImportRef.app('features/settings/settings_screen.dart'),
              ),
              destination: Destination(
                label: _titleText,
                icon: Fragment(
                  'Icons.settings',
                  imports: [
                    ImportRef('package:flutter/material.dart', show: ['Icons']),
                  ],
                ),
              ),
            ),
          ]),
        ),
        settingsScreenRole.data(const SettingsScreenRoute(_route)),
      ];
}

/// Renders the entries of the settings screen into the brick of the module.
final class _SettingsProvider extends RoleProvider<SettingsData> {
  const _SettingsProvider();

  @override
  Role<SettingsData> get role => settingsScreenRole;

  /// The widgets of the entries as the items of a constant list, one on a
  /// line, in the order of the role, with the imports of their files, each
  /// with a prefix of its own: `entry0` for the first file, `entry1` for
  /// the next. Without entries, the variable has no code, and its line of
  /// the template goes away.
  @override
  RoleOutput render(RoleHookInput<SettingsData> input) {
    // The import of each file of an entry, with its prefix, by the path of
    // the file.
    final files = <String, ImportRef>{};
    final items = <String>[];
    for (final entry in settingsScreenRole.entriesIn(input)) {
      final widget = entry.widget;
      // The template of the role rejects an entry whose widget is not in a
      // file of the app, so each has an import.
      final import = widget.import!;
      final prefix = files
          .putIfAbsent(
            import.uri,
            () => import.withPrefix('entry${files.length}'),
          )
          .prefix;
      items.add('        ${widget.codeWith(prefix)}(),');
    }
    return RoleOutput(
      vars: {
        'entries': Fragment(items.join('\n'), imports: [...files.values]),
      },
    );
  }
}
