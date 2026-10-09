// The tests that the matrix of CI adds to the apps of the fixture modules
// (fixtureAppTests, which tool/matrix.dart runs), and to the app of
// several providers (severalProvidersAppTests, which
// tool/several_providers_matrix.dart runs). CI runs them only in its
// job with Flutter, which checks that they apply to some app and that they
// check the contract of their roles with every provider only at its end;
// these tests check the same without Flutter.
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:fake_feature/fake_feature.dart';
import 'package:fake_infra/fake_infra.dart';
import 'package:fixture_registry/broken_providers.dart';
import 'package:fixture_registry/fixture_registry.dart';
import 'package:fixture_registry/matrix_app_tests.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_flutter_cli/matrix_app_tests.dart' show routerWalkFile;
import 'package:test/test.dart';

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
    appTests = await fixtureAppTests();
    final (apps: matrix, :failed) = await matrixOf(fixtureModules());
    expect(failed, isEmpty);
    apps = matrix;
  });

  /// The name of the directory of the files of [test], whose path joins its
  /// names with `\` on Windows, but for the last.
  String nameOf(MatrixAppTest test) =>
      test.directory.split(RegExp(r'[/\\]')).last;

  /// The app test whose files are in the directory [name].
  MatrixAppTest named(String name) =>
      appTests.tests.singleWhere((test) => nameOf(test) == name);

  /// The names of the apps that [test] applies to.
  List<String> appsOf(MatrixAppTest test) => [
        for (final app in apps)
          if (test.appliesTo(app)) app.name,
      ];

  test('each app test applies to an app of the matrix', () {
    expect(appTests.tests, isNotEmpty);
    for (final test in appTests.tests) {
      expect(appsOf(test), isNotEmpty, reason: test.directory);
    }
  });

  test(
      'the app tests check the contract of the router role, of the layout '
      'role, of the DI role, of the events role, of the preferences role, '
      'of the localization role, of the theme role and of the app entry role '
      'with every provider of each, which they tell apart by the roles of '
      'the app only', () {
    expect(
      appTests.testedRoles,
      containsAll([
        routerRole,
        layoutRole,
        diRole,
        eventsRole,
        preferencesRole,
        localizationRole,
        themeRole,
        appEntryRole,
      ]),
    );
    expect(named('localization_role').roles, {localizationRole});
    expect(named('router_screens').roles, {routerRole});
    expect(named('router_listeners').roles, {routerRole});
    expect(named('router_guards').roles, {routerRole});
    expect(named('router_guards_fallback').roles, {routerRole});
    expect(named('layout_guards').roles, {routerRole});
    expect(named('router_fallback').roles, {routerRole});
    expect(named('layout_screens').roles, {routerRole, layoutRole});
    expect(named('di_role').roles, {diRole});
    expect(named('di_disposal').roles, {diRole});
    expect(named('events_role').roles, {eventsRole});
    expect(named('preferences_role').roles, {preferencesRole});
    expect(named('preferences_restorers').roles, {preferencesRole});
    expect(named('router_walk').roles, {routerRole});
    expect(named('router_walk_guards').roles, {routerRole});
    // The test of the theme role checks that the root of the app, which
    // the provider of the app entry builds, follows the theme mode.
    expect(named('theme_role').roles, {themeRole, appEntryRole});
    // The test of the look of the fixture theme checks that the root
    // follows a widget that the themes of a provider read from its context.
    expect(named('theme_look').roles, {appEntryRole});

    expect(appTests.roleProblems(fixtureModules(), apps), isEmpty);
  });

  test(
      'no app test reads the name or the options of an app of the matrix: '
      'each takes what a role chose for the app, such as the value of a '
      'mode option, from the roles of the app', () {
    expect(appTests.modeProblems(apps), isEmpty);
  });

  test(
      'the test of the DI role applies only to the apps with the role whose '
      'services have every lifetime, of each DI container', () {
    final diRoleTest = named('di_role');

    for (final app in apps) {
      final hook = app.hook!;
      final lifetimes = hook.presentRoles.contains(diRole)
          ? {
              for (final registration
                  in diRole.graphOf(diRole.hookInput(hook)).ordered)
                registration.lifetime,
            }
          : const <DiLifetime>{};
      expect(
        diRoleTest.appliesTo(app),
        lifetimes.containsAll(DiLifetime.values),
        reason: app.name,
      );
    }
    // Those of the fixture services, with each container.
    expect(
      appsOf(diRoleTest),
      containsAll([
        'fake_registrations (fake_di)',
        'fake_registrations (get_it)',
      ]),
    );
  });

  test(
      'the test of the disposal of the fixture services applies to the apps '
      'with them, of each DI container, which have the test of the DI role '
      'too', () {
    final disposal = appsOf(named('di_disposal'));

    expect(disposal, [
      for (final app in apps)
        if (app.modules.contains(FakeRegistrationsModule.id)) app.name,
    ]);
    expect(
      disposal,
      containsAll([
        'fake_registrations (fake_di)',
        'fake_registrations (get_it)',
      ]),
    );
    // So it adds no app to those that run flutter test for the DI role.
    expect(appsOf(named('di_role')), containsAll(disposal));
  });

  test(
      'the tests of the events role, of the preferences role, of the '
      'localization role, of the theme role and of the walk of the routes '
      'apply only to the apps with every module, which have the roles and '
      'run flutter test for other tests already', () {
    final everyModule = [
      for (final app in apps)
        if (app.everyModuleWith != null) app,
    ];

    expect(appsOf(named('events_role')), [
      for (final app in everyModule) app.name,
    ]);
    // So do the test of the preferences that the CLI keeps, the test of
    // the restorers of the fixture setting, which every such app has, the
    // test of the theme role that the CLI keeps, for the fixture theme,
    // and the test of the look of that theme, which every such app has.
    for (final name in [
      'preferences_role',
      'preferences_restorers',
      'theme_role',
      'theme_look',
    ]) {
      expect(
        appsOf(named(name)),
        [for (final app in everyModule) app.name],
        reason: name,
      );
    }
    // So does the test of the localization role that the CLI keeps: each
    // such app has the texts of the second fixture feature, in two
    // languages of the app.
    expect(appsOf(named('localization_role')), [
      for (final app in everyModule) app.name,
    ]);
    for (final app in everyModule) {
      final input = localizationRole.hookInput(app.hook!);
      expect(
        localizationRole.localesIn(input),
        ['en', 'uk'],
        reason: app.name,
      );
      expect(localizationRole.textsIn(input), isNotEmpty, reason: app.name);
    }
    // So does the walk of the routes, which goes to the start screens of
    // both fixture features, destinations of the main navigation, with
    // each router and each layout.
    expect(appsOf(named('router_walk')), [
      for (final app in everyModule) app.name,
    ]);
    // One for each combination of the providers of the roles that take one,
    // and each once more for the other value of the mode option of the
    // fixture clock.
    expect(everyModule, hasLength(16));
    expect(everyModule.where((app) => app.modes.isEmpty), hasLength(8));
    for (final app in everyModule) {
      expect(
        app.hook!.presentRoles,
        containsAll([eventsRole, preferencesRole, themeRole]),
        reason: app.name,
      );
      expect(
        app.modules,
        containsAll([FakePreferencesUserModule.id, FakeThemeModule.id]),
        reason: app.name,
      );
      expect(appsOf(named('router_screens')), contains(app.name));
    }
  });

  test(
      'the test of the hours of the fixture clock applies to the apps with '
      'every module, which have the clock and the module that uses it, and '
      'gets the hours that the clock role chose for each: 24 in an app that '
      'got no value of the option of the role, and 12 in the app of the '
      'other value', () {
    final clockHours = named('clock_hours');
    final everyModule = [
      for (final app in apps)
        if (app.everyModuleWith != null) app,
    ];

    // It tests a module, not the contract of a role.
    expect(clockHours.roles, isEmpty);
    expect(appsOf(clockHours), [for (final app in everyModule) app.name]);
    expect(
      {for (final app in everyModule) app.name: clockHours.values!(app)},
      {
        for (final app in everyModule)
          app.name: {
            'clock_hours': app.name.endsWith(' --clock-hours=12') ? '12' : '24',
          },
      },
    );
    expect(
      [
        for (final app in everyModule)
          if (clockHours.values!(app)['clock_hours'] == '12') app.name,
      ],
      hasLength(8),
    );
    // The hours come from the choice of the role, which an app has without
    // the option too.
    final byDefault = everyModule.first;
    expect(
      clockHours.values!(
        MatrixApp(
          byDefault.name,
          byDefault.modules,
          everyModuleWith: byDefault.everyModuleWith,
          hook: byDefault.hook,
        ),
      ),
      {'clock_hours': '24'},
    );
    // The apps of the clock alone run no test for it.
    for (final name in [
      'fake_clock_badge',
      'fake_clock_user with clock, badge',
      'clock by fake_clock_badge --clock-hours=12',
    ]) {
      expect(
        clockHours.appliesTo(apps.singleWhere((app) => app.name == name)),
        isFalse,
        reason: name,
      );
    }
  });

  /// The modules of the fixtures that provide the router role.
  List<ModuleId> routers() => [
        for (final module in fixtureModules())
          if (module.descriptor.provides.contains(routerRole))
            module.descriptor.id,
      ];

  test(
      'the apps with every module come with the fixture gates and without '
      'them, with each router: the gates are in the apps with the state '
      'manager that they depend on, whichever the other providers are, so '
      'every covering of the pairs of providers has both kinds for each '
      'router; and the fixture late gate is in the apps with the fixture '
      'gates, before them, though the app asks its guard after theirs', () {
    final everyModule = [
      for (final app in apps)
        if (app.everyModuleWith != null) app,
    ];
    bool hasGates(MatrixApp app) => app.modules.contains(FakeGateModule.id);

    expect(routers(), hasLength(greaterThan(1)));
    for (final app in everyModule) {
      expect(
        hasGates(app),
        app.modules.contains(FakeGateModule.stateManager),
        reason: app.name,
      );
      expect(
        app.modules.contains(FakeLateGateModule.id),
        hasGates(app),
        reason: app.name,
      );
      if (!hasGates(app)) continue;
      // The stages of the guards go against the order of their modules.
      expect(
        app.modules.indexOf(FakeLateGateModule.id),
        lessThan(app.modules.indexOf(FakeGateModule.id)),
        reason: app.name,
      );
      expect(
        [
          for (final guard
              in routerRole.facadeOf(routerRole.hookInput(app.hook!)).guards)
            '${guard.fullName} ${guard.guard.stage.name}',
        ],
        [
          'fake_gate.first welcome',
          'fake_gate.second welcome',
          'fake_late_gate.late identity',
        ],
        reason: app.name,
      );
    }
    // A state manager is a role that takes one provider and has two here,
    // so each router is in an app with each of them.
    for (final router in routers()) {
      final ofRouter = everyModule.where((app) => app.modules.contains(router));
      expect(ofRouter.where(hasGates), isNotEmpty, reason: '$router');
      expect(
        ofRouter.where((app) => !hasGates(app)),
        isNotEmpty,
        reason: '$router',
      );
    }
  });

  test(
      'the tests of the listeners of the screen, of the layout and of the '
      'walk of the routes run in apps without guards too, with each router '
      'and a main navigation, which is what most apps are', () {
    for (final name in [
      'router_screens',
      'router_listeners',
      'layout_screens',
      'router_walk',
    ]) {
      final test = named(name);
      for (final router in routers()) {
        expect(
          [
            for (final app in apps)
              if (test.appliesTo(app) &&
                  app.modules.contains(router) &&
                  app.hook!.presentRoles.contains(layoutRole) &&
                  routerRole
                      .facadeOf(routerRole.hookInput(app.hook!))
                      .guards
                      .isEmpty)
                app.name,
          ],
          isNotEmpty,
          reason: '$name runs in no app of $router without guards and with '
              'a main navigation.',
        );
      }
    }
  });

  test(
      'the tests of the guards of the routes apply to the apps with every '
      'module that have the fixture gates and the fixture late gate, with '
      'each router, which run flutter test for other tests already; with a '
      'page over the main navigation, to those of them with a layout', () {
    final guards = named('router_guards');
    final withLayout = named('layout_guards');

    expect(appsOf(guards), [
      for (final app in apps)
        if (app.everyModuleWith != null &&
            app.modules.contains(FakeGateModule.id))
          app.name,
    ]);
    // They close and open the late gate too, so no app of either module
    // alone has them.
    for (final app in apps) {
      if (!guards.appliesTo(app)) continue;
      expect(app.modules, contains(FakeLateGateModule.id), reason: app.name);
    }
    // The test with the main navigation uses the helpers of the tests of
    // the guards.
    expect(appsOf(guards), containsAll(appsOf(withLayout)));
    for (final test in [guards, withLayout]) {
      for (final router in routers()) {
        expect(
          [
            for (final app in apps)
              if (test.appliesTo(app) && app.modules.contains(router)) app.name,
          ],
          isNotEmpty,
          reason: 'No app with $router has ${nameOf(test)}.',
        );
      }
    }
  });

  test(
      'the test of the guards over the fallback screen applies to the apps '
      'with the fixture gates in which no route starts the app, with each '
      'router', () {
    final fallback = named('router_guards_fallback');

    expect(appsOf(fallback), [
      for (final router in routers()) 'fake_gate ($router)',
    ]);
    for (final app in apps) {
      if (!fallback.appliesTo(app)) continue;
      expect(
        routerRole.startIn(routerRole.hookInput(app.hook!)),
        isNull,
        reason: app.name,
      );
    }
  });

  test(
      'the app of the fixture setting without the preferences gets no test '
      'of the preferences', () {
    final without = apps.singleWhere(
      (app) => app.name == 'fake_preferences_user',
    );

    expect(without.hook!.presentRoles, isNot(contains(preferencesRole)));
    for (final name in ['preferences_role', 'preferences_restorers']) {
      expect(named(name).appliesTo(without), isFalse, reason: name);
    }
  });

  test(
      'the test of the walk of the routes while a guard keeps the user out '
      'applies to the apps with the walk and the fixture gates, with each '
      'router', () {
    final walkGuards = named('router_walk_guards');

    expect(appsOf(walkGuards), isNotEmpty);
    // It runs the walk that the CLI keeps, with the file that the matrix
    // writes for it.
    expect(appsOf(named('router_walk')), containsAll(appsOf(walkGuards)));
    for (final app in apps) {
      if (!walkGuards.appliesTo(app)) continue;
      expect(
        app.modules,
        containsAll(const [ModuleId('fake_gate'), ModuleId('fake_late_gate')]),
        reason: app.name,
      );
    }
    for (final module in fixtureModules()) {
      if (!module.descriptor.provides.contains(routerRole)) continue;
      expect(
        [
          for (final app in apps)
            if (walkGuards.appliesTo(app) &&
                app.modules.contains(module.descriptor.id))
              app.name,
        ],
        isNotEmpty,
        reason: 'No app with ${module.descriptor.id} has the test of the walk '
            'while a guard keeps the user out.',
      );
    }
  });

  test(
      'the walk of the routes goes to the routes of the fixture gates and '
      'of the fixture late gate, the flows of their guards, and to the '
      'routes of the other fixtures, in the order of the routes of the app; '
      'and its file has the targets of the guards in the order the app asks '
      'the guards, by their stages', () {
    // The apps with every fixture, where the test of the walk closes and
    // opens a gate: the walk has locations of the flows of the three
    // guards and locations outside them to check there.
    final withGates = apps.where(named('router_walk_guards').appliesTo);
    expect(withGates, isNotEmpty);
    for (final app in withGates) {
      final file =
          named('router_walk').generatedFiles!(app, 'my_app')[routerWalkFile]!;
      final targetsAt = file.indexOf('guardTargets = [');
      expect(targetsAt, isPositive, reason: app.name);
      // The routes come in the order of the modules, the late gate first.
      expect(
        _walkedRoutesOf(file),
        [
          'fake_feature.home',
          'fake_second.second',
          'fake_second.outside',
          'fake_late_gate.gate',
          'fake_gate.gate',
          'fake_gate.step',
          'fake_gate.second',
        ],
        reason: app.name,
      );
      // The targets come in the order of the guards, the late gate last.
      expect(
        [
          for (final route in RegExp(r"route: '([\w.]+)'").allMatches(
            file.substring(
              targetsAt,
              file.indexOf('const ShownScreen startOfApp'),
            ),
          ))
            route[1],
        ],
        ['fake_gate.gate', 'fake_gate.second', 'fake_late_gate.gate'],
        reason: app.name,
      );
    }
  });

  test(
      'the tests that use the helpers of router_screens apply only to the '
      'apps that have them', () {
    final routerScreens = appsOf(named('router_screens'));

    for (final name in [
      'router_listeners',
      'router_guards',
      'layout_guards',
      'router_walk_guards',
      'layout_screens',
      'go_router_screens',
      'bottom_tabs_screens',
    ]) {
      expect(routerScreens, containsAll(appsOf(named(name))), reason: name);
    }
  });

  test(
      'the test of the tabs of bottom_tabs applies only to the apps with the '
      'tests of the layout, whose labels of the destinations it reads', () {
    final tabs = appsOf(named('bottom_tabs_screens'));

    expect(tabs, isNotEmpty);
    expect(appsOf(named('layout_screens')), containsAll(tabs));
  });

  group(
      'the labels of the destinations that the matrix writes for the tests '
      'of the layout', () {
    /// The top-level declarations of the Dart [code] by name, each as its
    /// source, and the URIs of its imports under the name `import`.
    Map<String, String> declarationsOf(String code) {
      final unit = parseString(content: code).unit;
      return {
        'import': [
          for (final directive in unit.directives.whereType<ImportDirective>())
            directive.uri.stringValue,
        ].join(', '),
        for (final declaration in unit.declarations)
          if (declaration case FunctionDeclaration(:final name))
            name.lexeme: declaration.toSource()
          else if (declaration
              case TopLevelVariableDeclaration(:final variables))
            variables.variables.single.name.lexeme: declaration.toSource(),
      };
    }

    /// The file of the labels of [app], whose package is `my_app`.
    Map<String, String> labelsOf(MatrixApp app) {
      final files = named('layout_screens').generatedFiles!(app, 'my_app');
      expect(files.keys, [destinationLabelsFile]);
      return declarationsOf(files[destinationLabelsFile]!);
    }

    test(
        'are in each language of an app with the localization role: the '
        'label of a feature that gave the role its text in that language, '
        'and that of a feature that does not list the role in English', () {
      final everyModule = [
        for (final app in apps)
          if (app.everyModuleWith != null) app,
      ];

      expect(everyModule, isNotEmpty);
      for (final app in everyModule) {
        expect(named('layout_screens').appliesTo(app), isTrue);
        expect(
          labelsOf(app),
          {
            'import': 'package:flutter/widgets.dart, '
                'package:my_app/core/l10n/app_locale.dart',
            'labelLanguages': "const List<String> labelLanguages = ['en', "
                "'uk'];",
            'destinationLabels': 'const Map<String, List<String>> '
                "destinationLabels = {'en' : ['Fixture', 'Second'], "
                "'uk' : ['Fixture', 'Другий']};",
            'chooseLanguage': 'Future<void> chooseLanguage(String language) '
                '=> appLocale.choose(Locale(language));',
            'followDevice': 'Future<void> followDevice() => '
                'appLocale.choose(null);',
          },
          reason: app.name,
        );
      }
    });

    test(
        'are in English alone for an app without the localization role, '
        'whose file names nothing of that role', () async {
      // The app of a broken layout, which has both fixture features and no
      // texts.
      final provider = brokenProviders().firstWhere(
        (provider) =>
            identical(provider.role, layoutRole) &&
            !provider.app.contains(FakeL10nModule.id),
      );
      final (:app, :problems) = await provider.failingApp.check();
      expect(problems, isEmpty);
      expect(app!.hook!.presentRoles, isNot(contains(localizationRole)));
      expect(named('layout_screens').appliesTo(app), isTrue);

      expect(labelsOf(app), {
        'import': '',
        'labelLanguages': "const List<String> labelLanguages = ['en'];",
        'destinationLabels': 'const Map<String, List<String>> '
            "destinationLabels = {'en' : ['Fixture', 'Second']};",
        'chooseLanguage': 'Future<void> chooseLanguage(String language) '
            'async {}',
        'followDevice': 'Future<void> followDevice() async {}',
      });
    });

    test(
        'are in the languages of the app only, with the English text of a '
        'label that has no translation into one of them', () async {
      // The app of the broken layout with texts, in the languages of
      // --locales.
      final provider = brokenProviders().firstWhere(
        (provider) =>
            identical(provider.role, layoutRole) &&
            provider.app.contains(FakeL10nModule.id),
      );
      final (apps: all, :failed) = await matrixOf(
        provider.modules,
        roleOptions: const {'locales': 'en'},
      );
      expect(failed, isEmpty);
      final app = all.firstWhere(named('layout_screens').appliesTo);

      final labels = labelsOf(app);
      expect(
        labels['labelLanguages'],
        "const List<String> labelLanguages = ['en'];",
      );
      expect(
        labels['destinationLabels'],
        'const Map<String, List<String>> destinationLabels = '
        "{'en' : ['Fixture', 'Second']};",
      );
      // The app has the role, so the file puts it into a language.
      expect(labels['chooseLanguage'], contains('appLocale.choose('));
    });
  });

  group('the app of several providers', () {
    late MatrixAppTests severalProviders;
    late List<MatrixApp> matrix;
    late MatrixApp everyModule;

    setUpAll(() async {
      severalProviders = await severalProvidersAppTests();
      final (apps: all, :failed) = await matrixOf(severalProvidersModules());
      expect(failed, isEmpty);
      matrix = all;
      everyModule = matrix.singleWhere((app) => app.everyModuleWith != null);
    });

    /// The app test of the app of several providers whose files are in the
    /// directory [name].
    MatrixAppTest ofSeveral(String name) =>
        severalProviders.tests.singleWhere((test) => nameOf(test) == name);

    test(
        'gets the app tests of the modules of the CLI, the tests of the DI '
        'role, of the events role, of the preferences role, of the settings '
        'screen role and of the theme role, the mocks of the fixture '
        'providers and the tests of the roles of several providers, which '
        'all apply to it', () {
      expect(
        [for (final test in severalProviders.tests) nameOf(test)],
        containsAll([
          'firebase_core',
          'firebase_crashlytics',
          'firebase_analytics',
          'screen_views',
          'onboarding',
          'settings',
          'shared_preferences',
          'home',
          'di_role',
          'events_role',
          'preferences_role',
          'router_walk',
          'settings_screen_role',
          'theme_role',
          'theme_setting',
          'fake_crash',
          'fake_analytics',
          'analytics_role',
          'crash_reporting_role',
          'localization_role',
          'language_setting',
        ]),
      );
      for (final test in severalProviders.tests) {
        expect(test.appliesTo(everyModule), isTrue, reason: test.directory);
      }
    });

    test(
        'starts on the screen of the fixture feature, with the start screen '
        'of the CLI among its routes, so the app test of that screen, which '
        'applies to it, goes to its screen through the navigation of the '
        'router role', () {
      final input = routerRole.hookInput(everyModule.hook!);

      expect(routerRole.startIn(input)!.fullName, 'fake_second.second');
      expect(
        [
          for (final route in routerRole.facadeOf(input).routes)
            if (!route.hasRequiredParams) route.fullName,
        ],
        contains('home.home'),
      );
      expect(ofSeveral('home').appliesTo(everyModule), isTrue);
    });

    test(
        'has the setting of the language, with texts in two languages: its '
        'app has the localization role and the settings screen role, and '
        'the test of the setting, a test of the localization role, applies '
        'to it with the helper of the tests of the settings screen', () {
      final hook = everyModule.hook!;
      final setting = ofSeveral('language_setting');

      expect(
        hook.presentRoles,
        containsAll([localizationRole, settingsScreenRole, preferencesRole]),
      );
      expect(
        localizationRole.localesIn(localizationRole.hookInput(hook)),
        ['en', 'uk'],
      );
      expect(
        [
          for (final entry in settingsScreenRole
              .entriesIn(settingsScreenRole.hookInput(hook)))
            entry.file,
        ],
        contains(LocalizationRole.languageSettingFile),
      );
      expect(setting.roles, {localizationRole});
      expect(setting.appliesTo(everyModule), isTrue);
      // It opens the settings screen with the helper of those tests, which
      // every app that it applies to has.
      for (final app in matrix.where(setting.appliesTo)) {
        expect(
          ofSeveral('settings_screen_role').appliesTo(app),
          isTrue,
          reason: app.name,
        );
      }
    });

    test(
        'checks the contract of the analytics role and of the crash reporting '
        'role with every provider of each, which it tells apart by the roles '
        'of the app only, in the app with every module only', () {
      expect(severalProviders.testedRoles, {analyticsRole, crashReportingRole});
      for (final (name, role) in [
        ('analytics_role', analyticsRole),
        ('crash_reporting_role', crashReportingRole),
      ]) {
        final test = ofSeveral(name);
        expect(test.roles, {role}, reason: name);
        // The tests look at the service log of the fixtures, which only the
        // app with every module of the registry is sure to have.
        expect(
          [
            for (final app in matrix)
              if (test.appliesTo(app)) app,
          ],
          [everyModule],
          reason: name,
        );
      }

      expect(
        severalProviders.roleProblems(severalProvidersModules(), matrix),
        isEmpty,
      );
      expect(severalProviders.modeProblems(matrix), isEmpty);
    });
  });
}
