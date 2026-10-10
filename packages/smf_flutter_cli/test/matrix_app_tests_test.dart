// The tests that the matrix of CI adds to the apps of the modules of
// `smf create` (smfAppTests, which tool/matrix.dart runs). CI runs them
// only in its job with Flutter, which checks that they apply to some app
// and that they check the contract of their roles with every provider
// only at its end; these tests check the same without Flutter.
import 'dart:convert';
import 'dart:io';

import 'package:mason/mason.dart';
import 'package:path/path.dart' as p;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_flutter_cli/matrix_app_tests.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:smf_sign_in/smf_sign_in.dart';
import 'package:test/test.dart';

/// A provider of the auth role for the test of the app test of the role,
/// which applies to the apps with the role whichever module provides it: a
/// service that has nobody signed in and takes no call.
final class _SignInOfTest extends SmfModule {
  const _SignInOfTest();

  /// The id of the module.
  static const id = ModuleId('sign_in_of_test');

  static const _path = 'core/sign_in_of_test/sign_in_of_test.dart';

  static const _file = ImportRef.app(_path);

  static const _source = '''
import '../auth/auth_service.dart';

AuthService createSignInOfTest() => const SignInOfTest();

final class SignInOfTest implements AuthService {
  const SignInOfTest();

  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> get userChanges => const Stream.empty();

  @override
  Future<void> signIn({required String email, required String password}) =>
      _refuse();

  @override
  Future<void> signUp({required String email, required String password}) =>
      _refuse();

  @override
  Future<void> linkPassword({
    required String email,
    required String password,
  }) =>
      _refuse();

  @override
  Future<void> signInAnonymously() => _refuse();

  @override
  Future<void> sendPasswordReset(String email) => _refuse();

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() => _refuse();

  Future<void> _refuse() async =>
      throw const AuthFailure(AuthFailureReason.notConfigured);
}
''';

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Sign-in that takes no call',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(authRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          MasonBundle(
            name: id.value,
            description: 'The service of the provider',
            version: '0.1.0',
            files: [
              MasonBundledFile(
                'lib/$_path',
                base64.encode(utf8.encode(_source)),
                'text',
              ),
            ],
          ),
        ),
        authRole.data(
          const RoleImplementation(
            type: TypeRef('SignInOfTest', import: _file),
            create: FactoryRef('createSignInOfTest', import: _file),
          ),
        ),
      ];
}

/// The apps with every module of the matrix of the CLI: one for each state
/// manager, and each once more for each other mode of the auth role, which
/// Firebase Authentication provides there.
const _everyModule = [
  'every module (bloc)',
  'every module (riverpod)',
  'every module (bloc) --auth-mode=guest',
  'every module (bloc) --auth-mode=anonymous',
  'every module (riverpod) --auth-mode=guest',
  'every module (riverpod) --auth-mode=anonymous',
];

/// The apps of the sign-in of the matrix of the CLI: one for each state
/// manager, with the localization and without. Each has a settings screen,
/// which the module requires for the entry of the account.
const List<String> _signIn = [
  ..._localizedSignIn,
  'sign_in (bloc)',
  'sign_in (riverpod)',
];

/// Those of them with the localization.
const _localizedSignIn = [
  'sign_in (bloc) with localization',
  'sign_in (riverpod) with localization',
];

/// The codes of the languages of the file of the texts of a module that
/// the matrix writes for an app, [file], in the order of the file.
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
      'of the events role, of the preferences role, of the auth role, of '
      'the settings screen role, of the theme role, of the localization '
      'role and of the app entry role with every provider of each, which '
      'they tell apart by the roles of the app only', () {
    expect(
      appTests.testedRoles,
      containsAll([
        routerRole,
        diRole,
        eventsRole,
        preferencesRole,
        authRole,
        settingsScreenRole,
        themeRole,
        appEntryRole,
        localizationRole,
      ]),
    );
    expect(named('screen_views').roles, contains(routerRole));
    expect(named('onboarding').roles, {routerRole});
    expect(named('sign_in').roles, {routerRole});
    expect(named('di_role').roles, {diRole});
    expect(named('events_role').roles, {eventsRole});
    expect(named('preferences_role').roles, {preferencesRole});
    expect(named('auth_role').roles, {authRole});
    // The test of the provider of the role checks what only it does.
    expect(named('firebase_auth').roles, isEmpty);
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
      'no app test reads the name or the options of an app of the matrix: '
      'each takes what a role chose for the app, such as the value of a '
      'mode option, from the roles of the app', () {
    expect(appTests.modeProblems(apps), isEmpty);
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
      _everyModule,
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
      [
        'WalkedLocation',
        'ShownScreen',
        'walkedLocations',
        'shownFor',
        'closedGuards',
      ],
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
    // No module of the app has a guard of the routes: the walk expects the
    // page and the screen of each location itself, and the file names
    // nothing of what the role generates for guards, which the app does not
    // have, nor the screen that the app starts on, which only a flow that
    // is over shows in place of a location.
    expect(
      files[routerWalkFile],
      contains(
        'ShownScreen shownFor(WalkedLocation walked) =>\n'
        '    (route: walked.route, screen: walked.screen);\n',
      ),
    );
    expect(
      files[routerWalkFile],
      contains('List<String> closedGuards() => const [];\n'),
    );
    for (final name in [
      RouterRole.redirectOf,
      RouterRole.flowIsOver,
      RouterRole.routeGuards,
      'startOfApp',
    ]) {
      expect(files[routerWalkFile], isNot(contains(name)));
    }
  });

  test(
      'in an app with guards of the routes, the file of the walk has the '
      'target of each guard once, also one beyond the locations that the '
      'walk goes to, the screen that the app starts on, what the router '
      'shows for a location, and the guards that do not allow', () {
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
    RouteGuard guard(
      String name,
      String target, {
      GuardStage stage = GuardStage.welcome,
    }) =>
        RouteGuard(
          name: name,
          allows: FunctionRef(name, import: status),
          redirectTo: target,
          stage: stage,
        );
    // An app that starts on the route at [start], or on the fallback start
    // screen of the app entry if no route starts it.
    String fileOf({String? start}) => named('router_walk').generatedFiles!(
          MatrixApp(
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
                          // As many routes as fill the walk with the two
                          // above.
                          for (var index = 2; index < routerWalkLimit; index++)
                            route('/r$index', 'Screen$index'),
                          route('/login', 'LoginScreen'),
                        ],
                        // The module declares its guard of the later
                        // stage first: the app asks it last.
                        guards: [
                          guard(
                            'signedIn',
                            'login',
                            stage: GuardStage.identity,
                          ),
                          guard('firstRun', 'intro'),
                          guard('consent', 'intro'),
                        ],
                      ),
                    )
                    .withOrigin(const ModuleOrigin(ModuleId('gate'))),
              ],
              presentRoles: {routerRole},
              context: ContractHarness.defaultContext,
              choices: {routerRole: RouterChoice(startPath: start)},
            ),
          ),
          'my_app',
        )[routerWalkFile]!;

    final text = fileOf(start: '/gate/r2');

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
        'ShownScreen',
        'walkedLocations',
        'guardTargets',
        'startOfApp',
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
      text.indexOf('const ShownScreen startOfApp'),
    );
    // The walk does not go to the target of the last guard, which is past
    // its limit; the file has it all the same, for the walk to expect it.
    // The targets are in the order the app asks the guards, by their
    // stages, and not as the module declares them.
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
    // The screen that the app starts on: that of the route that the router
    // role chose, with the name of that route.
    expect(
      text,
      contains(
        'const ShownScreen startOfApp = (\n'
        "  route: 'gate.r2',\n"
        '  screen: screen0.Screen2,\n'
        ');\n',
      ),
    );
    // What the router shows for a location is what the role says of its
    // route: the target of the guard that keeps the user from it, as
    // redirectOf() says, which decides first; else the screen that the app
    // starts on if flowIsOver() says that its flow is over; else the
    // location itself. And the guards that do not allow are those of
    // routeGuards of the role.
    expect(
      [
        for (final call in index.invocations)
          if (call.target == null) call.name,
      ],
      containsAllInOrder([RouterRole.redirectOf, RouterRole.flowIsOver]),
    );
    expect(
      text,
      contains(
        '  final target = redirectOf(walked.route);\n'
        '  if (target != null) {\n'
        '    final shown = guardTargets.firstWhere(\n'
        '      (shown) => shown.route == target.routeName,\n'
        '    );\n'
        '    return (route: shown.route, screen: shown.screen);\n'
        '  }\n'
        '  if (flowIsOver(walked.route)) return startOfApp;\n'
        '  return (route: walked.route, screen: walked.screen);\n',
      ),
    );
    expect(
      text,
      contains(
        '  for (final guard in routeGuards)\n'
        '    if (!guard.allows.value) guard.name,\n',
      ),
    );

    // In an app that no route can start, the screen that it starts on is
    // the fallback start screen of the app entry role, which is no route:
    // the file imports it like the screens of the routes.
    final withoutStart = fileOf();
    final parsed = DartFileIndexer.parse(routerWalkFile, withoutStart);
    expect(parsed.errors, isEmpty);
    expect(
      [
        for (final import in parsed.index.imports)
          '${import.uri} ${import.prefix}',
      ],
      contains('package:my_app/core/app/fallback_start_screen.dart screen1'),
    );
    expect(
      withoutStart,
      contains(
        'const ShownScreen startOfApp = (\n'
        '  route: null,\n'
        '  screen: screen1.FallbackStartScreen,\n'
        ');\n',
      ),
    );
  });

  test(
      'in an app with a guard that stands for a condition, the file of the '
      'walk has the routes that ask for the condition among its locations '
      'like any other, and the targets of the gates before those of such '
      'guards, a target that a gate and such a guard share once', () {
    const screens = ImportRef.app('features/club/club_screens.dart');
    const status = ImportRef.app('features/club/club_status.dart');
    // Conditions of a role of the app, as a role with an account
    // publishes them.
    const member = RouteCondition(preferencesRole, 'member');
    const paid = RouteCondition(preferencesRole, 'paid');
    Route route(
      String path,
      String screen, {
      List<RouteCondition> conditions = const [],
      List<Route> children = const [],
    }) =>
        Route(
          path,
          name: path.replaceFirst('/', ''),
          screen: ScreenRef(screen, import: screens),
          conditions: conditions,
          children: children,
        );
    RouteGuard guard(String name, String target, [RouteCondition? condition]) =>
        RouteGuard(
          name: name,
          allows: FunctionRef(name, import: status),
          redirectTo: target,
          stage: condition == null ? GuardStage.identity : GuardStage.welcome,
          condition: condition,
        );
    final text = named('router_walk').generatedFiles!(
      MatrixApp(
        'club',
        const [ModuleId('club')],
        hook: RoleHookRequest(
          data: [
            routerRole
                .data(
                  RoutesData(
                    [
                      route('/lobby', 'LobbyScreen'),
                      route(
                        '/members',
                        'MembersScreen',
                        conditions: const [member],
                        children: [route('card', 'CardScreen')],
                      ),
                      route(
                        '/lounge',
                        'LoungeScreen',
                        conditions: const [paid],
                      ),
                      route('/plans', 'PlansScreen'),
                      route('/login', 'LoginScreen'),
                    ],
                    // The module declares its guards of conditions first,
                    // with the earlier stage: the app asks them after its
                    // gate all the same. One of them shows the target of
                    // the gate.
                    guards: [
                      guard('hasPaid', 'plans', paid),
                      guard('isMember', 'login', member),
                      guard('signedIn', 'login'),
                    ],
                  ),
                )
                .withOrigin(const ModuleOrigin(ModuleId('club'))),
          ],
          presentRoles: {routerRole, preferencesRole},
          context: ContractHarness.defaultContext,
          choices: const {routerRole: RouterChoice(startPath: '/club/lobby')},
        ),
      ),
      'my_app',
    )[routerWalkFile]!;

    expect(DartFileIndexer.parse(routerWalkFile, text).errors, isEmpty);
    // The walk goes to a route that asks for a condition, and to the route
    // below it, as to any other: what the router shows for it is up to
    // redirectOf() of the app, which knows the routes of each guard.
    expect(_walkedRoutesOf(text), [
      'club.lobby',
      'club.members',
      'club.card',
      'club.lounge',
      'club.plans',
      'club.login',
    ]);
    final targetsAt = text.indexOf('guardTargets = [');
    expect(
      [
        for (final match in RegExp(r"route: '([\w.]+)'").allMatches(
          text.substring(
            targetsAt,
            text.indexOf('const ShownScreen startOfApp'),
          ),
        ))
          match[1],
      ],
      ['club.login', 'club.plans'],
    );
    expect(text, contains('  final target = redirectOf(walked.route);\n'));
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
      'guards like any other, in the order of the routes of the app, and '
      'leaves out the last ones in an app with more locations than it goes '
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
          stage: GuardStage.welcome,
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

    // No screen of a flow changes what the walk sees after it: while its
    // guard does not allow, the router shows the target for every location
    // outside the flow anyway, and once the flow is over, its screens are
    // not shown.
    final text = fileOf(appWith(routes: 2));
    expect(DartFileIndexer.parse(routerWalkFile, text).errors, isEmpty);
    expect(_walkedRoutesOf(text), [
      'gate.intro',
      'gate.terms',
      'gate.login',
      'gate.help',
      'feed.r0',
      'feed.r1',
    ]);

    // The locations of the flows count among those that the walk goes to,
    // and are left out no sooner than any other.
    final beyond = fileOf(appWith(routes: routerWalkLimit));
    expect(_walkedRoutesOf(beyond), [
      'gate.intro',
      'gate.terms',
      'gate.login',
      'gate.help',
      for (var index = 0; index < routerWalkLimit - 4; index++) 'feed.r$index',
    ]);
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
        ..._everyModule,
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
      _everyModule,
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
        // The localization role and the theme role require the
        // preferences.
        'flutter_core with router, localization',
        'flutter_core with localization',
        'home with localization',
        'settings with localization',
        'bottom_tabs with localization',
        'material_theme with settings_screen, localization',
        'material_theme with settings_screen',
        'material_theme with localization',
        'material_theme',
        'shared_preferences with di',
        'shared_preferences',
        // The onboarding requires the preferences.
        'onboarding with localization',
        'onboarding',
        // Firebase Authentication with the localization, which requires
        // the preferences, and the sign-in with it.
        'firebase_auth with localization, router',
        'firebase_auth with localization',
        'sign_in (bloc) with localization',
        'sign_in (riverpod) with localization',
        ..._everyModule,
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
      _everyModule,
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
    // of flutter_core with the localization, with a router and without,
    // those of material_theme with the localization, with a settings
    // screen and without, the app of the onboarding with the role, and the
    // apps with every module.
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
        // The apps of the modules with texts, and of the layout, which
        // shows the labels of the destinations in the language of the app.
        'flutter_core with router, localization',
        'flutter_core with localization',
        'home with localization',
        'settings with localization',
        'bottom_tabs with localization',
        'material_theme with settings_screen, localization',
        'material_theme with localization',
        'onboarding with localization',
        // Firebase Authentication, which asks for its messages in the
        // language of the app, and the sign-in, whose screens have texts.
        'firebase_auth with localization, router',
        'firebase_auth with localization',
        'sign_in (bloc) with localization',
        'sign_in (riverpod) with localization',
        ..._everyModule,
      ],
    );
    // What the test has to check there. Every app has the two texts of the
    // fallback start screen of its app entry, in English and in Ukrainian.
    // An app with a settings screen also has the texts of the setting of
    // the language, which the role gives it in both languages. An app with
    // the start screen or with the settings module has the label of its
    // destination in both, and an app with the onboarding the texts of its
    // pages. So the test reads texts in two languages in each app, with
    // the provider of the CLI.
    List<String> languagesOf(MatrixApp app) =>
        localizationRole.localesIn(localizationRole.hookInput(app.hook!));
    expect(
      {
        for (final app in apps)
          if (registered.appliesTo(app)) app.name: languagesOf(app),
      },
      {
        'flutter_core with router, localization': ['en', 'uk'],
        'flutter_core with localization': ['en', 'uk'],
        'home with localization': ['en', 'uk'],
        'settings with localization': ['en', 'uk'],
        'bottom_tabs with localization': ['en', 'uk'],
        'material_theme with settings_screen, localization': ['en', 'uk'],
        'material_theme with localization': ['en', 'uk'],
        'onboarding with localization': ['en', 'uk'],
        'firebase_auth with localization, router': ['en', 'uk'],
        'firebase_auth with localization': ['en', 'uk'],
        'sign_in (bloc) with localization': ['en', 'uk'],
        'sign_in (riverpod) with localization': ['en', 'uk'],
        for (final app in _everyModule) app: ['en', 'uk'],
      },
    );
    for (final app in apps) {
      if (!registered.appliesTo(app) || languagesOf(app).length < 2) continue;
      expect(
        localizationRole.textsIn(localizationRole.hookInput(app.hook!)),
        isNotEmpty,
        reason: app.name,
      );
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
        ..._localizedSignIn,
        ..._everyModule,
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
        ..._everyModule,
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
      'opened again, the user of Firebase Authentication, the onboarding '
      'of a first launch and the languages of the localization role, each '
      'a function of a file of its tests that takes the one that waits '
      'until the screen settles', () async {
    expect(named('start').readsStartProbes, isTrue);
    expect(
      {
        for (final test in appTests.tests)
          if (test.startProbe case final probe?)
            p.basename(test.directory): '${probe.path} ${probe.function}',
      },
      {
        'firebase_auth':
            'integration_test/firebase_auth/probe.dart probeFirebaseAuth',
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
    // the routes of the app past it. That of Firebase Authentication only
    // reads, so it holds wherever it comes.
    final app = apps.singleWhere((app) => app.name == 'every module (bloc)');
    final tests = appTestsFor(app, [named('start')], appTests.tests);
    expect(
      [for (final test in tests) p.basename(test.directory)],
      [
        'start',
        'firebase_auth',
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
        'probe0: firebase_auth/probe.dart',
        'probe1: onboarding/probe.dart',
        'probe2: shared_preferences/probe.dart',
        'probe3: di_role/probe.dart',
        'probe4: preferences_role/probe.dart',
        'probe5: router_walk/walk.dart',
        'probe6: localization_role/probe.dart',
      ],
    );
    expect(list, contains("('firebase_auth', probe0.probeFirebaseAuth),"));
    expect(list, contains("('onboarding', probe1.probeOnboarding),"));
    expect(
      list,
      contains("('shared_preferences', probe2.probeSharedPreferences),"),
    );
    expect(list, contains("('di_role', probe3.probeServices),"));
    expect(list, contains("('preferences_role', probe4.probePreferences),"));
    expect(list, contains("('router_walk', probe5.probeRoutes),"));
    expect(list, contains("('localization_role', probe6.probeLanguages),"));
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
      for (final name in _everyModule)
        name: 'package:my_app/features/home/home_screen.dart: '
            'screen.HomeScreen',
    });
    // The languages of the localization role of the app, which are those
    // of the texts of its modules, and English alone without the role.
    expect(languages, {
      'onboarding with localization': ['en', 'uk'],
      'onboarding': ['en'],
      for (final app in _everyModule) app: ['en', 'uk'],
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
        "    'done': 'Get started',\n";

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
        "    'done': 'Почати',\n"
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
      'the test of the sign-in applies to the apps with the module, '
      'whatever else they have, in every mode of the auth role, declares '
      'the mocks that sign a test account up through the session of the '
      'app for the tests of every module of those apps, has no probe, and '
      'expects the screen that the router role chose for the app to start '
      'on, or the fallback screen of the app entry, and the texts of the '
      'module in each language of the app', () {
    final test = named('sign_in');
    final applies = apps.where(test.appliesTo).toList();

    expect(
      [for (final app in applies) app.name],
      [
        for (final app in apps)
          if (app.modules.contains(const ModuleId('sign_in'))) app.name,
      ],
    );
    expect(
      [for (final app in applies) app.name],
      [..._signIn, ..._everyModule],
    );
    // The files of the test are the same in every mode, which the app has
    // as a constant, and the matrix has an app with the module in each:
    // the mode is the choice of the auth role for the app.
    expect(
      {
        for (final app in applies)
          authRole.modeIn(authRole.hookInput(app.hook!)).name,
      },
      {'required', 'guest', 'anonymous'},
    );
    expect(test.devDependencies, isEmpty);
    expect(test.values, isNull);
    // Nobody can sign in on a device, and the walk of the routes shows the
    // screens there.
    expect(test.startProbe, isNull);
    expect(test.mocks!.path, 'test/sign_in_mocks.dart');
    expect(test.mocks!.function, 'signUpTestAccount');
    final mocks = DartFileIndexer.index(
      test.mocks!.path,
      File(p.joinAll([test.directory, ...test.mocks!.path.split('/')]))
          .readAsStringSync(),
    );
    final function = mocks.declarations
        .singleWhere((declaration) => declaration.name == test.mocks!.function);
    expect(function.kind, DeclarationKind.function);
    expect(function.parameters, isEmpty);
    // The account goes through the session of the app, so the mocks know
    // no provider of the auth role: they call signUp() of the session, and
    // import no other file of the app than that of the role.
    expect(
      [
        for (final call in mocks.invocations)
          if (call.enclosingDeclaration == test.mocks!.function) call.name,
      ],
      containsAll(['signUp', 'unawaited']),
    );
    final sessionFile = AuthRole.sessionFile.substring('lib/'.length);
    expect(
      [
        for (final import in mocks.imports)
          if (import.uri.startsWith('package:')) import.uri,
      ],
      ['package:{{app_name}}/$sessionFile'],
    );

    final screens = <String, String>{};
    final others = <String, String>{};
    final settings = <String>{};
    final languages = <String, List<String>>{};
    for (final app in applies) {
      final files = test.generatedFiles!(app, 'my_app');
      expect(files.keys, [signInOfAppFile], reason: app.name);
      final text = files[signInOfAppFile]!;
      languages[app.name] = _languagesOf(text);
      final (:index, :errors) = DartFileIndexer.parse(signInOfAppFile, text);
      expect(errors, isEmpty, reason: app.name);
      expect(
        index.declarations.map((declaration) => declaration.name),
        [
          'startScreen',
          'otherPages',
          'settingsLocation',
          'settingsScreen',
          'accountEntry',
          'signInTexts',
        ],
        reason: app.name,
      );
      // The settings screen, as the settings screen role finds it in the
      // app, and the entry that the module gave the role, each from its
      // file with a prefix of its own.
      final input = settingsScreenRole.hookInput(app.hook!);
      final screen = settingsScreenRole.screenIn(input)!;
      final entry = settingsScreenRole
          .entriesIn(input)
          .singleWhere((entry) => entry.widget.name == 'AccountSetting')
          .widget;
      expect(
        {
          for (final import in index.imports)
            if (import.prefix case 'settings' || 'entry')
              import.prefix: import.uri,
        },
        {
          'entry': entry.import!.resolveUri('my_app'),
          'settings': screen.route.screen.import.resolveUri('my_app'),
        },
        reason: app.name,
      );
      settings.add(
        [
          for (final name in [
            'AppLocation settingsLocation',
            'Type settingsScreen',
            'Type accountEntry',
          ])
            RegExp('^const $name = (.+);\$', multiLine: true)
                .firstMatch(text)![1],
        ].join(', '),
      );
      final import =
          index.imports.singleWhere((import) => import.prefix == 'screen');
      screens[app.name] = '${import.uri}: '
          '${RegExp(r'const Type startScreen = (\S+);').firstMatch(text)![1]}';
      others[app.name] =
          RegExp(r'\(location: (\w+)\(\), screen: other\.(\w+)\)')
              .allMatches(text)
              .map((match) => '${match[1]} ${match[2]}')
              .join(', ');
    }
    // Another page of the app for a user to be on: the settings screen,
    // which every app with the module has. The other routes are the screen
    // that an app with every module starts on, those in the flows of the
    // guards, and the screen of the account, which asks for an account.
    expect(others, {
      for (final name in [..._signIn, ..._everyModule])
        name: 'SettingsSettingsLocation SettingsScreen',
    });
    // The settings screen and the entry of the account are the same in
    // every app of the matrix, whose settings screen is that of one module.
    const everywhere = 'SettingsSettingsLocation(), settings.SettingsScreen, '
        'entry.AccountSetting';
    expect(settings, {everywhere});
    expect(screens, {
      // No route can start the app, since those of the sign-in cannot.
      for (final name in _signIn)
        name: 'package:my_app/core/app/fallback_start_screen.dart: '
            'screen.FallbackStartScreen',
      // The start screen of home.
      for (final name in _everyModule)
        name: 'package:my_app/features/home/home_screen.dart: '
            'screen.HomeScreen',
    });
    expect(languages, {
      for (final name in _signIn)
        name: name.endsWith('with localization') ? ['en', 'uk'] : ['en'],
      for (final app in _everyModule) app: ['en', 'uk'],
    });
  });

  test(
      'the test of the sign-in gets each text of the module by its name, '
      'in each language of the app in the order of the localization role, '
      'in English where the module has no translation, and in English alone '
      'in an app without the role; its files look up only texts of the '
      'module, and have a text for every reason of a failure', () {
    final test = named('sign_in');
    // The settings screen of a module of the test, and the entry that the
    // sign-in module gives it.
    const options = ModuleOrigin(ModuleId('options'));
    final entry = settingsScreenRole
        .data(
          const SettingsEntry(
            widget: TypeRef(
              'AccountSetting',
              import: ImportRef.app('features/sign_in/account_setting.dart'),
            ),
          ),
        )
        .withOrigin(const ModuleOrigin(ModuleId('sign_in')));
    final screen = [
      routerRole
          .data(
            const RoutesData([
              Route(
                '/options',
                name: 'options',
                screen: ScreenRef(
                  'OptionsScreen',
                  import: ImportRef.app('features/options/options_screen.dart'),
                ),
              ),
            ]),
          )
          .withOrigin(options),
      settingsScreenRole
          .data(const SettingsScreenRoute('options'))
          .withOrigin(options),
    ];
    String textsOf({
      List<String>? languages,
      List<RoleData<Object>>? entries,
    }) =>
        test.generatedFiles!(
          MatrixApp(
            'texts',
            const [ModuleId('sign_in')],
            hook: RoleHookRequest(
              data: [
                ...screen,
                ...entries ?? [entry],
              ],
              presentRoles: {
                routerRole,
                settingsScreenRole,
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
        )[signInOfAppFile]!;
    // The texts of a language in the file, each by its name.
    Map<String, String> textsIn(String file, String language) {
      final start = file.indexOf("  '$language': {\n");
      expect(start, isNonNegative, reason: language);
      final entries = file.substring(start, file.indexOf('  },\n', start));
      return {
        for (final entry in RegExp(r"^    '(\w+)': (.+),$", multiLine: true)
            .allMatches(entries))
          entry[1]!: entry[2]!,
      };
    }

    final names = [for (final text in SignInModule.texts.texts) text.name];
    final localized = textsOf(languages: ['uk', 'en', 'de']);
    expect(_languagesOf(localized), ['uk', 'en', 'de']);
    expect(
      localized,
      contains('const Map<String, Map<String, String>> signInTexts = {\n'),
    );
    final english = textsIn(localized, 'en');
    expect(english.keys, names);
    expect(textsIn(localized, 'uk').keys, names);
    expect(english['title'], "'Sign in'");
    expect(textsIn(localized, 'uk')['title'], "'Вхід'");
    expect(
      english['failureCredentials'],
      "'The email or the password is wrong.'",
    );
    // The module has no German texts.
    expect(textsIn(localized, 'de'), english);
    final plain = textsOf();
    expect(_languagesOf(plain), ['en']);
    expect(textsIn(plain, 'en'), english);
    // The settings screen of the module of the test, and the entry of the
    // account among those of other modules: the one that the sign-in module
    // gave the role.
    final other = settingsScreenRole
        .data(
          const SettingsEntry(
            widget: TypeRef(
              'FeedSetting',
              import: ImportRef.app('features/options/feed_setting.dart'),
            ),
          ),
        )
        .withOrigin(options);
    expect(
      textsOf(entries: [other, entry, other]),
      allOf(
        contains(
          "import 'package:my_app/features/sign_in/account_setting.dart' "
          'as entry;\n',
        ),
        contains(
          "import 'package:my_app/features/options/options_screen.dart' "
          'as settings;\n',
        ),
        contains(
          'const AppLocation settingsLocation = OptionsOptionsLocation();\n',
        ),
        contains('const Type settingsScreen = settings.OptionsScreen;\n'),
        contains('const Type accountEntry = entry.AccountSetting;\n'),
      ),
    );
    // The test needs that one entry.
    for (final (entries, count) in [
      (<RoleData<Object>>[other], 0),
      ([entry, other, entry], 2),
    ]) {
      expect(
        () => textsOf(entries: entries),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'The module sign_in gives the settings screen of texts $count '
                'entries, rather than the entry of the account alone.',
          ),
        ),
      );
    }

    // The files of the test look each text up by its name, texts['name']
    // or text('name'), and failureTextOf() of app.dart names the text of
    // each reason of a failure: a name that the module does not have would
    // fail only in a running app.
    final looked = <String>{};
    final failures = <String>{};
    for (final file in Directory(test.directory)
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      looked.addAll([
        for (final use
            in RegExp(r"\btexts?[\[(]'(\w+)'[\])]").allMatches(source))
          use[1]!,
      ]);
      failures.addAll([
        for (final use
            in RegExp(r"AuthFailureReason\.\w+ => '(\w+)',").allMatches(source))
          use[1]!,
      ]);
    }
    expect(looked, isNotEmpty);
    expect(names, containsAll(looked));
    expect(failures, {
      for (final name in names)
        if (name.startsWith('failure')) name,
      // An address that is none has one text, in the form and from the
      // provider.
      'emailInvalid',
    });
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
        ..._signIn,
        ..._everyModule,
      ],
    );
    // They run in a test of the app only, so they have no probe for a
    // check on a device, where the walk of the routes goes to the screen.
    expect(settings.startProbe, isNull);
    // The entries of each app, as the role gives them: none in the app of
    // the settings module alone, whose modules have no setting; the entry
    // of the account, which the sign-in module gives the role, in the apps
    // with that module, before the entries of the templates of the roles;
    // the entry of the theme mode, which the template of the theme role
    // contributes, in the apps with the theme; and the setting of the
    // language, which the template of the localization role contributes, in
    // the apps with the localization, after that of the theme, as the
    // modules that provide the two roles are in the list of the CLI.
    List<SettingsEntry> entriesOf(MatrixApp app) =>
        settingsScreenRole.entriesIn(settingsScreenRole.hookInput(app.hook!));
    expect(
      {
        for (final app in apps.where(settings.appliesTo))
          app.name: [for (final entry in entriesOf(app)) entry.widget.name],
      },
      {
        'settings with localization': ['LanguageSetting'],
        'settings': isEmpty,
        'material_theme with settings_screen, localization': [
          'ThemeModeSetting',
          'LanguageSetting',
        ],
        'material_theme with settings_screen': ['ThemeModeSetting'],
        for (final app in _localizedSignIn)
          app: ['AccountSetting', 'LanguageSetting'],
        'sign_in (bloc)': ['AccountSetting'],
        'sign_in (riverpod)': ['AccountSetting'],
        for (final app in _everyModule)
          app: ['AccountSetting', 'ThemeModeSetting', 'LanguageSetting'],
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
        ..._everyModule,
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
      _everyModule,
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
        ..._everyModule,
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
        ..._signIn,
        ..._everyModule,
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
      [
        'settings',
        'material_theme with settings_screen',
        'sign_in (bloc)',
        'sign_in (riverpod)',
      ],
    );
    for (final app in withoutRole) {
      final files = settings.generatedFiles!(app, 'my_app');
      expect(files.keys, [settingsLanguagesFile, settingsOfAppFile]);
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
          ..._localizedSignIn,
          ..._everyModule,
        ],
        reason: languages,
      );
      for (final app in withRole) {
        final reason = '${app.name} in $languages';
        final files = settings.generatedFiles!(app, 'my_app');
        expect(
          files.keys,
          [settingsLanguagesFile, settingsOfAppFile],
          reason: reason,
        );
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
      'the test of the home module applies to the apps with the module, '
      'whatever else they have, with neither mocks nor a probe, and gets '
      'the texts of the screen of the module in each language of the app', () {
    final test = named('home');

    expect(
      [
        for (final app in apps)
          if (test.appliesTo(app)) app.name,
      ],
      [
        for (final app in apps)
          if (app.modules.contains(const ModuleId('home'))) app.name,
      ],
    );
    // It tests the module, not a role, and its screen reaches no platform
    // side that another test would have to mock. The walk of the routes
    // goes to its screen on a device.
    expect(test.roles, isEmpty);
    expect(test.devDependencies, isEmpty);
    expect(test.values, isNull);
    expect(test.mocks, isNull);
    expect(test.startProbe, isNull);

    final languages = <String, List<String>>{};
    for (final app in apps.where(test.appliesTo)) {
      final files = test.generatedFiles!(app, 'my_app');
      expect(files.keys, [homeTextsFile], reason: app.name);
      languages[app.name] = _languagesOf(files[homeTextsFile]!);
    }
    // The languages of the localization role of the app, which are those
    // of the texts of its modules, and English alone without the role.
    expect(languages, {
      'home with localization': ['en', 'uk'],
      'home': ['en'],
      for (final app in _everyModule) app: ['en', 'uk'],
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
      'the tests of the settings module get how many entries the screen '
      'has, from the settings screen role of the app, and whether it is a '
      'destination of the main navigation, where code cannot push it, from '
      'the layout role', () {
    final settings = named('settings');

    /// What the file of [app] says: the number of the entries, and whether
    /// the screen is a destination.
    (int, bool) ofApp(MatrixApp app) {
      final text = settings.generatedFiles!(app, 'my_app')[settingsOfAppFile]!;
      final (:index, :errors) = DartFileIndexer.parse(settingsOfAppFile, text);
      expect(errors, isEmpty, reason: app.name);
      expect(index.imports, isEmpty, reason: app.name);
      expect(
        index.declarations.map((declaration) => declaration.name),
        ['settingsEntryCount', 'settingsInMainNavigation'],
        reason: app.name,
      );
      final count = RegExp(
        r'^const int settingsEntryCount = (\d+);$',
        multiLine: true,
      ).firstMatch(text);
      final destination = RegExp(
        r'^const bool settingsInMainNavigation = (true|false);$',
        multiLine: true,
      ).firstMatch(text);
      expect((count, destination), isNot(contains(null)), reason: app.name);
      return (int.parse(count![1]!), destination![1] == 'true');
    }

    // The app of the module alone has no entry, so its screen has the note
    // of an app without settings, which the test checks there. The apps
    // with every module have a layout, whose destinations the screen is
    // one of; the other apps of the module have none.
    expect(
      {
        for (final app in apps.where(settings.appliesTo)) app.name: ofApp(app),
      },
      {
        'settings with localization': (1, false),
        'settings': (0, false),
        'material_theme with settings_screen, localization': (2, false),
        'material_theme with settings_screen': (1, false),
        // The entry of the account, and the setting of the language.
        for (final app in _localizedSignIn) app: (2, false),
        'sign_in (bloc)': (1, false),
        'sign_in (riverpod)': (1, false),
        for (final app in _everyModule) app: (3, true),
      },
    );
    for (final app in apps.where(settings.appliesTo)) {
      final hook = app.hook!;
      final input = settingsScreenRole.hookInput(hook);
      final screen = settingsScreenRole.screenIn(input)!;
      expect(
        ofApp(app),
        (
          settingsScreenRole.entriesIn(input).length,
          hook.presentRoles.contains(layoutRole) &&
              layoutRole
                  .destinationsIn(layoutRole.hookInput(hook))
                  .any((route) => route.fullName == screen.fullName),
        ),
        reason: app.name,
      );
    }
  });

  test(
      'the test of the home module gets each text of the screen by its name, '
      'in each language of the app in the order of the localization role, '
      'in English where the module has no translation, and in English alone '
      'in an app without the role', () {
    final test = named('home');
    String textsOf({List<String>? languages}) => test.generatedFiles!(
          MatrixApp(
            'texts',
            const [ModuleId('home')],
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
        )[homeTextsFile]!;
    const english = "    'greetingMorning': 'Good morning',\n"
        "    'greetingAfternoon': 'Good afternoon',\n"
        "    'greetingEvening': 'Good evening',\n"
        "    'readyTitle': 'Your app is ready',\n"
        "    'readyText': 'Generated with Say My Frame. Everything you see is "
        "yours to change.',\n"
        "    'nextTitle': 'Next steps',\n"
        "    'stepScreenTitle': 'Make this screen yours',\n"
        "    'stepScreenText': 'Replace this welcome with the first screen of "
        "your app.',\n"
        "    'stepFeatureTitle': 'Add a feature',\n"
        "    'stepFeatureText': 'A feature keeps its screens and routes in a "
        "folder of its own.',\n"
        "    'stepDocsTitle': 'Read the docs',\n"
        "    'stepDocsText': 'Guides for every module, and for writing your "
        "own.',\n"
        "    'copied': 'Copied',\n"
        "    'footer': 'Built with Say My Frame',\n";

    // The names are those that the files of the app test look each text up
    // by, which the tests of the module check.
    final localized = textsOf(languages: ['uk', 'en', 'de']);
    final (:index, :errors) = DartFileIndexer.parse(homeTextsFile, localized);
    expect(errors, isEmpty);
    expect(index.imports, isEmpty);
    expect(
      index.declarations.map((declaration) => declaration.name),
      ['homeTexts'],
    );
    expect(
      localized,
      endsWith(
        'const Map<String, Map<String, String>> homeTexts = {\n'
        "  'uk': {\n"
        "    'greetingMorning': 'Доброго ранку',\n"
        "    'greetingAfternoon': 'Добрий день',\n"
        "    'greetingEvening': 'Добрий вечір',\n"
        "    'readyTitle': 'Ваш застосунок готовий',\n"
        "    'readyText': 'Згенеровано з Say My Frame. Усе, що ви бачите, "
        "можна змінити.',\n"
        "    'nextTitle': 'Що далі',\n"
        "    'stepScreenTitle': 'Зробіть цей екран своїм',\n"
        "    'stepScreenText': 'Замініть це привітання першим екраном вашого "
        "застосунку.',\n"
        "    'stepFeatureTitle': 'Додайте фічу',\n"
        "    'stepFeatureText': 'Фіча тримає свої екрани й маршрути у власній "
        "теці.',\n"
        "    'stepDocsTitle': 'Почитайте документацію',\n"
        "    'stepDocsText': 'Настанови до кожного модуля і до написання "
        "власного.',\n"
        "    'copied': 'Скопійовано',\n"
        "    'footer': 'Зроблено з Say My Frame',\n"
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
        'const Map<String, Map<String, String>> homeTexts = {\n'
        "  'en': {\n"
        '$english'
        '  },\n'
        '};\n',
      ),
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
        for (final app in _everyModule) app: 'home.home',
      },
    );
  });

  test(
      'the test of the auth role applies to the apps with the role, '
      'whichever module provides it, in each mode of the role, and gets the '
      'mode that the role chose for each: the first one in an app that got '
      'no value of the option of the role', () async {
    final authTest = await authRoleAppTest();
    // No module of the CLI provides the role in the apps of its matrix, so
    // the registry has a provider of the test.
    const modules = <SmfModule>[FlutterCoreModule(), _SignInOfTest()];
    final (apps: ofRole, :failed) = await matrixOf(modules);
    expect(
      [
        for (final result in failed)
          '${result.contractCase}: ${result.errors.join('; ')}',
      ],
      isEmpty,
    );

    expect(p.basename(authTest.directory), 'auth_role');
    expect(Directory(authTest.directory).existsSync(), isTrue);
    expect(authTest.roles, {authRole});
    // The matrix writes no file for it, and it has neither mocks nor a
    // probe for the start check.
    expect(authTest.generatedFiles, isNull);
    expect(authTest.mocks, isNull);
    expect(authTest.startProbe, isNull);
    expect(
      {
        for (final app in ofRole)
          app.name: authTest.appliesTo(app) ? authTest.values!(app) : null,
      },
      {
        // The app entry alone has no sign-in.
        'flutter_core': null,
        // The app of the provider is the app with every module of the
        // registry too. It got no value of the option, so it is in the
        // first mode.
        'sign_in_of_test': {'auth_mode': 'required'},
        'auth by sign_in_of_test --auth-mode=guest': {'auth_mode': 'guest'},
        'auth by sign_in_of_test --auth-mode=anonymous': {
          'auth_mode': 'anonymous',
        },
      },
    );
    for (final app in ofRole) {
      expect(
        app.createArguments('app_1', '/apps').where(
              (argument) => argument.startsWith('--auth-mode'),
            ),
        [
          if (app.modes['auth-mode'] case final mode?) '--auth-mode=$mode',
        ],
        reason: app.name,
      );
    }
    // It selects its apps by the role, and reads the mode from the choice
    // of the role, not from the name or the options of an app.
    final tests = MatrixAppTests([authTest], testedRoles: {authRole});
    expect(tests.roleProblems(modules, ofRole), isEmpty);
    expect(tests.modeProblems(ofRole), isEmpty);
    // In the matrix of the CLI, Firebase Authentication provides the role:
    // the test applies to each of its apps, in the mode of the app.
    expect(
      {
        for (final app in apps)
          if (authTest.appliesTo(app))
            app.name: authTest.values!(app)['auth_mode'],
      },
      {
        for (final name in const [
          'firebase_auth with localization, router',
          'firebase_auth with localization',
          'firebase_auth with router',
          'firebase_auth',
          // The sign-in requires the role.
          ..._signIn,
        ])
          name: 'required',
        'auth by firebase_auth with router --auth-mode=guest': 'guest',
        'auth by firebase_auth with router --auth-mode=anonymous': 'anonymous',
        for (final name in _everyModule)
          name: switch (name.split('--auth-mode=')) {
            [_, final mode] => mode,
            _ => 'required',
          },
      },
    );
    expect(
      [
        for (final app in apps)
          if (authTest.appliesTo(app)) app.name,
      ],
      [
        for (final app in apps)
          if (app.hook!.presentRoles.contains(authRole)) app.name,
      ],
    );
  });

  test(
      'the test of Firebase Authentication applies to the apps with the '
      'module, whatever else they have, in every mode of the auth role, '
      'declares the mocks of its platform side for the tests of every '
      'module of those apps, has a probe for the start check, and gets the '
      'languages in which the app asks Firebase for its messages from the '
      'localization role of the app', () async {
    final test = named('firebase_auth');

    expect(
      [
        for (final app in apps)
          if (test.appliesTo(app)) app.name,
      ],
      [
        'firebase_auth with localization, router',
        'firebase_auth with localization',
        'firebase_auth with router',
        'firebase_auth',
        // The apps of the sign-in get the provider of the auth role.
        ..._signIn,
        'auth by firebase_auth with router --auth-mode=guest',
        'auth by firebase_auth with router --auth-mode=anonymous',
        ..._everyModule,
      ],
    );
    // It tests what only this provider of the auth role does, so it names
    // no role: the test of the role checks what every provider keeps to.
    expect(test.roles, isEmpty);
    expect(test.values, isNull);
    // The mocks answer the messages of the plugin in the codec of its
    // platform interface, which the app has only through the plugin.
    expect(test.devDependencies, ['firebase_auth_platform_interface']);
    expect(test.mocks!.path, 'test/firebase_auth_mocks.dart');
    expect(test.mocks!.function, 'mockFirebaseAuth');
    expect(test.startProbe!.path, 'integration_test/firebase_auth/probe.dart');
    expect(test.startProbe!.function, 'probeFirebaseAuth');
    for (final path in [test.mocks!.path, test.startProbe!.path]) {
      expect(
        File(p.joinAll([test.directory, ...path.split('/')])).existsSync(),
        isTrue,
        reason: path,
      );
    }

    // The apps as they are, and with the one language that they are given.
    final (apps: english, :failed) = await matrixOf(
      smfModules,
      roleOptions: const {'locales': 'en'},
    );
    expect(failed, isEmpty);
    for (final (matrix, languages) in [
      (apps, "['en', 'uk']"),
      (english, "['en']"),
    ]) {
      for (final app in matrix.where(test.appliesTo)) {
        final reason = '${app.name} in $languages';
        final files = test.generatedFiles!(app, 'my_app');
        expect(files.keys, [messageLanguagesFile], reason: reason);
        final text = files[messageLanguagesFile]!;
        final (:index, :errors) =
            DartFileIndexer.parse(messageLanguagesFile, text);
        expect(errors, isEmpty, reason: reason);
        expect(
          index.declarations.map((declaration) => declaration.name),
          ['messageLanguages', 'chooseLanguage'],
          reason: reason,
        );
        if (app.hook!.presentRoles.contains(localizationRole)) {
          // The languages of the role, and a choice through the language
          // that the role keeps for the app, also back to the languages of
          // the device.
          expect(
            [for (final import in index.imports) import.uri],
            ['dart:ui', 'package:my_app/core/l10n/app_locale.dart'],
            reason: reason,
          );
          expect(
            text,
            allOf(
              contains('const List<String> messageLanguages = $languages;'),
              contains(
                'Future<void> chooseLanguage(String? language) =>\n'
                '    appLocale.choose(language == null ? null : '
                'Locale(language));',
              ),
            ),
            reason: reason,
          );
        } else {
          // An app without the role asks Firebase for no language.
          expect(index.imports, isEmpty, reason: reason);
          expect(
            text,
            allOf(
              contains('const List<String> messageLanguages = [];'),
              contains(
                'Future<void> chooseLanguage(String? language) async {}',
              ),
            ),
            reason: reason,
          );
        }
      }
    }
    // Both kinds of apps are among those of the module.
    expect(
      {
        for (final app in apps.where(test.appliesTo))
          app.hook!.presentRoles.contains(localizationRole),
      },
      {true, false},
    );
  });
}
