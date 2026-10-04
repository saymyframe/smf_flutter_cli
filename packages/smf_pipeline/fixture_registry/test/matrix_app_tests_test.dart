// The tests that the matrix of CI adds to the apps of the fixture modules
// (fixtureAppTests, which tool/matrix.dart runs), and to the app of
// several providers (severalProvidersAppTests, which
// tool/several_providers_matrix.dart runs). CI runs them only in its
// job with Flutter, which checks that they apply to some app and that they
// check the contract of their roles with every provider only at its end;
// these tests check the same without Flutter.
import 'package:fake_feature/fake_feature.dart';
import 'package:fake_infra/fake_infra.dart';
import 'package:fixture_registry/fixture_registry.dart';
import 'package:fixture_registry/matrix_app_tests.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/matrix.dart';
import 'package:test/test.dart';

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
      'role, of the DI role, of the events role and of the preferences role '
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
      ]),
    );
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

    expect(appTests.roleProblems(fixtureModules(), apps), isEmpty);
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
      'the tests of the events role, of the preferences role and of the walk '
      'of the routes apply only to the apps with every module, which have '
      'the roles and run flutter test for other tests already', () {
    final everyModule = [
      for (final app in apps)
        if (app.everyModuleWith != null) app,
    ];

    expect(appsOf(named('events_role')), [
      for (final app in everyModule) app.name,
    ]);
    // So do the test of the preferences that the CLI keeps and the test of
    // the restorers of the fixture setting, which every such app has.
    for (final name in ['preferences_role', 'preferences_restorers']) {
      expect(
        appsOf(named(name)),
        [for (final app in everyModule) app.name],
        reason: name,
      );
    }
    // So does the walk of the routes, which goes to the start screens of
    // both fixture features, destinations of the main navigation, with
    // each router and each layout.
    expect(appsOf(named('router_walk')), [
      for (final app in everyModule) app.name,
    ]);
    // One for each combination of the providers of the roles that take one.
    expect(everyModule, hasLength(8));
    for (final app in everyModule) {
      expect(
        app.hook!.presentRoles,
        containsAll([eventsRole, preferencesRole]),
        reason: app.name,
      );
      expect(
        app.modules,
        contains(FakePreferencesUserModule.id),
        reason: app.name,
      );
      expect(appsOf(named('router_screens')), contains(app.name));
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
      'router', () {
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
      'module that have the fixture gates, with each router, which run '
      'flutter test for other tests already; with a page over the main '
      'navigation, to those of them with a layout', () {
    final guards = named('router_guards');
    final withLayout = named('layout_guards');

    expect(appsOf(guards), [
      for (final app in apps)
        if (app.everyModuleWith != null &&
            app.modules.contains(FakeGateModule.id))
          app.name,
    ]);
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
      'the tests that use the helpers of router_screens apply only to the '
      'apps that have them', () {
    final routerScreens = appsOf(named('router_screens'));

    for (final name in [
      'router_listeners',
      'router_guards',
      'layout_guards',
      'layout_screens',
      'go_router_screens',
      'bottom_tabs_screens',
    ]) {
      expect(routerScreens, containsAll(appsOf(named(name))), reason: name);
    }
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
        'role, of the events role and of the preferences role, the mocks of '
        'the fixture providers and the tests of the roles of several '
        'providers, which all apply to it', () {
      expect(
        [for (final test in severalProviders.tests) nameOf(test)],
        containsAll([
          'firebase_core',
          'firebase_crashlytics',
          'firebase_analytics',
          'screen_views',
          'settings',
          'shared_preferences',
          'di_role',
          'events_role',
          'preferences_role',
          'router_walk',
          'settings_screen_role',
          'fake_crash',
          'fake_analytics',
          'analytics_role',
          'crash_reporting_role',
        ]),
      );
      for (final test in severalProviders.tests) {
        expect(test.appliesTo(everyModule), isTrue, reason: test.directory);
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
    });
  });
}
