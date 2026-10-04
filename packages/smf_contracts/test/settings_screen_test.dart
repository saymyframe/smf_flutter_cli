import 'dart:convert';

import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'role_support.dart';
import 'support.dart';

const _themeFile = ImportRef.app('core/theme/theme_setting.dart');
const _themePath = 'lib/core/theme/theme_setting.dart';
const _theme =
    SettingsEntry(widget: TypeRef('ThemeSetting', import: _themeFile));

const _languageFile = ImportRef.app('core/l10n/language_setting.dart');
const _languagePath = 'lib/core/l10n/language_setting.dart';
const _language =
    SettingsEntry(widget: TypeRef('LanguageSetting', import: _languageFile));

const _accountFile = ImportRef.app('features/account/account_settings.dart');
const _accountPath = 'lib/features/account/account_settings.dart';
const _account =
    SettingsEntry(widget: TypeRef('AccountSettings', import: _accountFile));

const _screenPath = 'lib/features/settings/settings_screen.dart';

const _settings = ModuleOrigin(ModuleId('settings'));
const _appearance = ModuleOrigin(ModuleId('appearance'));

/// A role whose template gives the settings screen an entry, as a role with
/// a setting of its own does.
final _languageRole = TestRole<NoDsl>('language', uses: {settingsScreenRole});

/// The routes of the module `settings`: the screen at `/`, a page below
/// it, and a page that needs a value, with a page below that one.
RoleData<Object> get _routes => dataOf(
      routerRole,
      const RoutesData([
        Route(
          '/',
          name: 'settings',
          screen: ScreenRef(
            'SettingsScreen',
            import: ImportRef.app('features/settings/settings_screen.dart'),
          ),
          children: [
            Route(
              'licenses',
              name: 'licenses',
              screen: ScreenRef(
                'LicensesScreen',
                import: ImportRef.app('features/settings/licenses_screen.dart'),
              ),
            ),
          ],
        ),
        Route(
          '/accounts/:id',
          name: 'account',
          screen: ScreenRef(
            'AccountScreen',
            import: ImportRef.app('features/settings/account_screen.dart'),
          ),
          params: [RouteParam.path('id', type: int)],
          children: [
            Route(
              'limits',
              name: 'limits',
              screen: ScreenRef(
                'LimitsScreen',
                import: ImportRef.app('features/settings/limits_screen.dart'),
              ),
            ),
          ],
        ),
      ]),
      module: 'settings',
    );

/// The route [name] that the module [module] names as the settings screen.
RoleData<Object> _screenRoute(String name, {String module = 'settings'}) =>
    dataOf(settingsScreenRole, SettingsScreenRoute(name), module: module);

/// [entry] as the module [module] contributes it.
RoleData<Object> _entryOf(SettingsEntry entry, {required String module}) =>
    dataOf(settingsScreenRole, entry, module: module);

/// [entry] as the template of [role] contributes it.
RoleData<Object> _entryOfRole(SettingsEntry entry, Role role) =>
    settingsScreenRole.data(entry).withOrigin(RoleTemplateOrigin(role));

/// The input of the hooks of the settings screen role in an app with
/// [data] and a router.
RoleHookInput<SettingsData> _input(List<RoleData<Object>> data) =>
    inputOf(settingsScreenRole, data: data, present: {routerRole});

/// A feature that provides the settings screen role.
const _provider = ModuleDescriptor(
  id: ModuleId('settings'),
  description: 'Settings',
  kind: ModuleKinds.feature,
  providers: [RoleProvider.plain(settingsScreenRole)],
);

/// A module with a setting, which uses the role.
const _contributor = ModuleDescriptor(
  id: ModuleId('appearance'),
  description: 'Appearance',
  kind: ModuleKinds.infrastructure,
  uses: {settingsScreenRole},
);

/// A brick named [name] with a file at each of [paths].
BrickContribution _brick(
  List<String> paths, {
  String name = 'brick',
  Set<Role> when = const {},
}) =>
    BrickContribution(
      MasonBundle(
        name: name,
        description: name,
        version: '0.1.0',
        files: [
          for (final path in paths)
            MasonBundledFile(
              path,
              base64.encode(utf8.encode('// A file of the tests.\n')),
              'text',
            ),
        ],
      ),
      when: when,
    );

/// The issues of the module rules of the role for [module], which
/// contributes [contributions], in an app with a router where the roles in
/// [present] are present too and other contributors give the role [others].
List<SmfIssue> _moduleIssues(
  ModuleDescriptor module,
  List<Contribution> contributions, {
  List<RoleData<Object>> others = const [],
  Set<Role> present = const {},
}) {
  final origin = ModuleOrigin(module.id);
  // The pipeline gives each data its origin when it collects it.
  final own = [
    for (final contribution in contributions)
      if (contribution is RoleData<Object>)
        contribution.withOrigin(origin)
      else
        contribution,
  ];
  return settingsScreenRole.checkModule(
    ModuleRuleRequest(
      hook: RoleHookRequest(
        data: [...own.whereType<RoleData<Object>>(), ...others],
        presentRoles: {settingsScreenRole, routerRole, ...present},
        context: testContext,
      ),
      module: module,
      contributions: own,
    ),
  );
}

/// The index of the file at [path] that declares the widget class [name]
/// with one unnamed constructor, which takes [parameters] and is `const`
/// unless [isConst] is `false`.
DartFileIndex _widgetFile(
  String path,
  String name, {
  List<IndexedParameter> parameters = const [
    IndexedParameter('key', kind: ParameterKind.optionalNamed),
  ],
  bool isConst = true,
}) =>
    DartFileIndex(
      path: path,
      declarations: [
        IndexedDeclaration(
          name: name,
          kind: DeclarationKind.classType,
          constructors: [
            IndexedConstructor(parameters: parameters, isConst: isConst),
          ],
        ),
      ],
    );

/// The issues of the structural rules of the role in an app with [data],
/// the [files] with their [owners], and [modules].
List<SmfIssue> _structureIssues(
  List<RoleData<Object>> data, {
  required List<DartFileIndex> files,
  Map<String, ContributionOrigin> owners = const {},
  List<ModuleDescriptor> modules = const [],
}) =>
    settingsScreenRole.checkStructure(
      StructuralRuleRequest(
        hook: RoleHookRequest(
          data: data,
          presentRoles: {settingsScreenRole, routerRole},
          context: testContext,
        ),
        files: {for (final file in files) file.path: file},
        owners: owners,
        modules: modules,
      ),
    );

void main() {
  group('SettingsEntry', () {
    test('names a widget of a file of the app', () {
      expect(_theme.widget.name, 'ThemeSetting');
      expect(_theme.file, _themePath);
      expect(_theme.problems(), isEmpty);
      expect('$_theme', 'settings entry ThemeSetting');
    });

    test('is a widget of the app, not of a package or of dart:core', () {
      const ofPackage = SettingsEntry(
        widget: TypeRef(
          'AboutListTile',
          import: ImportRef('package:flutter/material.dart'),
        ),
      );
      const ofCore = SettingsEntry(widget: TypeRef('Object'));

      for (final entry in [ofPackage, ofCore]) {
        expect(entry.file, isNull);
        expect(
          entry.problems().single,
          'The widget ${entry.widget.name} of a settings entry must be a '
          'class of a file of the app, imported with ImportRef.app.',
        );
      }
    });

    test('reports the problems of its reference', () {
      const entry = SettingsEntry(
        widget: TypeRef('_Private', import: ImportRef.app('lib/a.dart')),
      );

      expect(entry.problems(), [
        contains('"_Private" is not a public Dart type name'),
        contains('The app import "lib/a.dart" must be a .dart path below lib/'),
      ]);
    });
  });

  test('SettingsScreenRoute names a route of the provider', () {
    const route = SettingsScreenRoute('settings');

    expect(route.name, 'settings');
    expect('$route', 'settings screen route "settings"');
  });

  group('the settings screen role', () {
    test('has at most one provider and requires the router', () {
      expect(settingsScreenRole.id, 'settings_screen');
      expect(settingsScreenRole.description, 'Settings screen');
      expect('$settingsScreenRole', 'settings screen role');
      expect(settingsScreenRole.presenceFlag, 'has_settings_screen');
      expect(settingsScreenRole.cardinality, RoleCardinality.atMostOne);
      expect(settingsScreenRole.requires, {routerRole});
      expect(settingsScreenRole.uses, isEmpty);
    });

    test(
        'guarantees no file and no symbol: the screen is a route of the '
        'provider', () {
      expect(settingsScreenRole.sockets, isEmpty);
      expect(settingsScreenRole.socketFamilies, isEmpty);
      expect(settingsScreenRole.options, isEmpty);
      expect(settingsScreenRole.interface.files, isEmpty);
      expect(settingsScreenRole.interface.symbols, isEmpty);
    });

    test('takes entries and the route of the screen as its data', () {
      expect(settingsScreenRole.accepts(_theme), isTrue);
      expect(
        settingsScreenRole.accepts(const SettingsScreenRoute('settings')),
        isTrue,
      );
      expect(settingsScreenRole.accepts('ThemeSetting'), isFalse);
    });

    test('has two module rules and two structural rules', () {
      expect(
        settingsScreenRole.moduleRules.map((rule) => rule.id),
        ['settings_screen.entries', 'settings_screen.route'],
      );
      expect(
        settingsScreenRole.structuralRules.map((rule) => rule.id),
        ['settings_screen.entry_widgets', 'settings_screen.entries_rendered'],
      );
      for (final description in [
        ...settingsScreenRole.moduleRules.map((rule) => rule.description),
        ...settingsScreenRole.structuralRules.map((rule) => rule.description),
      ]) {
        expect(description, endsWith('.'));
      }
    });
  });

  group('SettingsScreenRole.entriesIn', () {
    test(
        'lists the entries in the order of the data, and those of one '
        'contributor in its order', () {
      final input = _input([
        _entryOf(_account, module: 'account'),
        _screenRoute('settings'),
        _entryOf(_theme, module: 'appearance'),
        _entryOf(_language, module: 'appearance'),
      ]);

      expect(
        settingsScreenRole.entriesIn(input),
        [same(_account), same(_theme), same(_language)],
      );
    });

    test('has the entries of the templates of roles too', () {
      final input = _input([
        _entryOf(_theme, module: 'appearance'),
        _entryOfRole(_language, _languageRole),
      ]);

      expect(settingsScreenRole.entriesIn(input), [_theme, _language]);
    });

    test('leaves out an entry whose condition does not hold', () {
      List<SettingsEntry> entries({required Set<Role> present}) =>
          settingsScreenRole.entriesIn(
            inputOf(
              settingsScreenRole,
              data: [
                settingsScreenRole.data(_theme),
                settingsScreenRole.data(_account, when: {diRole}),
              ],
              present: {routerRole, ...present},
            ),
          );

      expect(entries(present: const {}), [_theme]);
      expect(entries(present: {diRole}), [_theme, _account]);
    });

    test('is empty in an app whose modules have no settings', () {
      expect(
        settingsScreenRole.entriesIn(_input([_screenRoute('settings')])),
        isEmpty,
      );
    });

    test('reads the entries for a role that uses the settings screen', () {
      final request = RoleHookRequest(
        data: [_entryOfRole(_language, _languageRole)],
        presentRoles: {settingsScreenRole, _languageRole},
        context: testContext,
      );

      expect(
        settingsScreenRole.entriesIn(_languageRole.hookInput(request)),
        [_language],
      );
      expect(
        () => settingsScreenRole.entriesIn(diRole.hookInput(request)),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('neither requires nor uses the settings screen role'),
          ),
        ),
      );
    });
  });

  group('SettingsScreenRole.screenIn', () {
    test('is the route that the provider names, among its routes', () {
      final screen = settingsScreenRole.screenIn(
        _input([
          _routes,
          _entryOf(_theme, module: 'appearance'),
          _screenRoute('settings'),
        ]),
      )!;

      expect(screen.fullPath, '/settings');
      expect(screen.fullName, 'settings.settings');
      expect(screen.route.screen.className, 'SettingsScreen');
      expect(screen.route.screen.file, _screenPath);
      expect(screen.hasRequiredParams, isFalse);
    });

    test('may be a page below another route', () {
      final screen = settingsScreenRole
          .screenIn(_input([_routes, _screenRoute('licenses')]))!;

      expect(screen.fullPath, '/settings/licenses');
      expect(screen.parent!.fullPath, '/settings');
    });

    test('is a route of the module that names it, not of another', () {
      expect(
        settingsScreenRole.screenIn(
          _input([_routes, _screenRoute('settings', module: 'account')]),
        ),
        isNull,
      );
    });

    test('is missing when no module names it or the name is of no route', () {
      expect(settingsScreenRole.screenIn(_input([_routes])), isNull);
      expect(
        settingsScreenRole
            .screenIn(_input([_routes, _screenRoute('preferences')])),
        isNull,
      );
      expect(
        settingsScreenRole.screenIn(_input([_screenRoute('settings')])),
        isNull,
      );
    });

    test('is not what the template of a role names', () {
      expect(
        settingsScreenRole.screenIn(
          _input([
            _routes,
            settingsScreenRole
                .data(const SettingsScreenRoute('settings'))
                .withOrigin(RoleTemplateOrigin(_languageRole)),
          ]),
        ),
        isNull,
      );
    });
  });

  group('the template of the settings screen role', () {
    final template = settingsScreenRole.template;

    test('adds nothing to the app: it only checks the data of the role', () {
      expect(template.contribute(testContext), isEmpty);
      expect(template.render(_input([_screenRoute('settings')])).vars, isEmpty);
    });

    test('accepts the entries of modules and of the templates of roles', () {
      expect(
        template.validate(
          _input([
            _screenRoute('settings'),
            _entryOf(_theme, module: 'appearance'),
            _entryOf(_account, module: 'appearance'),
            _entryOfRole(_language, _languageRole),
          ]),
        ),
        isEmpty,
      );
    });

    test('reports the problems of an entry with its contributor', () {
      const outside = SettingsEntry(
        widget: TypeRef(
          'AboutListTile',
          import: ImportRef('package:flutter/material.dart'),
        ),
      );
      final issues = template.validate(
        _input([
          _entryOf(outside, module: 'appearance'),
          _entryOfRole(
            const SettingsEntry(
              widget: TypeRef('language', import: ImportRef.app('/a.dart')),
            ),
            _languageRole,
          ),
        ]),
      );

      expect(
        [for (final issue in issues) issue.message],
        [
          contains('The widget AboutListTile of a settings entry must be'),
          contains('The app import "/a.dart" must be a .dart path below lib/'),
        ],
      );
      expect(
        [for (final issue in issues) issue.origin],
        [_appearance, RoleTemplateOrigin(_languageRole)],
      );
    });

    test('rejects an entry that two contributors give, or one twice', () {
      final issues = template.validate(
        _input([
          _entryOf(_theme, module: 'appearance'),
          _entryOf(_language, module: 'appearance'),
          // The same widget, whatever prefix its import has.
          _entryOfRole(
            const SettingsEntry(
              widget: TypeRef(
                'LanguageSetting',
                import: ImportRef.app(
                  'core/l10n/language_setting.dart',
                  prefix: 'l10n',
                ),
              ),
            ),
            _languageRole,
          ),
          _entryOf(_theme, module: 'appearance'),
        ]),
      );

      const language = 'The settings entry LanguageSetting of $_languagePath '
          'is contributed twice, by appearance and by role:language.';
      const theme = 'The settings entry ThemeSetting of $_themePath is '
          'contributed twice, by appearance and by appearance.';
      expect([for (final issue in issues) issue.message], [language, theme]);
      expect(
        [for (final issue in issues) issue.origin],
        [RoleTemplateOrigin(_languageRole), _appearance],
      );
      expect(issues.first.hint, contains('shows each entry once'));
    });

    test('tells apart widgets of the same name in different files', () {
      expect(
        template.validate(
          _input([
            _entryOf(_theme, module: 'appearance'),
            _entryOf(
              const SettingsEntry(
                widget: TypeRef(
                  'ThemeSetting',
                  import: ImportRef.app('features/account/theme_setting.dart'),
                ),
              ),
              module: 'account',
            ),
          ]),
        ),
        isEmpty,
      );
    });

    test('rejects a route of the screen that no module names', () {
      final issue = template
          .validate(
            _input([
              _screenRoute('settings'),
              settingsScreenRole
                  .data(const SettingsScreenRoute('language'))
                  .withOrigin(RoleTemplateOrigin(_languageRole)),
            ]),
          )
          .single;

      expect(
        issue.message,
        'Only the module that provides the settings screen role names the '
        'route of the settings screen, not role:language.',
      );
      expect(issue.origin, RoleTemplateOrigin(_languageRole));
    });
  });

  group('the module rule settings_screen.entries', () {
    test('accepts entries whose files the bricks of the module generate', () {
      expect(
        _moduleIssues(_contributor, [
          settingsScreenRole.data(_theme),
          settingsScreenRole.data(_language),
          _brick([_themePath], when: {settingsScreenRole}),
          _brick(
            ['lib/core/l10n/language_names.dart', _languagePath],
            when: {settingsScreenRole},
          ),
        ]),
        isEmpty,
      );
    });

    test('rejects an entry whose file the bricks do not generate', () {
      final issue = _moduleIssues(_contributor, [
        settingsScreenRole.data(_theme),
        settingsScreenRole.data(_language),
        _brick([_themePath], when: {settingsScreenRole}),
      ]).single;

      expect(
        issue.message,
        'The widget LanguageSetting of a settings entry is in '
        '$_languagePath, which the bricks of the module do not generate.',
      );
      expect(issue.hint, contains('when: {settingsScreenRole}'));
      expect(issue.origin, _appearance);
      expect(issue.path, _languagePath);
    });

    test('counts only the bricks that apply in the app', () {
      const module = ModuleDescriptor(
        id: ModuleId('appearance'),
        description: 'Appearance',
        kind: ModuleKinds.infrastructure,
        uses: {settingsScreenRole, diRole},
      );
      final contributions = [
        settingsScreenRole.data(_theme),
        _brick([_themePath], when: {settingsScreenRole, diRole}),
      ];

      expect(
        _moduleIssues(module, contributions).single.message,
        contains('which the bricks of the module do not generate'),
      );
      expect(_moduleIssues(module, contributions, present: {diRole}), isEmpty);
    });

    test(
        'rejects a brick of a module that only uses the role which generates '
        'the widget of an entry in an app without a settings screen', () {
      const module = ModuleDescriptor(
        id: ModuleId('appearance'),
        description: 'Appearance',
        kind: ModuleKinds.infrastructure,
        uses: {settingsScreenRole, diRole},
      );
      final issues = _moduleIssues(
        module,
        [
          settingsScreenRole.data(_theme),
          settingsScreenRole.data(_language),
          settingsScreenRole.data(_account),
          _brick([_themePath], name: 'appearance'),
          // A condition, but not the one of the settings screen.
          _brick([_languagePath], name: 'appearance_services', when: {diRole}),
          _brick(
            [_accountPath],
            name: 'appearance_settings',
            when: {settingsScreenRole},
          ),
        ],
        present: {diRole},
      );

      String message(String brick, String path, String widget) =>
          'The brick $brick of the module generates $path, the file of the '
          'widget $widget of a settings entry, in an app without a settings '
          'screen too: the module only uses the settings screen role, and '
          'the brick does not name it in its when.';
      expect(
        [for (final issue in issues) issue.message],
        [
          message('appearance', _themePath, 'ThemeSetting'),
          message('appearance_services', _languagePath, 'LanguageSetting'),
        ],
      );
      expect(
        [for (final issue in issues) issue.path],
        [_themePath, _languagePath],
      );
      expect(issues.map((issue) => issue.origin), everyElement(_appearance));
      expect(issues.first.hint, contains('when: {settingsScreenRole}'));
    });

    test(
        'asks no condition of the bricks of a module that is only in apps '
        'with a settings screen', () {
      // A module that requires the role, as the provider of the role, whose
      // entries another test checks, is never in an app without it.
      const module = ModuleDescriptor(
        id: ModuleId('appearance'),
        description: 'Appearance',
        kind: ModuleKinds.infrastructure,
        requires: {settingsScreenRole},
      );

      expect(
        _moduleIssues(module, [
          settingsScreenRole.data(_theme),
          _brick([_themePath]),
        ]),
        isEmpty,
      );
    });

    test('does not count the files of other contributors', () {
      final issue = _moduleIssues(
        _contributor,
        [settingsScreenRole.data(_theme)],
        others: [_entryOf(_account, module: 'account')],
      ).single;

      expect(issue.message, contains('The widget ThemeSetting'));
    });

    test('leaves an entry outside the app to the template of the role', () {
      expect(
        _moduleIssues(_contributor, [
          settingsScreenRole.data(
            const SettingsEntry(
              widget: TypeRef(
                'AboutListTile',
                import: ImportRef('package:flutter/material.dart'),
              ),
            ),
          ),
        ]),
        isEmpty,
      );
    });

    test('checks the entries of the provider of the role too', () {
      final contributions = [
        routerRole.data(_routes.value as RoutesData),
        settingsScreenRole.data(const SettingsScreenRoute('settings')),
        settingsScreenRole.data(_account),
      ];

      expect(
        _moduleIssues(_provider, contributions).single.message,
        contains('The widget AccountSettings of a settings entry is in'),
      );
      expect(
        _moduleIssues(_provider, [
          ...contributions,
          _brick([_accountPath]),
        ]),
        isEmpty,
      );
    });
  });

  group('the module rule settings_screen.route', () {
    /// The issues for the provider, which contributes its routes and
    /// [named].
    List<SmfIssue> ofProvider(List<String> named) => _moduleIssues(_provider, [
          routerRole.data(_routes.value as RoutesData),
          for (final name in named)
            settingsScreenRole.data(SettingsScreenRoute(name)),
        ]);

    test('accepts a provider that names a route of its own', () {
      expect(ofProvider(['settings']), isEmpty);
      expect(ofProvider(['licenses']), isEmpty);
    });

    test('rejects a provider that names no route, or two', () {
      for (final (named, count) in [
        (<String>[], 0),
        (['settings', 'licenses'], 2),
      ]) {
        final issue = ofProvider(named).single;

        expect(
          issue.message,
          'The provider of the settings screen role names exactly one route '
          'as the settings screen, but the module names $count.',
        );
        expect(issue.hint, contains('SettingsScreenRoute'));
        expect(issue.origin, _settings);
      }
    });

    test('rejects a name that is of no route of the provider', () {
      final issue = ofProvider(['preferences']).single;

      expect(
        issue.message,
        'The module names its route "preferences" as the settings screen, '
        'but declares no route of that name.',
      );
      expect(issue.origin, _settings);
    });

    test('rejects the route of another module', () {
      final issue = _moduleIssues(
        const ModuleDescriptor(
          id: ModuleId('account'),
          description: 'Account',
          kind: ModuleKinds.feature,
          providers: [RoleProvider.plain(settingsScreenRole)],
        ),
        [settingsScreenRole.data(const SettingsScreenRoute('settings'))],
        others: [_routes],
      ).single;

      expect(issue.message, contains('but declares no route of that name'));
      expect(issue.origin, const ModuleOrigin(ModuleId('account')));
    });

    test('rejects a route that needs values, its own or of a route above it',
        () {
      for (final (name, path) in [
        ('account', '/settings/accounts/:id'),
        // The page has no parameter of its own: the value is of its parent.
        ('limits', '/settings/accounts/:id/limits'),
      ]) {
        final issue = ofProvider([name]).single;

        expect(
          issue.message,
          'The route "$name" ($path) of the settings screen needs :id; the '
          'settings screen is reached without values.',
        );
        expect(issue.origin, _settings);
      }
    });

    test('rejects a module that names the route without providing the role',
        () {
      final issue = _moduleIssues(
        _contributor,
        [settingsScreenRole.data(const SettingsScreenRoute('settings'))],
        others: [_routes, _screenRoute('settings')],
      ).single;

      expect(
        issue.message,
        'The module names the route of the settings screen, which only the '
        'provider of the settings screen role does.',
      );
      expect(issue.origin, _appearance);
    });

    test('asks nothing of a module that only has entries', () {
      expect(
        _moduleIssues(
          _contributor,
          [
            settingsScreenRole.data(_theme),
            _brick([_themePath], when: {settingsScreenRole}),
          ],
          others: [_routes, _screenRoute('settings')],
        ),
        isEmpty,
      );
    });
  });

  group('the structural rule settings_screen.entry_widgets', () {
    test(
        'accepts a class with a const constructor that requires nothing, in '
        'a file of its contributor', () {
      expect(
        _structureIssues(
          [
            _entryOf(_theme, module: 'appearance'),
            _entryOf(_account, module: 'account'),
            _entryOfRole(_language, _languageRole),
          ],
          files: [
            _widgetFile(_themePath, 'ThemeSetting'),
            // The implicit default constructor of an enum-like widget is
            // not const, so the class declares one; optional parameters
            // are fine.
            _widgetFile(
              _accountPath,
              'AccountSettings',
              parameters: const [
                IndexedParameter('dense', kind: ParameterKind.optionalNamed),
                IndexedParameter('key', kind: ParameterKind.optionalNamed),
              ],
            ),
            _widgetFile(_languagePath, 'LanguageSetting'),
          ],
          owners: {
            _themePath: _appearance,
            // A brick of the variant of the module for a state manager.
            _accountPath: const ModuleOrigin(
              ModuleId('account'),
              variant: ModuleId('bloc'),
            ),
            _languagePath: RoleTemplateOrigin(_languageRole),
          },
        ),
        isEmpty,
      );
    });

    test('rejects a missing file and a missing class', () {
      final issues = _structureIssues(
        [
          _entryOf(_theme, module: 'appearance'),
          _entryOf(_language, module: 'appearance'),
        ],
        files: [_widgetFile(_languagePath, 'LocaleSetting')],
        owners: const {_languagePath: _appearance},
      );

      expect(
        [for (final issue in issues) issue.message],
        [
          '$_themePath is missing, so it cannot declare class ThemeSetting.',
          '$_languagePath does not declare class LanguageSetting.',
        ],
      );
      expect(
        [for (final issue in issues) issue.path],
        [_themePath, _languagePath],
      );
      expect(issues.map((issue) => issue.origin), everyElement(_appearance));
      expect(
        issues.first.hint,
        'The provider of the settings screen role creates the widget of an '
        'entry as a constant, without arguments.',
      );
    });

    test('rejects a widget that cannot be created as a constant', () {
      final issue = _structureIssues(
        [_entryOf(_theme, module: 'appearance')],
        files: [_widgetFile(_themePath, 'ThemeSetting', isConst: false)],
      ).single;

      expect(
        issue.message,
        'class ThemeSetting in $_themePath must have a const unnamed '
        'constructor.',
      );
    });

    test('rejects a widget that requires arguments', () {
      final issues = _structureIssues(
        [_entryOf(_theme, module: 'appearance')],
        files: [
          _widgetFile(
            _themePath,
            'ThemeSetting',
            parameters: const [
              IndexedParameter(
                'controller',
                kind: ParameterKind.requiredPositional,
              ),
              IndexedParameter('title', kind: ParameterKind.requiredNamed),
            ],
          ),
        ],
      );

      expect(
        [for (final issue in issues) issue.message],
        [
          contains('must not require more than 0 positional arguments'),
          contains('must not require the parameter title'),
        ],
      );
    });

    test('rejects a widget in a file of another contributor', () {
      final issues = _structureIssues(
        [
          _entryOf(_theme, module: 'account'),
          _entryOf(_language, module: 'appearance'),
          _entryOfRole(_account, _languageRole),
        ],
        files: [
          _widgetFile(_themePath, 'ThemeSetting'),
          _widgetFile(_languagePath, 'LanguageSetting'),
          _widgetFile(_accountPath, 'AccountSettings'),
        ],
        owners: {
          _themePath: _appearance,
          _languagePath: RoleTemplateOrigin(_languageRole),
          _accountPath: const RoleTemplateOrigin(routerRole),
        },
      );

      const own = 'an entry shows a widget of its own contributor.';
      const theme = 'The widget ThemeSetting of a settings entry of account '
          'is in $_themePath, a file of appearance; $own';
      const language = 'The widget LanguageSetting of a settings entry of '
          'appearance is in $_languagePath, a file of role:language; $own';
      const account = 'The widget AccountSettings of a settings entry of '
          'role:language is in $_accountPath, a file of role:router; $own';
      expect(
        [for (final issue in issues) issue.message],
        [theme, language, account],
      );
      expect(
        [for (final issue in issues) issue.origin],
        [
          const ModuleOrigin(ModuleId('account')),
          _appearance,
          RoleTemplateOrigin(_languageRole),
        ],
      );
      expect(issues.first.path, _themePath);
    });

    test('leaves an entry outside the app to the template of the role', () {
      expect(
        _structureIssues(
          [
            _entryOf(
              const SettingsEntry(widget: TypeRef('Object')),
              module: 'appearance',
            ),
          ],
          files: const [],
        ),
        isEmpty,
      );
    });
  });

  group('the structural rule settings_screen.entries_rendered', () {
    const helpersPath = 'lib/features/settings/more_settings.dart';

    final data = [
      _routes,
      _screenRoute('settings'),
      _entryOf(_theme, module: 'appearance'),
      _entryOf(_language, module: 'appearance'),
    ];

    /// The issues in an app where the module `appearance` has two entries
    /// and the module `settings`, the provider of the role unless
    /// [withProvider] is `false`, generates [files].
    List<SmfIssue> check(
      List<DartFileIndex> files, {
      bool withProvider = true,
    }) =>
        _structureIssues(
          data,
          files: [
            _widgetFile(_themePath, 'ThemeSetting'),
            // A file of the contributor that creates its own widgets,
            // which shows no entry, since only the provider of the role
            // does.
            DartFileIndex(
              path: _languagePath,
              imports: const [IndexedImport('../theme/theme_setting.dart')],
              declarations:
                  _widgetFile(_languagePath, 'LanguageSetting').declarations,
              invocations: const [
                IndexedInvocation('ThemeSetting'),
                IndexedInvocation('LanguageSetting'),
              ],
            ),
            ...files,
          ],
          owners: {
            _themePath: _appearance,
            _languagePath: _appearance,
            for (final file in files) file.path: _settings,
          },
          modules: [if (withProvider) _provider, _contributor],
        );

    /// The file of the screen, which imports the files of the entries with
    /// the prefixes `entry0` and `entry1` and creates [created] through
    /// them.
    DartFileIndex screen(List<IndexedInvocation> created) => DartFileIndex(
          path: _screenPath,
          imports: const [
            IndexedImport(
              'package:my_app/core/theme/theme_setting.dart',
              prefix: 'entry0',
            ),
            IndexedImport(
              'package:my_app/core/l10n/language_setting.dart',
              prefix: 'entry1',
            ),
          ],
          invocations: created,
        );

    test('accepts a provider whose files create the widget of every entry', () {
      expect(
        check([
          screen(const [
            IndexedInvocation('ThemeSetting', target: 'entry0'),
            IndexedInvocation('LanguageSetting', target: 'entry1'),
          ]),
        ]),
        isEmpty,
      );
      // In any of its files, by a relative URI too, under any prefix that
      // only the import of the file of the entry has.
      expect(
        check([
          screen(const [IndexedInvocation('ThemeSetting', target: 'entry0')]),
          const DartFileIndex(
            path: helpersPath,
            imports: [
              IndexedImport('package:flutter/material.dart'),
              IndexedImport(
                '../../core/l10n/language_setting.dart',
                prefix: 'language',
              ),
            ],
            invocations: [
              IndexedInvocation('LanguageSetting', target: 'language'),
            ],
          ),
        ]),
        isEmpty,
      );
    });

    test('reports an entry that no file of the provider creates', () {
      final issue = check([
        screen(const [IndexedInvocation('ThemeSetting', target: 'entry0')]),
      ]).single;

      expect(
        issue.message,
        'The provider of the settings screen role does not render the '
        'settings entry LanguageSetting: none of its files creates '
        'LanguageSetting through an import of $_languagePath with a prefix '
        'of its own.',
      );
      expect(issue.hint, contains('SettingsScreenRole.entriesIn()'));
      expect(issue.hint, contains('a prefix that no import of another file'));
      // The contributor of the entry, which the app would not show.
      expect(issue.origin, _appearance);
      expect(issue.path, _screenPath);
    });

    test(
        'reports an entry that is created through an import without a prefix '
        'of its own', () {
      List<String> entriesOf(List<DartFileIndex> files) => [
            for (final issue in check(files))
              RegExp(r'the settings entry (\w+):')
                  .firstMatch(issue.message)!
                  .group(1)!,
          ];

      // Without a prefix, a widget of the same name in the file of another
      // entry would make the name ambiguous, and the app would not compile.
      expect(
        entriesOf([
          screen(const [IndexedInvocation('ThemeSetting', target: 'entry0')]),
          const DartFileIndex(
            path: helpersPath,
            imports: [IndexedImport('../../core/l10n/language_setting.dart')],
            invocations: [IndexedInvocation('LanguageSetting')],
          ),
        ]),
        ['LanguageSetting'],
      );
      // So would one prefix for the files of two entries.
      expect(
        entriesOf([
          const DartFileIndex(
            path: _screenPath,
            imports: [
              IndexedImport(
                'package:my_app/core/theme/theme_setting.dart',
                prefix: 'entries',
              ),
              IndexedImport(
                'package:my_app/core/l10n/language_setting.dart',
                prefix: 'entries',
              ),
            ],
            invocations: [
              IndexedInvocation('ThemeSetting', target: 'entries'),
              IndexedInvocation('LanguageSetting', target: 'entries'),
            ],
          ),
        ]),
        ['ThemeSetting', 'LanguageSetting'],
      );
      // And a prefix that the import of a library of a package shares.
      expect(
        entriesOf([
          const DartFileIndex(
            path: _screenPath,
            imports: [
              IndexedImport('package:flutter/material.dart', prefix: 'entry0'),
              IndexedImport(
                'package:my_app/core/theme/theme_setting.dart',
                prefix: 'entry0',
              ),
              IndexedImport(
                'package:my_app/core/l10n/language_setting.dart',
                prefix: 'entry1',
              ),
            ],
            invocations: [
              IndexedInvocation('ThemeSetting', target: 'entry0'),
              IndexedInvocation('LanguageSetting', target: 'entry1'),
            ],
          ),
        ]),
        ['ThemeSetting'],
      );
    });

    test('counts a creation of the widget, not a mention of its name', () {
      final issues = check([
        DartFileIndex(
          path: _screenPath,
          imports: screen(const []).imports,
          // The types of the widgets, which the file reads and never
          // creates.
          memberAccesses: const [
            IndexedMemberAccess('entry0', 'ThemeSetting'),
            IndexedMemberAccess('entry1', 'LanguageSetting'),
          ],
        ),
      ]);

      expect(
        [for (final issue in issues) issue.message],
        [
          contains('the settings entry ThemeSetting'),
          contains('the settings entry LanguageSetting'),
        ],
      );
    });

    test(
        'takes a creation for the entry of its file alone, among widgets of '
        'one name', () {
      const otherPath = 'lib/features/account/theme_setting.dart';
      const account = ModuleOrigin(ModuleId('account'));
      List<SmfIssue> issues(List<IndexedInvocation> created) =>
          _structureIssues(
            [
              _routes,
              _screenRoute('settings'),
              _entryOf(_theme, module: 'appearance'),
              _entryOf(
                const SettingsEntry(
                  widget: TypeRef(
                    'ThemeSetting',
                    import:
                        ImportRef.app('features/account/theme_setting.dart'),
                  ),
                ),
                module: 'account',
              ),
            ],
            files: [
              _widgetFile(_themePath, 'ThemeSetting'),
              _widgetFile(otherPath, 'ThemeSetting'),
              DartFileIndex(
                path: _screenPath,
                imports: const [
                  IndexedImport(
                    'package:my_app/core/theme/theme_setting.dart',
                    prefix: 'entry0',
                  ),
                  IndexedImport(
                    'package:my_app/features/account/theme_setting.dart',
                    prefix: 'entry1',
                  ),
                ],
                invocations: created,
              ),
            ],
            owners: const {
              _themePath: _appearance,
              otherPath: account,
              _screenPath: _settings,
            },
            modules: const [_provider, _contributor],
          );

      // The widget of one file, twice: the entry of the other file is not
      // on the screen.
      final issue = issues(const [
        IndexedInvocation('ThemeSetting', target: 'entry0'),
        IndexedInvocation('ThemeSetting', target: 'entry0'),
      ]).single;
      expect(
        issue.message,
        contains('creates ThemeSetting through an import of $otherPath'),
      );
      expect(issue.origin, account);
      expect(
        issues(const [
          IndexedInvocation('ThemeSetting', target: 'entry0'),
          IndexedInvocation('ThemeSetting', target: 'entry1'),
        ]),
        isEmpty,
      );
    });

    test('counts only the widgets of the files that the entries name', () {
      final issues = check([
        const DartFileIndex(
          path: _screenPath,
          imports: [
            IndexedImport('package:my_app/core/other.dart'),
            IndexedImport(
              'package:my_app/core/l10n/language_setting.dart',
              prefix: 'entry1',
            ),
          ],
          invocations: [
            // Of other.dart, which the file imports without a prefix.
            IndexedInvocation('ThemeSetting'),
            // Through a prefix that is not of the file of the entry.
            IndexedInvocation('LanguageSetting', target: 'entry0'),
          ],
        ),
      ]);

      expect(
        [for (final issue in issues) issue.message],
        [
          contains('the settings entry ThemeSetting'),
          contains('the settings entry LanguageSetting'),
        ],
      );
    });

    test('names no file when the provider names no route', () {
      final issues = _structureIssues(
        [_entryOf(_theme, module: 'appearance')],
        files: [_widgetFile(_themePath, 'ThemeSetting')],
        owners: const {_themePath: _appearance},
        modules: const [_provider, _contributor],
      );

      expect(issues.single.message, contains('does not render'));
      expect(issues.single.path, isNull);
    });

    test(
        'checks the files of a provider among the modules, and nothing '
        'without one', () {
      expect(check(const []), hasLength(2));
      expect(check(const [], withProvider: false), isEmpty);
    });

    test('leaves an entry outside the app to the template of the role', () {
      expect(
        _structureIssues(
          [
            _entryOf(
              const SettingsEntry(widget: TypeRef('Object')),
              module: 'appearance',
            ),
          ],
          files: const [],
          modules: const [_provider, _contributor],
        ),
        isEmpty,
      );
    });
  });
}
