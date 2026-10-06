// The tests that the matrix of CI adds to the apps of the modules of
// `smf create` (smfAppTests, which tool/matrix.dart runs). CI runs them
// only in its job with Flutter, which checks that they apply to some app
// and that they check the contract of their roles with every provider
// only at its end; these tests check the same without Flutter.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_flutter_cli/matrix_app_tests.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

/// The codes of the languages of the file of the texts of the onboarding
/// that the matrix writes for an app, [file], in the order of the file.
List<String> _languagesOf(String file) => [
      for (final language
          in RegExp(r"^  '(\w+)': \{$", multiLine: true).allMatches(file))
        language[1]!,
    ];

/// The full names of the routes of the locations that the walk of the
/// routes goes to, in its order, from the file that the matrix writes for
/// it, [file].
List<String> _walkedRoutesOf(String file) {
  const start = 'const List<WalkedLocation> walkedLocations = [';
  final list = file.substring(file.indexOf(start) + start.length);
  return [
    for (final route in RegExp(r"^    route: '([\w.]+)',$", multiLine: true)
        .allMatches(list.substring(0, list.indexOf('\n];'))))
      route[1]!,
  ];
}

void main() {
  late MatrixAppTests appTests;
  late List<MatrixApp> apps;

  setUpAll(() async {
    appTests = await smfAppTests();
    final (apps: matrix, :failed) = await matrixOf(smfModules);
    expect(failed, isEmpty);
    apps = matrix;
  });

  /// The app test whose files are in the directory [name].
  MatrixAppTest named(String name) =>
      appTests.tests.singleWhere((test) => p.basename(test.directory) == name);

  test('each app test applies to an app of the matrix', () {
    expect(appTests.tests, isNotEmpty);
    for (final test in appTests.tests) {
      expect(apps.where(test.appliesTo), isNotEmpty, reason: test.directory);
    }
  });

  test(
      'the app tests check the contract of the router role, of the DI role, '
      'of the events role, of the preferences role, of the settings screen '
      'role, of the theme role, of the localization role and of the app '
      'entry role with every provider of each, which they tell apart by the '
      'roles of the app only', () {
    expect(
      appTests.testedRoles,
      containsAll([
        routerRole,
        diRole,
        eventsRole,
        preferencesRole,
        settingsScreenRole,
        themeRole,
        appEntryRole,
        localizationRole,
      ]),
    );
    expect(named('screen_views').roles, contains(routerRole));
    expect(named('onboarding').roles, {routerRole});
    expect(named('di_role').roles, {diRole});
    expect(named('events_role').roles, {eventsRole});
    expect(named('preferences_role').roles, {preferencesRole});
    expect(named('router_walk').roles, {routerRole});
    expect(named('settings_screen_role').roles, {settingsScreenRole});
    // The test of the theme role checks that the root of the app, which the
    // provider of the app entry builds, follows the theme mode.
    expect(named('theme_role').roles, {themeRole, appEntryRole});
    expect(named('theme_setting').roles, {themeRole});
    expect(named('localization_role').roles, {localizationRole});
    expect(named('language_setting').roles, {localizationRole});

    expect(appTests.roleProblems(smfModules, apps), isEmpty);
  });

  test(
      'the walk of the routes applies to the apps with the router role, or '
      'to those of them that it is given, and goes to the locations of the '
      'app that need no values', () async {
    final walk = named('router_walk');

    expect(
      [
        for (final app in apps)
          if (walk.appliesTo(app)) app.name,
      ],
      [
        for (final app in apps)
          if (app.hook!.presentRoles.contains(routerRole)) app.name,
      ],
    );
    expect(
      [
        for (final app in apps)
          if (walk.appliesTo(app)) app.name,
      ],
      containsAll(['home', 'every module (bloc)', 'every module (riverpod)']),
    );
    final everyModule = await routerWalkAppTest(
      among: (app) => app.everyModuleWith != null,
    );
    expect(
      [
        for (final app in apps)
          if (everyModule.appliesTo(app)) app.name,
      ],
      ['every module (bloc)', 'every module (riverpod)'],
    );

    // The locations of an app with home, whose route starts the app.
    final home = apps.singleWhere((app) => app.name == 'home');
    final files = walk.generatedFiles!(home, 'my_app');
    expect(files.keys, [routerWalkFile]);
    final (:index, :errors) = DartFileIndexer.parse(
      routerWalkFile,
      files[routerWalkFile]!,
    );
    expect(errors, isEmpty);
    expect(
      [for (final import in index.imports) '${import.uri} ${import.prefix}'],
      [
        'package:my_app/core/router/navigation.dart null',
        'package:my_app/features/home/home_screen.dart screen0',
      ],
    );
    expect(
      index.declarations.map((declaration) => declaration.name),
      ['WalkedLocation', 'walkedLocations', 'shownFor', 'closedGuards'],
    );
    expect(
      files[routerWalkFile],
      contains(
        '  (\n'
        "    route: 'home.home',\n"
        '    location: HomeHomeLocation(),\n'
        '    screen: screen0.HomeScreen,\n'
        '  ),\n',
      ),
    );
    // No module of the app has a guard of the routes: the walk expects each
    // location itself, and the file names nothing of what the role
    // generates for guards, which the app does not have.
    expect(
      files[routerWalkFile],
      contains(
        'WalkedLocation shownFor(WalkedLocation walked) => walked;\n',
      ),
    );
    expect(
      files[routerWalkFile],
      contains('List<String> closedGuards() => const [];\n'),
    );
    for (final name in [RouterRole.redirectOf, RouterRole.routeGuards]) {
      expect(files[routerWalkFile], isNot(contains(name)));
    }
  });

  test(
      'in an app with guards of the routes, the file of the walk has the '
      'target of each guard once, also one beyond the locations that the '
      'walk goes to, the location that the router shows for another, and '
      'the guards that do not allow', () {
    const screens = ImportRef.app('features/gate/gate_screens.dart');
    const status = ImportRef.app('features/gate/gate_status.dart');
    Route route(
      String path,
      String screen, {
      List<Route> children = const [],
    }) =>
        Route(
          path,
          name: path.replaceFirst('/', ''),
          screen: ScreenRef(screen, import: screens),
          children: children,
        );
    RouteGuard guard(String name, String target) => RouteGuard(
          name: name,
          allows: FunctionRef(name, import: status),
          redirectTo: target,
        );
    final app = MatrixApp(
      'gate',
      const [ModuleId('gate')],
      hook: RoleHookRequest(
        data: [
          routerRole
              .data(
                RoutesData(
                  [
                    route(
                      '/intro',
                      'IntroScreen',
                      children: [route('terms', 'TermsScreen')],
                    ),
                    // As many routes as fill the walk with the two above.
                    for (var index = 2; index < routerWalkLimit; index++)
                      route('/r$index', 'Screen$index'),
                    route('/login', 'LoginScreen'),
                  ],
                  guards: [
                    guard('firstRun', 'intro'),
                    guard('consent', 'intro'),
                    guard('signedIn', 'login'),
                  ],
                ),
              )
              .withOrigin(const ModuleOrigin(ModuleId('gate'))),
        ],
        presentRoles: {routerRole},
        context: ContractHarness.defaultContext,
      ),
    );

    final text =
        named('router_walk').generatedFiles!(app, 'my_app')[routerWalkFile]!;

    final (:index, :errors) = DartFileIndexer.parse(routerWalkFile, text);
    expect(errors, isEmpty);
    // The file of the role with the guards, next to its navigation.
    expect(
      [for (final import in index.imports) '${import.uri} ${import.prefix}'],
      [
        'package:my_app/core/router/app_router.dart null',
        'package:my_app/core/router/navigation.dart null',
        'package:my_app/features/gate/gate_screens.dart screen0',
      ],
    );
    expect(
      index.declarations.map((declaration) => declaration.name),
      [
        'WalkedLocation',
        'walkedLocations',
        'guardTargets',
        'shownFor',
        'closedGuards',
      ],
    );
    List<String?> routesIn(String code) => [
          for (final match in RegExp(r"route: '([\w.]+)'").allMatches(code))
            match[1],
        ];
    final targetsAt = text.indexOf('guardTargets = [');
    final walked = text.substring(0, targetsAt);
    final targets = text.substring(
      targetsAt,
      text.indexOf('WalkedLocation shownFor'),
    );
    // The walk does not go to the target of the last guard, which is past
    // its limit; the file has it all the same, for the walk to expect it.
    expect(routesIn(walked), hasLength(routerWalkLimit));
    expect(routesIn(walked), isNot(contains('gate.login')));
    expect(routesIn(targets), ['gate.intro', 'gate.login']);
    expect(
      targets,
      contains(
        '  (\n'
        "    route: 'gate.login',\n"
        '    location: GateLoginLocation(),\n'
        '    screen: screen0.LoginScreen,\n'
        '  ),\n',
      ),
    );
    // What the router shows for a location is what redirectOf() of the
    // role says of its route, and the guards that do not allow are those of
    // routeGuards of the role.
    expect(
      [
        for (final call in index.invocations)
          if (call.target == null) call.name,
      ],
      contains(RouterRole.redirectOf),
    );
    expect(
      text,
      contains(
        '  final target = redirectOf(walked.route);\n'
        '  if (target == null) return walked;\n',
      ),
    );
    expect(
      text,
      contains(
        '  for (final guard in routeGuards)\n'
        '    if (!guard.allows.value) guard.name,\n',
      ),
    );
  });

  test(
      'the walk of the routes goes to the locations in the flows of the '
      'guards after every other location, in their order among themselves, '
      'and leaves them out first in an app with more locations than it goes '
      'to', () {
    const gate = ImportRef.app('features/gate/gate_screens.dart');
    const feed = ImportRef.app('features/feed/feed_screens.dart');
    const status = ImportRef.app('features/gate/gate_status.dart');
    Route route(
      String path,
      String screen,
      ImportRef file, {
      List<Route> children = const [],
    }) =>
        Route(
          path,
          name: path.replaceFirst('/', ''),
          screen: ScreenRef(screen, import: file),
          children: children,
        );
    RouteGuard guard(String name, String target) => RouteGuard(
          name: name,
          allows: FunctionRef(name, import: status),
          redirectTo: target,
        );
    // A module with two guards, listed before a module with [routes] routes
    // of its own. The flow of its first guard is the target and the route
    // below it, and its last route is in no flow.
    MatrixApp appWith({required int routes}) => MatrixApp(
          'gate, feed',
          const [ModuleId('gate'), ModuleId('feed')],
          hook: RoleHookRequest(
            data: [
              routerRole
                  .data(
                    RoutesData(
                      [
                        route(
                          '/intro',
                          'IntroScreen',
                          gate,
                          children: [route('terms', 'TermsScreen', gate)],
                        ),
                        route('/login', 'LoginScreen', gate),
                        route('/help', 'HelpScreen', gate),
                      ],
                      guards: [
                        guard('firstRun', 'intro'),
                        guard('signedIn', 'login'),
                      ],
                    ),
                  )
                  .withOrigin(const ModuleOrigin(ModuleId('gate'))),
              routerRole
                  .data(
                    RoutesData([
                      for (var index = 0; index < routes; index++)
                        route('/r$index', 'Screen$index', feed),
                    ]),
                  )
                  .withOrigin(const ModuleOrigin(ModuleId('feed'))),
            ],
            presentRoles: {routerRole},
            context: ContractHarness.defaultContext,
          ),
        );
    String fileOf(MatrixApp app) =>
        named('router_walk').generatedFiles!(app, 'my_app')[routerWalkFile]!;

    // A screen in the flow of a guard may change what its guard allows when
    // it is shown. The router then shows the target of that guard for each
    // location after it, so the walk would not see the screens of those.
    final text = fileOf(appWith(routes: 2));
    expect(DartFileIndexer.parse(routerWalkFile, text).errors, isEmpty);
    expect(_walkedRoutesOf(text), [
      'gate.help',
      'feed.r0',
      'feed.r1',
      'gate.intro',
      'gate.terms',
      'gate.login',
    ]);

    // The locations of the flows count among those that the walk goes to,
    // so they are the first that it leaves out.
    expect(_walkedRoutesOf(fileOf(appWith(routes: routerWalkLimit - 2))), [
      'gate.help',
      for (var index = 0; index < routerWalkLimit - 2; index++) 'feed.r$index',
      'gate.intro',
    ]);
    final beyond = fileOf(appWith(routes: routerWalkLimit));
    expect(_walkedRoutesOf(beyond), [
      'gate.help',
      for (var index = 0; index < routerWalkLimit - 1; index++) 'feed.r$index',
    ]);
    // The file has the targets of the guards all the same, for the walk to
    // expect them while a guard does not allow.
    expect(beyond, contains("    route: 'gate.intro',\n"));
    expect(beyond, contains("    route: 'gate.login',\n"));
  });

  test(
      'the walk of the routes goes to the first $routerWalkLimit locations '
      'that need no values, children and optional values included, with '
      'the screen of each', () {
    const file = ImportRef.app('features/many/many_screens.dart');
    const other = ImportRef.app('features/many/other_screen.dart');
    Route route(int index, {List<Route> children = const []}) => Route(
          '/r$index',
          name: 'r$index',
          screen: ScreenRef('Screen$index', import: file),
          children: children,
        );
    final app = MatrixApp(
      'many',
      const [ModuleId('many')],
      hook: RoleHookRequest(
        data: [
          routerRole
              .data(
                RoutesData([
                  // A route that needs a value, and one whose value may be
                  // left out, with a child that needs none.
                  const Route(
                    '/item/:id',
                    name: 'item',
                    screen: ScreenRef('ItemScreen', import: other),
                    params: [RouteParam.path('id', type: int)],
                  ),
                  const Route(
                    '/search',
                    name: 'search',
                    screen: ScreenRef('SearchScreen', import: other),
                    params: [
                      RouteParam.query('q', type: String, optional: true),
                    ],
                    children: [
                      Route(
                        'filters',
                        name: 'filters',
                        screen: ScreenRef('FiltersScreen', import: other),
                      ),
                    ],
                  ),
                  for (var index = 0; index < routerWalkLimit; index++)
                    route(index),
                ]),
              )
              .withOrigin(const ModuleOrigin(ModuleId('many'))),
        ],
        presentRoles: {routerRole},
        context: ContractHarness.defaultContext,
      ),
    );

    final text =
        named('router_walk').generatedFiles!(app, 'my_app')[routerWalkFile]!;

    expect(DartFileIndexer.parse(routerWalkFile, text).errors, isEmpty);
    expect(
      [
        for (final match in RegExp(r"route: '([\w.]+)'").allMatches(text))
          match[1],
      ],
      [
        'many.search',
        'many.filters',
        for (var index = 0; index < routerWalkLimit - 2; index++)
          'many.r$index',
      ],
    );
    expect(text, contains('location: ManySearchLocation(),'));
    expect(text, contains('screen: screen0.FiltersScreen,'));
    expect(text, contains('screen: screen1.Screen0,'));
    expect(
      text,
      contains(
        "import 'package:my_app/features/many/other_screen.dart' as "
        'screen0;',
      ),
    );
  });

  test(
      'the test of the events role applies to the apps with the role, or to '
      'those of them that it is given', () async {
    bool hasEvents(MatrixApp app) =>
        app.hook!.presentRoles.contains(eventsRole);

    expect(
      [
        for (final app in apps)
          if (named('events_role').appliesTo(app)) app.name,
      ],
      [
        for (final app in apps)
          if (hasEvents(app)) app.name,
      ],
    );
    expect(
      [
        for (final app in apps)
          if (named('events_role').appliesTo(app)) app.name,
      ],
      [
        'event_bus with di',
        'event_bus',
        'every module (bloc)',
        'every module (riverpod)',
      ],
    );

    // As the fixtures take it, only in the apps with every module.
    final everyModule = await eventsRoleAppTest(
      among: (app) => app.everyModuleWith != null,
    );
    expect(
      [
        for (final app in apps)
          if (everyModule.appliesTo(app)) app.name,
      ],
      ['every module (bloc)', 'every module (riverpod)'],
    );
  });

  test(
      'the test of the preferences role applies to the apps with the role, '
      'whichever module provides it, or to those of them that it is given',
      () async {
    bool hasPreferences(MatrixApp app) =>
        app.hook!.presentRoles.contains(preferencesRole);

    expect(
      [
        for (final app in apps)
          if (named('preferences_role').appliesTo(app)) app.name,
      ],
      [
        for (final app in apps)
          if (hasPreferences(app)) app.name,
      ],
    );
    expect(
      [
        for (final app in apps)
          if (named('preferences_role').appliesTo(app)) app.name,
      ],
      [
        // The theme role and the localization role require the
        // preferences.
        'settings with localization',
        'material_theme with settings_screen, localization',
        'material_theme with settings_screen',
        'material_theme with localization',
        'material_theme',
        'gen_l10n',
        'shared_preferences with di',
        'shared_preferences',
        // The onboarding requires the preferences.
        'onboarding with localization',
        'onboarding',
        'every module (bloc)',
        'every module (riverpod)',
      ],
    );

    // As the fixtures take it, only in the apps with every module.
    final everyModule = await preferencesRoleAppTest(
      among: (app) => app.everyModuleWith != null,
    );
    expect(
      [
        for (final app in apps)
          if (everyModule.appliesTo(app)) app.name,
      ],
      ['every module (bloc)', 'every module (riverpod)'],
    );
  });

  test(
      'the test of shared_preferences applies to the apps with the module, '
      'whose start-up opens the preferences, and declares the mocks of the '
      'platform side of the package for the tests of every module of those '
      'apps', () {
    final test = named('shared_preferences');

    expect(
      [
        for (final app in apps)
          if (test.appliesTo(app)) app.name,
      ],
      [
        for (final app in apps)
          if (app.modules.contains(const ModuleId('shared_preferences')))
            app.name,
      ],
    );
    expect(test.roles, isEmpty);
    expect(test.devDependencies, ['shared_preferences_platform_interface']);
    expect(test.mocks!.path, 'test/shared_preferences_mocks.dart');
    expect(test.mocks!.function, 'mockSharedPreferences');
    final (:index, :errors) = DartFileIndexer.parse(
      test.mocks!.path,
      File(p.joinAll([test.directory, ...test.mocks!.path.split('/')]))
          .readAsStringSync(),
    );
    expect(errors, isEmpty);
    final function = index.declarations
        .singleWhere((declaration) => declaration.name == test.mocks!.function);
    expect(function.kind, DeclarationKind.function);
    expect(function.parameters, isEmpty);
  });

  test(
      'the test of the localization role applies to the apps with the role, '
      'whichever module provides it, or to those of them that it is given, '
      'and has a probe for the start check', () async {
    MatrixApp appWith(Role role, {List<ModuleId>? everyModuleWith}) =>
        MatrixApp(
          'texts',
          const [ModuleId('texts')],
          everyModuleWith: everyModuleWith,
          hook: RoleHookRequest(
            data: const [],
            presentRoles: {role},
            context: ContractHarness.defaultContext,
          ),
        );
    final test = await localizationRoleAppTest();

    expect(p.basename(test.directory), 'localization_role');
    expect(test.roles, {localizationRole});
    expect(test.appliesTo(appWith(localizationRole)), isTrue);
    expect(test.appliesTo(appWith(preferencesRole)), isFalse);
    // The matrix of the CLI runs it in every app with the role: the apps
    // of gen_l10n and those of material_theme with the localization, with
    // a settings screen and without, the app of the onboarding with the
    // role, and the apps with every module.
    final registered = named('localization_role');
    expect(registered.roles, test.roles);
    expect(registered.startProbe!.path, test.startProbe!.path);
    expect(
      [
        for (final app in apps)
          if (registered.appliesTo(app)) app.name,
      ],
      [
        for (final app in apps)
          if (app.hook!.presentRoles.contains(localizationRole)) app.name,
      ],
    );
    expect(
      [
        for (final app in apps)
          if (registered.appliesTo(app)) app.name,
      ],
      [
        'settings with localization',
        'material_theme with settings_screen, localization',
        'material_theme with localization',
        'gen_l10n',
        'onboarding with localization',
        'every module (bloc)',
        'every module (riverpod)',
      ],
    );
    // What the test has to check there. An app with a settings screen has
    // the texts of the setting of the language, which the role gives it in
    // English and in Ukrainian, so the test reads texts in two languages
    // with the provider of the CLI. Without a settings screen an app may
    // have no text at all, as the app of gen_l10n alone: there the test
    // checks the languages of the root and the choice that the app saves
    // and restores.
    final localized = [
      for (final app in apps)
        if (registered.appliesTo(app) &&
            app.hook!.presentRoles.contains(settingsScreenRole))
          app,
    ];
    expect(
      [for (final app in localized) app.name],
      [
        'settings with localization',
        'material_theme with settings_screen, localization',
        'every module (bloc)',
        'every module (riverpod)',
      ],
    );
    for (final app in localized) {
      final input = localizationRole.hookInput(app.hook!);
      expect(
        localizationRole.localesIn(input),
        ['en', 'uk'],
        reason: app.name,
      );
      expect(localizationRole.textsIn(input), isNotEmpty, reason: app.name);
    }

    // As the fixtures take it, only in the apps with every module.
    final everyModule = await localizationRoleAppTest(
      among: (app) => app.everyModuleWith != null,
    );
    expect(everyModule.appliesTo(appWith(localizationRole)), isFalse);
    expect(
      everyModule.appliesTo(
        appWith(localizationRole, everyModuleWith: const []),
      ),
      isTrue,
    );
    expect(
      everyModule.appliesTo(
        appWith(preferencesRole, everyModuleWith: const []),
      ),
      isFalse,
    );

    // Its probe is a function of a file of the test that takes the one that
    // waits until the screen settles, as the start check calls it.
    final probe = test.startProbe!;
    expect(probe.path, 'integration_test/localization_role/probe.dart');
    final file = File(p.joinAll([test.directory, ...probe.path.split('/')]));
    final (:index, :errors) =
        DartFileIndexer.parse(probe.path, file.readAsStringSync());
    expect(errors, isEmpty);
    final function = index.declarations
        .singleWhere((declaration) => declaration.name == probe.function);
    expect(function.name, 'probeLanguages');
    expect(function.kind, DeclarationKind.function);
    expect(function.type, 'Future<List<String>>');
    expect(
      [
        for (final parameter in function.parameters)
          '${parameter.kind.name} ${parameter.type}',
      ],
      ['requiredPositional Future<void> Function()'],
    );
    // The probe reads what the matrix writes next to it.
    expect(
      p.posix.dirname(languagesAndTextsFile),
      p.posix.dirname(probe.path),
    );
    expect(
      [for (final import in index.imports) import.uri],
      contains(p.posix.basename(languagesAndTextsFile)),
    );
  });

  test(
      'the test of the localization role gets the languages of the app, the '
      'key of the role and each text of the app, with what it reads in each '
      'language, from the data of the role', () async {
    MatrixApp appOf(
      List<RoleData<Object>> texts, {
      List<String>? languages,
    }) =>
        MatrixApp(
          'texts',
          const [ModuleId('cart')],
          hook: RoleHookRequest(
            data: texts,
            presentRoles: {localizationRole},
            context: ContractHarness.defaultContext,
            choices: {
              if (languages != null)
                localizationRole: LocalizationChoice(languages),
            },
          ),
        );
    final test = await localizationRoleAppTest();
    final app = appOf(
      [
        localizationRole
            .data(
              const TextsData([
                LocalizedText(
                  'title',
                  en: 'Your cart',
                  translations: {'uk': 'Ваш кошик', 'de': 'Ihr Warenkorb'},
                ),
                // A text without a translation, with what code escapes.
                LocalizedText('empty', en: r"It's empty: $0"),
              ]),
            )
            .withOrigin(const ModuleOrigin(ModuleId('cart'))),
        localizationRole
            .data(
              const TextsData([
                LocalizedText(
                  'language',
                  en: 'Language',
                  translations: {'uk': 'Мова'},
                ),
              ]),
            )
            .withOrigin(const RoleTemplateOrigin(localizationRole)),
      ],
      languages: ['uk', 'en'],
    );

    final files = test.generatedFiles!(app, 'my_app');

    expect(files.keys, [languagesAndTextsFile]);
    final text = files[languagesAndTextsFile]!;
    final (:index, :errors) =
        DartFileIndexer.parse(languagesAndTextsFile, text);
    expect(errors, isEmpty);
    expect(
      [for (final import in index.imports) import.uri],
      ['package:flutter/widgets.dart', 'package:my_app/core/l10n/l10n.dart'],
    );
    expect(
      index.declarations.map((declaration) => declaration.name),
      [
        'appLanguages',
        'probedLanguages',
        'savedLanguageKey',
        'AppTextCheck',
        'appTextChecks',
      ],
    );
    // The languages that the role chose, in their order, and its key.
    expect(text, contains("const List<String> appLanguages = ['uk', 'en'];"));
    // The probe goes through each language of an app with a few of them.
    expect(
      text,
      contains("const List<String> probedLanguages = ['uk', 'en'];"),
    );
    expect(
      text,
      contains(
        "const String savedLanguageKey = '${LocalizationRole.localeKey}';",
      ),
    );
    // Each text by the getter of the role, in each language of the app and
    // in no other: its translation, or its English text.
    expect(
      text,
      contains(
        '  (\n'
        "    name: 'text title of the module cart',\n"
        '    read: (context) => context.l10n.cartTitle,\n'
        '    expected: {\n'
        "      'uk': 'Ваш кошик',\n"
        "      'en': 'Your cart',\n"
        '    },\n'
        '  ),\n'
        '  (\n'
        "    name: 'text empty of the module cart',\n"
        '    read: (context) => context.l10n.cartEmpty,\n'
        '    expected: {\n'
        r"      'uk': 'It\'s empty: \$0',"
        '\n'
        r"      'en': 'It\'s empty: \$0',"
        '\n'
        '    },\n'
        '  ),\n',
      ),
    );
    final texts =
        localizationRole.textsIn(localizationRole.hookInput(app.hook!));
    expect(
      [
        for (final match in RegExp(r'context\.l10n\.(\w+),').allMatches(text))
          match[1],
      ],
      [for (final text in texts) text.getter],
    );
    expect(texts.last.getter, 'localizationLanguage');
    expect(text, isNot(contains('Ihr Warenkorb')));

    // Before a choice, the languages are those of the texts.
    final unchosen = test.generatedFiles!(
      appOf([app.hook!.data.first]),
      'my_app',
    )[languagesAndTextsFile]!;
    expect(
      unchosen,
      contains("const List<String> appLanguages = ['en', 'uk', 'de'];"),
    );

    // An app without texts reads none, so its file does not import them.
    final empty =
        test.generatedFiles!(appOf(const []), 'my_app')[languagesAndTextsFile]!;
    final parsed = DartFileIndexer.parse(languagesAndTextsFile, empty);
    expect(parsed.errors, isEmpty);
    expect(
      [for (final import in parsed.index.imports) import.uri],
      ['package:flutter/widgets.dart'],
    );
    expect(empty, contains("const List<String> appLanguages = ['en'];"));
    expect(empty, contains('const List<AppTextCheck> appTextChecks = [];'));
  });

  test(
      'the probe of the localization role goes through the first '
      '$languagesProbeLimit languages of an app, which has all of them',
      () async {
    final languages = [
      ...LocalizationRole.supportedLanguages.take(languagesProbeLimit + 2),
    ];
    final test = await localizationRoleAppTest();
    final app = MatrixApp(
      'texts',
      const [ModuleId('texts')],
      hook: RoleHookRequest(
        data: const [],
        presentRoles: {localizationRole},
        context: ContractHarness.defaultContext,
        choices: {localizationRole: LocalizationChoice(languages)},
      ),
    );

    final text = test.generatedFiles!(app, 'my_app')[languagesAndTextsFile]!;

    String listOf(Iterable<String> codes) =>
        [for (final code in codes) "'$code'"].join(', ');
    expect(DartFileIndexer.parse(languagesAndTextsFile, text).errors, isEmpty);
    expect(languagesProbeLimit, 10);
    expect(languages, hasLength(12));
    expect(
      text,
      contains('const List<String> appLanguages = [${listOf(languages)}];'),
    );
    expect(
      text,
      contains(
        'const List<String> probedLanguages = '
        '[${listOf(languages.take(10))}];',
      ),
    );
  });

  test(
      'the test of the setting of the language applies to the apps with the '
      'localization role and the settings screen role, whichever modules '
      'provide them, and gets the widget of the entry, the label of each '
      'language and the texts of the setting from the data of the roles',
      () async {
    const settingFile = ImportRef.app('core/l10n/language_setting.dart');
    MatrixApp appWith(
      Set<Role> roles, {
      List<String>? languages,
      bool setting = true,
    }) =>
        MatrixApp(
          'texts',
          const [ModuleId('texts'), ModuleId('screen')],
          hook: RoleHookRequest(
            data: [
              // An entry of a module, and the entry of the template of the
              // localization role after it.
              settingsScreenRole
                  .data(
                    const SettingsEntry(
                      widget: TypeRef(
                        'ThemeSetting',
                        import: ImportRef.app('core/theme/theme_setting.dart'),
                      ),
                    ),
                  )
                  .withOrigin(const ModuleOrigin(ModuleId('theme'))),
              if (setting)
                settingsScreenRole
                    .data(
                      const SettingsEntry(
                        widget: TypeRef('LanguageSetting', import: settingFile),
                      ),
                    )
                    .withOrigin(const RoleTemplateOrigin(localizationRole)),
            ],
            presentRoles: roles,
            context: ContractHarness.defaultContext,
            choices: {
              if (languages != null)
                localizationRole: LocalizationChoice(languages),
            },
          ),
        );
    final test = await languageSettingAppTest();

    expect(p.basename(test.directory), 'language_setting');
    // A provider of the localization role breaks it, so it is a test of
    // that role.
    expect(test.roles, {localizationRole});
    expect(test.startProbe, isNull);
    expect(
      test.appliesTo(appWith({localizationRole, settingsScreenRole})),
      isTrue,
    );
    expect(test.appliesTo(appWith({localizationRole})), isFalse);
    expect(test.appliesTo(appWith({settingsScreenRole})), isFalse);
    // The apps of the matrix of the CLI with both roles: the app of
    // gen_l10n with a settings screen, and the apps with every module.
    final registered = named('language_setting');
    expect(registered.roles, test.roles);
    expect(
      [
        for (final app in apps)
          if (registered.appliesTo(app)) app.name,
      ],
      [
        for (final app in apps)
          if (app.hook!.presentRoles
              .containsAll({localizationRole, settingsScreenRole}))
            app.name,
      ],
    );
    expect(
      [
        for (final app in apps)
          if (registered.appliesTo(app)) app.name,
      ],
      [
        'settings with localization',
        'material_theme with settings_screen, localization',
        'every module (bloc)',
        'every module (riverpod)',
      ],
    );

    final files = test.generatedFiles!(
      appWith(
        {localizationRole, settingsScreenRole},
        languages: ['uk', 'en', 'de'],
      ),
      'my_app',
    );
    expect(files.keys, [languageSettingFile]);
    final text = files[languageSettingFile]!;
    final (:index, :errors) = DartFileIndexer.parse(languageSettingFile, text);
    expect(errors, isEmpty);
    expect(
      [for (final import in index.imports) '${import.uri} as ${import.prefix}'],
      ['package:my_app/core/l10n/language_setting.dart as entry'],
    );
    expect(
      'lib/${settingFile.uri}',
      LocalizationRole.languageSettingFile,
    );
    expect(
      index.declarations.map((declaration) => declaration.name),
      [
        'languageSetting',
        'savedLanguageKey',
        'languageLabels',
        'settingTitles',
        'deviceOptions',
      ],
    );
    expect(
      text,
      contains('const Type languageSetting = entry.LanguageSetting;'),
    );
    expect(
      text,
      contains(
        "const String savedLanguageKey = '${LocalizationRole.localeKey}';",
      ),
    );
    // Each language of the app in its order: a name of the role, or the
    // code of the language; and the texts of the setting, in English where
    // they have no translation.
    expect(
      text,
      contains(
        'const Map<String, String> languageLabels = {\n'
        "  'uk': 'Українська',\n"
        "  'en': 'English',\n"
        "  'de': 'de',\n"
        '};\n',
      ),
    );
    expect(
      text,
      contains(
        'const Map<String, String> settingTitles = {\n'
        "  'uk': 'Мова',\n"
        "  'en': 'Language',\n"
        "  'de': 'Language',\n"
        '};\n',
      ),
    );
    expect(
      text,
      contains(
        'const Map<String, String> deviceOptions = {\n'
        "  'uk': 'Як у системі',\n"
        "  'en': 'System',\n"
        "  'de': 'System',\n"
        '};\n',
      ),
    );

    // An app whose settings screen lacks the entry has nothing to test.
    expect(
      () => test.generatedFiles!(
        appWith({localizationRole, settingsScreenRole}, setting: false),
        'my_app',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'The settings screen of texts has 0 entries in '
              '${LocalizationRole.languageSettingFile}, the file of the '
              'setting of the language, rather than one.',
        ),
      ),
    );
  });

  test(
      'the test of the DI role applies to the apps with the role whose '
      'modules register services, and gets the services of each from the '
      'data of the role', () {
    final diRoleTest = named('di_role');
    bool hasDi(MatrixApp app) => app.hook!.presentRoles.contains(diRole);

    expect(
      [
        for (final app in apps)
          if (diRoleTest.appliesTo(app)) app.name,
      ],
      [
        'event_bus with di',
        'shared_preferences with di',
        'firebase_crashlytics with di',
        'firebase_analytics with di, router',
        'firebase_analytics with di',
        'every module (bloc)',
        'every module (riverpod)',
      ],
    );
    // The app of the container alone, whose modules register nothing.
    expect(
      [
        for (final app in apps)
          if (hasDi(app) && !diRoleTest.appliesTo(app)) app.name,
      ],
      ['get_it'],
    );

    for (final app in apps.where(diRoleTest.appliesTo)) {
      final files = diRoleTest.generatedFiles!(app, 'my_app');
      expect(files.keys, [registeredServicesFile]);
      final (:index, :errors) = DartFileIndexer.parse(
        registeredServicesFile,
        files[registeredServicesFile]!,
      );
      expect(errors, isEmpty, reason: app.name);
      // The service locator, and the file of each type once, each with a
      // prefix of its own.
      final prefixes = {
        for (final import in index.imports) import.uri: import.prefix!,
      };
      expect(
        prefixes,
        containsPair('package:my_app/core/di/service_locator.dart', 'locator'),
      );
      expect({...prefixes.values}, hasLength(prefixes.length));
      expect(
        index.declarations.map((declaration) => declaration.name),
        ['RegisteredService', 'registeredServices'],
      );
      // Each service, in the order of its registration, resolved through
      // the service locator by its type and name.
      final registrations = diRole.graphOf(diRole.hookInput(app.hook!)).ordered;
      expect(registrations, isNotEmpty);
      String typeOf(TypeRef type) =>
          '${prefixes[type.import!.resolveUri('my_app')]}.${type.name}';
      String call(
        String target,
        String name,
        List<String> types, {
        required bool named,
      }) =>
          '$target.$name<${types.join(', ')}>(${named ? 'instanceName' : ''})';
      expect(
        [
          for (final invocation in index.invocations)
            call(
              '${invocation.target}',
              invocation.name,
              invocation.typeArguments,
              named: invocation.namedArguments.contains('instanceName'),
            ),
        ],
        [
          for (final registration in registrations)
            call(
              'locator',
              'resolve',
              [typeOf(registration.type)],
              named: registration.instanceName != null,
            ),
        ],
        reason: app.name,
      );
      for (final registration in registrations) {
        expect(
          files[registeredServicesFile],
          contains(
            "    name: '${registration.key}',\n"
            "    lifetime: '${registration.lifetime.name}',\n",
          ),
          reason: app.name,
        );
      }
    }
  });

  test(
      'the services of the test of the DI role name a type of dart:core '
      'without a prefix, the file of a package with one, and a service by '
      'its name, and the test takes the apps with the lifetimes it is given',
      () async {
    const file = ImportRef.app('core/values/values.dart');
    MatrixApp appOf(List<DiRegistration> registrations) => MatrixApp(
          'values',
          const [ModuleId('values')],
          hook: RoleHookRequest(
            data: [
              for (final registration in registrations)
                diRole
                    .data(registration)
                    .withOrigin(const ModuleOrigin(ModuleId('values'))),
            ],
            presentRoles: {diRole},
            context: ContractHarness.defaultContext,
          ),
        );
    const registrations = [
      DiRegistration(
        type: TypeRef('Uri'),
        create: FactoryRef('createApiUri', import: file),
        lifetime: DiLifetime.singleton,
        instanceName: 'api',
      ),
      DiRegistration(
        type: TypeRef('Random', import: ImportRef('dart:math')),
        create: FactoryRef('createRandom', import: file),
      ),
      DiRegistration(
        type: TypeRef('Values', import: file),
        create: FactoryRef('createValues', import: file),
        lifetime: DiLifetime.factory,
      ),
    ];
    final app = appOf(registrations);

    final text = named('di_role').generatedFiles!(app, 'my_app').values.single;

    final (:index, :errors) = DartFileIndexer.parse(
      registeredServicesFile,
      text,
    );
    expect(errors, isEmpty);
    expect(
      [for (final import in index.imports) '${import.uri} as ${import.prefix}'],
      [
        'dart:math as di0',
        'package:my_app/core/di/service_locator.dart as locator',
        'package:my_app/core/values/values.dart as di1',
      ],
    );
    String written(IndexedInvocation call) =>
        '${call.target}.${call.name}<${call.typeArguments.join()}>'
        '(${call.namedArguments.join()})';
    expect(
      index.invocations.map(written),
      [
        'locator.resolve<Uri>(instanceName)',
        'locator.resolve<di0.Random>()',
        'locator.resolve<di1.Values>()',
      ],
    );
    expect(
      text,
      contains(
        "    name: 'Uri \"api\"',\n"
        "    lifetime: 'singleton',\n"
        "    resolve: () => locator.resolve<Uri>(instanceName: 'api'),\n",
      ),
    );

    // The fixtures take only the apps whose services have every lifetime,
    // which no app of the modules of the CLI has.
    final everyLifetime = await diRoleAppTest(
      lifetimes: DiLifetime.values.toSet(),
    );
    expect(everyLifetime.appliesTo(app), isTrue);
    expect(everyLifetime.appliesTo(appOf(registrations.sublist(1))), isFalse);
    expect(apps.where(everyLifetime.appliesTo), isEmpty);
  });

  test(
      'the start check runs the probes of the tests that go into an app '
      'with it, the walk of the routes, the services of the DI role, the '
      'preferences of the role, those of shared_preferences once they are '
      'opened again, the onboarding of a first launch and the languages '
      'of the localization role, each a function of a file of its tests '
      'that takes the one that waits until the screen settles', () async {
    expect(named('start').readsStartProbes, isTrue);
    expect(
      {
        for (final test in appTests.tests)
          if (test.startProbe case final probe?)
            p.basename(test.directory): '${probe.path} ${probe.function}',
      },
      {
        'onboarding': 'integration_test/onboarding/probe.dart probeOnboarding',
        'shared_preferences': 'integration_test/shared_preferences/probe.dart '
            'probeSharedPreferences',
        'di_role': 'integration_test/di_role/probe.dart probeServices',
        'preferences_role':
            'integration_test/preferences_role/probe.dart probePreferences',
        'router_walk': 'integration_test/router_walk/walk.dart probeRoutes',
        'localization_role':
            'integration_test/localization_role/probe.dart probeLanguages',
      },
    );
    for (final test in appTests.tests) {
      final probe = test.startProbe;
      if (probe == null) continue;
      final file = File(p.joinAll([test.directory, ...probe.path.split('/')]));
      final (:index, :errors) =
          DartFileIndexer.parse(probe.path, file.readAsStringSync());
      expect(errors, isEmpty, reason: probe.path);
      final function = index.declarations
          .singleWhere((declaration) => declaration.name == probe.function);
      expect(function.kind, DeclarationKind.function);
      expect(function.type, 'Future<List<String>>');
      expect(
        [
          for (final parameter in function.parameters)
            '${parameter.kind.name} ${parameter.type}',
        ],
        ['requiredPositional Future<void> Function()'],
      );
    }

    // With the start check, an app with every module gets the probes of
    // all of them, which the list of the probes names. That of the
    // onboarding comes before the walk of the routes: it finishes the
    // onboarding that a first launch shows, and the walk then goes through
    // the routes of the app past it.
    final app = apps.singleWhere((app) => app.name == 'every module (bloc)');
    final tests = appTestsFor(app, [named('start')], appTests.tests);
    expect(
      [for (final test in tests) p.basename(test.directory)],
      [
        'start',
        'onboarding',
        'shared_preferences',
        'di_role',
        'preferences_role',
        'router_walk',
        'localization_role',
      ],
    );
    final directory = Directory.systemTemp.createTempSync('smf_probes_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final added = addAppTests(
      tests,
      directory: directory.path,
      packageName: 'my_app',
      app: app,
    );
    // The paths in the app, as the file system of the machine writes them.
    expect(
      added,
      containsAll([
        for (final file in [
          startProbesFile,
          registeredServicesFile,
          routerWalkFile,
          languagesAndTextsFile,
        ])
          p.joinAll(file.split('/')),
      ]),
    );
    final list = File(
      p.joinAll([directory.path, ...startProbesFile.split('/')]),
    ).readAsStringSync();
    final (:index, :errors) = DartFileIndexer.parse(startProbesFile, list);
    expect(errors, isEmpty);
    expect(
      [for (final import in index.imports) '${import.prefix}: ${import.uri}'],
      [
        'probe0: onboarding/probe.dart',
        'probe1: shared_preferences/probe.dart',
        'probe2: di_role/probe.dart',
        'probe3: preferences_role/probe.dart',
        'probe4: router_walk/walk.dart',
        'probe5: localization_role/probe.dart',
      ],
    );
    expect(list, contains("('onboarding', probe0.probeOnboarding),"));
    expect(
      list,
      contains("('shared_preferences', probe1.probeSharedPreferences),"),
    );
    expect(list, contains("('di_role', probe2.probeServices),"));
    expect(list, contains("('preferences_role', probe3.probePreferences),"));
    expect(list, contains("('router_walk', probe4.probeRoutes),"));
    expect(list, contains("('localization_role', probe5.probeLanguages),"));
  });

  test(
      'the test of the onboarding applies to the apps with the module, '
      'whatever else they have, declares the mocks that finish the '
      'onboarding for the tests of every module of those apps, and expects '
      'the screen that the router role chose for the app to start on, or '
      'the fallback screen of the app entry, and the texts of the module in '
      'each language of the app', () {
    final test = named('onboarding');

    expect(
      [
        for (final app in apps)
          if (test.appliesTo(app)) app.name,
      ],
      [
        for (final app in apps)
          if (app.modules.contains(const ModuleId('onboarding'))) app.name,
      ],
    );
    expect(test.devDependencies, isEmpty);
    expect(test.values, isNull);
    expect(test.mocks!.path, 'test/onboarding_mocks.dart');
    expect(test.mocks!.function, 'finishOnboarding');
    final mocks = DartFileIndexer.parse(
      test.mocks!.path,
      File(p.joinAll([test.directory, ...test.mocks!.path.split('/')]))
          .readAsStringSync(),
    );
    expect(mocks.errors, isEmpty);
    final function = mocks.index.declarations
        .singleWhere((declaration) => declaration.name == test.mocks!.function);
    expect(function.kind, DeclarationKind.function);
    expect(function.parameters, isEmpty);

    final screens = <String, String>{};
    final languages = <String, List<String>>{};
    for (final app in apps.where(test.appliesTo)) {
      final files = test.generatedFiles!(app, 'my_app');
      expect(
        files.keys,
        [onboardingStartScreenFile, onboardingTextsFile],
        reason: app.name,
      );
      languages[app.name] = _languagesOf(files[onboardingTextsFile]!);
      final text = files[onboardingStartScreenFile]!;
      final (:index, :errors) =
          DartFileIndexer.parse(onboardingStartScreenFile, text);
      expect(errors, isEmpty, reason: app.name);
      expect(
        index.declarations.map((declaration) => declaration.name),
        ['startScreen'],
        reason: app.name,
      );
      final import = index.imports.single;
      expect(import.prefix, 'screen', reason: app.name);
      screens[app.name] = '${import.uri}: '
          '${RegExp(r'const Type startScreen = (\S+);').firstMatch(text)![1]}';
    }
    expect(screens, {
      // No route can start the app, since the onboarding cannot.
      for (final name in ['onboarding with localization', 'onboarding'])
        name: 'package:my_app/core/app/fallback_start_screen.dart: '
            'screen.FallbackStartScreen',
      // The start screen of home.
      for (final name in ['every module (bloc)', 'every module (riverpod)'])
        name: 'package:my_app/features/home/home_screen.dart: '
            'screen.HomeScreen',
    });
    // The languages of the localization role of the app, which are those
    // of the texts of its modules, and English alone without the role.
    expect(languages, {
      'onboarding with localization': ['en', 'uk'],
      'onboarding': ['en'],
      'every module (bloc)': ['en', 'uk'],
      'every module (riverpod)': ['en', 'uk'],
    });
    for (final app in apps.where(test.appliesTo)) {
      expect(
        languages[app.name],
        app.hook!.presentRoles.contains(localizationRole)
            ? localizationRole.localesIn(
                localizationRole.hookInput(app.hook!),
              )
            : ['en'],
        reason: app.name,
      );
    }
  });

  test(
      'the test of the onboarding gets each text of the module by its name, '
      'in each language of the app in the order of the localization role, '
      'in English where the module has no translation, and in English alone '
      'in an app without the role', () {
    final test = named('onboarding');
    String textsOf({List<String>? languages}) => test.generatedFiles!(
          MatrixApp(
            'texts',
            const [ModuleId('onboarding')],
            hook: RoleHookRequest(
              data: const [],
              presentRoles: {
                routerRole,
                if (languages != null) localizationRole,
              },
              context: ContractHarness.defaultContext,
              choices: {
                if (languages != null)
                  localizationRole: LocalizationChoice(languages),
              },
            ),
          ),
          'my_app',
        )[onboardingTextsFile]!;
    const english = "    'welcome': 'Welcome! We are glad you are here.',\n"
        "    'readyTitle': 'You are all set',\n"
        "    'ready': 'Enjoy the app.',\n"
        "    'skip': 'Skip',\n"
        "    'next': 'Next',\n"
        "    'done': 'Done',\n";

    // The names are those that first_launch_test.dart of the app test looks
    // each text up by: a new text of the module needs a look there.
    final localized = textsOf(languages: ['uk', 'en', 'de']);
    final (:index, :errors) =
        DartFileIndexer.parse(onboardingTextsFile, localized);
    expect(errors, isEmpty);
    expect(index.imports, isEmpty);
    expect(
      index.declarations.map((declaration) => declaration.name),
      ['onboardingTexts'],
    );
    expect(
      localized,
      endsWith(
        'const Map<String, Map<String, String>> onboardingTexts = {\n'
        "  'uk': {\n"
        "    'welcome': 'Вітаємо! Раді, що ви з нами.',\n"
        "    'readyTitle': 'Усе готово',\n"
        "    'ready': 'Приємного користування!',\n"
        "    'skip': 'Пропустити',\n"
        "    'next': 'Далі',\n"
        "    'done': 'Готово',\n"
        '  },\n'
        "  'en': {\n"
        '$english'
        '  },\n'
        // The module has no German texts.
        "  'de': {\n"
        '$english'
        '  },\n'
        '};\n',
      ),
    );
    expect(_languagesOf(localized), ['uk', 'en', 'de']);

    expect(
      textsOf(),
      endsWith(
        'const Map<String, Map<String, String>> onboardingTexts = {\n'
        "  'en': {\n"
        '$english'
        '  },\n'
        '};\n',
      ),
    );
  });

  test(
      'the tests of the settings screen role apply to the apps with the '
      'role, and get the location and the type of the screen, and the types '
      'of the entries, from the data of the role', () {
    final settings = named('settings_screen_role');

    expect(
      [
        for (final app in apps)
          if (settings.appliesTo(app)) app.name,
      ],
      [
        for (final app in apps)
          if (app.hook!.presentRoles.contains(settingsScreenRole)) app.name,
      ],
    );
    expect(
      [
        for (final app in apps)
          if (settings.appliesTo(app)) app.name,
      ],
      [
        'settings with localization',
        'settings',
        'material_theme with settings_screen, localization',
        'material_theme with settings_screen',
        'every module (bloc)',
        'every module (riverpod)',
      ],
    );
    // They run in a test of the app only, so they have no probe for a
    // check on a device, where the walk of the routes goes to the screen.
    expect(settings.startProbe, isNull);
    // The entries of each app, as the role gives them: none in the app of
    // the settings module alone, whose modules have no setting; the entry
    // of the theme mode, which the template of the theme role contributes,
    // in the apps with the theme; and the setting of the language, which
    // the template of the localization role contributes, in the apps with
    // the localization, after that of the theme, as the modules that
    // provide the two roles are in the list of the CLI.
    List<SettingsEntry> entriesOf(MatrixApp app) =>
        settingsScreenRole.entriesIn(settingsScreenRole.hookInput(app.hook!));
    expect(
      {
        for (final app in apps.where(settings.appliesTo))
          app.name: [for (final entry in entriesOf(app)) entry.widget.name],
      },
      {
        'settings': isEmpty,
        'material_theme with settings_screen, localization': [
          'ThemeModeSetting',
          'LanguageSetting',
        ],
        'material_theme with settings_screen': ['ThemeModeSetting'],
        'settings with localization': ['LanguageSetting'],
        'every module (bloc)': ['ThemeModeSetting', 'LanguageSetting'],
        'every module (riverpod)': ['ThemeModeSetting', 'LanguageSetting'],
      },
    );

    for (final app in apps.where(settings.appliesTo)) {
      final files = settings.generatedFiles!(app, 'my_app');
      expect(files.keys, [settingsScreenFile]);
      final text = files[settingsScreenFile]!;
      final (:index, :errors) = DartFileIndexer.parse(settingsScreenFile, text);
      expect(errors, isEmpty, reason: app.name);
      // The screen of the provider, as the role finds it.
      final screen =
          settingsScreenRole.screenIn(settingsScreenRole.hookInput(app.hook!))!;
      // The file of each entry, with a prefix of its own, in the order of
      // the entries; the imports are sorted.
      final entries = entriesOf(app);
      expect(
        [for (final import in index.imports) '${import.uri} ${import.prefix}'],
        [
          'package:my_app/core/router/navigation.dart null',
          for (final (index, entry) in entries.indexed)
            '${entry.widget.import!.resolveUri('my_app')} entry$index',
          '${screen.route.screen.import.resolveUri('my_app')} screen',
        ]..sort(),
        reason: app.name,
      );
      expect(
        index.declarations.map((declaration) => declaration.name),
        ['settingsLocation', 'settingsScreen', 'settingsEntries'],
        reason: app.name,
      );
      expect(
        text,
        allOf(
          contains(
            'const AppLocation settingsLocation = ${screen.locationClass}();',
          ),
          contains(
            'const Type settingsScreen = '
            'screen.${screen.route.screen.className};',
          ),
          contains(
            'const List<Type> settingsEntries = [\n'
            '${[
              for (final (index, entry) in entries.indexed)
                '  entry$index.${entry.widget.name},\n',
            ].join()}'
            '];',
          ),
        ),
        reason: app.name,
      );
    }
  });

  test(
      'the file of the tests of the settings screen role names the widget '
      'of each entry in the order of the role, through an import of its '
      'file with a prefix of its own, and needs the route of the screen', () {
    const routes = RoutesData([
      Route(
        '/',
        name: 'options',
        screen: ScreenRef(
          'OptionsScreen',
          import: ImportRef.app('features/options/options_screen.dart'),
        ),
        children: [
          Route(
            'all',
            name: 'all',
            screen: ScreenRef(
              'AllOptionsScreen',
              import: ImportRef.app('features/options/all_screen.dart'),
            ),
          ),
        ],
      ),
    ]);
    SettingsEntry entry(String widget, String file) =>
        SettingsEntry(widget: TypeRef(widget, import: ImportRef.app(file)));
    const options = ModuleOrigin(ModuleId('options'));
    const look = ModuleOrigin(ModuleId('look'));
    MatrixApp appOf(List<RoleData<Object>> data) => MatrixApp(
          'options',
          const [ModuleId('options'), ModuleId('look')],
          hook: RoleHookRequest(
            data: data,
            presentRoles: {routerRole, settingsScreenRole},
            context: ContractHarness.defaultContext,
          ),
        );
    final entries = [
      for (final (origin, widget, file) in [
        (look, 'ThemeSetting', 'core/look/look_settings.dart'),
        (look, 'FontSetting', 'core/look/look_settings.dart'),
        // A row of the provider itself, in the file of the screen.
        (options, 'ResetOptions', 'features/options/all_screen.dart'),
        (
          const RoleTemplateOrigin(diRole),
          'ServicesSetting',
          'core/di/services_setting.dart',
        ),
      ])
        settingsScreenRole.data(entry(widget, file)).withOrigin(origin),
    ];
    final settings = named('settings_screen_role');

    final text = settings.generatedFiles!(
      appOf([
        routerRole.data(routes).withOrigin(options),
        settingsScreenRole
            .data(const SettingsScreenRoute('all'))
            .withOrigin(options),
        ...entries,
      ]),
      'my_app',
    )[settingsScreenFile]!;

    final (:index, :errors) = DartFileIndexer.parse(settingsScreenFile, text);
    expect(errors, isEmpty);
    expect(
      [for (final import in index.imports) '${import.uri} as ${import.prefix}'],
      [
        'package:my_app/core/di/services_setting.dart as entry1',
        'package:my_app/core/look/look_settings.dart as entry0',
        'package:my_app/core/router/navigation.dart as null',
        'package:my_app/features/options/all_screen.dart as screen',
      ],
    );
    expect(
      text,
      allOf(
        contains('const AppLocation settingsLocation = OptionsAllLocation();'),
        contains('const Type settingsScreen = screen.AllOptionsScreen;'),
        contains(
          'const List<Type> settingsEntries = [\n'
          '  entry0.ThemeSetting,\n'
          '  entry0.FontSetting,\n'
          '  screen.ResetOptions,\n'
          '  entry1.ServicesSetting,\n'
          '];\n',
        ),
      ),
    );

    // An app whose provider names no route of its own is no app of the
    // matrix: the rules of the role report it first.
    expect(
      () => settings.generatedFiles!(
        appOf([routerRole.data(routes).withOrigin(options), ...entries]),
        'my_app',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'No module of options names a route of its own as the settings '
              'screen.',
        ),
      ),
    );
  });

  test(
      'the test of the theme role applies to the apps with the role, '
      'whichever module provides it, or to those of them that it is given, '
      'and gets the key of the theme mode that the role publishes', () async {
    final theme = named('theme_role');

    expect(
      [
        for (final app in apps)
          if (theme.appliesTo(app)) app.name,
      ],
      [
        for (final app in apps)
          if (app.hook!.presentRoles.contains(themeRole)) app.name,
      ],
    );
    expect(
      [
        for (final app in apps)
          if (theme.appliesTo(app)) app.name,
      ],
      [
        'material_theme with settings_screen, localization',
        'material_theme with settings_screen',
        'material_theme with localization',
        'material_theme',
        'every module (bloc)',
        'every module (riverpod)',
      ],
    );
    for (final app in apps.where(theme.appliesTo)) {
      expect(
        theme.values!(app),
        {'mode_key': ThemeRole.modeKey},
        reason: app.name,
      );
    }
    expect(theme.generatedFiles, isNull);
    // On a device the mode is the same Dart state as in a test, so the test
    // has no probe for the start check.
    expect(theme.startProbe, isNull);

    // As the fixtures take it, only in the apps with every module.
    final everyModule = await themeRoleAppTest(
      among: (app) => app.everyModuleWith != null,
    );
    expect(
      [
        for (final app in apps)
          if (everyModule.appliesTo(app)) app.name,
      ],
      ['every module (bloc)', 'every module (riverpod)'],
    );
  });

  test(
      'the test of the entry of the theme mode applies to the apps with the '
      'theme role and the settings screen role, and gets the location of '
      'the settings screen and the type of the entry from the data of the '
      'settings screen role, and the key of the mode', () {
    final setting = named('theme_setting');

    expect(
      [
        for (final app in apps)
          if (setting.appliesTo(app)) app.name,
      ],
      [
        for (final app in apps)
          if (app.hook!.presentRoles
              .containsAll([themeRole, settingsScreenRole]))
            app.name,
      ],
    );
    expect(
      [
        for (final app in apps)
          if (setting.appliesTo(app)) app.name,
      ],
      [
        'material_theme with settings_screen, localization',
        'material_theme with settings_screen',
        'every module (bloc)',
        'every module (riverpod)',
      ],
    );
    // It opens the settings screen with the location that the matrix writes
    // for it, so it needs no file of the tests of the settings screen role.
    expect(setting.startProbe, isNull);

    for (final app in apps.where(setting.appliesTo)) {
      expect(
        setting.values!(app),
        {'mode_key': ThemeRole.modeKey},
        reason: app.name,
      );
      final files = setting.generatedFiles!(app, 'my_app');
      expect(files.keys, [themeSettingFile]);
      final text = files[themeSettingFile]!;
      final (:index, :errors) = DartFileIndexer.parse(themeSettingFile, text);
      expect(errors, isEmpty, reason: app.name);
      expect(
        [for (final import in index.imports) '${import.uri} ${import.prefix}'],
        [
          'package:my_app/core/router/navigation.dart null',
          'package:my_app/core/theme/theme_mode_setting.dart entry',
        ],
        reason: app.name,
      );
      expect(
        index.declarations.map((declaration) => declaration.name),
        ['settingsLocation', 'themeModeEntry'],
        reason: app.name,
      );
      // The screen of the provider, as the settings screen role finds it.
      final screen =
          settingsScreenRole.screenIn(settingsScreenRole.hookInput(app.hook!))!;
      expect(
        text,
        allOf(
          contains(
            'const AppLocation settingsLocation = ${screen.locationClass}();',
          ),
          contains('const Type themeModeEntry = entry.ThemeModeSetting;'),
        ),
        reason: app.name,
      );
    }
  });

  test(
      'the file of the test of the entry of the theme mode names the entry '
      'that the template of the theme role contributes, among those of the '
      'modules and of other roles, and needs that one entry and the route of '
      'the screen', () {
    const routes = RoutesData([
      Route(
        '/options',
        name: 'options',
        screen: ScreenRef(
          'OptionsScreen',
          import: ImportRef.app('features/options/options_screen.dart'),
        ),
      ),
    ]);
    const options = ModuleOrigin(ModuleId('options'));
    RoleData<Object> entry(
      String widget,
      String file,
      ContributionOrigin origin,
    ) =>
        settingsScreenRole
            .data(
              SettingsEntry(
                widget: TypeRef(widget, import: ImportRef.app(file)),
              ),
            )
            .withOrigin(origin);
    MatrixApp appOf(List<RoleData<Object>> data) => MatrixApp(
          'options',
          const [ModuleId('options')],
          hook: RoleHookRequest(
            data: data,
            presentRoles: {routerRole, settingsScreenRole, themeRole},
            context: ContractHarness.defaultContext,
          ),
        );
    final screen = [
      routerRole.data(routes).withOrigin(options),
      settingsScreenRole
          .data(const SettingsScreenRoute('options'))
          .withOrigin(options),
    ];
    // A setting of a module, of the provider of the theme, such as a colour,
    // and of the template of another role, before and after the entry of
    // the theme mode.
    final others = [
      entry('FeedSetting', 'features/options/feed_setting.dart', options),
      entry(
        'ColourSetting',
        'core/theme/colour_setting.dart',
        const ModuleOrigin(ModuleId('look')),
      ),
    ];
    final ofTheme = entry(
      'ModeSetting',
      'core/theme/mode_setting.dart',
      const RoleTemplateOrigin(themeRole),
    );
    final ofLanguage = entry(
      'LanguageSetting',
      'core/l10n/language_setting.dart',
      const RoleTemplateOrigin(localizationRole),
    );
    final setting = named('theme_setting');
    String fileOf(List<RoleData<Object>> entries) => setting.generatedFiles!(
          appOf([...screen, ...entries]),
          'my_app',
        )[themeSettingFile]!;

    final text = fileOf([...others, ofTheme, ofLanguage]);

    final (:index, :errors) = DartFileIndexer.parse(themeSettingFile, text);
    expect(errors, isEmpty);
    expect(
      [for (final import in index.imports) '${import.uri} as ${import.prefix}'],
      [
        'package:my_app/core/router/navigation.dart as null',
        'package:my_app/core/theme/mode_setting.dart as entry',
      ],
    );
    expect(
      text,
      allOf(
        contains(
          'const AppLocation settingsLocation = OptionsOptionsLocation();',
        ),
        contains('const Type themeModeEntry = entry.ModeSetting;'),
      ),
    );

    // The test taps the modes of one entry: an app in which the template of
    // the theme role gives the settings screen none, or two, is no app of
    // the matrix.
    for (final (entries, count) in [
      ([...others, ofLanguage], 0),
      (
        [
          ofTheme,
          entry(
            'ContrastSetting',
            'core/theme/contrast_setting.dart',
            const RoleTemplateOrigin(themeRole),
          ),
        ],
        2,
      ),
    ]) {
      expect(
        () => fileOf(entries),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'The template of the theme role gives the settings screen of '
                'options $count entries, rather than the entry of the theme '
                'mode alone.',
          ),
        ),
        reason: '$count',
      );
    }
    // Nor is an app whose provider of the settings screen names no route of
    // its own: the rules of the role report it first.
    expect(
      () => setting.generatedFiles!(
        appOf([routerRole.data(routes).withOrigin(options), ofTheme]),
        'my_app',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'No module of options names a route of its own as the settings '
              'screen.',
        ),
      ),
    );
  });

  test(
      'the test of the settings module applies to the apps with the module, '
      'whatever else they have', () {
    expect(
      [
        for (final app in apps)
          if (named('settings').appliesTo(app)) app.name,
      ],
      [
        'settings with localization',
        'settings',
        'material_theme with settings_screen, localization',
        'material_theme with settings_screen',
        'every module (bloc)',
        'every module (riverpod)',
      ],
    );
  });

  test(
      'the tests of the settings module get the languages of the app, which '
      'is in English alone without the localization role', () {
    final settings = named('settings');
    final withoutRole = [
      for (final app in apps.where(settings.appliesTo))
        if (!app.hook!.presentRoles.contains(localizationRole)) app,
    ];

    expect(
      withoutRole.map((app) => app.name),
      ['settings', 'material_theme with settings_screen'],
    );
    for (final app in withoutRole) {
      final files = settings.generatedFiles!(app, 'my_app');
      expect(files.keys, [settingsLanguagesFile]);
      final text = files[settingsLanguagesFile]!;
      final (:index, :errors) =
          DartFileIndexer.parse(settingsLanguagesFile, text);
      expect(errors, isEmpty, reason: app.name);
      expect(index.imports, isEmpty, reason: app.name);
      expect(
        index.declarations.map((declaration) => declaration.name),
        ['appLanguages', 'chooseLanguage'],
        reason: app.name,
      );
      expect(
        text,
        allOf(
          contains("const List<String> appLanguages = ['en'];"),
          // Nothing to choose.
          contains('Future<void> chooseLanguage(String language) async {}'),
        ),
        reason: app.name,
      );
    }
  });

  test(
      'the file of the languages of an app with the localization role has '
      'the languages of the role, also when the app is given its languages, '
      'and chooses one through the language that the role keeps for the '
      'app', () async {
    final settings = named('settings');
    // The apps as they are, and with the one language that they are given.
    final (apps: english, :failed) = await matrixOf(
      smfModules,
      roleOptions: const {'locales': 'en'},
    );
    expect(failed, isEmpty);

    for (final (matrix, languages) in [
      // The languages that the title of the module is in.
      (apps, "['en', 'uk']"),
      (english, "['en']"),
    ]) {
      final withRole = [
        for (final app in matrix.where(settings.appliesTo))
          if (app.hook!.presentRoles.contains(localizationRole)) app,
      ];

      expect(
        withRole.map((app) => app.name),
        [
          'settings with localization',
          'material_theme with settings_screen, localization',
          'every module (bloc)',
          'every module (riverpod)',
        ],
        reason: languages,
      );
      for (final app in withRole) {
        final reason = '${app.name} in $languages';
        final files = settings.generatedFiles!(app, 'my_app');
        expect(files.keys, [settingsLanguagesFile], reason: reason);
        final text = files[settingsLanguagesFile]!;
        final (:index, :errors) =
            DartFileIndexer.parse(settingsLanguagesFile, text);
        expect(errors, isEmpty, reason: reason);
        expect(
          [for (final import in index.imports) import.uri],
          ['dart:ui', 'package:my_app/core/l10n/app_locale.dart'],
          reason: reason,
        );
        expect(
          index.declarations.map((declaration) => declaration.name),
          ['appLanguages', 'chooseLanguage'],
          reason: reason,
        );
        expect(
          text,
          allOf(
            contains('const List<String> appLanguages = $languages;'),
            // The future of the role, which completes once the choice is
            // saved.
            contains(
              'Future<void> chooseLanguage(String language) =>\n'
              '    appLocale.choose(Locale(language));',
            ),
          ),
          reason: reason,
        );
      }
    }
  });

  test(
      'the test of the screen views expects the screen that the router role '
      'chose for the app to start on', () {
    final screenViews = named('screen_views');

    expect(
      {
        for (final app in apps)
          if (screenViews.appliesTo(app))
            app.name: screenViews.values!(app)['start_screen'],
      },
      {
        // The fallback screen of the app entry, without a route that can
        // start the app.
        'firebase_analytics with di, router': '/',
        'firebase_analytics with router': '/',
        // The start screen of home.
        'every module (bloc)': 'home.home',
        'every module (riverpod)': 'home.home',
      },
    );
  });
}
