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
      'of the events role and of the settings screen role with every '
      'provider of each, which they tell apart by the roles of the app only',
      () {
    expect(
      appTests.testedRoles,
      containsAll([routerRole, diRole, eventsRole, settingsScreenRole]),
    );
    expect(named('screen_views').roles, contains(routerRole));
    expect(named('di_role').roles, {diRole});
    expect(named('events_role').roles, {eventsRole});
    expect(named('router_walk').roles, {routerRole});
    expect(named('settings_screen_role').roles, {settingsScreenRole});

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
      ['WalkedLocation', 'walkedLocations'],
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
      'whichever module provides it, or to those of them that it is given, '
      'and has a probe for the start check', () async {
    MatrixApp appWith(Role role, {List<ModuleId>? everyModuleWith}) =>
        MatrixApp(
          'store',
          const [ModuleId('store')],
          everyModuleWith: everyModuleWith,
          hook: RoleHookRequest(
            data: const [],
            presentRoles: {role},
            context: ContractHarness.defaultContext,
          ),
        );
    final test = await preferencesRoleAppTest();

    expect(p.basename(test.directory), 'preferences_role');
    expect(test.roles, {preferencesRole});
    expect(test.appliesTo(appWith(preferencesRole)), isTrue);
    expect(test.appliesTo(appWith(eventsRole)), isFalse);
    // No module of the CLI provides the role, so its matrix does not run
    // the test: that of the fixtures does, with their provider.
    expect(apps.where(test.appliesTo), isEmpty);
    expect(
      [for (final test in appTests.tests) p.basename(test.directory)],
      isNot(contains('preferences_role')),
    );

    // As the fixtures take it, only in the apps with every module.
    final everyModule = await preferencesRoleAppTest(
      among: (app) => app.everyModuleWith != null,
    );
    expect(everyModule.appliesTo(appWith(preferencesRole)), isFalse);
    expect(
      everyModule.appliesTo(
        appWith(preferencesRole, everyModuleWith: const []),
      ),
      isTrue,
    );
    expect(
      everyModule.appliesTo(appWith(eventsRole, everyModuleWith: const [])),
      isFalse,
    );

    // Its probe is a function of a file of the test that takes the one that
    // waits until the screen settles, as the start check calls it.
    final probe = test.startProbe!;
    expect(probe.path, 'integration_test/preferences_role/probe.dart');
    final file = File(p.joinAll([test.directory, ...probe.path.split('/')]));
    final (:index, :errors) =
        DartFileIndexer.parse(probe.path, file.readAsStringSync());
    expect(errors, isEmpty);
    final function = index.declarations
        .singleWhere((declaration) => declaration.name == probe.function);
    expect(function.name, 'probePreferences');
    expect(function.kind, DeclarationKind.function);
    expect(function.type, 'Future<List<String>>');
    expect(
      [
        for (final parameter in function.parameters)
          '${parameter.kind.name} ${parameter.type}',
      ],
      ['requiredPositional Future<void> Function()'],
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
      'the start check runs the probes of the tests of the roles that go '
      'into an app with it, the walk of the routes and the services of the '
      'DI role, each a function of a file of its tests that takes the one '
      'that waits until the screen settles', () async {
    expect(named('start').readsStartProbes, isTrue);
    expect(
      {
        for (final test in appTests.tests)
          if (test.startProbe case final probe?)
            p.basename(test.directory): '${probe.path} ${probe.function}',
      },
      {
        'di_role': 'integration_test/di_role/probe.dart probeServices',
        'router_walk': 'integration_test/router_walk/walk.dart probeRoutes',
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
    // both, which the list of the probes names.
    final app = apps.singleWhere((app) => app.name == 'every module (bloc)');
    final tests = appTestsFor(app, [named('start')], appTests.tests);
    expect(
      [for (final test in tests) p.basename(test.directory)],
      ['start', 'di_role', 'router_walk'],
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
        'probe0: di_role/probe.dart',
        'probe1: router_walk/walk.dart',
      ],
    );
    expect(list, contains("('di_role', probe0.probeServices),"));
    expect(list, contains("('router_walk', probe1.probeRoutes),"));
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
      ['settings', 'every module (bloc)', 'every module (riverpod)'],
    );
    // They run in a test of the app only, so they have no probe for a
    // check on a device, where the walk of the routes goes to the screen.
    expect(settings.startProbe, isNull);

    for (final app in apps.where(settings.appliesTo)) {
      final files = settings.generatedFiles!(app, 'my_app');
      expect(files.keys, [settingsScreenFile]);
      final text = files[settingsScreenFile]!;
      final (:index, :errors) = DartFileIndexer.parse(settingsScreenFile, text);
      expect(errors, isEmpty, reason: app.name);
      // The screen of the provider, as the role finds it.
      final screen =
          settingsScreenRole.screenIn(settingsScreenRole.hookInput(app.hook!))!;
      expect(
        [for (final import in index.imports) '${import.uri} ${import.prefix}'],
        [
          'package:my_app/core/router/navigation.dart null',
          '${screen.route.screen.import.resolveUri('my_app')} screen',
        ],
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
          // No module of the CLI has a setting yet.
          contains('const List<Type> settingsEntries = [\n];'),
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
      'the test of the settings module applies to the apps with the module, '
      'whatever else they have', () {
    expect(
      [
        for (final app in apps)
          if (named('settings').appliesTo(app)) app.name,
      ],
      ['settings', 'every module (bloc)', 'every module (riverpod)'],
    );
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
