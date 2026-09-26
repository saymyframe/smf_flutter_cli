import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:smf_contracts/lego.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_home_flutter/smf_home_flutter.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

/// The modules of the tests: flutter_core, which creates the app, go_router,
/// which routes it, and this one.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  GoRouterModule(),
  HomeModule(),
];

/// The path of the screen of the module in the app.
const _screen = 'lib/features/home/home_screen.dart';

/// The path of the file of `createAppRouter()`.
const String _factory = RouterRole.appRouterFactoryFile;

/// The annotation that [_Annotating] gives the class of the screen.
const String _annotation = "@Deprecated('An annotation of the tests')";

/// A module that annotates the class of the screen of home through the
/// router role, as a router whose screens need annotations would.
final class _Annotating extends SmfModule {
  const _Annotating();

  static const id = ModuleId('annotating');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Annotates the screen of home (test)',
        kind: ModuleKinds.infrastructure,
        uses: {routerRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        SocketContribution.code(
          RouterRole.screenAnnotations(
            (feature: HomeModule.id, screen: 'HomeScreen'),
          ),
          const Fragment(_annotation),
          when: const {routerRole},
        ),
      ];
}

/// What the contract harness finds for the app of [modules] among
/// [registry] and in [context], which has no errors and is rendered.
Future<ContractResult> _rendered(
  List<ModuleId> modules, {
  List<SmfModule> registry = _modules,
  ModuleContext context = ContractHarness.defaultContext,
}) async {
  final result = await ContractHarness(
    ModuleRegistry(registry),
    context: context,
  ).check(ContractCase(modules.join(', '), requested: modules));
  if (result.errors.isNotEmpty || result.app == null) {
    throw StateError(
      'The app of $modules has errors: ${result.errors.join('\n')}',
    );
  }
  return result;
}

/// The parsed file [path] of [app].
CompilationUnit _parsed(RenderedApp app, String path) =>
    parseString(content: app.files[path]!.text).unit;

/// The class [name] of [unit].
ClassDeclaration _classOf(CompilationUnit unit, String name) =>
    unit.declarations
        .whereType<ClassDeclaration>()
        .singleWhere((declaration) => declaration.name.lexeme == name);

/// The expression that the getter or the method [name] of [declaration]
/// returns.
Expression _returnedBy(ClassDeclaration declaration, String name) {
  final member = declaration.members
      .whereType<MethodDeclaration>()
      .singleWhere((method) => method.name.lexeme == name);
  return (member.body as ExpressionFunctionBody).expression;
}

/// The named argument [label] of [call], or `null`.
Expression? _argument(MethodInvocation call, String label) => [
      for (final argument in call.argumentList.arguments)
        if (argument case NamedExpression(:final name, :final expression)
            when name.label.name == label)
          expression,
    ].firstOrNull;

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

/// The calls of the function or constructor [name] in [unit].
List<MethodInvocation> _callsOf(CompilationUnit unit, String name) {
  final finder = _CallFinder(name);
  unit.accept(finder);
  return finder.calls;
}

/// The value of the string literal [expression].
String? _string(Expression? expression) =>
    (expression as StringLiteral?)?.stringValue;

void main() {
  const module = HomeModule();

  group('HomeModule', () {
    test('is a feature without variants, which requires the router', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('home'));
      expect(descriptor.kind, ModuleKinds.feature);
      expect(descriptor.provides, isEmpty);
      // The kind makes a feature require the router.
      expect(descriptor.requires, isEmpty);
      expect(descriptor.effectiveRequires, {routerRole});
      expect(descriptor.uses, isEmpty);
      expect(descriptor.dependsOn, isEmpty);
      expect(descriptor.variants, isNull);
    });

    test('forms a valid registry with the modules of the tests', () {
      expect(ModuleRegistry.problemsOf(_modules), isEmpty);
    });

    test(
        'declares one route: the start screen at / of the module, with the '
        'destination Home', () {
      final data = [
        for (final contribution
            in module.contribute(ContractHarness.defaultContext))
          if (contribution is RoleData<RoutesData>) contribution,
      ].single;

      expect(data.role, routerRole);
      final route = data.value.routes.single;
      expect(route.path, '/');
      expect(route.name, 'home');
      expect(route.screen.className, 'HomeScreen');
      expect(route.screen.file, _screen);
      expect(route.params, isEmpty);
      expect(route.children, isEmpty);
      expect(route.startCandidate, isTrue);
      final destination = route.destination!;
      expect(destination.label, 'Home');
      // A constant, so that the main navigation can be one.
      expect(destination.icon.code, 'Icons.home');
      final import = destination.icon.imports.single;
      expect(import.uri, 'package:flutter/material.dart');
      expect(import.prefix, isNull);
      expect(import.show, ['Icons']);
    });
  });

  group('the contract harness', () {
    late List<ContractResult> results;

    setUpAll(() async {
      results = await ContractHarness(ModuleRegistry(_modules)).checkAll();
    });

    test('builds the apps with and without home', () {
      expect(results.map((result) => result.contractCase.name), [
        'flutter_core with router',
        'flutter_core',
        'home',
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
  });

  group('the app with home', () {
    late ContractResult result;
    late RenderedApp app;
    late RenderedApp withRouter;

    setUpAll(() async {
      result = await _rendered(const [HomeModule.id]);
      app = result.app!;
      withRouter = (await _rendered(const [GoRouterModule.id])).app!;
    });

    test('gets the only router, which home requires', () {
      expect(
        {
          for (final module in result.resolution!.modules)
            '${module.id}': '${module.reason}',
        },
        {
          'home': 'requested',
          'flutter_core': 'the only provider of the app_entry (every app '
              'needs the app_entry)',
          'go_router': 'the only provider of the router (home requires the '
              'router)',
        },
      );
    });

    test('gets the brick of the screen and the route, and nothing else', () {
      final contributions = [
        for (final collected in result.collection!.ofModule(HomeModule.id))
          collected.contribution,
      ];

      expect(contributions, hasLength(2));
      final brick = contributions.first as BrickContribution;
      expect(brick.bundle.name, 'home');
      expect(brick.bundle.files.map((file) => file.path), [_screen]);
      expect(brick.vars, isEmpty);
      expect(
        (contributions.last as RoleData<RoutesData>).value.routes.single.name,
        'home',
      );
    });

    test('is the app with the router but for the screen and its route', () {
      const routeFiles = {_factory, RouterRole.navigationFile};

      expect(app.files.keys.toSet(), {...withRouter.files.keys, _screen});
      expect(app.files[_screen]!.owner, const ModuleOrigin(HomeModule.id));
      // The pubspec too: home adds no dependency.
      for (final MapEntry(key: path, value: file) in withRouter.files.entries) {
        if (routeFiles.contains(path)) continue;
        expect(app.files[path]!.bytes, file.bytes, reason: path);
      }
    });

    test('opens on the screen of home at /home, which / redirects to', () {
      final unit = _parsed(app, _factory);
      final router = _callsOf(unit, 'GoRouter').single;

      expect(_string(_argument(router, 'initialLocation')), '/home');
      final routes = _callsOf(unit, 'GoRoute');
      expect(routes, hasLength(2));
      final [root, home] = routes;
      expect(_string(_argument(root, 'path')), '/');
      expect(
        _argument(root, 'redirect')!.toSource(),
        "(context, state) => '/home'",
      );
      expect(_argument(root, 'builder'), isNull);
      expect(_string(_argument(home, 'path')), '/home');
      expect(_string(_argument(home, 'name')), 'home.home');
      expect(
        _argument(home, 'builder')!.toSource(),
        '(context, state) => const screen0.HomeScreen()',
      );
      expect(_argument(home, 'redirect'), isNull);
      expect(
        app.files[_factory]!.addedImports.map(
          (added) => (added.import.uri, added.import.prefix, added.contributor),
        ),
        [
          (
            'package:contract_app/features/home/home_screen.dart',
            'screen0',
            const ModuleOrigin(GoRouterModule.id),
          ),
        ],
      );
    });

    test('offers the route to the navigation of the app', () {
      final unit = _parsed(app, RouterRole.navigationFile);
      final location = _classOf(unit, 'HomeHomeLocation');

      expect(location.extendsClause!.superclass.name.lexeme, 'AppLocation');
      expect(_string(_returnedBy(location, 'routeName')), 'home.home');
      expect(_string(_returnedBy(location, 'path')), '/home');
      expect(
        _returnedBy(_classOf(unit, 'HomeRoutes'), 'home').toSource(),
        'NavLink(_context, const HomeHomeLocation())',
      );
      expect(
        _returnedBy(_classOf(unit, 'AppNav'), 'home').toSource(),
        'HomeRoutes._(_context)',
      );
    });

    test(
        'shows the name of the app in the app bar of a screen without a '
        'body', () {
      final text = app.files[_screen]!.text;
      final unit = parseString(content: text).unit;
      final screen = _classOf(unit, 'HomeScreen');

      expect(text, isNot(contains('{{')));
      expect(
        unit.directives.map((directive) => directive.toSource()),
        ["import 'package:flutter/material.dart';"],
      );
      expect(unit.declarations, [screen]);
      expect(screen.extendsClause!.superclass.name.lexeme, 'StatelessWidget');
      expect(screen.metadata, isEmpty);
      final constructor =
          screen.members.whereType<ConstructorDeclaration>().single;
      expect(constructor.name, isNull);
      expect(constructor.constKeyword, isNotNull);
      expect(constructor.parameters.toSource(), '({super.key})');
      expect(
        _returnedBy(screen, 'build').toSource(),
        "Scaffold(appBar: AppBar(title: const Text('Contract App')))",
      );
    });
  });

  test('names the app in the app bar as the context names it', () async {
    final result = await _rendered(
      const [HomeModule.id],
      context: const ModuleContext(
        appName: 'bird_watch',
        orgName: 'org.example',
        appIdentity: AppIdentity(
          androidApplicationId: 'org.example.bird_watch',
          iosBundleId: 'org.example.bird-watch',
          androidNamespace: 'org.example.bird_watch',
        ),
      ),
    );
    final screen = _classOf(_parsed(result.app!, _screen), 'HomeScreen');

    expect(
      _returnedBy(screen, 'build').toSource(),
      "Scaffold(appBar: AppBar(title: const Text('Bird Watch')))",
    );
  });

  test('keeps the annotations of the router role on the class of the screen',
      () async {
    final result = await _rendered(
      const [HomeModule.id, _Annotating.id],
      registry: const [..._modules, _Annotating()],
    );
    final screen = _classOf(_parsed(result.app!, _screen), 'HomeScreen');

    expect(
      screen.metadata.map((annotation) => annotation.toSource()),
      [_annotation],
    );
    expect(
      screen.documentationComment!.tokens.single.lexeme,
      '/// The screen the app starts on, with the name of the app.',
    );
  });
}
