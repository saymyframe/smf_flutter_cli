import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_settings/bundles/settings_bundle.dart';
import 'package:smf_settings/src/agents.dart';

/// The module of the settings screen of the app: a feature with one route,
/// whose screen, `SettingsScreen`, shows the settings that the modules of
/// the app have, and so a provider of the settings screen role.
///
/// The screen has a large title and, below it, the settings in one group,
/// a card with a line between them. The group has an entry for each
/// setting that a module of the app, or the template of a role, gives the
/// role, such as the theme or the language: the widget of the entry, in
/// the order of the entries of the role, created as a constant through an
/// import of its file with a prefix of its own, `entry0` for the first
/// file. The title and the group are in a list, which scrolls.
///
/// In an app whose modules have no setting, the screen has a note for the
/// developer of the app in place of the group: that the app has no
/// settings yet, and the path of the file of the screen, where a setting
/// goes, which a tap copies. The provider knows whether the app has
/// entries when it renders them, so an app gets the code of its own screen
/// only. The note is in English in every app. An app with the localization
/// role never has it, because that role gives every settings screen the
/// setting of the language.
///
/// The title of the screen is a text of the module, in English and in
/// Ukrainian, which the module gives the localization role, a role that it
/// uses. It is the label of the destination of the screen in the main
/// navigation too. With the role, the screen reads the title, and the main
/// navigation the label, from the texts of the app, in the language of the
/// app; without it, both are the English text.
///
/// The route is `/` of the module, so its full path is `/settings`. The
/// main navigation of the app, when a module provides it, shows the route
/// as Settings with the settings icon, after the destinations of the
/// features before it. There the screen has no app bar. Without a main
/// navigation, nothing that SMF generates opens the screen: code of the
/// app shows it on top of the current screen with
/// `context.nav.settings.settings().push<void>()`. Shown so, the screen
/// has an app bar with a back button, which leads back. `go()` would
/// replace the stack with the screen alone, and nothing would lead back
/// from it.
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
///
/// In the guide for coding agents of the app, the module adds to the section
/// of the settings screen where the screen is, what it shows, and how code
/// opens it in an app without a main navigation ([agentNote]).
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

  /// The text of the title of the screen, which is the label of its
  /// destination too: the screen and the main navigation read it from the
  /// texts of the app in an app with the localization role.
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
          vars: localizationRole.varsOf(id, _texts),
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
        AppEntryRole.agentSections.entry(
          settingsScreenRole.description,
          AgentNote(agentNote),
        ),
      ];
}

/// Renders the entries of the settings screen into the brick of the module,
/// and tells the brick whether the app has any.
final class _SettingsProvider extends RoleProvider<SettingsData> {
  const _SettingsProvider();

  @override
  Role<SettingsData> get role => settingsScreenRole;

  /// Two variables of the brick of the screen:
  /// - `entries`, the widgets of the entries as the items of a constant
  ///   list, one on a line, in the order of the role, with the imports of
  ///   their files, each with a prefix of its own: `entry0` for the first
  ///   file, `entry1` for the next. Without entries, the variable has no
  ///   code, and its line of the template goes away.
  /// - `with_entries`, whether the app has an entry. The template has the
  ///   group of the entries in an app with one, and the note of a screen
  ///   without settings in an app with none, so no app gets the code of
  ///   the other screen.
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
      items.add('                  ${widget.codeWith(prefix)}(),');
    }
    return RoleOutput(
      vars: {
        'with_entries': items.isNotEmpty,
        'entries': Fragment(items.join('\n'), imports: [...files.values]),
      },
    );
  }
}
