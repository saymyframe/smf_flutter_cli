import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:smf_contracts/lego.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'support/features.dart';
import 'support/type_check.dart';

/// `_checkValues` as the analyzer prints its declaration.
final String _expectedCheckValues = parseString(
  content: r'''
String? _checkValues(Map<String, Object?> values) {
  final invalid = [
    for (final MapEntry(:key, :value) in values.entries)
      if (value == null) key,
  ];
  if (invalid.isEmpty) return null;
  throw GoException('The location has no valid ${invalid.join(', ')}.');
}
''',
).unit.declarations.single.toSource();

/// `_checkMainNavigation` as the analyzer prints its declaration.
final String _expectedCheckMainNavigation = parseString(
  content: r'''
class _GoAppRouter {
  void _checkMainNavigation(AppLocation location, String method) {
    final matches = config.routerDelegate.currentConfiguration.matches;
    if (matches.isEmpty ||
        matches.last is ShellRouteMatch ||
        !matches.any((match) => match is ShellRouteMatch)) {
      return;
    }
    final target = config.configuration.findMatch(Uri.parse(location.path));
    if (target.matches.firstOrNull is! ShellRouteMatch) return;
    throw StateError(
      'Cannot $method ${location.path}: it is in the main navigation, and a '
      'page is shown over the main navigation. Use go() to show it there.',
    );
  }
}
''',
)
    .unit
    .declarations
    .whereType<ClassDeclaration>()
    .single
    .members
    .single
    .toSource();

/// The path of the file of `createAppRouter()`.
const String _factory = RouterRole.appRouterFactoryFile;

/// The pubspec of [app] as plain maps and lists.
Map<String, Object?> _pubspecOf(RenderedApp app) {
  Object? plain(Object? node) => switch (node) {
        final YamlMap map => {
            for (final MapEntry(:key, :value) in map.entries)
              '$key': plain(value),
          },
        final YamlList list => [for (final item in list) plain(item)],
        _ => node,
      };
  return plain(loadYaml(app.files['pubspec.yaml']!.text))!
      as Map<String, Object?>;
}

/// The parsed file of `createAppRouter()` of [app].
CompilationUnit _factoryOf(RenderedApp app) =>
    parseString(content: app.files[_factory]!.text).unit;

/// The call that creates the `GoRouter` in [unit].
MethodInvocation _goRouterOf(CompilationUnit unit) {
  final finder = _CallFinder('GoRouter');
  unit.accept(finder);
  return finder.calls.single;
}

/// The named argument [label] of [call], or `null`.
Expression? _argument(MethodInvocation call, String label) => [
      for (final argument in call.argumentList.arguments)
        if (argument case NamedExpression(:final name, :final expression)
            when name.label.name == label)
          expression,
    ].firstOrNull;

/// A `GoRoute(...)` of the generated code.
final class _GoRoute {
  _GoRoute(this.call);

  final MethodInvocation call;

  String get path => (_argument(call, 'path')! as StringLiteral).stringValue!;

  String? get name => (_argument(call, 'name') as StringLiteral?)?.stringValue;

  /// The source of the redirect, or `null`.
  String? get redirect => _argument(call, 'redirect')?.toSource();

  /// The source of the builder, or `null`.
  String? get builder => _argument(call, 'builder')?.toSource();

  /// The arguments that the builder passes to the screen, by name, as
  /// source.
  Map<String, String> get screenArguments {
    final body = (_argument(call, 'builder')! as FunctionExpression).body
        as ExpressionFunctionBody;
    final arguments = switch (body.expression) {
      MethodInvocation(:final argumentList) => argumentList,
      InstanceCreationExpression(:final argumentList) => argumentList,
      final other => throw StateError('The builder returns $other'),
    };
    return {
      for (final argument in arguments.arguments)
        if (argument case NamedExpression(:final name, :final expression))
          name.label.name: expression.toSource(),
    };
  }

  List<_GoRoute> get children => switch (_argument(call, 'routes')) {
        final ListLiteral list => [
            for (final element in list.elements)
              _GoRoute(element as MethodInvocation),
          ],
        _ => const [],
      };
}

/// The items of the list of routes of `GoRouter` in [unit].
List<MethodInvocation> _topLevelOf(CompilationUnit unit) => [
      for (final element
          in (_argument(_goRouterOf(unit), 'routes')! as ListLiteral).elements)
        element as MethodInvocation,
    ];

/// The `GoRoute`s in the list of routes of `GoRouter` in [unit].
List<_GoRoute> _routesOf(CompilationUnit unit) => [
      for (final route in _topLevelOf(unit))
        if (route.target == null && route.methodName.name == 'GoRoute')
          _GoRoute(route),
    ];

/// The `StatefulShellRoute.indexedStack` in the list of routes of
/// `GoRouter` in [unit], or `null`.
MethodInvocation? _shellOf(CompilationUnit unit) => [
      for (final route in _topLevelOf(unit))
        if (route.target?.toSource() == 'StatefulShellRoute' &&
            route.methodName.name == 'indexedStack')
          route,
    ].singleOrNull;

/// A `StatefulShellBranch(...)` of the generated code.
final class _Branch {
  _Branch(this.call);

  final MethodInvocation call;

  String get initialLocation =>
      (_argument(call, 'initialLocation')! as StringLiteral).stringValue!;

  /// The source of the observers.
  String get observers => _argument(call, 'observers')!.toSource();

  List<_GoRoute> get routes => [
        for (final element
            in (_argument(call, 'routes')! as ListLiteral).elements)
          _GoRoute(element as MethodInvocation),
      ];
}

/// The branches of [shell], a `StatefulShellRoute.indexedStack(...)`.
List<_Branch> _branchesOf(MethodInvocation shell) => [
      for (final element
          in (_argument(shell, 'branches')! as ListLiteral).elements)
        _Branch(element as MethodInvocation),
    ];

/// The source of the list that the function `_observers()` of [unit]
/// returns.
String _observersOf(CompilationUnit unit) {
  final function = unit.declarations
      .whereType<FunctionDeclaration>()
      .singleWhere((function) => function.name.lexeme == '_observers');
  return (function.functionExpression.body as ExpressionFunctionBody)
      .expression
      .toSource();
}

/// Every route of [routes] and below them, parents first, each with the
/// path of its parent.
List<(_GoRoute, String?)> _allOf(List<_GoRoute> routes, [String? parent]) => [
      for (final route in routes) ...[
        (route, parent),
        ..._allOf(route.children, route.name),
      ],
    ];

final class _CallFinder extends RecursiveAstVisitor<void> {
  _CallFinder(this.name);

  final String name;
  final List<MethodInvocation> calls = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null && node.methodName.name == name) calls.add(node);
    super.visitMethodInvocation(node);
  }
}

/// The declaration of the class that `createAppRouter()` creates in [unit].
ClassDeclaration _routerClassOf(CompilationUnit unit) {
  final factory = unit.declarations
      .whereType<FunctionDeclaration>()
      .singleWhere((function) => function.name.lexeme == 'createAppRouter');
  final body = factory.functionExpression.body as ExpressionFunctionBody;
  final created = (body.expression as MethodInvocation).methodName.name;
  return unit.declarations
      .whereType<ClassDeclaration>()
      .singleWhere((declaration) => declaration.name.lexeme == created);
}

/// The source of the body of the method [name] of [declaration].
String _bodyOf(ClassDeclaration declaration, String name) => declaration.members
    .whereType<MethodDeclaration>()
    .singleWhere((method) => method.name.lexeme == name)
    .body
    .toSource();

void main() {
  const module = GoRouterModule();

  group('GoRouterModule', () {
    test('is infrastructure that provides the router', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('go_router'));
      expect(descriptor.kind, ModuleKinds.infrastructure);
      expect(descriptor.provides, {routerRole});
      expect(descriptor.dependsOn, isEmpty);
      expect(descriptor.requires, isEmpty);
      expect(descriptor.uses, isEmpty);
      expect(descriptor.variants, isNull);
    });

    test('forms a valid registry with the modules of the tests', () {
      expect(ModuleRegistry.problemsOf(testModules), isEmpty);
    });
  });

  group('the contract harness', () {
    late List<ContractResult> results;

    setUpAll(() async {
      results = await ContractHarness(ModuleRegistry(testModules)).checkAll();
    });

    test(
        'builds the apps with the router, its features and observers, and '
        'without them', () {
      // The app of go_router and of the router role by go_router is the app
      // of flutter_core with the router, or with the layout too, which
      // requires the router.
      expect(results.map((result) => result.contractCase.name), [
        'flutter_core with router',
        'flutter_core',
        'go_router with layout',
        'catalog',
        'settings',
        'profile',
        'observing with router',
        'observing',
      ]);
    });

    test('finds no errors in any app, rendered code included', () {
      for (final result in results) {
        expect(
          result.errors.map((issue) => '$issue'),
          isEmpty,
          reason: '${result.contractCase}',
        );
        expect(result.app, isNotNull, reason: '${result.contractCase}');
      }
    });

    test('renders apps whose code type-checks', () async {
      for (final result in results) {
        expect(
          await analysisProblems(result.app!),
          isEmpty,
          reason: '${result.contractCase}',
        );
      }
    });
  });

  group('an app without features', () {
    late ContractResult result;
    late RenderedApp withRouter;
    late RenderedApp without;

    setUpAll(() async {
      result = await renderedApp(const [GoRouterModule.id]);
      withRouter = result.app!;
      without = (await renderedApp(const [FlutterCoreModule.id])).app!;
    });

    test('gets go_router and the brick of the router, and nothing else', () {
      final contributions = [
        for (final collected
            in result.collection!.ofModule(module.descriptor.id))
          collected.contribution,
      ];

      expect(contributions, hasLength(2));
      final brick = contributions.first as BrickContribution;
      expect(brick.bundle.name, 'go_router');
      final dependency = contributions.last as PubspecDependency;
      expect(dependency.package, 'go_router');
      expect(dependency.constraint, '^17.5.0');
      expect(dependency.dev, isFalse);
      expect(_pubspecOf(withRouter)['dependencies'], {
        'flutter': {'sdk': 'flutter'},
        'go_router': '^17.5.0',
      });
    });

    test('shows the fallback screen through the router', () {
      final unit = _factoryOf(withRouter);
      final router = _goRouterOf(unit);

      expect(
        (_argument(router, 'initialLocation')! as StringLiteral).stringValue,
        '/',
      );
      final routes = _routesOf(unit);
      expect(routes.map((route) => route.path), ['/']);
      expect(
        routes.single.builder,
        '(context, state) => const FallbackStartScreen()',
      );
      expect(routes.single.redirect, isNull);
      expect(
        withRouter.files[_factory]!.addedImports.map(
          (added) => (added.import.uri, added.import.prefix),
        ),
        [
          (
            'package:contract_app/core/app/fallback_start_screen.dart',
            null,
          ),
        ],
      );
      // No route has values to check, and no module gives an observer.
      expect(withRouter.files[_factory]!.text, isNot(contains('_checkValues')));
      expect(_argument(router, 'observers')!.toSource(), '_observers()');
      expect(
        _observersOf(unit),
        '[for (final create in <NavigatorObserver Function()>[]) create()]',
      );
    });

    test('runs the router of the app in the MaterialApp', () {
      expect(
        withRouter.files['lib/app.dart']!.text,
        allOf(
          contains('MaterialApp.router('),
          contains('routerConfig: appRouter.config,'),
          isNot(contains('home:')),
        ),
      );
    });

    test('is the app without a router but for the router', () {
      const routerFiles = {
        RouterRole.appRouterFile,
        RouterRole.navigationFile,
        RouterRole.appRouterFactoryFile,
      };
      expect(
        withRouter.files.keys.toSet(),
        {...without.files.keys, ...routerFiles},
      );
      expect(
        withRouter.files[_factory]!.owner,
        const ModuleOrigin(GoRouterModule.id),
      );
      for (final MapEntry(key: path, value: file) in without.files.entries) {
        if (const {'pubspec.yaml', 'lib/app.dart'}.contains(path)) continue;
        expect(withRouter.files[path]!.bytes, file.bytes, reason: path);
      }
      final pubspec = _pubspecOf(withRouter);
      final dependencies = {
        ...pubspec['dependencies']! as Map<String, Object?>,
      }..remove('go_router');
      expect({...pubspec, 'dependencies': dependencies}, _pubspecOf(without));
    });
  });

  group('an app with features', () {
    late ContractResult result;
    late RenderedApp app;
    late CompilationUnit unit;
    late Map<String, _GoRoute> routes;

    setUpAll(() async {
      result = await renderedApp(const [
        CatalogFeature.id,
        SettingsFeature.id,
        ObservingModule.id,
      ]);
      app = result.app!;
      unit = _factoryOf(app);
      routes = {
        for (final (route, _) in _allOf(_routesOf(unit)))
          if (route.name case final name?) name: route,
      };
    });

    test('opens on the start route, which / redirects to', () {
      expect(
        (_argument(_goRouterOf(unit), 'initialLocation')! as StringLiteral)
            .stringValue,
        '/catalog',
      );
      final root = _routesOf(unit).first;
      expect(root.path, '/');
      expect(root.name, isNull);
      expect(root.redirect, "(context, state) => '/catalog'");
      expect(root.builder, isNull);
    });

    test(
        'has a route for every route of the facade, named by its full name, '
        'with its children below it', () {
      final facade = routerRole.facadeOf(
        routerRole.hookInput(
          RoleHookRequest(
            data: result.collection!.roleData,
            presentRoles: result.resolution!.presentRoles,
            context: ContractHarness.defaultContext,
          ),
        ),
      );
      final parents = {
        for (final (route, parent) in _allOf(_routesOf(unit)))
          if (route.name case final name?) name: parent,
      };

      expect(
        parents.keys,
        [for (final route in facade.routes) route.fullName],
      );
      for (final route in facade.routes) {
        final goRoute = routes[route.fullName]!;
        expect(parents[route.fullName], route.parent?.fullName);
        expect(
          goRoute.path,
          route.parent == null ? route.fullPath : route.route.path,
          reason: route.fullName,
        );
      }
      expect(routes.keys, containsAll(['catalog.review', 'settings.settings']));
    });

    test('imports each file of screens once, with a prefix of its own', () {
      final screens = {
        for (final added in app.files[_factory]!.addedImports)
          if (added.import.uri.contains('/features/'))
            added.import.uri: added.import.prefix,
      };

      expect(screens, {
        'package:contract_app/features/catalog/catalog_screen.dart': 'screen0',
        'package:contract_app/features/catalog/item_screen.dart': 'screen1',
        'package:contract_app/features/catalog/review_screen.dart': 'screen2',
        'package:contract_app/features/catalog/more_screens.dart': 'screen3',
        'package:contract_app/features/settings/settings_screen.dart':
            'screen4',
        'package:contract_app/features/settings/about_screen.dart': 'screen5',
      });
      expect(
        {
          for (final added in app.files[_factory]!.addedImports)
            added.import.uri: '${added.contributor}',
        },
        {
          for (final screen in screens.keys) screen: 'go_router',
          // The factory of the observer comes with its import.
          'package:contract_app/core/observing/test_observer.dart': 'observing',
        },
      );
      expect(routes['catalog.tag']!.builder, contains('screen3.TagScreen('));
      expect(
        routes['settings.settings']!.builder,
        '(context, state) => const screen4.SettingsScreen()',
      );
    });

    test(
        'passes optional int, double and bool query parameters as nullable '
        'values', () {
      // A value that the location does not have, or that is not of its
      // type, is null.
      expect(routes['catalog.catalog']!.screenArguments, {
        'page': "int.tryParse(state.uri.queryParameters['page'] ?? '')",
        'minPrice':
            "double.tryParse(state.uri.queryParameters['minPrice'] ?? '')",
        'onSale': "bool.tryParse(state.uri.queryParameters['onSale'] ?? '')",
        'search': "state.uri.queryParameters['search']",
      });
      expect(routes['catalog.catalog']!.redirect, isNull);
    });

    test('checks the required values of a location before the screen', () {
      expect(
        routes['catalog.compare']!.redirect,
        [
          '(context, state) => _checkValues({',
          "'left' : int.tryParse(state.uri.queryParameters['left'] ?? ''), ",
          "'right' : int.tryParse(state.uri.queryParameters['right'] ?? '')})",
        ].join(),
      );
      expect(routes['catalog.compare']!.screenArguments, {
        'left': "int.tryParse(state.uri.queryParameters['left'] ?? '')!",
        'right': "int.tryParse(state.uri.queryParameters['right'] ?? '')!",
      });
      expect(routes['catalog.price']!.screenArguments, {
        'amount': "double.tryParse(state.pathParameters['amount'] ?? '')!",
        'exact': "bool.tryParse(state.pathParameters['exact'] ?? '')!",
      });
      expect(routes['catalog.price']!.redirect, contains("'amount' :"));
      expect(routes['catalog.price']!.redirect, contains("'exact' :"));
      // A path always has its String parameters.
      expect(routes['catalog.tag']!.redirect, isNull);
      expect(routes['catalog.tag']!.screenArguments, {
        'tag': "state.pathParameters['tag']!",
      });

      // A query may leave out a String too.
      expect(
        routes['catalog.search']!.redirect,
        "(context, state) => _checkValues({'q' : "
        "state.uri.queryParameters['q']})",
      );
      expect(routes['catalog.search']!.screenArguments, {
        'q': "state.uri.queryParameters['q']!",
      });

      final checks = unit.declarations
          .whereType<FunctionDeclaration>()
          .singleWhere((function) => function.name.lexeme == '_checkValues');
      expect(checks.toSource(), _expectedCheckValues);
    });

    test('reads a path parameter of the parent from the path', () {
      // The redirect of the parent checks it, since go_router runs the
      // redirect of every route that matches the location.
      expect(routes['catalog.item']!.redirect, contains("'id' :"));
      expect(routes['catalog.review']!.redirect, isNull);
      expect(routes['catalog.review']!.screenArguments, {
        'id': "int.tryParse(state.pathParameters['id'] ?? '')!",
        'reviewId': "state.pathParameters['reviewId']!",
      });
      expect(routes['catalog.item']!.screenArguments, {
        'id': "int.tryParse(state.pathParameters['id'] ?? '')!",
        'variant': "state.uri.queryParameters['variant']",
      });
    });

    test('creates the observers of the router role for its navigator', () {
      final observers = _argument(_goRouterOf(unit), 'observers')!;

      // Every call creates instances of its own.
      expect(observers.toSource(), '_observers()');
      expect(
        _observersOf(unit),
        '[for (final create in <NavigatorObserver Function()>[() => '
        'TestObserver()]) create()]',
      );
    });

    test('has no main navigation without a layout', () {
      expect(_shellOf(unit), isNull);
      expect(
        app.files[_factory]!.addedImports.map((added) => added.import.uri),
        isNot(contains(contains('/core/layout/'))),
      );
    });

    test('navigates through the router it created once, whatever the context',
        () {
      final router = _routerClassOf(unit);

      expect(router.name.lexeme, isNot('AppRouter'));
      final config = router.members.whereType<FieldDeclaration>().singleWhere(
            (field) => field.fields.variables.single.name.lexeme == 'config',
          );
      expect(config.fields.isLate, isTrue);
      expect(config.fields.isFinal, isTrue);
      expect(_bodyOf(router, 'navigatorOf'), '=> this;');
      expect(_bodyOf(router, 'go'), '=> config.go(location.path);');
      // Without a main navigation, nothing to check first.
      expect(
        _bodyOf(router, 'push'),
        '{return config.push<T>(location.path);}',
      );
      expect(
        _bodyOf(router, 'replace'),
        '{config.pushReplacement<Object?>(location.path);}',
      );
      expect(app.files[_factory]!.text, isNot(contains('GoRouter.of(')));
      expect(
        app.files[_factory]!.text,
        isNot(contains('_checkMainNavigation')),
      );
    });
  });

  group('an app with a layout', () {
    late ContractResult result;
    late RenderedApp app;
    late CompilationUnit unit;
    late MethodInvocation shell;

    setUpAll(() async {
      result = await renderedApp(const [
        CatalogFeature.id,
        SettingsFeature.id,
        ObservingModule.id,
        TabsLayout.id,
      ]);
      app = result.app!;
      unit = _factoryOf(app);
      shell = _shellOf(unit)!;
    });

    test(
        'puts the destinations into a shell of branches right after /, and '
        'the other routes after it', () {
      final topLevel = _topLevelOf(unit);

      expect(topLevel.first.methodName.name, 'GoRoute');
      expect(topLevel[1], shell);
      expect(
        [for (final route in _routesOf(unit)) route.path],
        [
          '/',
          '/catalog/compare',
          '/catalog/prices/:amount/:exact',
          '/catalog/tags/:tag',
          '/catalog/search',
        ],
      );
      // The route that the router matches first is in the shell.
      expect(
        _routesOf(unit).first.redirect,
        "(context, state) => '/catalog'",
      );
    });

    test('has a branch for each destination, with the routes below it', () {
      final branches = _branchesOf(shell);

      expect(
        [for (final branch in branches) branch.initialLocation],
        ['/catalog', '/settings'],
      );
      final catalog = branches[0].routes.single;
      expect(catalog.path, '/catalog');
      expect(catalog.name, 'catalog.catalog');
      expect(
        [
          for (final (route, parent) in _allOf([catalog]))
            '$parent > ${route.name} (${route.path})',
        ],
        [
          'null > catalog.catalog (/catalog)',
          'catalog.catalog > catalog.item (items/:id)',
          'catalog.item > catalog.review (reviews/:reviewId)',
        ],
      );
      final settings = branches[1].routes.single;
      expect(settings.path, '/settings');
      expect(
        [for (final child in settings.children) child.name],
        ['settings.about'],
      );
    });

    test('shows the shell of the layout with the destinations as constants',
        () {
      expect(
        _argument(shell, 'builder')!.toSource(),
        '(context, state, shell) => AppShell(destinations: const '
        "[Destination(label: 'Catalog', icon: Icons.list), "
        "Destination(label: 'Settings', icon: Icons.settings)], "
        'currentIndex: shell.currentIndex, onSelect: shell.goBranch, body: '
        'shell)',
      );
      expect(
        {
          for (final added in app.files[_factory]!.addedImports)
            if (!added.import.uri.contains('/features/'))
              added.import.uri: 'show ${added.import.show.join(', ')} for '
                  '${added.contributor}',
        },
        {
          'package:contract_app/core/layout/app_shell.dart':
              'show AppShell for go_router',
          'package:contract_app/core/layout/destination.dart':
              'show Destination for go_router',
          'package:flutter/material.dart': 'show Icons for go_router',
          'package:contract_app/core/observing/test_observer.dart':
              'show  for observing',
        },
      );
    });

    test(
        'gives each navigator observers of its own, and the root navigator '
        'none of the branches', () {
      expect(_argument(shell, 'notifyRootObserver')!.toSource(), 'false');
      expect(
        [for (final branch in _branchesOf(shell)) branch.observers],
        ['_observers()', '_observers()'],
      );
      expect(
        _argument(_goRouterOf(unit), 'observers')!.toSource(),
        '_observers()',
      );
      expect(
        _observersOf(unit),
        '[for (final create in <NavigatorObserver Function()>[() => '
        'TestObserver()]) create()]',
      );
    });

    test(
        'lets push() and replace() show a location of the main navigation '
        'only on top of it', () {
      final router = _routerClassOf(unit);

      expect(
        _bodyOf(router, 'push'),
        "{_checkMainNavigation(location, 'push'); return "
        'config.push<T>(location.path);}',
      );
      expect(
        _bodyOf(router, 'replace'),
        "{_checkMainNavigation(location, 'replace'); "
        'config.pushReplacement<Object?>(location.path);}',
      );
      expect(
        router.members
            .whereType<MethodDeclaration>()
            .singleWhere(
              (method) => method.name.lexeme == '_checkMainNavigation',
            )
            .toSource(),
        _expectedCheckMainNavigation,
      );
    });

    test('renders code that type-checks', () async {
      expect(await analysisProblems(app), isEmpty);
    });

    test('orders the branches as the features were asked for', () async {
      final result = await renderedApp(
        const [
          SettingsFeature.id,
          ProfileFeature.id,
          CatalogFeature.id,
          TabsLayout.id,
        ],
        roleOptions: {RouterRole.startOption.name: '/catalog'},
      );
      final shell = _shellOf(_factoryOf(result.app!))!;

      expect(
        [for (final branch in _branchesOf(shell)) branch.initialLocation],
        ['/settings', '/profile', '/catalog'],
      );
      expect(
        _argument(shell, 'builder')!.toSource(),
        contains(
          "[Destination(label: 'Settings', icon: Icons.settings), "
          "Destination(label: 'Profile', icon: Icons.person), "
          "Destination(label: 'Catalog', icon: Icons.list)]",
        ),
      );
    });

    test('starts on the branch of the start route, which --start chooses',
        () async {
      // Two routes can start the app, so the choice needs --start, or an
      // answer to the question of the router.
      const modules = [
        CatalogFeature.id,
        SettingsFeature.id,
        ProfileFeature.id,
        TabsLayout.id,
      ];
      final answered = await renderedApp(modules);
      expect(answered.answers, {RouterRole.startOption.name: '/catalog'});
      expect(
        (_argument(_goRouterOf(_factoryOf(answered.app!)), 'initialLocation')!
                as StringLiteral)
            .stringValue,
        '/catalog',
      );

      final result = await renderedApp(
        modules,
        roleOptions: {RouterRole.startOption.name: '/profile'},
      );
      final unit = _factoryOf(result.app!);
      final shell = _shellOf(unit)!;

      expect(
        (_argument(_goRouterOf(unit), 'initialLocation')! as StringLiteral)
            .stringValue,
        '/profile',
      );
      expect(
        _routesOf(unit).first.redirect,
        "(context, state) => '/profile'",
      );
      // The third branch, whose destination is the start route.
      final branches = _branchesOf(shell);
      expect(branches[2].initialLocation, '/profile');
      expect(branches[2].routes.single.name, 'profile.profile');
      expect(await analysisProblems(result.app!), isEmpty);
    });

    test('has no shell without destinations', () async {
      final result = await renderedApp(const [TabsLayout.id]);
      final unit = _factoryOf(result.app!);

      expect(_shellOf(unit), isNull);
      expect(_routesOf(unit).map((route) => route.path), ['/']);
      expect(
        result.app!.files[_factory]!.addedImports.map(
          (added) => added.import.uri,
        ),
        isNot(contains(contains('/core/layout/'))),
      );
    });
  });

  group('the start of an app', () {
    test('is the fallback screen when no route can start the app', () async {
      final result = await renderedApp(const [SettingsFeature.id]);
      final unit = _factoryOf(result.app!);

      final routes = _routesOf(unit);
      expect(routes.map((route) => route.path), ['/', '/settings']);
      expect(
        routes.first.builder,
        '(context, state) => const FallbackStartScreen()',
      );
    });

    test('can be a child route that --start names', () async {
      final result = await renderedApp(
        const [SettingsFeature.id],
        roleOptions: {RouterRole.startOption.name: '/settings/about'},
      );
      final unit = _factoryOf(result.app!);

      expect(
        (_argument(_goRouterOf(unit), 'initialLocation')! as StringLiteral)
            .stringValue,
        '/settings/about',
      );
      expect(
        _routesOf(unit).first.redirect,
        "(context, state) => '/settings/about'",
      );
      // go_router shows the chain of parents of the child.
      final settings = _routesOf(unit)[1];
      expect(settings.path, '/settings');
      expect(settings.children.single.path, 'about');
    });

    test('is the route that --start names', () async {
      final result = await renderedApp(
        const [CatalogFeature.id, SettingsFeature.id],
        roleOptions: {RouterRole.startOption.name: '/settings'},
      );
      final unit = _factoryOf(result.app!);

      expect(
        (_argument(_goRouterOf(unit), 'initialLocation')! as StringLiteral)
            .stringValue,
        '/settings',
      );
      expect(
        _routesOf(unit).first.redirect,
        "(context, state) => '/settings'",
      );
    });
  });
}
