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
/// that take no arguments, [createLightTheme], which returns a `ThemeData`
/// of `Brightness.light`, and [createDarkTheme], which returns one of
/// `Brightness.dark`. The root of the app calls them each time it builds,
/// so a change of that file shows on a hot reload.
///
/// The role's template owns the mode, whichever provider is selected. It
/// generates [themeModeFile] with:
/// - `themeModeController`, the `ThemeModeController` of the app. Its
///   `mode` is the `ThemeMode` of the app: `ThemeMode.system`, which follows
///   the device, unless the user selected another. `select(mode)` makes
///   `mode` the mode of the app at once and saves it; its future completes
///   once the mode is saved. The controller is a `ChangeNotifier`, which
///   tells its listeners when the mode changes;
/// - `ThemeModeScope`, the widget around the root of the app, whose
///   `ThemeModeScope.of(context)` returns the controller and rebuilds the
///   widget of `context` when the mode changes;
/// - `restoreThemeMode`, the restorer of the mode, which the template puts
///   into [PreferencesRole.restorers].
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
/// saved or when what is saved is no name of a mode. Before the preferences
/// are open, `select` changes only memory.
///
/// A write of the mode that fails is not caught: the future of `select`
/// completes with the error of the preferences. The app is in the selected
/// mode by then and stays in it while it runs, but its next launch has the
/// mode that was saved before; the same choice again saves it. The entry of
/// the settings screen does not wait for that future, so there the error
/// reaches the handlers of the uncaught errors of the app.
///
/// In an app with the [SettingsScreenRole], the template also generates
/// [themeModeSettingFile] with `ThemeModeSetting`, the entry of the
/// settings screen in which the user selects the mode: follow the device,
/// light, or dark. In an app with the [LocalizationRole], the texts of the
/// entry are texts of the app, which the template has in English and in
/// Ukrainian; in an app without it they are English.
///
/// The screens of a module read the theme as any Flutter code does, with
/// `Theme.of(context)`, in an app with the role and in one without it. A
/// module that declares the role may also read and select the mode through
/// [themeModeFile].
///
/// A test selects a mode with `themeModeController.select(mode)` and reads
/// the selected one from `themeModeController.mode`, whichever module
/// provides the role. It shows that a mode is saved by reading [modeKey]
/// from the preferences after a choice, and that it is remembered by
/// writing [modeKey], running `initPreferences()` again and reading the
/// mode (see [PreferencesRole.restorers]). The app has one controller,
/// which keeps its mode from one test of a file to the next, so a test that
/// selects a mode selects `ThemeMode.system` again when it ends.
final class ThemeRole extends Role<NoDsl> {
  const ThemeRole._();

  /// The path of the file with `themeModeController`, `ThemeModeController`,
  /// `ThemeModeScope` and `restoreThemeMode`.
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

  /// `ThemeData createLightTheme()`, the light theme of the app, which
  /// every provider generates: a theme whose brightness is
  /// `Brightness.light`.
  static const createLightTheme = RequiredFunction(
    'createLightTheme',
    path: appThemeFile,
    returnType: 'ThemeData',
  );

  /// `ThemeData createDarkTheme()`, the dark theme of the app, which every
  /// provider generates: a theme whose brightness is `Brightness.dark`.
  static const createDarkTheme = RequiredFunction(
    'createDarkTheme',
    path: appThemeFile,
    returnType: 'ThemeData',
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

/// The template of the [ThemeRole]: the theme mode that the user selected,
/// what the root of the app needs to follow it, the restorer that takes it
/// from the preferences, and the entry of the settings screen that selects
/// it.
final class _ThemeTemplate extends RoleTemplate<NoDsl> {
  const _ThemeTemplate();

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(themeRoleBundle),
        const SocketContribution.wrap(
          AppEntryRole.rootWrappers,
          Fragment.wrap(
            'ThemeModeScope(notifier: themeModeController, child: ',
            ')',
            imports: [_themeMode],
          ),
        ),
        SocketContribution.arg(
          AppEntryRole.appArgs,
          'theme',
          Fragment(
            '${ThemeRole.createLightTheme.name}()',
            imports: [ThemeRole.createLightTheme.importRef],
          ),
        ),
        SocketContribution.arg(
          AppEntryRole.appArgs,
          'darkTheme',
          Fragment(
            '${ThemeRole.createDarkTheme.name}()',
            imports: [ThemeRole.createDarkTheme.importRef],
          ),
        ),
        const SocketContribution.arg(
          AppEntryRole.appArgs,
          'themeMode',
          Fragment('ThemeModeScope.of(context).mode', imports: [_themeMode]),
        ),
        const SocketContribution.item(
          PreferencesRole.restorers,
          Fragment('restoreThemeMode', imports: [_themeMode]),
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
