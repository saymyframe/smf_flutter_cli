import 'package:smf_contracts/bundles/theme_role_bundle.dart';
import 'package:smf_contracts/bundles/theme_role_setting_bundle.dart';
import 'package:smf_contracts/smf_contracts.dart';

/// The theme role; see [ThemeRole].
const themeRole = ThemeRole._();

/// The role of the theme of the app: how the app looks in a light and in a
/// dark theme, and which of the two it shows, the theme mode that the user
/// selects and the app remembers.
///
/// A provider owns the look. It generates [appThemeFile] with two functions
/// that take the `BuildContext` of the root of the app, [createLightTheme],
/// which returns a `ThemeData` of `Brightness.light`, and
/// [createDarkTheme], which returns one of `Brightness.dark`. The root of
/// the app calls them each time it builds, so a change of that file shows
/// on a hot reload.
///
/// That context is the one of the [AppEntryRole.appArgs]: below the
/// [AppEntryRole.rootWrappers] and above the root `MaterialApp`, so it has
/// neither the theme nor the localizations of the app. A provider whose
/// look depends on state of its own, such as a colour that the user picks
/// or that the device gives, puts an inherited widget with that state among
/// the root wrappers and reads it from the context in the two functions:
/// the root rebuilds in the new look when that widget notifies. A provider
/// whose look is fixed leaves the context alone.
///
/// The role's template owns the mode, whichever provider is selected. It
/// generates [themeModeFile] with:
/// - `appThemeMode`, the `AppThemeModeController` of the app, which has no
///   other. Its `value` is the `ThemeMode` of the app: `ThemeMode.system`,
///   which follows the device, unless the user selected another.
///   `choose(mode)` makes `mode` the mode of the app at once and saves it;
///   its future completes once the mode is saved. The controller is a
///   `ChangeNotifier`, which tells its listeners when the mode changes;
/// - `AppThemeModeScope`, the widget around the root of the app, whose
///   `AppThemeModeScope.of(context)` returns the mode and rebuilds the
///   widget of `context` when the mode changes;
/// - `restoreAppThemeMode`, the restorer of the mode, which the template
///   puts into [PreferencesRole.restorers].
///
/// So a widget reads the mode from the scope, and code changes it on
/// `appThemeMode`.
///
/// The template gives the root `MaterialApp` its `theme`, its `darkTheme`
/// and its `themeMode`, which reads the scope from the context of the root:
/// the root rebuilds in the mode that the user selects. Each of the three
/// takes one value, so a module that sets one of them cannot be in an app
/// with the role: the pipeline reports the two values.
///
/// The role requires the [PreferencesRole]: the mode is saved under the key
/// [modeKey], as the name of the `ThemeMode`, such as `dark`. The restorer
/// takes the mode that is saved, and keeps the current one when nothing is
/// saved or when what is saved is no name of a mode. Until the preferences
/// were opened for the first time, `choose` changes only memory; from then
/// on it saves through the preferences that were opened last.
///
/// A write of the mode that fails is not caught: the future of `choose`
/// completes with the error of the preferences. The app is in the selected
/// mode by then and stays in it while it runs, but its next launch has the
/// mode that was saved before; the same choice again saves it. The entry of
/// the settings screen does not wait for that future, so there the error
/// reaches the handlers of the uncaught errors of the app.
///
/// In an app with the [SettingsScreenRole], the template also generates
/// [themeModeSettingFile] with `ThemeModeSetting`, the entry of the
/// settings screen in which the user selects the mode: follow the device,
/// light, or dark. The entry reads the mode from the scope and chooses on
/// `appThemeMode`. In an app with the [LocalizationRole], the texts of the
/// entry are texts of the app, which the template has in English and in
/// Ukrainian; in an app without it they are English.
///
/// The mode and its entry are the role's, the same with every provider: a
/// provider keeps no mode of its own and adds no entry for the mode. A
/// provider that has a setting of its own for its look, such as that
/// colour, contributes a [SettingsEntry] of its own for it.
///
/// The screens of a module read the theme as any Flutter code does, with
/// `Theme.of(context)`, in an app with the role and in one without it. A
/// module that declares the role may also read and choose the mode through
/// [themeModeFile].
///
/// A test selects a mode with `appThemeMode.choose(mode)` and reads the
/// selected one from `appThemeMode.value`, whichever module provides the
/// role. It shows that a mode is saved by reading [modeKey] from the
/// preferences after a choice, and that it is remembered by writing
/// [modeKey], running `initPreferences()` again and reading the mode (see
/// [PreferencesRole.restorers]).
///
/// The app has one controller, and two things of it outlive a test, into
/// the next test of the same file: its mode, and the preferences of the
/// last start, through which `choose` saves from then on, also before the
/// next start. So a test that selects a mode chooses `ThemeMode.system`
/// again when it ends. That choice saves `system`: a test that needs
/// nothing saved removes [modeKey] from the preferences.
final class ThemeRole extends Role<NoDsl> {
  const ThemeRole._();

  /// The path of the file with `appThemeMode`, `AppThemeModeController`,
  /// `AppThemeModeScope` and `restoreAppThemeMode`.
  static const themeModeFile = 'lib/core/theme/theme_mode.dart';

  /// The path of the file with `ThemeModeSetting`, the entry of the theme
  /// mode on the settings screen, which only an app with the
  /// [SettingsScreenRole] has. So it is no file of the [interface] of the
  /// role: the provider of the settings screen creates the entry, and no
  /// other code names it.
  static const themeModeSettingFile = 'lib/core/theme/theme_mode_setting.dart';

  /// The path of the provider's file with [createLightTheme] and
  /// [createDarkTheme].
  static const appThemeFile = 'lib/core/theme/app_theme.dart';

  /// `ThemeData createLightTheme(BuildContext context)`, the light theme of
  /// the app, which every provider generates: a theme whose brightness is
  /// `Brightness.light`. Its argument is the context of the root of the
  /// app, below the root wrappers and above the root `MaterialApp`.
  static const createLightTheme = RequiredFunction(
    'createLightTheme',
    path: appThemeFile,
    returnType: 'ThemeData',
    positionalArguments: 1,
  );

  /// `ThemeData createDarkTheme(BuildContext context)`, the dark theme of
  /// the app, which every provider generates: a theme whose brightness is
  /// `Brightness.dark`. Its argument is the context of the root of the app,
  /// as that of [createLightTheme].
  static const createDarkTheme = RequiredFunction(
    'createDarkTheme',
    path: appThemeFile,
    returnType: 'ThemeData',
    positionalArguments: 1,
  );

  /// The key of the theme mode in the preferences of the app, under which
  /// the name of the selected `ThemeMode` is saved: `system`, `light` or
  /// `dark`.
  static const modeKey = 'theme.mode';

  @override
  String get id => 'theme';

  @override
  String get description => 'Theme';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  @override
  Set<Role> get requires => {preferencesRole};

  @override
  Set<Role> get uses => {settingsScreenRole, localizationRole};

  @override
  RoleInterface get interface => const RoleInterface(
        files: [themeModeFile],
        symbols: [createLightTheme, createDarkTheme],
      );

  @override
  RoleTemplate<NoDsl> get template => const _ThemeTemplate();
}

const _themeMode = ImportRef.app('core/theme/theme_mode.dart');

/// The texts of the entry of the theme mode on the settings screen: its
/// title, and the three modes that the user selects among.
const _title = LocalizedText(
  'title',
  en: 'Theme',
  translations: {'uk': 'Тема'},
);

const _system = LocalizedText(
  'system',
  en: 'System',
  translations: {'uk': 'Системна'},
);

const _light = LocalizedText(
  'light',
  en: 'Light',
  translations: {'uk': 'Світла'},
);

const _dark = LocalizedText(
  'dark',
  en: 'Dark',
  translations: {'uk': 'Темна'},
);

/// The texts of the template, each with the variable of the brick of the
/// entry that reads it.
const Map<String, LocalizedText> _texts = {
  'text_title': _title,
  'text_system': _system,
  'text_light': _light,
  'text_dark': _dark,
};

/// The note of the theme role in the guide for coding agents: where the
/// look and the theme mode of the app are and how code changes each,
/// whichever module provides the role. It names the two files that every
/// app with the role has, and not the entry of the settings screen, which
/// only some have.
final String _agentNote = '''
- `${ThemeRole.createLightTheme.name}(context)` and `${ThemeRole.createDarkTheme.name}(context)` in `${ThemeRole.appThemeFile}` return the light and the dark theme of the app. Change the look there. Keep both functions and their `BuildContext` parameter, because the root of the app calls them each time it builds, for the `theme` and the `darkTheme` of the root `MaterialApp`. Leave those two arguments and its `themeMode` as they are.
- The theme mode is in `${ThemeRole.themeModeFile}`. Change it only with `appThemeMode.choose(mode)`, which also saves it in the preferences, and write nothing under the key `${ThemeRole.modeKey}` yourself. A widget reads the mode with `AppThemeModeScope.of(context)` and rebuilds when it changes.
- Take the colours and the text styles of a screen from `Theme.of(context)`, not from constants, so that the screen follows the mode.
''';

/// The template of the [ThemeRole]: the theme mode that the user selected,
/// what the root of the app needs to follow it, the restorer that takes it
/// from the preferences, the entry of the settings screen that selects it,
/// and the note of the role for coding agents.
final class _ThemeTemplate extends RoleTemplate<NoDsl> {
  const _ThemeTemplate();

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(themeRoleBundle),
        AppEntryRole.agentSections.entry(
          themeRole.description,
          AgentNote.ofRole(_agentNote),
        ),
        const SocketContribution.wrap(
          AppEntryRole.rootWrappers,
          Fragment.wrap(
            'AppThemeModeScope(notifier: appThemeMode, child: ',
            ')',
            imports: [_themeMode],
          ),
        ),
        SocketContribution.arg(
          AppEntryRole.appArgs,
          'theme',
          Fragment(
            '${ThemeRole.createLightTheme.name}(context)',
            imports: [ThemeRole.createLightTheme.importRef],
          ),
        ),
        SocketContribution.arg(
          AppEntryRole.appArgs,
          'darkTheme',
          Fragment(
            '${ThemeRole.createDarkTheme.name}(context)',
            imports: [ThemeRole.createDarkTheme.importRef],
          ),
        ),
        const SocketContribution.arg(
          AppEntryRole.appArgs,
          'themeMode',
          Fragment('AppThemeModeScope.of(context)', imports: [_themeMode]),
        ),
        const SocketContribution.item(
          PreferencesRole.restorers,
          Fragment('restoreAppThemeMode', imports: [_themeMode]),
        ),
        // The entry of the settings screen, with its texts: only an app with
        // a settings screen gets the file of the entry, and only then does
        // the app need the texts.
        BrickContribution(
          themeRoleSettingBundle,
          when: const {settingsScreenRole},
        ),
        settingsScreenRole.data(
          const SettingsEntry(
            widget: TypeRef(
              'ThemeModeSetting',
              import: ImportRef.app('core/theme/theme_mode_setting.dart'),
            ),
          ),
        ),
        localizationRole.data(
          TextsData([..._texts.values]),
          when: const {settingsScreenRole},
        ),
      ];

  /// The key of the mode in the preferences, and the code that reads each
  /// text of the entry of the settings screen: a text of the app in an app
  /// with the localization role, and the English text in one without it.
  @override
  RoleOutput render(RoleHookInput<NoDsl> input) => RoleOutput(
        vars: {
          'mode_key': SmfNames.dartString(ThemeRole.modeKey),
          for (final MapEntry(key: variable, value: text) in _texts.entries)
            variable: localizationRole.expressionOf(
              input,
              const RoleTemplateOrigin(themeRole),
              text,
            ),
        },
      );
}
