import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_bottom_tabs/smf_bottom_tabs.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:smf_settings/smf_settings.dart';
import 'package:test/test.dart';

import 'support/settings.dart';

/// A feature of the tests with a setting, and a library with two.
const _feed = SettingsFeature('feed', settings: ['FeedSetting']);
const _look = SettingsInfrastructure(
  'look',
  settings: ['ThemeSetting', 'FontSetting'],
);

/// The modules of the tests: flutter_core, which creates the app, go_router,
/// which routes it, bottom tabs, whose main navigation shows its
/// destinations, this module, and the contributors of settings: a feature,
/// a library, and the provider of a role whose template has a setting.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  GoRouterModule(),
  BottomTabsModule(),
  _feed,
  SettingsModule(),
  _look,
  ZoomModule(),
];

/// The path of the screen of the module in the app.
const _screen = 'lib/features/settings/settings_screen.dart';

/// The annotation that [_Annotating] gives the class of the screen.
const String _annotation = "@Deprecated('An annotation of the tests')";

/// A module that annotates the class of the screen of the module through
/// the router role, as a router whose screens need annotations would.
final class _Annotating extends SmfModule {
  const _Annotating();

  static const id = ModuleId('annotating');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Annotates the settings screen (test)',
        kind: ModuleKinds.infrastructure,
        uses: {routerRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        SocketContribution.code(
          RouterRole.screenAnnotations(
            (feature: SettingsModule.id, screen: 'SettingsScreen'),
          ),
          const Fragment(_annotation),
          when: const {routerRole},
        ),
      ];
}

/// What the contract harness finds for the app of [modules] among
/// [registry], in [context], which has no errors and is rendered.
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
ClassDeclaration _classOf(CompilationUnit unit, String name) => unit
    .declarations
    .whereType<ClassDeclaration>()
    .singleWhere((declaration) => declaration.namePart.typeName.lexeme == name);

/// The expression that the getter or the method [name] of [declaration]
/// returns.
Expression _returnedBy(ClassDeclaration declaration, String name) {
  final member = declaration.body.members
      .whereType<MethodDeclaration>()
      .singleWhere((method) => method.name.lexeme == name);
  return (member.body as ExpressionFunctionBody).expression;
}

/// The value of the string literal [expression].
String? _string(Expression? expression) =>
    (expression as StringLiteral?)?.stringValue;

/// The argument [name] of [call], the creation of a widget.
Expression _argument(Expression call, String name) => (call as MethodInvocation)
    .argumentList
    .arguments
    .whereType<NamedArgument>()
    .singleWhere((argument) => argument.name.lexeme == name)
    .argumentExpression;

/// The list of the rows of the settings screen of [app], as the screen
/// creates it: the `children` of the list that is the body of its
/// `Scaffold`.
ListLiteral _rowsOf(RenderedApp app) {
  final screen = _classOf(_parsed(app, _screen), 'SettingsScreen');
  final list = _argument(_returnedBy(screen, 'build'), 'body');
  expect((list as MethodInvocation).methodName.name, 'ListView');
  return _argument(list, 'children') as ListLiteral;
}

/// The imports of the settings screen of [app], each with its prefix, by
/// URI.
Map<String, String?> _importsOf(RenderedApp app) => {
      for (final directive
          in _parsed(app, _screen).directives.whereType<ImportDirective>())
        directive.uri.stringValue!: directive.prefix?.name,
    };

/// The entries of the settings screen of the app of [result], as the role
/// gives them to its provider, whichever module provides it: the class of
/// the widget of each and its file.
List<String> _entriesOf(ContractResult result) => [
      for (final entry in settingsScreenRole
          .entriesIn(settingsScreenRole.hookInput(result.hook!)))
        '${entry.widget.name} of ${entry.file}',
    ];

/// The route that the router role chose to start the app of [result] on,
/// as every router gets it, whichever module provides the role.
FacadeRoute? _startRouteOf(ContractResult result) =>
    routerRole.startIn(routerRole.hookInput(result.hook!));

/// The labels of the destinations of the main navigation of the app of
/// [result], in their order, as the layout role gives them to the router.
List<String> _labelsOf(ContractResult result) => [
      for (final route
          in layoutRole.destinationsIn(layoutRole.hookInput(result.hook!)))
        route.route.destination!.label,
    ];

/// The modules that provide [role] in the app of [result], whichever they
/// are.
Set<ModuleId> _providersOf(ContractResult result, Role role) => {
      for (final module in result.resolution!.providersOf(role)) module.id,
    };

void main() {
  const module = SettingsModule();

  group('SettingsModule', () {
    test(
        'is a feature without variants, which provides the settings screen '
        'role and requires the router', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('settings'));
      expect(descriptor.kind, ModuleKinds.feature);
      expect(descriptor.provides, {settingsScreenRole});
      // The kind makes a feature require the router, and so does the role.
      expect(descriptor.requires, isEmpty);
      expect(descriptor.effectiveRequires, {routerRole});
      expect(descriptor.effectiveUses, isEmpty);
      expect(descriptor.dependsOn, isEmpty);
      expect(descriptor.variants, isNull);
    });

    test('forms a valid registry with the modules of the tests', () {
      expect(ModuleRegistry.problemsOf(_modules), isEmpty);
    });

    test(
        'declares one route: the settings screen at / of the module, with '
        'the destination Settings, on which the app does not start', () {
      final data = [
        for (final contribution
            in module.contribute(ContractHarness.defaultContext))
          if (contribution is RoleData<RoutesData>) contribution,
      ].single;

      expect(data.role, routerRole);
      final route = data.value.routes.single;
      expect(route.path, '/');
      expect(route.name, 'settings');
      expect(route.screen.className, 'SettingsScreen');
      expect(route.screen.file, _screen);
      expect(route.params, isEmpty);
      expect(route.children, isEmpty);
      expect(route.startCandidate, isFalse);
      final destination = route.destination!;
      expect(destination.label, 'Settings');
      // A constant, so that the main navigation can be one.
      expect(destination.icon.code, 'Icons.settings');
      final import = destination.icon.imports.single;
      expect(import.uri, 'package:flutter/material.dart');
      expect(import.prefix, isNull);
      expect(import.show, ['Icons']);
    });

    test('names its route as the settings screen of the role', () {
      final data = [
        for (final contribution
            in module.contribute(ContractHarness.defaultContext))
          if (contribution is RoleData<SettingsData>) contribution,
      ].single;

      expect(data.role, settingsScreenRole);
      expect((data.value as SettingsScreenRoute).name, 'settings');
    });
  });

  group('the contract harness', () {
    late List<ContractResult> results;

    setUpAll(() async {
      results = await ContractHarness(ModuleRegistry(_modules)).checkAll();
    });

    test(
        'builds the app of the module, and those of the contributors of '
        'settings with and without the settings screen', () {
      expect(results.map((result) => result.contractCase.name), [
        'flutter_core with router',
        'flutter_core',
        'go_router with layout',
        'feed with settings_screen',
        'feed',
        'settings',
        'look with settings_screen',
        'look',
        'pinch_zoom with settings_screen',
        'pinch_zoom',
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

    test(
        'checks each module with the provider of each role it requires or '
        'uses', () async {
      expect(
        await ContractHarness(ModuleRegistry(_modules)).uncheckedProviders(),
        isEmpty,
      );
    });
  });

  group('the app with settings', () {
    late ContractResult result;
    late RenderedApp app;
    late RenderedApp withRouter;

    setUpAll(() async {
      result = await _rendered(const [SettingsModule.id]);
      app = result.app!;
      withRouter = (await _rendered(const [GoRouterModule.id])).app!;
    });

    test('gets the only router, which settings requires', () {
      expect(
        {
          for (final module in result.resolution!.modules)
            '${module.id}': '${module.reason}',
        },
        {
          'settings': 'requested',
          'flutter_core':
              'the only provider of the app entry role, which every app needs',
          'go_router': 'the only provider of the router role, which settings '
              'requires',
        },
      );
    });

    test(
        'gets the brick of the screen with its title, the route and its name '
        'for the role, and nothing else', () {
      final contributions = [
        for (final collected in result.collection!.ofModule(SettingsModule.id))
          collected.contribution,
      ];

      expect(contributions, hasLength(3));
      final brick = contributions.whereType<BrickContribution>().single;
      expect(brick.bundle.name, 'settings');
      expect(brick.bundle.files.map((file) => file.path), [_screen]);
      expect(brick.vars, {'title': "'Settings'"});
      expect(contributions.whereType<RoleData<RoutesData>>(), hasLength(1));
      expect(contributions.whereType<RoleData<SettingsData>>(), hasLength(1));
    });

    test('is the app with the router but for the screen and its route', () {
      final router = _providersOf(result, routerRole);

      expect(app.files.keys.toSet(), {...withRouter.files.keys, _screen});
      expect(app.files[_screen]!.owner, const ModuleOrigin(SettingsModule.id));
      // The pubspec too: the screen needs nothing but Flutter. The route
      // goes into the navigation of the role and into the files of the
      // router.
      for (final MapEntry(key: path, value: file) in withRouter.files.entries) {
        if (path == RouterRole.navigationFile) continue;
        if (file.owner case ModuleOrigin(:final module)
            when router.contains(module)) {
          continue;
        }
        expect(app.files[path]!.bytes, file.bytes, reason: path);
      }
    });

    test(
        'starts on the fallback screen of the app entry, since the settings '
        'screen cannot start the app', () {
      expect(_startRouteOf(result), isNull);
      // No question to answer, so no option of the router either.
      expect(result.answers, isEmpty);
    });

    test('tells the role where the screen is: at /settings', () {
      final screen = settingsScreenRole
          .screenIn(settingsScreenRole.hookInput(result.hook!))!;

      expect(screen.fullPath, '/settings');
      expect(screen.fullName, 'settings.settings');
      expect(screen.hasRequiredParams, isFalse);
      expect(screen.route.screen.className, 'SettingsScreen');
      expect(screen.route.screen.file, _screen);
    });

    test('offers the route to the navigation of the app', () {
      final unit = _parsed(app, RouterRole.navigationFile);
      final location = _classOf(unit, 'SettingsSettingsLocation');

      expect(location.extendsClause!.superclass.name.lexeme, 'AppLocation');
      expect(_string(_returnedBy(location, 'routeName')), 'settings.settings');
      expect(_string(_returnedBy(location, 'path')), '/settings');
      expect(
        _returnedBy(_classOf(unit, 'SettingsRoutes'), 'settings').toSource(),
        'NavLink(_context, const SettingsSettingsLocation())',
      );
      expect(
        _returnedBy(_classOf(unit, 'AppNav'), 'settings').toSource(),
        'SettingsRoutes._(_context)',
      );
    });

    test(
        'shows its title and, in an app whose modules have no settings, only '
        'what the app is', () {
      final text = app.files[_screen]!.text;
      final unit = parseString(content: text).unit;
      final screen = _classOf(unit, 'SettingsScreen');

      expect(text, isNot(contains('{{')));
      expect(_entriesOf(result), isEmpty);
      expect(
        unit.directives.map((directive) => directive.toSource()),
        ["import 'package:flutter/material.dart';"],
      );
      expect(unit.declarations, [screen]);
      expect(screen.extendsClause!.superclass.name.lexeme, 'StatelessWidget');
      expect(screen.metadata, isEmpty);
      final constructor =
          screen.body.members.whereType<ConstructorDeclaration>().single;
      expect(constructor.name, isNull);
      expect(constructor.constKeyword, isNotNull);
      expect(constructor.parameters.toSource(), '({super.key})');
      expect(
        _returnedBy(screen, 'build').toSource(),
        "Scaffold(appBar: AppBar(title: const Text('Settings')), body: "
        'ListView(children: const [AboutListTile(icon: '
        "Icon(Icons.info_outline), applicationName: 'Contract App')]))",
      );
      // No blank line where the entries would be.
      expect(text, contains('children: const [\n        AboutListTile('));
    });
  });

  group('the entries of the settings screen', () {
    late ContractResult result;
    late RenderedApp app;

    setUpAll(() async {
      result = await _rendered(
        [_feed.id, SettingsModule.id, _look.id, ZoomModule.id],
      );
      app = result.app!;
    });

    test(
        'are those of the modules, in the order of the modules, and then '
        'those of the templates of roles', () {
      expect(_entriesOf(result), [
        'FeedSetting of lib/${_feed.settingsFile}',
        'ThemeSetting of lib/${_look.settingsFile}',
        'FontSetting of lib/${_look.settingsFile}',
        'ZoomSetting of lib/${ZoomRole.settingFile}',
      ]);
      expect(
        app.files['lib/${ZoomRole.settingFile}']!.owner,
        const RoleTemplateOrigin(zoomRole),
      );
    });

    test(
        'are the rows of the screen, each created once as a constant, in '
        'the order of the role, before what the app is', () {
      final rows = _rowsOf(app);

      const about = 'AboutListTile(icon: Icon(Icons.info_outline), '
          "applicationName: 'Contract App')";
      expect(rows.constKeyword, isNotNull);
      expect(rows.elements.map((row) => row.toSource()), [
        'entry0.FeedSetting()',
        'entry1.ThemeSetting()',
        'entry1.FontSetting()',
        'entry2.ZoomSetting()',
        about,
      ]);
    });

    test(
        'come through an import of the file of each, once, with a prefix of '
        'its own', () {
      expect(_importsOf(app), {
        'package:contract_app/${_feed.settingsFile}': 'entry0',
        'package:contract_app/${_look.settingsFile}': 'entry1',
        'package:contract_app/${ZoomRole.settingFile}': 'entry2',
        'package:flutter/material.dart': null,
      });
    });

    test('follow the order of the modules of the app', () async {
      final reversed = await _rendered(
        [ZoomModule.id, _look.id, SettingsModule.id, _feed.id],
      );

      expect(_entriesOf(reversed), [
        'ThemeSetting of lib/${_look.settingsFile}',
        'FontSetting of lib/${_look.settingsFile}',
        'FeedSetting of lib/${_feed.settingsFile}',
        'ZoomSetting of lib/${ZoomRole.settingFile}',
      ]);
      expect(
        _rowsOf(reversed.app!).elements.map((row) => row.toSource()).take(4),
        [
          'entry0.ThemeSetting()',
          'entry0.FontSetting()',
          'entry1.FeedSetting()',
          'entry2.ZoomSetting()',
        ],
      );
    });

    test('are only those of the modules of the app', () async {
      final result = await _rendered([SettingsModule.id, _look.id]);

      expect(_entriesOf(result), [
        'ThemeSetting of lib/${_look.settingsFile}',
        'FontSetting of lib/${_look.settingsFile}',
      ]);
      expect(_importsOf(result.app!), {
        'package:contract_app/${_look.settingsFile}': 'entry0',
        'package:flutter/material.dart': null,
      });
    });
  });

  group('the main navigation', () {
    test('shows Settings after the destinations of the features before it',
        () async {
      final result = await _rendered(
        [_feed.id, SettingsModule.id, BottomTabsModule.id],
      );

      expect(_labelsOf(result), ['Feed', 'Settings']);
      // The app starts on the feature: the settings screen starts no app.
      expect(_startRouteOf(result)!.fullPath, '/feed');

      final reversed = await _rendered(
        [SettingsModule.id, _feed.id, BottomTabsModule.id],
      );
      expect(_labelsOf(reversed), ['Settings', 'Feed']);
      expect(_startRouteOf(reversed)!.fullPath, '/feed');
    });

    test('is not there without a layout, and the screen stays a route',
        () async {
      final result = await _rendered([_feed.id, SettingsModule.id]);

      expect(_providersOf(result, layoutRole), isEmpty);
      expect(
        settingsScreenRole
            .screenIn(settingsScreenRole.hookInput(result.hook!))!
            .fullPath,
        '/settings',
      );
      expect(_startRouteOf(result)!.fullPath, '/feed');
    });
  });

  test('names the app in the row of what the app is as the context names it',
      () async {
    final result = await _rendered(
      const [SettingsModule.id],
      context: const ModuleContext(
        appName: 'bird_watch',
        orgName: 'org.example',
        appIdentity: AppIdentity(
          platforms: ['android', 'ios'],
          androidApplicationId: 'org.example.bird_watch',
          iosBundleId: 'org.example.bird-watch',
          androidNamespace: 'org.example.bird_watch',
        ),
      ),
    );

    final about = _rowsOf(result.app!).elements.single as Expression;
    expect(_argument(about, 'applicationName').toSource(), "'Bird Watch'");
  });

  test('keeps the annotations of the router role on the class of the screen',
      () async {
    final result = await _rendered(
      const [SettingsModule.id, _Annotating.id],
      registry: const [..._modules, _Annotating()],
    );
    final screen = _classOf(_parsed(result.app!, _screen), 'SettingsScreen');

    expect(
      screen.metadata.map((annotation) => annotation.toSource()),
      [_annotation],
    );
    expect(screen.documentationComment, isNotNull);
  });
}
