import 'dart:io';

import 'package:mason/mason.dart' hide GeneratedFile;
import 'package:path/path.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_go_router/bundles/smf_go_router_bundle.dart';
import 'package:smf_go_router/src/smf_go_router_module.dart';
import 'package:test/test.dart';

import 'helpers/dart_code.dart';
import 'helpers/route_fixtures.dart';

const _appName = 'test_app';

void main() {
  late Directory tempDir;
  late String projectRoot;

  String shellPath() =>
      join(projectRoot, 'lib', 'core', 'widgets', 'main_tabs_shell.dart');
  String routerPath() =>
      join(projectRoot, 'lib', 'core', 'router', 'app_router.dart');
  String appRoutesPath() =>
      join(projectRoot, 'lib', 'core', 'router', 'app_routes.dart');

  Future<List<GeneratedFile>> generate({
    required List<RouteGroup> routeGroups,
    List<ShellDeclaration> shellDeclarations = const [],
    String? initialRoute,
  }) {
    return SmfGoRouterModule().generateFromDsl(
      DslContext(
        projectRootPath: projectRoot,
        mustacheVariables: {'app_name': _appName},
        logger: Logger(),
        initialRoute: initialRoute ?? routeGroups.first.initialRoute!,
        routeGroups: routeGroups,
        shellDeclarations: shellDeclarations,
      ),
    );
  }

  /// Generates with the main tabs shell declared, as the CLI does whenever a
  /// module links a route to it, and returns the router file content.
  Future<String> generateRouter(List<RouteGroup> routeGroups) async {
    final files = await generate(
      routeGroups: routeGroups,
      shellDeclarations: [mainTabsShell],
      initialRoute: '/home',
    );
    return files.singleWhere((f) => f.path == routerPath()).content;
  }

  String contentOf(List<GeneratedFile> files, String path) =>
      files.singleWhere((f) => f.path == path).content;

  /// The `GoRoute(...)` call of the route at [path] in the generated router.
  String goRouteOf(String router, String path) {
    final start =
        router.lastIndexOf('GoRoute(', router.indexOf("path: '$path'"));
    var depth = 0;
    for (var i = start + 'GoRoute'.length; i < router.length; i++) {
      if (router[i] == '(') depth++;
      if (router[i] == ')' && --depth == 0) {
        return router.substring(start, i + 1);
      }
    }
    fail('No complete GoRoute for $path in:\n$router');
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('smf_go_router_test');
    final generator = await MasonGenerator.fromBundle(smfGoRouterBundle);
    await generator.generate(
      DirectoryGeneratorTarget(tempDir),
      vars: {'app_name': _appName},
    );
    projectRoot = join(tempDir.path, _appName);
  });

  tearDown(() => tempDir.delete(recursive: true));

  test('removes the tabs shell template when no module adds tabs', () async {
    expect(File(shellPath()).existsSync(), isTrue);

    final files = await generate(
      routeGroups: [
        const RouteGroup(
          initialRoute: '/noModules',
          routes: [
            Route(
              path: '/noModules',
              screen: RouteScreen('NoModulesScreen'),
            ),
          ],
        ),
      ],
    );

    expect(File(shellPath()).existsSync(), isFalse);
    expect(files.map((f) => f.path), isNot(contains(shellPath())));
    for (final file in files) {
      expect(file.content, isNot(contains('{{')), reason: file.path);
      expect(file.content, isNot(contains('main_tabs_shell')));
    }
  });

  test('renders the tabs shell when a module adds tabs', () async {
    final files = await generate(
      routeGroups: [
        RouteGroup(
          initialRoute: '/home',
          routes: [
            NestedRoute(
              shellLink: RouteShellLink.toMainTabsShell(),
              children: [
                const Route(
                  path: '/home',
                  name: 'homeScreen',
                  screen: RouteScreen('HomeScreen'),
                  meta: RouteMeta(label: 'Home', icon: 'Icons.home'),
                ),
              ],
            ),
          ],
        ),
      ],
      shellDeclarations: [ShellRegistry.resolve('main-tabs')!],
    );

    final shell = files.singleWhere((f) => f.path == shellPath());
    expect(shell.content, contains('_TabInfo(path: "/home"'));
    expect(shell.content, isNot(contains('{{')));
  });

  group('router', () {
    test('starts at the initial route of the DSL context', () async {
      final files = await generate(
        routeGroups: [
          const RouteGroup(
            routes: [Route(path: '/splash'), Route(path: '/login')],
          ),
        ],
        initialRoute: '/login',
      );

      expect(
        contentOf(files, routerPath()),
        contains("initialLocation: '/login',"),
      );
    });

    test('renders valid files with only GoRoutes when no module adds tabs',
        () async {
      final files = await generate(
        routeGroups: [
          const RouteGroup(
            initialRoute: '/noModules',
            routes: [
              Route(path: '/noModules', screen: RouteScreen('NoModules')),
            ],
          ),
        ],
      );

      final router = contentOf(files, routerPath());
      expect(countOf(router, 'GoRoute('), 1);
      expect(router, isNot(contains('ShellRoute(')));
      expect(files.map((f) => f.path), [routerPath(), appRoutesPath()]);
      for (final file in files) {
        expectParses(file.content);
      }
    });

    test('renders plain routes and one ShellRoute for the tabs of all modules',
        () async {
      final files = await generate(
        initialRoute: '/home',
        shellDeclarations: [mainTabsShell],
        routeGroups: [
          RouteGroup(
            routes: [
              NestedRoute(
                shellLink: RouteShellLink.toMainTabsShell(),
                children: [
                  const Route(
                    path: '/home',
                    name: 'home',
                    screen: RouteScreen('HomeScreen'),
                    meta: RouteMeta(label: 'Home', icon: 'Icons.home'),
                    imports: [Import.features('home/home_screen.dart')],
                  ),
                ],
              ),
            ],
          ),
          const RouteGroup(
            routes: [
              Route(
                path: '/settings',
                screen: RouteScreen('SettingsScreen'),
                imports: [Import.features('settings/settings_screen.dart')],
              ),
            ],
          ),
          RouteGroup(
            routes: [
              NestedRoute(
                shellLink: RouteShellLink.toMainTabsShell(),
                children: [
                  const Route(
                    path: '/analytics',
                    name: 'analytics',
                    screen: RouteScreen('AnalyticsScreen'),
                    meta: RouteMeta(label: 'Analytics', icon: 'Icons.star'),
                    imports: [
                      Import.features('analytics/analytics_screen.dart'),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final router = contentOf(files, routerPath());
      expect(countOf(router, 'ShellRoute('), 1);
      expect(countOf(router, 'GoRoute('), 3);
      expect(countOf(router, 'MainTabsShell(child: child)'), 1);

      final settings = router.indexOf("path: '/settings'");
      final shellRoute = router.indexOf('ShellRoute(');
      final home = router.indexOf("path: '/home'");
      final analytics = router.indexOf("path: '/analytics'");
      expect(settings, lessThan(shellRoute));
      expect(shellRoute, lessThan(home));
      expect(home, lessThan(analytics));

      expect(
        files.map((f) => f.path),
        [routerPath(), appRoutesPath(), shellPath()],
      );
      for (final file in files) {
        expect(file.content, isNot(contains('{{')), reason: file.path);
        expectParses(file.content);
      }
    });

    test('imports each route file once, resolving the app package name',
        () async {
      final router = await generateRouter([
        const RouteGroup(
          routes: [
            Route(
              path: '/orders',
              imports: [Import.features('orders/orders.dart')],
            ),
            Route(
              path: '/orders/:id',
              imports: [
                Import.features('orders/orders.dart'),
                Import.direct("import 'package:intl/intl.dart'"),
              ],
            ),
          ],
        ),
      ]);

      const ordersImport =
          "import 'package:test_app/features/orders/orders.dart';";
      expect(countOf(router, ordersImport), 1);
      expect(router, contains("import 'package:intl/intl.dart';"));
    });

    test('imports the rendered shell widget', () async {
      final router = await generateRouter([
        RouteGroup(
          routes: [
            NestedRoute(
              shellLink: RouteShellLink.toMainTabsShell(),
              children: [
                const Route(path: '/home', meta: RouteMeta(icon: 'Icons.home')),
              ],
            ),
          ],
        ),
      ]);

      expect(
        router,
        contains(
          "import 'package:test_app/core/widgets/main_tabs_shell.dart';",
        ),
      );
    });

    test('checks the core guards of all route groups at the router level',
        () async {
      final router = await generateRouter([
        RouteGroup(
          routes: [const Route(path: '/home')],
          coreGuards: [goRouterGuard('maintenanceGuard(context, state)')],
        ),
        RouteGroup(
          routes: [const Route(path: '/login')],
          coreGuards: [goRouterGuard('authGuard(context, state)')],
        ),
      ]);

      final routerRedirect = router.substring(router.lastIndexOf('redirect:'));
      expect(
        routerRedirect,
        contains('final r0 = maintenanceGuard(context, state);'),
      );
      expect(routerRedirect, contains('final r1 = authGuard(context, state);'));
      expectParses(router);
    });

    test('applies guards declared on a route to that route only', () async {
      final router = await generateRouter([
        RouteGroup(
          routes: [
            const Route(path: '/home'),
            Route(
              path: '/account',
              guards: [goRouterGuard('authGuard(context, state)')],
            ),
          ],
        ),
      ]);

      expect(countOf(router, 'authGuard(context, state)'), 1);
      expect(
        router.indexOf('authGuard'),
        greaterThan(router.indexOf("path: '/account'")),
      );
    });

    test('rejects a nested route linked to an undeclared shell', () async {
      await expectLater(
        generate(
          initialRoute: '/home',
          routeGroups: [
            const RouteGroup(
              routes: [
                NestedRoute(
                  shellLink: RouteShellLink('unknown-shell'),
                  children: [Route(path: '/home')],
                ),
              ],
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test(
      'applies guards declared on a nested route to its routes',
      () async {
        final router = await generateRouter([
          RouteGroup(
            routes: [
              NestedRoute(
                shellLink: RouteShellLink.toMainTabsShell(),
                guards: [goRouterGuard('onboardingGuard(context, state)')],
                children: [
                  const Route(
                    path: '/home',
                    meta: RouteMeta(icon: 'Icons.home'),
                  ),
                  const Route(
                    path: '/cart',
                    meta: RouteMeta(icon: 'Icons.cart'),
                  ),
                ],
              ),
            ],
          ),
        ]);

        expect(
          goRouteOf(router, '/home'),
          contains('final r0 = onboardingGuard(context, state);'),
        );
        expect(
          goRouteOf(router, '/cart'),
          contains('final r0 = onboardingGuard(context, state);'),
        );
        // On the routes only, not on the shell or the router.
        expect(countOf(router, 'onboardingGuard'), 2);
        expectParses(router);
      },
    );

    test(
        'does not apply the nested route guards of one module to the tabs '
        'another module adds to the same shell', () async {
      final router = await generateRouter([
        RouteGroup(
          routes: [
            NestedRoute(
              shellLink: RouteShellLink.toMainTabsShell(),
              guards: [goRouterGuard('onboardingGuard(context, state)')],
              children: [
                const Route(path: '/home', meta: RouteMeta(icon: 'Icons.home')),
              ],
            ),
          ],
        ),
        RouteGroup(
          routes: [
            NestedRoute(
              shellLink: const RouteShellLink('main-tabs'),
              children: [
                Route(
                  path: '/profile',
                  meta: const RouteMeta(icon: 'Icons.person'),
                  guards: [goRouterGuard('authGuard(context, state)')],
                ),
              ],
            ),
          ],
        ),
      ]);

      expect(countOf(router, 'ShellRoute('), 1);
      expect(countOf(router, 'onboardingGuard'), 1);
      expect(goRouteOf(router, '/home'), contains('onboardingGuard'));
      expect(goRouteOf(router, '/home'), isNot(contains('authGuard')));
      expect(goRouteOf(router, '/profile'), isNot(contains('onboardingGuard')));
      expect(
        goRouteOf(router, '/profile'),
        contains('final r0 = authGuard(context, state);'),
      );
    });

    test(
      'imports files declared on a nested route',
      () async {
        final router = await generateRouter([
          RouteGroup(
            routes: [
              NestedRoute(
                shellLink: RouteShellLink.toMainTabsShell(),
                imports: [
                  const Import.core(
                    ImportAnchor.coreWidgets,
                    'tabs_scope.dart',
                  ),
                ],
                children: [
                  const Route(
                    path: '/home',
                    meta: RouteMeta(icon: 'Icons.home'),
                  ),
                ],
              ),
            ],
          ),
        ]);

        expect(
          router,
          contains("import 'package:test_app/core/widgets/tabs_scope.dart';"),
        );
      },
    );

    test(
      'imports what route guards need',
      () async {
        final router = await generateRouter([
          RouteGroup(
            routes: [
              Route(
                path: '/account',
                guards: [
                  goRouterGuard(
                    'authGuard(context, state)',
                    imports: [
                      const Import.core(
                        ImportAnchor.coreService,
                        'auth/guard.dart',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ]);

        expect(
          router,
          contains("import 'package:test_app/core/services/auth/guard.dart';"),
        );
      },
    );

    test(
      'imports what core guards need',
      () async {
        final router = await generateRouter([
          RouteGroup(
            routes: [const Route(path: '/home')],
            coreGuards: [
              goRouterGuard(
                'authGuard(context, state)',
                imports: [
                  const Import.core(
                    ImportAnchor.coreService,
                    'auth/guard.dart',
                  ),
                ],
              ),
            ],
          ),
        ]);

        expect(
          router,
          contains("import 'package:test_app/core/services/auth/guard.dart';"),
        );
      },
    );

    test('imports what the guards of nested and tab routes need, once',
        () async {
      const authImport = Import.core(ImportAnchor.coreService, 'auth.dart');
      final router = await generateRouter([
        RouteGroup(
          routes: [
            NestedRoute(
              shellLink: RouteShellLink.toMainTabsShell(),
              guards: [
                goRouterGuard(
                  'onboardingGuard(context, state)',
                  imports: [const Import.features('onboarding/guard.dart')],
                ),
              ],
              children: [
                Route(
                  path: '/home',
                  meta: const RouteMeta(icon: 'Icons.home'),
                  guards: [
                    goRouterGuard(
                      'authGuard(context, state)',
                      imports: [authImport],
                    ),
                  ],
                ),
              ],
            ),
          ],
          coreGuards: [
            goRouterGuard(
              'sessionGuard(context, state)',
              imports: [authImport],
            ),
          ],
        ),
      ]);

      expect(
        router,
        contains("import 'package:test_app/features/onboarding/guard.dart';"),
      );
      expect(
        countOf(router, "import 'package:test_app/core/services/auth.dart';"),
        1,
      );
    });
  });

  group('AppRoutes', () {
    Set<String> referencedMembers(String router) => RegExp(r'AppRoutes\.(\w+)')
        .allMatches(router)
        .map((m) => m.group(1)!)
        .toSet();

    Set<String> declaredMembers(String appRoutes) =>
        RegExp(r'static const (\w+) =')
            .allMatches(appRoutes)
            .map((m) => m.group(1)!)
            .toSet();

    test('declares constants for the routes inside the tabs shell', () async {
      final files = await generate(
        initialRoute: '/home',
        shellDeclarations: [mainTabsShell],
        routeGroups: [
          RouteGroup(
            routes: [
              NestedRoute(
                shellLink: RouteShellLink.toMainTabsShell(),
                children: [
                  const Route(
                    path: '/home',
                    name: 'home',
                    meta: RouteMeta(icon: 'Icons.home'),
                  ),
                  const Route(
                    path: '/cart',
                    meta: RouteMeta(icon: 'Icons.cart'),
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final appRoutes = contentOf(files, appRoutesPath());
      expect(appRoutes, contains("static const homePath = '/home';"));
      expect(appRoutes, contains("static const home = 'home';"));
      expect(appRoutes, contains("static const cartPath = '/cart';"));
      expect(appRoutes, isNot(contains('{{')));
      expectParses(appRoutes);
    });

    test('declares every member the router refers to for tab routes', () async {
      final files = await generate(
        initialRoute: '/home',
        shellDeclarations: [mainTabsShell],
        routeGroups: [
          RouteGroup(
            routes: [
              NestedRoute(
                shellLink: RouteShellLink.toMainTabsShell(),
                children: [
                  const Route(
                    path: '/home',
                    name: 'home',
                    meta: RouteMeta(icon: 'Icons.home'),
                  ),
                  const Route(
                    path: '/profile',
                    name: 'profile',
                    meta: RouteMeta(icon: 'Icons.person'),
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final referenced = referencedMembers(contentOf(files, routerPath()));
      expect(referenced, {'home', 'profile'});
      expect(
        declaredMembers(contentOf(files, appRoutesPath())),
        containsAll(referenced),
      );
    });

    test(
      'declares every member the router refers to for top-level routes',
      () async {
        final files = await generate(
          routeGroups: [
            const RouteGroup(
              initialRoute: '/login',
              routes: [
                Route(
                  path: '/login',
                  name: 'login',
                  screen: RouteScreen('LoginScreen'),
                ),
              ],
            ),
          ],
        );

        final referenced = referencedMembers(contentOf(files, routerPath()));
        expect(referenced, {'login'});
        expect(
          declaredMembers(contentOf(files, appRoutesPath())),
          containsAll(referenced),
        );
      },
    );

    test('declares camelCased route names as the router refers to them',
        () async {
      final files = await generate(
        initialRoute: '/home',
        shellDeclarations: [mainTabsShell],
        routeGroups: [
          RouteGroup(
            routes: [
              const Route(path: '/user-profile', name: 'userProfile'),
              NestedRoute(
                shellLink: RouteShellLink.toMainTabsShell(),
                children: [
                  const Route(
                    path: '/home',
                    name: 'homeScreen',
                    meta: RouteMeta(icon: 'Icons.home'),
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final referenced = referencedMembers(contentOf(files, routerPath()));
      expect(referenced, {'userProfile', 'homeScreen'});
      expect(
        declaredMembers(contentOf(files, appRoutesPath())),
        containsAll([...referenced, 'userProfilePath', 'homeScreenPath']),
      );
    });

    test('declares constants for top-level and tab routes alike', () async {
      final files = await generate(
        initialRoute: '/home',
        shellDeclarations: [mainTabsShell],
        routeGroups: [
          RouteGroup(
            routes: [
              const Route(path: '/login'),
              const Route(path: '/settings', name: 'settings'),
              NestedRoute(
                shellLink: RouteShellLink.toMainTabsShell(),
                children: [
                  const Route(
                    path: '/home',
                    meta: RouteMeta(icon: 'Icons.home'),
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final appRoutes = contentOf(files, appRoutesPath());
      expect(appRoutes, contains("static const loginPath = '/login';"));
      expect(appRoutes, contains("static const settingsPath = '/settings';"));
      expect(appRoutes, contains("static const settings = 'settings';"));
      expect(appRoutes, contains("static const homePath = '/home';"));
      expectParses(appRoutes);
    });
  });

  group('tabs shell', () {
    test('lists the tabs of all modules ordered by RouteMeta.order', () async {
      NestedRoute tab(String path, {int? order}) => NestedRoute(
            shellLink: RouteShellLink.toMainTabsShell(),
            children: [
              Route(
                path: path,
                meta: RouteMeta(icon: 'Icons.circle', order: order),
              ),
            ],
          );

      final files = await generate(
        initialRoute: '/home',
        shellDeclarations: [mainTabsShell],
        routeGroups: [
          RouteGroup(routes: [tab('/analytics')]),
          RouteGroup(routes: [tab('/profile', order: 1)]),
          RouteGroup(routes: [tab('/home', order: 0)]),
        ],
      );

      final shell = contentOf(files, shellPath());
      final tabPaths = RegExp(r'_TabInfo\(path: "([^"]+)"')
          .allMatches(shell)
          .map((m) => m.group(1))
          .toList();
      expect(tabPaths, ['/home', '/profile', '/analytics']);
      expectParses(shell);
    });
  });

  group('mergeNestedRoutesByShellLink', () {
    final module = SmfGoRouterModule();

    test('keeps plain routes first and merges nested routes per shell link',
        () {
      const pagesLink = RouteShellLink('onboarding-pages');
      const home = Route(path: '/home');
      const profile = Route(path: '/profile');
      const welcome = Route(path: '/welcome');
      const settings = Route(path: '/settings');

      final merged = module.mergeNestedRoutesByShellLink([
        NestedRoute(
          shellLink: RouteShellLink.toMainTabsShell(),
          children: [home],
        ),
        settings,
        const NestedRoute(shellLink: pagesLink, children: [welcome]),
        NestedRoute(
          shellLink: RouteShellLink.toMainTabsShell(),
          children: [profile],
        ),
      ]);

      expect(merged, hasLength(3));
      expect(merged[0], same(settings));
      final tabs = merged[1] as NestedRoute;
      expect(tabs.shellLink.id, 'main-tabs');
      expect(tabs.children, [home, profile]);
      final pages = merged[2] as NestedRoute;
      expect(pages.shellLink.id, 'onboarding-pages');
      expect(pages.children, [welcome]);
    });

    test(
      'merges nested routes that link the same shell id via separate links',
      () {
        // Equal but non-identical links, as two separate modules create them.
        final merged = module.mergeNestedRoutesByShellLink([
          const NestedRoute(
            shellLink: RouteShellLink('main-tabs'),
            children: [Route(path: '/home')],
          ),
          const NestedRoute(
            shellLink: RouteShellLink('main-tabs'),
            children: [Route(path: '/profile')],
          ),
        ]);

        expect(merged, hasLength(1));
      },
    );

    test('merges by shell id even when the links are not equal', () {
      // The published smf_contracts may predate RouteShellLink equality.
      final merged = module.mergeNestedRoutesByShellLink([
        NestedRoute(
          shellLink: _IdentityShellLink('main-tabs'),
          children: [const Route(path: '/home')],
        ),
        NestedRoute(
          shellLink: _IdentityShellLink('main-tabs'),
          children: [const Route(path: '/profile')],
        ),
      ]);

      expect(merged, hasLength(1));
    });

    test('moves the guards of each nested route onto its own children', () {
      final onboarding = goRouterGuard('onboardingGuard(context, state)');
      final premium = goRouterGuard('premiumGuard(context, state)');
      final home = Route(
        path: '/home',
        name: 'home',
        screen: const RouteScreen('HomeScreen'),
        parameters: [const QueryParam('tab', type: String, optional: true)],
        meta: const RouteMeta(icon: 'Icons.home'),
        guards: [premium],
        imports: [const Import.features('home/home_screen.dart')],
      );
      const profile = Route(path: '/profile');

      final merged = module.mergeNestedRoutesByShellLink([
        NestedRoute(
          shellLink: RouteShellLink.toMainTabsShell(),
          guards: [onboarding],
          children: [home],
        ),
        NestedRoute(
          shellLink: RouteShellLink.toMainTabsShell(),
          children: [profile],
        ),
      ]);

      final tabs = merged.single as NestedRoute;
      expect(tabs.guards, isEmpty);
      expect(tabs.children, hasLength(2));

      final guardedHome = tabs.children[0];
      expect(guardedHome.guards, [onboarding, premium]);
      expect(guardedHome.path, home.path);
      expect(guardedHome.name, home.name);
      expect(guardedHome.screen, same(home.screen));
      expect(guardedHome.parameters, same(home.parameters));
      expect(guardedHome.meta, same(home.meta));
      expect(guardedHome.imports, same(home.imports));

      expect(tabs.children[1], same(profile));
    });

    test('keeps the imports of every merged nested route', () {
      const tabsScope = Import.core(ImportAnchor.coreWidgets, 'tabs.dart');
      const authScope = Import.features('auth/auth_scope.dart');

      final merged = module.mergeNestedRoutesByShellLink([
        NestedRoute(
          shellLink: RouteShellLink.toMainTabsShell(),
          imports: [tabsScope],
          children: [const Route(path: '/home')],
        ),
        NestedRoute(
          shellLink: RouteShellLink.toMainTabsShell(),
          imports: [authScope],
          children: [const Route(path: '/profile')],
        ),
      ]);

      expect((merged.single as NestedRoute).imports, [tabsScope, authScope]);
    });
  });

  group('groupRoutesByShellLink', () {
    final module = SmfGoRouterModule();

    test('groups the tab routes of all route groups by shell declaration', () {
      const home = Route(path: '/home');
      const profile = Route(path: '/profile');

      final grouped = module.groupRoutesByShellLink([
        RouteGroup(
          routes: [
            const Route(path: '/settings'),
            NestedRoute(
              shellLink: RouteShellLink.toMainTabsShell(),
              children: [home],
            ),
          ],
        ),
        RouteGroup(
          routes: [
            NestedRoute(
              shellLink: RouteShellLink.toMainTabsShell(),
              children: [profile],
            ),
          ],
        ),
      ]);

      expect(grouped.keys, [mainTabsShell]);
      expect(grouped[mainTabsShell], [home, profile]);
    });

    test('throws for a shell link missing from ShellRegistry', () {
      expect(
        () => module.groupRoutesByShellLink([
          const RouteGroup(
            routes: [
              NestedRoute(
                shellLink: RouteShellLink('unknown-shell'),
                children: [Route(path: '/home')],
              ),
            ],
          ),
        ]),
        throwsArgumentError,
      );
    });
  });
}

/// A link that equals only itself, like RouteShellLink before it compared ids.
///
/// Its identity-based `==` and `hashCode` are what Object has, which is safe
/// for mutable classes. It is not `@immutable`, as that asks for a const
/// constructor, and const links with the same id would be one canonical
/// instance, equal to itself.
class _IdentityShellLink extends RouteShellLink {
  _IdentityShellLink(super.id);

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes, identity-based.
  bool operator ==(Object other) => identical(this, other);

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes, identity-based.
  int get hashCode => identityHashCode(this);
}
