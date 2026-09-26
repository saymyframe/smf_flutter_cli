import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:smf_bottom_tabs/smf_bottom_tabs.dart';
import 'package:smf_contracts/lego.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

import 'support/features.dart';

/// The features of the tests, whose destinations are Inbox, the start
/// screen, and Search.
const _inbox = TabFeature('inbox', startCandidate: true);
const _search = TabFeature('search');

/// The modules of the tests: flutter_core, which creates the app, go_router,
/// which builds its main navigation, this module and two features.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  GoRouterModule(),
  BottomTabsModule(),
  _inbox,
  _search,
];

/// Four more features with destinations, which make six with [_modules].
const List<SmfModule> _more = [
  TabFeature('people'),
  TabFeature('settings'),
  TabFeature('help'),
  TabFeature('info'),
];

/// The path of the file of `AppShell`.
const String _shell = LayoutRole.appShellFile;

/// The path of the file of `createAppRouter()`.
const String _factory = RouterRole.appRouterFactoryFile;

/// What the contract harness finds for the app of [modules] among
/// [registry].
Future<ContractResult> _check(
  List<ModuleId> modules, {
  List<SmfModule> registry = _modules,
}) =>
    ContractHarness(ModuleRegistry(registry)).check(
      ContractCase(modules.join(', '), requested: modules),
    );

/// What the contract harness finds for the app of [modules] among
/// [registry], which has no errors and is rendered.
Future<ContractResult> _rendered(
  List<ModuleId> modules, {
  List<SmfModule> registry = _modules,
}) async {
  final result = await _check(modules, registry: registry);
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

/// The named argument [label] of [arguments], or `null`.
Expression? _argument(ArgumentList arguments, String label) => [
      for (final argument in arguments.arguments)
        if (argument case NamedExpression(:final name, :final expression)
            when name.label.name == label)
          expression,
    ].firstOrNull;

/// The names of the named arguments of [arguments].
List<String> _argumentNames(ArgumentList arguments) => [
      for (final argument in arguments.arguments)
        if (argument case NamedExpression(:final name)) name.label.name,
    ];

/// The arguments of the calls of the function or constructor [name] in
/// [unit], without a target, as the parser reads them.
List<ArgumentList> _callsOf(CompilationUnit unit, String name) {
  final finder = _CallFinder(name);
  unit.accept(finder);
  return finder.calls;
}

final class _CallFinder extends RecursiveAstVisitor<void> {
  _CallFinder(this.name);

  final String name;
  final List<ArgumentList> calls = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null && node.methodName.name == name) {
      calls.add(node.argumentList);
    }
    super.visitMethodInvocation(node);
  }
}

/// The labels of the destinations that the router of [app] gives the shell.
List<String> _labelsOf(RenderedApp app) {
  final shell = _callsOf(_parsed(app, _factory), 'AppShell').single;
  final destinations = _argument(shell, 'destinations')! as ListLiteral;
  return [
    for (final element in destinations.elements)
      (_argument((element as MethodInvocation).argumentList, 'label')!
              as StringLiteral)
          .stringValue!,
  ];
}

void main() {
  const module = BottomTabsModule();

  group('BottomTabsModule', () {
    test('is a layout, which requires the router', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('bottom_tabs'));
      expect(descriptor.kind, ModuleKinds.layout);
      expect(descriptor.provides, {layoutRole});
      // The layout role requires the router.
      expect(descriptor.requires, isEmpty);
      expect(descriptor.effectiveRequires, {routerRole});
      expect(descriptor.uses, isEmpty);
      expect(descriptor.dependsOn, isEmpty);
      expect(descriptor.variants, isNull);
    });

    test('forms a valid registry with the modules of the tests', () {
      expect(ModuleRegistry.problemsOf([..._modules, ..._more]), isEmpty);
    });
  });

  group('the contract harness', () {
    late List<ContractResult> results;

    setUpAll(() async {
      results = await ContractHarness(ModuleRegistry(_modules)).checkAll();
    });

    test('builds the apps with and without the layout', () {
      // The app of this module is the app of go_router with the layout.
      expect(results.map((result) => result.contractCase.name), [
        'flutter_core with router',
        'flutter_core',
        'go_router with layout',
        'inbox',
        'search',
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

  group('the app with bottom tabs', () {
    late ContractResult result;
    late RenderedApp app;
    late RenderedApp without;

    setUpAll(() async {
      result = await _rendered([_inbox.id, _search.id, BottomTabsModule.id]);
      app = result.app!;
      without = (await _rendered([_inbox.id, _search.id])).app!;
    });

    test('gets the only router, which the layout requires', () async {
      final result = await _rendered(const [BottomTabsModule.id]);

      expect(
        {
          for (final module in result.resolution!.modules)
            '${module.id}': '${module.reason}',
        },
        {
          'bottom_tabs': 'requested',
          'flutter_core': 'the only provider of the app_entry (every app '
              'needs the app_entry)',
          'go_router': 'the only provider of the router (bottom_tabs '
              'requires the router)',
        },
      );
    });

    test('gets the brick of the shell, and nothing else', () {
      final contributions = [
        for (final collected
            in result.collection!.ofModule(BottomTabsModule.id))
          collected.contribution,
      ];

      final brick = contributions.single as BrickContribution;
      expect(brick.bundle.name, 'bottom_tabs');
      expect(brick.bundle.files.map((file) => file.path), [_shell]);
      expect(brick.vars, isEmpty);
    });

    test(
        'is the app without it but for the shell, the destinations and the '
        'router', () {
      expect(
        app.files.keys.toSet(),
        {...without.files.keys, _shell, LayoutRole.destinationFile},
      );
      expect(
        app.files[_shell]!.owner,
        const ModuleOrigin(BottomTabsModule.id),
      );
      expect(
        app.files[LayoutRole.destinationFile]!.owner,
        const RoleTemplateOrigin(layoutRole),
      );
      // The pubspec too: the shell needs nothing but Flutter.
      for (final MapEntry(key: path, value: file) in without.files.entries) {
        if (path == _factory) continue;
        expect(app.files[path]!.bytes, file.bytes, reason: path);
      }
      expect(
        app.files[_factory]!.text,
        isNot(without.files[_factory]!.text),
      );
    });

    test(
        'shows a bar with a tab for each destination below the screen of the '
        'selected one', () {
      final unit = _parsed(app, _shell);
      final shell = unit.declarations
          .whereType<ClassDeclaration>()
          .singleWhere((declaration) => declaration.name.lexeme == 'AppShell');

      expect(
        unit.directives.map((directive) => directive.toSource()),
        [
          "import 'package:flutter/material.dart';",
          "import 'destination.dart';",
        ],
      );
      expect(unit.declarations, [shell]);
      expect(shell.extendsClause!.superclass.name.lexeme, 'StatelessWidget');
      final constructor =
          shell.members.whereType<ConstructorDeclaration>().single;
      expect(constructor.name, isNull);
      expect(constructor.constKeyword, isNotNull);
      expect(
        constructor.parameters.toSource(),
        '({required this.destinations, required this.currentIndex, '
        'required this.onSelect, required this.body, super.key})',
      );
      expect(
        {
          for (final field in shell.members.whereType<FieldDeclaration>())
            field.fields.variables.single.name.lexeme:
                field.fields.type!.toSource(),
        },
        {
          'destinations': 'List<Destination>',
          'currentIndex': 'int',
          'onSelect': 'ValueChanged<int>',
          'body': 'Widget',
        },
      );
      final build = shell.members
          .whereType<MethodDeclaration>()
          .singleWhere((method) => method.name.lexeme == 'build');
      expect(
        (build.body as ExpressionFunctionBody).expression.toSource(),
        'Scaffold(body: body, bottomNavigationBar: destinations.length < 2 ? '
        'null : NavigationBar(selectedIndex: currentIndex, '
        'onDestinationSelected: onSelect, destinations: [for (final '
        'destination in destinations) NavigationDestination(icon: '
        'Icon(destination.icon), label: destination.label)]))',
      );
    });

    test(
        'is built by the router with the destinations of the features, in '
        'their order', () async {
      final shell = _callsOf(_parsed(app, _factory), 'AppShell').single;

      expect(
        _argumentNames(shell),
        ['destinations', 'currentIndex', 'onSelect', 'body'],
      );
      expect(_labelsOf(app), ['Inbox', 'Search']);

      final reversed =
          (await _rendered([_search.id, _inbox.id, BottomTabsModule.id])).app!;
      expect(_labelsOf(reversed), ['Search', 'Inbox']);
    });

    test('is built with one destination too, whose bar the shell hides',
        () async {
      final app = (await _rendered([_inbox.id, BottomTabsModule.id])).app!;

      expect(_labelsOf(app), ['Inbox']);
    });

    test('has no shell to show without destinations', () async {
      final app = (await _rendered(const [BottomTabsModule.id])).app!;

      expect(app.files.keys, contains(_shell));
      expect(_callsOf(_parsed(app, _factory), 'AppShell'), isEmpty);
    });
  });

  group('the number of destinations', () {
    const registry = [..._modules, ..._more];

    test('can be five', () async {
      final result = await _rendered(
        [
          _inbox.id,
          _search.id,
          for (final feature in _more.take(3)) feature.descriptor.id,
          BottomTabsModule.id,
        ],
        registry: registry,
      );

      expect(
        _labelsOf(result.app!),
        ['Inbox', 'Search', 'People', 'Settings', 'Help'],
      );
    });

    test('cannot be more than five', () async {
      final result = await _check(
        [
          _inbox.id,
          _search.id,
          for (final feature in _more) feature.descriptor.id,
          BottomTabsModule.id,
        ],
        registry: registry,
      );

      final error = result.errors.single;
      expect(
        error.message,
        'The layout can show 5 destinations, but the app has 6: /inbox, '
        '/search, /people, /settings, /help, /info.',
      );
      expect(
        error.hint,
        'Leave out a feature, or remove the destination of a route.',
      );
      // The feature whose destination is the first too many.
      expect(error.origin, const ModuleOrigin(ModuleId('info')));
      expect(result.app, isNull);
    });
  });
}
