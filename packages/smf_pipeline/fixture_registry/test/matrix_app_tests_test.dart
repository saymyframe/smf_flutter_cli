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
import 'package:fake_roles/fake_roles.dart';
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
      'of the localization role, of the theme role, of the app entry role '
      'and of the auth role with every provider of each, which they tell '
      'apart by the roles of the app only', () {
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
        authRole,
      ]),
    );
    expect(named('auth_role').roles, {authRole});
    expect(named('localization_role').roles, {localizationRole});
    expect(named('router_screens').roles, {routerRole});
    expect(named('router_listeners').roles, {routerRole});
    expect(named('router_guards').roles, {routerRole});
    expect(named('router_conditions').roles, {routerRole});
    expect(named('router_flow_opens').roles, {routerRole});
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
    // and each once more for every other combination of the values of the
    // two mode options of the fixtures: the three modes of the auth role
    // and the two of the fixture clock.
    expect(everyModule, hasLength(48));
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
      'other value, in each mode of the auth role', () {
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
    // Each app with every module has a clock of 12 hours once in each of
    // the three modes of the auth role, whose option comes before that of
    // the clock in the name of an app.
    expect(
      [
        for (final app in everyModule)
          if (clockHours.values!(app)['clock_hours'] == '12') app.name,
      ],
      hasLength(24),
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

  test(
      'the test of the auth role applies to every app with the role, the '
      'apps of the fixture sign-in alone, with a router and without one, '
      'and the apps with every module, in each mode of the role, and gets '
      'the mode that the role chose for each: required in an app that got '
      'no value of the option of the role', () {
    final authTest = named('auth_role');
    final withRole = [
      for (final app in apps)
        if (app.hook!.presentRoles.contains(authRole)) app,
    ];

    expect(appsOf(authTest), [for (final app in withRole) app.name]);
    expect(
      appsOf(authTest),
      containsAll([
        // The role uses the router role, so its provider has an app with
        // each router and one without, and the app of each other mode has
        // the first router.
        'fake_auth (fake_router) with router',
        'fake_auth (go_router) with router',
        'fake_auth',
        'auth by fake_auth (fake_router) with router --auth-mode=guest',
        'auth by fake_auth (fake_router) with router --auth-mode=anonymous',
        for (final app in apps)
          if (app.everyModuleWith != null) app.name,
      ]),
    );
    // The apps without the role get no test of it.
    expect(authTest.appliesTo(apps.first), isFalse);
    expect(apps.first.hook!.presentRoles, isNot(contains(authRole)));
    final modeInName = RegExp(r' --auth-mode=(\w+)');
    expect(
      {for (final app in withRole) app.name: authTest.values!(app)},
      {
        for (final app in withRole)
          app.name: {
            'auth_mode': modeInName.firstMatch(app.name)?[1] ?? 'required',
          },
      },
    );
    // The apps of each mode: those of the fixture alone, three in the
    // default mode and one in each other mode, and each app with every
    // module with a clock of 24 hours and with one of 12.
    expect(
      {
        for (final mode in AuthMode.values)
          mode.name: withRole
              .where((app) => authTest.values!(app)['auth_mode'] == mode.name)
              .length,
      },
      {'required': 19, 'guest': 17, 'anonymous': 17},
    );
    // The mode comes from the choice of the role, which an app has without
    // the option too.
    final byDefault = withRole.first;
    expect(
      authTest.values!(
        MatrixApp(byDefault.name, byDefault.modules, hook: byDefault.hook),
      ),
      {'auth_mode': 'required'},
    );
    // The matrix writes no file for it, and it has neither mocks nor a
    // probe for the start check: nobody can sign in on a device.
    expect(authTest.generatedFiles, isNull);
    expect(authTest.mocks, isNull);
    expect(authTest.startProbe, isNull);
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
      'gates, before them, though the app asks its guard after their gates, '
      'and the guard of a condition of the fixture gates after every gate', () {
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
      // And the guards that stand for a condition come after the gates,
      // that of a later stage too, though their module declares the first
      // of them second.
      final facade = routerRole.facadeOf(routerRole.hookInput(app.hook!));
      expect(
        [
          for (final guard in facade.guards)
            [
              guard.fullName,
              guard.guard.stage.name,
              if (guard.guard.condition case final condition?) '$condition',
            ].join(' '),
        ],
        [
          'fake_gate.first welcome',
          'fake_gate.second welcome',
          'fake_late_gate.late identity',
          'fake_gate.holder welcome badge.holder',
          'fake_gate.senior welcome badge.senior',
        ],
        reason: app.name,
      );
      expect(
        [
          for (final feature in facade.features)
            for (final guard in feature.guards) guard.fullName,
        ],
        [
          'fake_late_gate.late',
          'fake_gate.first',
          'fake_gate.holder',
          'fake_gate.second',
          'fake_gate.senior',
        ],
        reason: app.name,
      );
      // The app has the role of the conditions, which the fixture gates
      // require, and the routes of the second fixture feature ask for
      // them, one of them for both.
      expect(app.hook!.presentRoles, contains(badgeRole), reason: app.name);
      expect(
        [
          for (final route in facade.routesAsking(BadgeRole.holder))
            route.fullName,
        ],
        [
          'fake_second.vault',
          'fake_second.members',
          'fake_second.memberCard',
          'fake_second.loungeSeat',
        ],
        reason: app.name,
      );
      expect(
        [
          for (final route in facade.routesAsking(BadgeRole.senior))
            route.fullName,
        ],
        ['fake_second.lounge', 'fake_second.loungeSeat'],
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
      'the tests of a guard that stands for a condition apply to the apps '
      'with the tests of the guards, which have the guard of the fixture '
      'gates for the condition of the fixture badge role and the routes of '
      'the second fixture feature that ask for it, with each router', () {
    final conditions = named('router_conditions');

    // They use the helpers of the tests of the guards, and close and open
    // the gates and the late gate too.
    expect(appsOf(conditions), appsOf(named('router_guards')));
    for (final app in apps) {
      if (!conditions.appliesTo(app)) continue;
      final facade = routerRole.facadeOf(routerRole.hookInput(app.hook!));
      final guard = facade.guardFor(BadgeRole.holder);
      expect(guard?.fullName, 'fake_gate.holder', reason: app.name);
      // The guard has the flow of a gate of its module, and does not bring
      // the user back.
      expect(
        [
          for (final other in facade.guards)
            if (other.isGate && other.target == guard!.target) other.fullName,
        ],
        ['fake_gate.first'],
        reason: app.name,
      );
      expect(guard!.guard.resumes, isFalse, reason: app.name);
      // One route lists the condition itself below a route that asks
      // for nothing, so that a router has to ask about the route of a
      // location and not about the route above it. Another asks by being
      // below one that does. All are outside the main navigation.
      final routes = facade.routesAsking(BadgeRole.holder);
      String asks(FacadeRoute route) {
        final own = '${route.route.name} ${route.route.conditions.length}';
        final parent = route.parent;
        return parent == null
            ? own
            : '$own below ${parent.route.name}, which asks for '
                '${parent.conditions.length}';
      }

      // And one asks for a second condition too, by being below a route
      // that asks for that one.
      expect(
        routes.map(asks),
        [
          'vault 1 below outside, which asks for 0',
          'members 1',
          'memberCard 0 below members, which asks for 1',
          'loungeSeat 1 below lounge, which asks for 1',
        ],
        reason: app.name,
      );
      for (final route in routes) {
        expect(route.topLevel.route.destination, isNull, reason: app.name);
      }
      // The second condition has a guard of its own, with another flow:
      // that of the second gate. The app asks it after the first.
      final second = facade.guardFor(BadgeRole.senior);
      expect(second?.fullName, 'fake_gate.senior', reason: app.name);
      expect(
        [
          for (final other in facade.guards)
            if (other.isGate && other.target == second!.target) other.fullName,
        ],
        ['fake_gate.second'],
        reason: app.name,
      );
      expect(second!.target, isNot(guard.target), reason: app.name);
      expect(
        facade.guards.indexOf(guard),
        lessThan(facade.guards.indexOf(second)),
        reason: app.name,
      );
    }
    for (final router in routers()) {
      expect(
        [
          for (final app in apps)
            if (conditions.appliesTo(app) && app.modules.contains(router))
              app.name,
        ],
        isNotEmpty,
        reason: 'No app with $router has the tests of the conditions.',
      );
    }
    // No app of the second fixture feature without the fixture gates has
    // them: its routes that ask for the condition have no guard there.
    for (final app in apps) {
      if (!app.modules.contains(FakeSecondModule.id)) continue;
      if (app.modules.contains(FakeGateModule.id)) continue;
      expect(conditions.appliesTo(app), isFalse, reason: app.name);
      expect(
        routerRole
            .facadeOf(routerRole.hookInput(app.hook!))
            .guardFor(BadgeRole.holder),
        isNull,
        reason: app.name,
      );
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
      'routes of the other fixtures, those that ask for a condition among '
      'them, in the order of the routes of the app; and its file has the '
      'targets of the guards in the order the app asks the guards, by their '
      'stages, each once', () {
    // The apps with every fixture, where the test of the walk closes and
    // opens a gate: the walk has locations of the flows of the guards,
    // locations that ask for a condition and others to check there.
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
          'fake_second.vault',
          'fake_second.members',
          'fake_second.memberCard',
          'fake_second.lounge',
          'fake_second.loungeSeat',
          'fake_late_gate.gate',
          'fake_gate.gate',
          'fake_gate.step',
          'fake_gate.second',
        ],
        reason: app.name,
      );
      // The targets come in the order of the guards, the late gate last.
      // The guard of a condition, which the app asks after it, shows the
      // target of the first guard, which the file has once.
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
      'the test of a request that opens the flow of a condition applies to '
      'each app with the tests of the conditions, and its apps have the '
      'guard of the condition and the route that the test asks for', () {
    final opens = named('router_flow_opens');

    expect(appsOf(opens), containsAll(appsOf(named('router_conditions'))));
    for (final app in apps.where(opens.appliesTo)) {
      final facade = routerRole.facadeOf(routerRole.hookInput(app.hook!));
      expect(
        facade.guardFor(BadgeRole.holder)?.fullName,
        'fake_gate.holder',
        reason: app.name,
      );
      expect(
        [
          for (final route in facade.routesAsking(BadgeRole.holder))
            route.fullName,
        ],
        contains('fake_second.members'),
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
      'router_conditions',
      'router_flow_opens',
      'layout_guards',
      'router_walk_guards',
      'layout_screens',
      'go_router_screens',
      'go_router_branches',
      'go_router_conditions',
      'bottom_tabs_screens',
    ]) {
      expect(routerScreens, containsAll(appsOf(named(name))), reason: name);
    }
  });

  test(
      'the test of the conditions of go_router applies to the apps of '
      'go_router with the tests of the conditions, whose helpers it uses', () {
    final conditions = named('go_router_conditions');
    final withConditions = apps.where(conditions.appliesTo).toList();

    expect(withConditions, isNotEmpty);
    for (final app in withConditions) {
      expect(app.modules, contains(const ModuleId('go_router')));
      // Each guard of the app that stands for a condition has routes that
      // ask for it.
      final facade = routerRole.facadeOf(routerRole.hookInput(app.hook!));
      expect(
        [
          for (final guard in facade.guards)
            if (guard.guard.condition case final condition?)
              facade.routesAsking(condition).length,
        ],
        [isPositive, isPositive],
        reason: app.name,
      );
    }
    expect(
      appsOf(named('router_conditions')),
      containsAll(appsOf(conditions)),
    );
    // And to each app of go_router with those tests.
    expect(
      appsOf(conditions),
      [
        for (final app in apps)
          if (named('router_conditions').appliesTo(app) &&
              app.modules.contains(const ModuleId('go_router')))
            app.name,
      ],
    );
    expect(conditions.roles, isEmpty);
  });

  test(
      'the test of the branches of go_router applies to the apps of '
      'go_router with a main navigation of both fixture features, those '
      'with guards and those without', () {
    final branches = named('go_router_branches');
    bool hasGuards(MatrixApp app) =>
        routerRole.facadeOf(routerRole.hookInput(app.hook!)).guards.isNotEmpty;
    final withBranches = apps.where(branches.appliesTo).toList();

    // The router asks the guards in the redirect of its routes, which stays
    // with the routes that get a new main navigation.
    expect(withBranches.where(hasGuards), isNotEmpty);
    expect(withBranches.where((app) => !hasGuards(app)), isNotEmpty);
    for (final app in withBranches) {
      expect(
        [
          for (final route
              in layoutRole.destinationsIn(layoutRole.hookInput(app.hook!)))
            route.fullName,
        ],
        containsAll(['fake_feature.home', 'fake_second.second']),
        reason: app.name,
      );
    }
    // And to no app that the tests of go_router of every app do not apply
    // to.
    expect(
      appsOf(named('go_router_screens')),
      containsAll(appsOf(branches)),
    );
    expect(named('go_router_screens').roles, isEmpty);
    expect(branches.roles, isEmpty);
  });

  test(
      'the test of the tabs of bottom_tabs applies only to the apps with the '
      'tests of the layout, whose labels of the destinations it reads', () {
    final tabs = appsOf(named('bottom_tabs_screens'));

    expect(tabs, isNotEmpty);
    expect(appsOf(named('layout_screens')), containsAll(tabs));
  });

  test(
      'the tests of the screens get the locations that a router shows from '
      'any page: of the routes that need no values, that no guard keeps the '
      'user from, and that are outside the main navigation of an app with '
      'one', () {
    final screens = named('router_screens');

    /// The classes of the locations in the file that the matrix writes for
    /// [app], whose package is `my_app`.
    List<String> locationsOf(MatrixApp app) {
      final files = screens.generatedFiles!(app, 'my_app');
      expect(files.keys, [locationsFromAnyPageFile]);
      final unit = parseString(content: files[locationsFromAnyPageFile]!).unit;
      expect(
        [
          for (final directive in unit.directives.whereType<ImportDirective>())
            directive.uri.stringValue,
        ],
        ['package:my_app/core/router/navigation.dart'],
      );
      final list = unit.declarations
          .whereType<TopLevelVariableDeclaration>()
          .single
          .variables;
      expect(list.isConst, isTrue);
      expect(list.type!.toSource(), 'List<AppLocation>');
      final variable = list.variables.single;
      expect(variable.name.lexeme, 'locationsFromAnyPage');
      return [
        for (final location in (variable.initializer! as ListLiteral).elements)
          (location as MethodInvocation).toSource(),
      ];
    }

    final withTests = [
      for (final app in apps)
        if (screens.appliesTo(app)) app,
    ];
    expect(withTests, isNotEmpty);
    for (final app in withTests) {
      final hook = app.hook!;
      final facade = routerRole.facadeOf(routerRole.hookInput(hook));
      final layout = hook.presentRoles.contains(layoutRole);
      // Every app that the tests apply to has such a location, which they
      // ask its router for from its error screen. Without a main
      // navigation, the start route of the fixture feature is one, and the
      // route below it needs a value. With one, both are in it, and so is
      // the destination of the second fixture feature, whose route outside
      // the main navigation is left. The routes of the flows of the guards,
      // and those that ask for a condition, are none either.
      expect(
        locationsOf(app),
        [
          if (layout)
            'FakeSecondOutsideLocation()'
          else
            'FakeFeatureHomeLocation()',
        ],
        reason: app.name,
      );
      expect(
        {for (final route in facade.destinations) route.fullName},
        layout
            ? containsAll(['fake_feature.home', 'fake_second.second'])
            : anything,
        reason: app.name,
      );
    }
    // An app with a router whose only routes are in its main navigation, or
    // that has none, has no such location.
    final withoutRoutes = [
      for (final app in apps)
        if (app.hook case final hook?
            when hook.presentRoles.contains(routerRole) &&
                routerRole.facadeOf(routerRole.hookInput(hook)).routes.isEmpty)
          app,
    ];
    expect(withoutRoutes, isNotEmpty);
    for (final app in withoutRoutes) {
      expect(locationsOf(app), isEmpty, reason: app.name);
    }
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
      // The app that the tool of several providers checks: the one that a
      // run of the apps with every module takes.
      everyModule =
          const MatrixSelection(everyModule: true).of(matrix).single.$2;
    });

    /// The app test of the app of several providers whose files are in the
    /// directory [name].
    MatrixAppTest ofSeveral(String name) =>
        severalProviders.tests.singleWhere((test) => nameOf(test) == name);

    test(
        'is the app with every module in the first mode of the auth role, '
        'which Firebase Authentication provides there: the matrix of the '
        'registry has it once more for each other mode, which a run of the '
        'apps with every module leaves out', () {
      expect(
        [
          for (final app in matrix)
            if (app.everyModuleWith != null) app.name,
        ],
        [
          'every module',
          'every module --auth-mode=guest',
          'every module --auth-mode=anonymous',
        ],
      );
      expect(everyModule.name, 'every module');
      expect(everyModule.modes, isEmpty);
      // It gets no value of the option, so the role chooses the first mode,
      // as for a user who does not give the option.
      expect(everyModule.roleOptions.keys, isNot(contains('auth-mode')));
      expect(
        authRole.modeIn(authRole.hookInput(everyModule.hook!)),
        AuthMode.required,
      );
    });

    test(
        'gets the app tests of the modules of the CLI, the tests of the DI '
        'role, of the events role, of the preferences role, of the auth '
        'role, of the settings screen role and of the theme role, the mocks '
        'of the fixture providers and the tests of the roles of several '
        'providers, which all apply to it', () {
      expect(
        [for (final test in severalProviders.tests) nameOf(test)],
        containsAll([
          'firebase_core',
          'firebase_crashlytics',
          'firebase_analytics',
          'screen_views',
          'firebase_auth',
          'auth_role',
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
        // apps with every module of the registry are sure to have: the one
        // that the tool checks, and the same app in the other modes of the
        // auth role.
        expect(
          [
            for (final app in matrix)
              if (test.appliesTo(app)) app,
          ],
          [
            for (final app in matrix)
              if (app.everyModuleWith != null) app,
          ],
          reason: name,
        );
        expect(test.appliesTo(everyModule), isTrue, reason: name);
      }

      expect(
        severalProviders.roleProblems(severalProvidersModules(), matrix),
        isEmpty,
      );
      expect(severalProviders.modeProblems(matrix), isEmpty);
    });
  });
}
