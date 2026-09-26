@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
import 'package:smf_contracts/bundles/router_role_bundle.dart';
import 'package:smf_contracts/lego.dart';
import 'package:test/test.dart';

import 'role_support.dart';
import 'support.dart';

const _material = ImportRef('package:flutter/material.dart');

ScreenRef _screen(String name, String feature) => ScreenRef(
      name,
      import: ImportRef.app(
        'features/$feature/${SmfNames.snakeCaseOf(name)}.dart',
      ),
    );

Destination _destination(String label) => Destination(
      label: label,
      icon: const Fragment('Icons.home', imports: [_material]),
    );

final _homeRoutes = RoutesData([
  Route(
    '/',
    name: 'root',
    screen: _screen('HomeScreen', 'home'),
    destination: _destination('Home'),
    startCandidate: true,
    children: [
      Route(
        'details/:id',
        name: 'details',
        screen: _screen('DetailsScreen', 'home'),
        params: const [
          RouteParam.path('id', type: int),
          RouteParam.query('tab', type: String, optional: true),
        ],
      ),
    ],
  ),
]);

final _settingsRoutes = RoutesData([
  Route(
    '/',
    name: 'root',
    screen: _screen('SettingsScreen', 'settings'),
    destination: _destination('Settings'),
    startCandidate: true,
  ),
  Route(
    '/users/:userId',
    name: 'user',
    screen: _screen('UserScreen', 'settings'),
    params: const [RouteParam.path('userId', type: String)],
    children: [
      Route(
        'posts/:postId',
        name: 'post',
        screen: _screen('PostScreen', 'settings'),
        params: const [RouteParam.path('postId', type: int)],
      ),
    ],
  ),
  Route(
    '/search',
    name: 'search',
    screen: _screen('SearchScreen', 'settings'),
    params: const [
      RouteParam.query('q', type: String),
      RouteParam.query('page', type: int, optional: true),
    ],
  ),
]);

final List<RoleData<Object>> _data = [
  dataOf(routerRole, _homeRoutes),
  dataOf(routerRole, _settingsRoutes, module: 'settings'),
];

RouterFacade _facade([List<RoleData<Object>>? data]) =>
    routerRole.facadeOf(inputOf(routerRole, data: data ?? _data));

/// The input of the module rules of the router for [routes] of the feature
/// `home`, whose bricks are [bundles].
ModuleRuleInput<RoutesData> _moduleInput(
  List<Route> routes, {
  List<MasonBundle> bundles = const [],
}) {
  // The input can only be built by a role; a test role captures it.
  late ModuleRuleInput<RoutesData> captured;
  final role = TestRole<RoutesData>(
    'capture',
    moduleRules: [
      ModuleRule(
        id: 'capture',
        description: 'Captures the input.',
        check: (input) {
          captured = input;
          return const [];
        },
      ),
    ],
  );
  final data = role.data(RoutesData(routes));
  role.checkModule(
    ModuleRuleRequest(
      hook: RoleHookRequest(
        data: [data.withOrigin(const ModuleOrigin(ModuleId('home')))],
        presentRoles: {role},
        context: testContext,
      ),
      module: const ModuleDescriptor(
        id: ModuleId('home'),
        description: 'Home',
        kind: ModuleKinds.feature,
      ),
      contributions: [
        data,
        for (final bundle in bundles) BrickContribution(bundle),
      ],
    ),
  );
  return captured;
}

/// The issues of the router's module rule [id] for [input].
List<SmfIssue> _moduleIssues(String id, ModuleRuleInput<RoutesData> input) =>
    routerRole.moduleRules.firstWhere((rule) => rule.id == id).check(input);

List<String> _routeProblems(List<Route> routes) => [
      for (final issue in _moduleIssues('router.routes', _moduleInput(routes)))
        issue.message,
    ];

MasonBundle _bundle(Map<String, String> files) => MasonBundle(
      name: 'home',
      description: 'Home',
      version: '0.1.0',
      files: [
        for (final MapEntry(key: path, value: text) in files.entries)
          MasonBundledFile(path, base64.encode(utf8.encode(text)), 'text'),
      ],
    );

/// A stand-in for the router of the app, which prints what it is asked.
const _vmRouter = r'''
final class _Navigator {
  void go(AppLocation location) => print('go ${location.path}');
  Future<T?> push<T extends Object?>(AppLocation location) async {
    print('push ${location.path}');
    return null;
  }
  void replace(AppLocation location) => print('replace ${location.path}');
}

final class _Router {
  _Navigator navigatorOf(BuildContext context) => _Navigator();
}

final appRouter = _Router();
''';

/// Prints the locations of some links and navigates with three of them.
const _vmMain = '''
Future<void> main() async {
  final context = BuildContext();
  final links = [
    context.nav.home.root(),
    context.nav.home.details(id: 5),
    context.nav.home.details(id: 5, tab: 'a b&c'),
    context.nav.settings.post(userId: 'ann/bo', postId: 7),
    context.nav.settings.search(q: 'dart', page: 2),
    context.nav.settings.search(q: ''),
  ];
  for (final link in links) {
    final location = link.location;
    print([
      location.routeName,
      location.path,
      location.chain.map((l) => l.path).join(' > '),
    ].join(' | '));
  }
  links[1].go();
  await links[3].push<bool>();
  links[4].replace();
}
''';

void main() {
  group('the routes DSL', () {
    test('RouteParam names the supported types', () {
      expect(const RouteParam.path('id', type: int).typeName, 'int');
      expect(const RouteParam.query('q', type: String).typeName, 'String');
      expect(const RouteParam.query('x', type: double).typeName, 'double');
      expect(const RouteParam.query('on', type: bool).typeName, 'bool');
      expect(const RouteParam.query('at', type: DateTime).typeName, isNull);
    });

    test('a path parameter is required, a query one when not optional', () {
      const path = RouteParam.path('id', type: int);
      const optional = RouteParam.query('q', type: String, optional: true);

      expect(path.isRequired, isTrue);
      expect(path.source, RouteParamSource.path);
      expect('$path', ':id');
      expect(const RouteParam.query('q', type: String).isRequired, isTrue);
      expect(optional.isRequired, isFalse);
      expect('$optional', '?q');
    });

    test('ScreenRef knows the file of a screen of the app', () {
      final screen = _screen('HomeScreen', 'home');

      expect(screen.file, 'lib/features/home/home_screen.dart');
      expect('$screen', 'HomeScreen');
      expect(
        const ScreenRef('X', import: ImportRef('package:x/x.dart')).file,
        isNull,
      );
    });
  });

  group('RouterFacade', () {
    test('resolves full paths and names under the modules namespaces', () {
      final facade = _facade();

      expect(
        [for (final route in facade.routes) route.fullPath],
        [
          '/home',
          '/home/details/:id',
          '/settings',
          '/settings/users/:userId',
          '/settings/users/:userId/posts/:postId',
          '/settings/search',
        ],
      );
      expect(
        [for (final route in facade.routes) route.fullName],
        [
          'home.root',
          'home.details',
          'settings.root',
          'settings.user',
          'settings.post',
          'settings.search',
        ],
      );
      expect(
        [for (final route in facade.routes) route.locationClass],
        [
          'HomeRootLocation',
          'HomeDetailsLocation',
          'SettingsRootLocation',
          'SettingsUserLocation',
          'SettingsPostLocation',
          'SettingsSearchLocation',
        ],
      );
    });

    test('keeps the features in the order of the data and merges them', () {
      final facade = _facade([
        dataOf(routerRole, _settingsRoutes, module: 'settings'),
        dataOf(routerRole, _homeRoutes),
        dataOf(
          routerRole,
          RoutesData([
            Route('/more', name: 'more', screen: _screen('MoreScreen', 'home')),
          ]),
        ),
        dataOf(routerRole, const RoutesData([]), module: 'empty'),
      ]);

      expect([
        for (final f in facade.features) '${f.module}',
      ], [
        'settings',
        'home',
      ]);
      final home = facade.features.last;
      expect(
        [for (final r in home.routes) r.fullPath],
        ['/home', '/home/more'],
      );
      expect(home.accessor, 'home');
      expect(home.routesClass, 'HomeRoutes');
      expect(home.namespace, '/home');
      expect('$home', 'routes of home');
    });

    test('knows the chain, parameters and keys of a route', () {
      final post = _facade().routeAt('/settings/users/:userId/posts/:postId')!;

      expect([for (final r in post.chain) r.route.name], ['user', 'post']);
      expect(post.topLevel.route.name, 'user');
      expect(post.parent!.children, [post]);
      expect(post.pathParams.map((p) => p.name), ['userId', 'postId']);
      expect(post.params.map((p) => p.name), ['userId', 'postId']);
      expect(post.hasRequiredParams, isTrue);
      expect(
        post.screenKey,
        (
          feature: const ModuleId('settings'),
          screen: 'PostScreen',
        ),
      );
      expect(
        post.paramKey(post.route.params.single),
        (
          feature: const ModuleId('settings'),
          screen: 'PostScreen',
          param: 'postId',
        ),
      );
      expect('$post', 'route settings.post');

      final search = _facade().routeAt('/settings/search')!;
      expect(search.params.map((p) => p.name), ['q', 'page']);
      expect(search.hasRequiredParams, isTrue);
      expect(_facade().routeAt('/home')!.hasRequiredParams, isFalse);
      expect(_facade().routeAt('/nowhere'), isNull);
    });

    test('lists the destinations of the top-level routes in order', () {
      expect(
        [for (final route in _facade().destinations) route.fullPath],
        ['/home', '/settings'],
      );
    });

    test('leaves out routes that do not come from a module', () {
      final facade = RouterFacade.of([
        routerRole
            .data(_homeRoutes)
            .withOrigin(const RoleTemplateOrigin(layoutRole)),
        routerRole.data(_homeRoutes),
        routerRole
            .data(_settingsRoutes)
            .withOrigin(const ModuleOrigin(ModuleId('settings'))),
      ]);

      expect([for (final f in facade.features) '${f.module}'], ['settings']);
    });

    test('passes path parameters of parents on, each once', () {
      final facade = _facade([
        dataOf(
          routerRole,
          RoutesData([
            Route(
              '/users/:userId',
              name: 'user',
              screen: _screen('UserScreen', 'home'),
              params: const [RouteParam.path('userId', type: String)],
              children: [
                Route(
                  'posts/:postId',
                  name: 'post',
                  screen: _screen('PostScreen', 'home'),
                  params: const [
                    RouteParam.path('userId', type: String),
                    RouteParam.path('postId', type: int),
                  ],
                ),
              ],
            ),
          ]),
        ),
      ]);
      final post = facade.routeAt('/home/users/:userId/posts/:postId')!;

      expect(post.pathParams.map((p) => p.name), ['userId', 'postId']);
      expect(post.params.map((p) => p.name), ['userId', 'postId']);
      expect(post.isInherited(post.route.params.first), isTrue);
      expect(post.isInherited(post.route.params.last), isFalse);
      expectParses(facade.toDart());
    });

    test('names the location of a route without a name', () {
      final facade = _facade([
        dataOf(
          routerRole,
          RoutesData([Route('/', name: '', screen: _screen('A', 'home'))]),
        ),
      ]);

      expect(facade.routes.single.locationClass, 'HomeLocation');
    });
  });

  group('RouterFacade.toDart', () {
    test('generates valid Dart with a location and a method per route', () {
      final code = _facade().toDart();

      expectParses(code);
      expect(code, contains('final class SettingsPostLocation extends'));
      expect(
        code,
        contains(
          'AppLocation get parent => SettingsUserLocation(userId: userId);',
        ),
      );
      expect(
        code,
        contains('AppLocation get parent => const HomeRootLocation();'),
      );
      expect(code, contains('HomeRoutes get home => HomeRoutes._(_context);'));
      expect(
        code,
        contains(
          'NavLink details({required int id, String? tab}) => '
          'NavLink(_context, HomeDetailsLocation(id: id, tab: tab));',
        ),
      );
      expect(
        code,
        contains(
          'NavLink root() => NavLink(_context, const HomeRootLocation());',
        ),
      );
      expect(code, contains('String _withQuery('));
    });

    test('leaves out the query helper when no route has a query', () {
      final code = _facade([dataOf(routerRole, _settingsRoutes)]).toDart();
      final plain = _facade([
        dataOf(
          routerRole,
          RoutesData([Route('/', name: 'root', screen: _screen('A', 'a'))]),
        ),
      ]).toDart();

      expect(code, contains('_withQuery('));
      expect(plain, isNot(contains('_withQuery')));
      expectParses(plain);
    });

    test('rebuilds a parent without its query for a child', () {
      final code = _facade([
        dataOf(
          routerRole,
          RoutesData([
            Route(
              '/search',
              name: 'search',
              screen: _screen('SearchScreen', 'home'),
              params: const [
                RouteParam.query('q', type: String, optional: true),
              ],
              children: [
                Route(
                  'results/:id',
                  name: 'result',
                  screen: _screen('ResultScreen', 'home'),
                  params: const [RouteParam.path('id', type: int)],
                ),
              ],
            ),
          ]),
        ),
      ]).toDart();

      expectParses(code);
      expect(
        code,
        contains('AppLocation get parent => const HomeSearchLocation();'),
      );
      expect(code, contains("_withQuery('/home/search', {'q': q})"));
    });

    test('generates an empty facade for an app without routes', () {
      final code = _facade(const []).toDart();

      expectParses(code);
      expect(code, contains('AppNav get nav => const AppNav._();'));
      expect(code, isNot(contains('_context')));
    });

    test('builds the locations and navigates at run time', () async {
      final directory = await Directory.systemTemp.createTemp('smf_facade');
      addTearDown(() => directory.delete(recursive: true));
      // The brick's navigation.dart with the facade, where stand-ins
      // replace Flutter and the router of the app.
      final navigation = (await renderBundle(routerRoleBundle, {
        'facade': _facade().toDart(),
      }))[RouterRole.navigationFile]!;
      final source = navigation
          .replaceFirst(
            "import 'package:flutter/widgets.dart';",
            'class BuildContext {}',
          )
          .replaceFirst("import 'app_router.dart';", _vmRouter);
      final file = File('${directory.path}/facade.dart');
      await file.writeAsString('$source$_vmMain');
      final result = await Process.run(
        Platform.resolvedExecutable,
        ['run', file.path],
      );

      expect(result.stderr, isEmpty);
      final lines = (result.stdout as String).trim().split('\n');
      expect(lines, hasLength(9));
      expect(lines[0], 'home.root | /home | /home');
      expect(
        lines[1],
        'home.details | /home/details/5 | /home > /home/details/5',
      );
      expect(
        lines[2],
        'home.details | /home/details/5?tab=a+b%26c | /home > '
        '/home/details/5?tab=a+b%26c',
      );
      expect(
        lines[3],
        'settings.post | /settings/users/ann%2Fbo/posts/7 | '
        '/settings/users/ann%2Fbo > /settings/users/ann%2Fbo/posts/7',
      );
      expect(
        lines[4],
        'settings.search | /settings/search?q=dart&page=2 | '
        '/settings/search?q=dart&page=2',
      );
      expect(
        lines[5],
        'settings.search | /settings/search?q | /settings/search?q',
      );
      expect(lines.sublist(6), [
        'go /home/details/5',
        'push /settings/users/ann%2Fbo/posts/7',
        'replace /settings/search?q=dart&page=2',
      ]);
    });
  });

  group('the router template', () {
    final template = routerRole.template;

    test('contributes its brick', () {
      final contributions = template.contribute(testContext);

      expect(contributions, hasLength(1));
      expect(
        (contributions.single as BrickContribution).bundle.name,
        'router_role',
      );
    });

    test('accepts the routes of the modules', () {
      expect(template.validate(inputOf(routerRole, data: _data)), isEmpty);
    });

    test('rejects routes of a role template', () {
      final issues = template.validate(
        inputOf(
          routerRole,
          data: [
            routerRole
                .data(_homeRoutes)
                .withOrigin(const RoleTemplateOrigin(layoutRole)),
          ],
        ),
      );

      expect(issues.single.message, contains('Only modules'));
      expect(issues.single.origin, const RoleTemplateOrigin(layoutRole));
    });

    test('rejects modules whose routes cannot be a getter of context.nav', () {
      final issues = template.validate(
        inputOf(
          routerRole,
          data: [
            for (final module in ['class', 'to_string', 'home'])
              dataOf(
                routerRole,
                RoutesData([
                  Route('/', name: 'root', screen: _screen('A', module)),
                ]),
                module: module,
              ),
          ],
        ),
      );

      expect(issues, hasLength(2));
      expect(issues.first.message, contains('context.nav.class'));
      expect(issues.first.origin, const ModuleOrigin(ModuleId('class')));
      expect(issues.last.message, contains('context.nav.toString'));
    });

    test('rejects two routes that need the same location class', () {
      final issues = template.validate(
        inputOf(
          routerRole,
          data: [
            dataOf(
              routerRole,
              RoutesData([
                Route(
                  '/page',
                  name: 'settingsPage',
                  screen: _screen('A', 'home'),
                ),
              ]),
            ),
            dataOf(
              routerRole,
              RoutesData([
                Route('/', name: 'page', screen: _screen('B', 'home_settings')),
              ]),
              module: 'home_settings',
            ),
          ],
        ),
      );

      expect(issues.single.message, contains('HomeSettingsPageLocation'));
      expect(
        issues.single.origin,
        const ModuleOrigin(ModuleId('home_settings')),
      );
    });

    test('renders the facade into its brick', () {
      final output = template.render(inputOf(routerRole, data: _data));

      expect(output.fragments, isEmpty);
      expect(output.vars, {'facade': _facade().toDart()});
    });

    test('generates valid Dart files', () async {
      final rendered = await renderTemplate(routerRole, data: _data);

      expect(rendered.files.keys, [
        RouterRole.appRouterFile,
        RouterRole.navigationFile,
      ]);
      for (final MapEntry(key: path, value: code) in rendered.files.entries) {
        expectParses(code, reason: path);
      }
      expect(
        rendered.files[RouterRole.navigationFile],
        contains('final class HomeDetailsLocation extends AppLocation'),
      );
      expect(
        rendered.files[RouterRole.appRouterFile],
        contains('final AppRouter appRouter = createAppRouter();'),
      );
    });
  });

  group('the router choice of the start route', () {
    Future<Object?> choose(
      List<RoleData<Object>> data, {
      String? start,
      SmfEnvironment? environment,
    }) =>
        routerRole.template.choose(
          routerRole.choiceContext(
            RoleChoiceRequest(
              data: data,
              presentRoles: {routerRole},
              optionValues: {'start': start},
              environment: environment ?? FakeEnvironment(),
              context: testContext,
            ),
          ),
        );

    String? pathOf(Object? choice) => (choice! as RouterChoice).startPath;

    test('takes the only candidate', () async {
      expect(pathOf(await choose([_data.first])), '/home');
    });

    test('has no start route without candidates, and warns', () async {
      final environment = PromptingEnvironment();
      final choice = await choose(
        [
          dataOf(
            routerRole,
            RoutesData([Route('/', name: 'root', screen: _screen('A', 'a'))]),
          ),
        ],
        environment: environment,
      );

      expect(pathOf(choice), isNull);
      expect(environment.warnings.single, contains('--start'));
      expect(pathOf(await choose(const [])), isNull);
    });

    test('asks the user to pick one of several candidates', () async {
      final environment = PromptingEnvironment(pick: 1);

      expect(
        pathOf(await choose(_data, environment: environment)),
        '/settings',
      );
      expect(environment.asked, ['Which screen does the app start on?']);
      expect(environment.shown, ['/home (home)', '/settings (settings)']);
    });

    test('needs --start for several candidates without a terminal', () {
      expect(
        () => choose(_data),
        throwsA(
          isA<SmfUsageException>().having(
            (e) => e.message,
            'message',
            allOf(contains('/home, /settings'), contains('--start')),
          ),
        ),
      );
    });

    test('takes the route of --start', () async {
      expect(pathOf(await choose(_data, start: '/settings')), '/settings');
      expect(
        pathOf(await choose([_data.first], start: '/home')),
        '/home',
      );
    });

    test('rejects a --start that is not a route or needs values', () {
      expect(
        () => choose(_data, start: '/nowhere'),
        throwsA(
          isA<SmfUsageException>().having(
            (e) => e.message,
            'message',
            contains('no route /nowhere'),
          ),
        ),
      );
      expect(
        () => choose(const [], start: '/home'),
        throwsA(
          isA<SmfUsageException>().having(
            (e) => e.message,
            'message',
            'The app has no routes, so it cannot start on /home.',
          ),
        ),
      );
      expect(
        () => choose(_data, start: '/home/details/:id'),
        throwsA(
          isA<SmfUsageException>().having(
            (e) => e.message,
            'message',
            contains(':id'),
          ),
        ),
      );
      expect(
        () => choose(_data, start: '/settings/search'),
        throwsA(
          isA<SmfUsageException>().having(
            (e) => e.message,
            'message',
            contains('?q'),
          ),
        ),
      );
    });

    test('startIn reads the chosen route', () {
      expect(
        routerRole
            .startIn(
              inputOf(
                routerRole,
                data: _data,
                choice: const RouterChoice(startPath: '/settings'),
              ),
            )
            ?.fullName,
        'settings.root',
      );
      expect(
        routerRole.startIn(
          inputOf(routerRole, data: _data, choice: const RouterChoice()),
        ),
        isNull,
      );
      expect(routerRole.startIn(inputOf(routerRole, data: _data)), isNull);
    });
  });

  group('the annotation socket families', () {
    test('name a tag per screen and per parameter', () {
      const home = ModuleId('home');
      final screen =
          RouterRole.screenAnnotations((feature: home, screen: 'HomeScreen'));
      final param = RouterRole.paramAnnotations(
        (feature: home, screen: 'UserScreen', param: 'userId'),
      );

      expect(screen.tag, 'smf_router__screen_annotations__home__home_screen');
      expect(
        param.tag,
        'smf_router__param_annotations__home__user_screen__user_id',
      );
      expect(RouterRole.screenAnnotations.memberOfTag(screen.tag), screen);
      expect(RouterRole.paramAnnotations.memberOfTag(param.tag), param);
      expect(RouterRole.observers.tag, 'smf_router__observers');
    });
  });
  group('the module rule router.routes', () {
    test('accepts valid routes', () {
      expect(_routeProblems(_homeRoutes.routes), isEmpty);
      expect(_routeProblems(_settingsRoutes.routes), isEmpty);
    });

    test('names the module in every issue', () {
      final issues = _moduleIssues(
        'router.routes',
        _moduleInput([Route('home', name: 'root', screen: _screen('A', 'h'))]),
      );

      expect(issues.single.origin, const ModuleOrigin(ModuleId('home')));
    });

    test('rejects a module without routes', () {
      expect(_routeProblems(const []), [
        'The module contributes routes data without routes.',
      ]);
    });

    test('rejects invalid paths', () {
      final problems = _routeProblems([
        Route('home', name: 'a', screen: _screen('A', 'h')),
        Route('/Home', name: 'b', screen: _screen('B', 'h')),
        Route('/ok/', name: 'c', screen: _screen('C', 'h')),
        Route(
          '/',
          name: 'd',
          screen: _screen('D', 'h'),
          children: [
            Route('/child', name: 'e', screen: _screen('E', 'h')),
            Route('', name: 'f', screen: _screen('F', 'h')),
          ],
        ),
      ]);

      expect(problems, hasLength(5));
      expect(problems.first, contains('a top-level path starts with /'));
      expect(problems.last, contains('the path of a child has no leading /'));
    });

    test('rejects invalid and repeated names', () {
      final problems = _routeProblems([
        Route('/a', name: 'Details', screen: _screen('A', 'h')),
        Route('/b', name: 'class', screen: _screen('B', 'h')),
        Route('/c', name: 'toString', screen: _screen('C', 'h')),
        Route('/d', name: 'same', screen: _screen('D', 'h')),
        Route('/e', name: 'same', screen: _screen('E', 'h')),
      ]);

      expect(problems.where((p) => p.contains('lowerCamelCase')), hasLength(3));
      expect(problems, contains('Two routes of the module are named "same".'));
    });

    test('rejects two routes at the same path', () {
      expect(
        _routeProblems([
          Route('/a', name: 'a', screen: _screen('A', 'h')),
          Route(
            '/',
            name: 'b',
            screen: _screen('B', 'h'),
            children: [Route('a', name: 'c', screen: _screen('C', 'h'))],
          ),
        ]),
        ['Two routes of the module have the path "/a".'],
      );
    });

    test('rejects screens that are not classes of the app or are shared', () {
      final problems = _routeProblems([
        Route('/a', name: 'a', screen: _screen('a', 'h')),
        const Route(
          '/b',
          name: 'b',
          screen: ScreenRef('B', import: ImportRef('package:x/b.dart')),
        ),
        const Route(
          '/c',
          name: 'c',
          screen: ScreenRef('C', import: ImportRef.app('c.dart', prefix: 'c')),
        ),
        Route('/d', name: 'd', screen: _screen('D', 'h')),
        Route('/e', name: 'e', screen: _screen('D', 'h')),
      ]);

      expect(problems, hasLength(4));
      expect(problems[0], contains('not an UpperCamelCase class name'));
      expect(problems[1], contains('imported with ImportRef.app'));
      expect(problems[2], contains('with a prefix or show'));
      expect(problems[3], contains('show the same screen D'));
    });

    test('rejects invalid parameters', () {
      final problems = _routeProblems([
        Route(
          '/:id/:other',
          name: 'a',
          screen: _screen('A', 'h'),
          params: const [
            RouteParam.path('id', type: int),
            RouteParam.path('id', type: int),
            RouteParam.path('missing', type: int),
            RouteParam.query('path', type: String),
            RouteParam.query('int', type: String),
            RouteParam.query('at', type: DateTime),
          ],
        ),
      ]);

      expect(problems, hasLength(6));
      expect(problems[0], contains('declares the parameter "id" twice'));
      expect(problems[1], contains('nor the path of a parent has a :missing'));
      expect(problems[2], contains('a parameter name is a lowerCamelCase'));
      expect(problems[3], contains('a parameter name is a lowerCamelCase'));
      expect(problems[4], contains('use String, int, double or bool'));
      expect(problems[5], contains('segment :other but no RouteParam.path'));
    });

    test('rejects a parameter whose name a parent already has', () {
      final problems = _routeProblems([
        Route(
          '/:id',
          name: 'a',
          screen: _screen('A', 'h'),
          params: const [
            RouteParam.path('id', type: int),
            RouteParam.query('q', type: String, optional: true),
          ],
          children: [
            Route(
              'b',
              name: 'b',
              screen: _screen('B', 'h'),
              params: const [
                RouteParam.query('id', type: int, optional: true),
                RouteParam.query('q', type: String, optional: true),
              ],
            ),
            Route(
              'c/:id',
              name: 'c',
              screen: _screen('C', 'h'),
              params: const [RouteParam.path('id', type: int)],
            ),
          ],
        ),
      ]);

      expect(problems, hasLength(3));
      expect(problems, everyElement(contains('which a parent already has')));
    });

    test('lets a child pass a path parameter of a parent to its screen', () {
      expect(
        _routeProblems([
          Route(
            '/users/:userId',
            name: 'user',
            screen: _screen('UserScreen', 'h'),
            params: const [RouteParam.path('userId', type: String)],
            children: [
              Route(
                'posts/:postId',
                name: 'post',
                screen: _screen('PostScreen', 'h'),
                params: const [
                  RouteParam.path('userId', type: String),
                  RouteParam.path('postId', type: int),
                ],
              ),
            ],
          ),
        ]),
        isEmpty,
      );
      expect(
        _routeProblems([
          Route(
            '/users/:userId',
            name: 'user',
            screen: _screen('UserScreen', 'h'),
            params: const [RouteParam.path('userId', type: String)],
            children: [
              Route(
                'posts',
                name: 'posts',
                screen: _screen('PostsScreen', 'h'),
                params: const [RouteParam.path('userId', type: int)],
              ),
            ],
          ),
        ]).single,
        contains('but the parent declares it as String'),
      );
    });

    test('rejects route names that hide members or types', () {
      final problems = _routeProblems([
        Route('/a', name: 'int', screen: _screen('A', 'h')),
        Route('/b', name: 'hashCode', screen: _screen('B', 'h')),
      ]);

      expect(problems, hasLength(2));
      expect(
        problems,
        everyElement(contains('lowerCamelCase Dart identifier')),
      );
    });

    test('rejects paths that match the same locations', () {
      expect(
        _routeProblems([
          Route(
            '/:id',
            name: 'a',
            screen: _screen('A', 'h'),
            params: const [RouteParam.path('id', type: int)],
          ),
          Route(
            '/:slug',
            name: 'b',
            screen: _screen('B', 'h'),
            params: const [RouteParam.path('slug', type: String)],
          ),
        ]).single,
        'The routes "a" and "b" have the paths "/:id" and "/:slug", which '
        'match the same locations.',
      );
    });

    test('rejects names that would share the tags of annotations', () {
      final problems = _routeProblems([
        Route(
          '/a',
          name: 'a',
          screen: _screen('ABScreen', 'h'),
          params: const [
            RouteParam.query('userId', type: String, optional: true),
            RouteParam.query('userID', type: String, optional: true),
          ],
        ),
        Route('/b', name: 'b', screen: _screen('AbScreen', 'h')),
      ]);

      expect(problems, hasLength(2));
      expect(problems[0], contains('"userId" and "userID"'));
      expect(problems[1], contains('ABScreen and AbScreen'));
    });

    test('rejects destinations that need values', () {
      final problems = _routeProblems([
        Route(
          '/:id',
          name: 'a',
          screen: _screen('A', 'h'),
          params: const [RouteParam.path('id', type: int)],
          destination: _destination('A'),
        ),
        Route(
          '/b',
          name: 'b',
          screen: _screen('B', 'h'),
          params: const [RouteParam.query('q', type: String)],
          destination: _destination('B'),
        ),
        Route(
          '/c',
          name: 'c',
          screen: _screen('C', 'h'),
          params: const [RouteParam.query('q', type: String, optional: true)],
          destination: _destination('C'),
        ),
      ]);

      expect(problems, hasLength(2));
      expect(problems, everyElement(contains('is a destination of the main')));
    });

    test('rejects start candidates that need values', () {
      final problems = _routeProblems([
        Route(
          '/:id',
          name: 'a',
          screen: _screen('A', 'h'),
          params: const [RouteParam.path('id', type: int)],
          startCandidate: true,
          children: [
            Route(
              'b',
              name: 'b',
              screen: _screen('B', 'h'),
              startCandidate: true,
            ),
          ],
        ),
        Route(
          '/c',
          name: 'c',
          screen: _screen('C', 'h'),
          params: const [RouteParam.query('q', type: String, optional: true)],
          startCandidate: true,
        ),
      ]);

      expect(problems, hasLength(2));
      expect(problems, everyElement(contains('is a start candidate')));
    });

    test('rejects destinations of children and without label or icon', () {
      final problems = _routeProblems([
        Route(
          '/',
          name: 'a',
          screen: _screen('A', 'h'),
          destination: const Destination(
            label: ' ',
            icon: Fragment.wrap('Icon(', ')'),
          ),
          children: [
            Route(
              'b',
              name: 'b',
              screen: _screen('B', 'h'),
              destination: _destination('B'),
            ),
          ],
        ),
      ]);

      expect(problems, hasLength(3));
      expect(problems[0], contains('without a label'));
      expect(problems[1], contains('icon is not an expression'));
      expect(problems[2], contains('is a child'));
    });

    test('rejects required query parameters of a route with children', () {
      final problems = _routeProblems([
        Route(
          '/',
          name: 'a',
          screen: _screen('A', 'h'),
          params: const [RouteParam.query('q', type: String)],
          children: [Route('b', name: 'b', screen: _screen('B', 'h'))],
        ),
      ]);

      expect(problems.single, contains('query parameters must be optional'));
    });
  });

  group('the module rule router.screen_sockets', () {
    const screenTag =
        '{{{smf_router__screen_annotations__home__details_screen}}}';
    const idTag =
        '{{{smf_router__param_annotations__home__details_screen__id}}}';
    const tabTag =
        '{{{smf_router__param_annotations__home__details_screen__tab}}}';
    final details = _homeRoutes.routes.single.children.single;

    /// A screen template with the tags where they belong.
    const screen = '''
import 'package:flutter/widgets.dart';

/// The details of an item; the rule looks for class DetailsScreen only in
/// declarations.
$screenTag
// The annotations of the router go above.
@immutable
class DetailsScreen extends StatelessWidget {
  const DetailsScreen({
    $idTag required this.id,
    $tabTag this.tab,
    super.key,
  });

  final int id;

  final String? tab;

  @override
  Widget build(BuildContext context) => Text('\$id \$tab');
}
''';

    List<String> problems(String? template) => [
          for (final issue in _moduleIssues(
            'router.screen_sockets',
            _moduleInput(
              [details],
              bundles: [
                if (template != null)
                  _bundle({'lib/features/home/details_screen.dart': template}),
              ],
            ),
          ))
            issue.message,
        ];

    test('accepts a screen with the tags of its annotations', () {
      expect(problems(screen), isEmpty);
    });

    test('accepts a screen that renders to valid Dart', () async {
      final bundle = _bundle({'lib/features/home/details_screen.dart': screen});
      String name(String tag) => tag.substring(3, tag.length - 3);

      for (final vars in [
        {name(screenTag): '', name(idTag): '', name(tabTag): ''},
        {
          name(screenTag): '@RoutePage()',
          name(idTag): "@PathParam('id')",
          name(tabTag): "@QueryParam('tab')",
        },
      ]) {
        final rendered = await renderBundle(bundle, vars);
        final code = rendered['lib/features/home/details_screen.dart']!;

        expectParses(code);
        expect(code, contains('${vars[name(idTag)]} required this.id,'));
      }
    });

    test('rejects a screen that the bricks do not generate', () {
      expect(problems(null).single, contains('do not generate'));
    });

    test('rejects missing tags and a missing class', () {
      expect(
        problems('''
class DetailsScreen extends StatelessWidget {
  const DetailsScreen({required this.id, this.tab});
}
'''),
        [
          contains('lacks the tag $screenTag'),
          contains('lacks the tag $idTag'),
          contains('lacks the tag $tabTag'),
        ],
      );
      expect(
        problems('$screenTag\n$idTag $tabTag').first,
        contains('does not declare the class DetailsScreen'),
      );
    });

    test('rejects a tag that follows a brace, which mustache would eat', () {
      expect(
        problems(
          screen.replaceFirst('({\n    $idTag', '({$idTag'),
        ).single,
        contains('follows a "{"'),
      );
    });

    test('rejects a class tag away from the class', () {
      expect(
        problems(
          screen.replaceFirst(
            '$screenTag\n',
            '$screenTag\nclass Helper {}\n',
          ),
        ).single,
        contains('must come right before the declaration'),
      );
      expect(
        problems(
          screen.replaceFirst('$screenTag\n', '').replaceFirst(
                'super.key,\n  });',
                'super.key,\n  });\n$screenTag',
              ),
        ).single,
        contains('must come right before the declaration'),
      );
    });

    test('rejects a parameter tag outside its parameter', () {
      expect(
        problems(
          screen
              .replaceFirst('$idTag required this.id', 'required this.id')
              .replaceFirst('final int id;', '$idTag final int id;'),
        ).single,
        contains('right before the parameter id'),
      );
      expect(
        problems(
          screen
              .replaceFirst('$idTag required this.id', 'required this.id')
              .replaceFirst('$tabTag this.tab', '$idTag $tabTag this.tab'),
        ).single,
        contains('right before the parameter id'),
      );
    });

    test('skips screens with invalid names, which router.routes reports', () {
      expect(
        _moduleIssues(
          'router.screen_sockets',
          _moduleInput([Route('/', name: 'a', screen: _screen('a', 'home'))]),
        ),
        isEmpty,
      );
    });
  });

  group('the structural rule router.nav_access', () {
    List<SmfIssue> check(
      Map<String, ContributionOrigin> owners, {
      Set<ModuleId> dependsOn = const {},
    }) =>
        routerRole
            .checkStructure(
              StructuralRuleRequest(
                hook: RoleHookRequest(
                  data: _data,
                  presentRoles: {routerRole},
                  context: testContext,
                ),
                files: {
                  for (final path in owners.keys)
                    path: DartFileIndex(
                      path: path,
                      memberAccesses: const [
                        IndexedMemberAccess('context', 'nav'),
                        IndexedMemberAccess('context.nav', 'settings'),
                      ],
                    ),
                },
                owners: owners,
                modules: [
                  ModuleDescriptor(
                    id: const ModuleId('home'),
                    description: 'Home',
                    kind: ModuleKinds.feature,
                    dependsOn: dependsOn,
                  ),
                  const ModuleDescriptor(
                    id: ModuleId('settings'),
                    description: 'Settings',
                    kind: ModuleKinds.feature,
                  ),
                ],
              ),
            )
            .where((issue) => issue.message.contains('navigates'))
            .toList();

    test('lets a module navigate to its own routes', () {
      expect(
        check({
          'lib/features/settings/a.dart':
              const ModuleOrigin(ModuleId('settings')),
          'lib/core/router/navigation.dart':
              const RoleTemplateOrigin(routerRole),
        }),
        isEmpty,
      );
    });

    test('rejects routes of modules the module does not depend on', () {
      final issues = check({
        'lib/features/home/a.dart': const ModuleOrigin(ModuleId('home')),
      });

      expect(issues.single.message, contains('context.nav.settings'));
      expect(issues.single.origin, const ModuleOrigin(ModuleId('home')));
      expect(issues.single.path, 'lib/features/home/a.dart');
      expect(
        check(
          {'lib/features/home/a.dart': const ModuleOrigin(ModuleId('home'))},
          dependsOn: {const ModuleId('settings')},
        ),
        isEmpty,
      );
    });

    test('rejects the location classes of such modules, but not in the router',
        () {
      List<SmfIssue> locations(
        ModuleOrigin owner, {
        List<RoleProvider> providers = const [],
      }) =>
          routerRole.checkStructure(
            StructuralRuleRequest(
              hook: RoleHookRequest(
                data: _data,
                presentRoles: {routerRole},
                context: testContext,
              ),
              files: {
                'lib/a.dart': const DartFileIndex(
                  path: 'lib/a.dart',
                  invocations: [
                    IndexedInvocation('NavLink'),
                    IndexedInvocation('SettingsUserLocation'),
                    IndexedInvocation('HomeRootLocation'),
                  ],
                ),
              },
              owners: {'lib/a.dart': owner},
              modules: [
                ModuleDescriptor(
                  id: owner.module,
                  description: 'Module',
                  kind: ModuleKinds.infrastructure,
                  providers: providers,
                ),
              ],
            ),
          );

      final issues = [
        for (final issue in locations(const ModuleOrigin(ModuleId('home'))))
          if (issue.message.contains(' uses ')) issue,
      ];
      expect(issues.single.message, contains('uses SettingsUserLocation'));
      expect(issues.single.origin, const ModuleOrigin(ModuleId('home')));
      expect(
        locations(
          const ModuleOrigin(ModuleId('go_router')),
          providers: [const RoleProvider.plain(routerRole)],
        ).where((issue) => issue.message.contains(' uses ')),
        isEmpty,
      );
    });
  });

  group('the structural rule router.screen_constructors', () {
    const detailsPath = 'lib/features/home/details_screen.dart';

    List<SmfIssue> check(Map<String, DartFileIndex> files) =>
        routerRole.checkStructure(
          StructuralRuleRequest(
            hook: RoleHookRequest(
              data: [_data.first],
              presentRoles: {routerRole},
              context: testContext,
            ),
            files: files,
          ),
        );

    List<String> checkDetails(
      List<IndexedParameter> parameters, {
      bool isConst = true,
    }) =>
        [
          for (final issue in check({
            'lib/features/home/home_screen.dart': const DartFileIndex(
              path: 'lib/features/home/home_screen.dart',
              declarations: [
                IndexedDeclaration(
                  name: 'HomeScreen',
                  kind: DeclarationKind.classType,
                  constructors: [IndexedConstructor(isConst: true)],
                ),
              ],
            ),
            detailsPath: DartFileIndex(
              path: detailsPath,
              declarations: [
                IndexedDeclaration(
                  name: 'DetailsScreen',
                  kind: DeclarationKind.classType,
                  constructors: [
                    IndexedConstructor(
                      parameters: parameters,
                      isConst: isConst,
                    ),
                  ],
                ),
              ],
            ),
          }))
            issue.message,
        ];

    test('accepts a constructor that takes the route parameters', () {
      expect(
        checkDetails(const [
          IndexedParameter(
            'id',
            kind: ParameterKind.requiredNamed,
            type: 'int',
          ),
          IndexedParameter(
            'tab',
            kind: ParameterKind.optionalNamed,
            type: 'String?',
          ),
          IndexedParameter('key', kind: ParameterKind.optionalNamed),
        ]),
        isEmpty,
      );
    });

    test('rejects missing, extra required and non-nullable parameters', () {
      final problems = checkDetails(const [
        IndexedParameter(
          'tab',
          kind: ParameterKind.optionalNamed,
          type: 'String',
        ),
        IndexedParameter('title', kind: ParameterKind.requiredNamed),
      ]);

      expect(problems, hasLength(3));
      expect(problems[0], contains('must accept the named parameter id'));
      expect(problems[1], contains('must not require the parameter title'));
      expect(problems[2], contains('tab of DetailsScreen must be nullable'));
    });

    test('rejects a screen without a const constructor', () {
      final problems = checkDetails(
        const [
          IndexedParameter('id', kind: ParameterKind.requiredNamed),
          IndexedParameter(
            'tab',
            kind: ParameterKind.optionalNamed,
            type: 'String?',
          ),
        ],
        isConst: false,
      );

      expect(problems.single, contains('must have a const unnamed'));
    });

    test('rejects a screen whose file is missing', () {
      final issues = check(const {});

      expect(issues, hasLength(2));
      expect(issues.first.message, contains('is missing'));
      expect(issues.first.origin, const ModuleOrigin(ModuleId('home')));
      expect(issues.first.path, 'lib/features/home/home_screen.dart');
    });
  });
}
