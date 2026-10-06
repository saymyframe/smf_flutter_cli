@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_gen_l10n/smf_gen_l10n.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_home_flutter/bundles/home_bundle.dart';
import 'package:smf_home_flutter/smf_home_flutter.dart';
import 'package:smf_home_flutter/src/agents.dart';
import 'package:smf_home_flutter/src/app_cell.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:smf_shared_preferences/smf_shared_preferences.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The modules of the tests: flutter_core, which creates the app, go_router,
/// which routes it, this one, gen_l10n, which keeps the texts of the app,
/// for the texts of the screen and the label of its destination, and
/// shared_preferences, in which the app remembers its language.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  GoRouterModule(),
  HomeModule(),
  GenL10nModule(),
  SharedPreferencesModule(),
];

/// The path of the screen of the module in the app.
const _screen = 'lib/features/home/home_screen.dart';

/// The files of the image of the mark in the app: the image, and its files
/// for the screens with more pixels.
final List<String> _markFiles = [
  HomeModule.markFile,
  ...HomeModule.markVariants.values,
];

/// The owner of the files of the module.
const _module = ModuleOrigin(HomeModule.id);

/// The getters of the texts of the screen in an app with the localization
/// role, each with its English text, in the order of the texts.
const _texts = {
  'homeGreetingMorning': 'Good morning',
  'homeGreetingAfternoon': 'Good afternoon',
  'homeGreetingEvening': 'Good evening',
  'homeReadyTitle': 'Your app is ready',
  'homeReadyText':
      'Generated with Say My Frame. Everything you see is yours to change.',
  'homeNextTitle': 'Next steps',
  'homeStepScreenTitle': 'Make this screen yours',
  'homeStepScreenText':
      'Replace this welcome with the first screen of your app.',
  'homeStepFeatureTitle': 'Add a feature',
  'homeStepFeatureText':
      'A feature keeps its screens and routes in a folder of its own.',
  'homeStepDocsTitle': 'Read the docs',
  'homeStepDocsText': 'Guides for every module, and for writing your own.',
  'homeCopied': 'Copied',
  'homeFooter': 'Built with Say My Frame',
};

/// The Ukrainian texts of the screen, by the same getters.
const _ukrainian = {
  'homeGreetingMorning': 'Доброго ранку',
  'homeGreetingAfternoon': 'Добрий день',
  'homeGreetingEvening': 'Добрий вечір',
  'homeReadyTitle': 'Ваш застосунок готовий',
  'homeReadyText':
      'Згенеровано з Say My Frame. Усе, що ви бачите, можна змінити.',
  'homeNextTitle': 'Що далі',
  'homeStepScreenTitle': 'Зробіть цей екран своїм',
  'homeStepScreenText':
      'Замініть це привітання першим екраном вашого застосунку.',
  'homeStepFeatureTitle': 'Додайте фічу',
  'homeStepFeatureText': 'Фіча тримає свої екрани й маршрути у власній теці.',
  'homeStepDocsTitle': 'Почитайте документацію',
  'homeStepDocsText': 'Настанови до кожного модуля і до написання власного.',
  'homeCopied': 'Скопійовано',
  'homeFooter': 'Зроблено з Say My Frame',
};

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

/// The context of the app named [appName].
ModuleContext _contextOf(String appName) => ModuleContext(
      appName: appName,
      orgName: 'org.example',
      appIdentity: AppIdentity(
        platforms: const ['android', 'ios'],
        androidApplicationId: 'org.example.$appName',
        iosBundleId: 'org.example.${appName.replaceAll('_', '-')}',
        androidNamespace: 'org.example.$appName',
      ),
    );

/// What the contract harness finds for the app of [modules] among
/// [registry], in [context] and with [roleOptions], which has no errors and
/// is rendered.
Future<ContractResult> _rendered(
  List<ModuleId> modules, {
  List<SmfModule> registry = _modules,
  ModuleContext context = ContractHarness.defaultContext,
  Map<String, String?> roleOptions = const {},
}) async {
  final result = await ContractHarness(
    ModuleRegistry(registry),
    context: context,
  ).check(
    ContractCase(
      modules.join(', '),
      requested: modules,
      roleOptions: roleOptions,
    ),
  );
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

/// The name of the class that [node] is in.
String _classAround(AstNode node) =>
    node.thisOrAncestorOfType<ClassDeclaration>()!.namePart.typeName.lexeme;

/// The method [name] of the class [type] of [unit].
MethodDeclaration _methodOf(CompilationUnit unit, String type, String name) =>
    _classOf(unit, type)
        .body
        .members
        .whereType<MethodDeclaration>()
        .singleWhere((method) => method.name.lexeme == name);

/// The expression that the getter or the method [name] of [declaration]
/// returns.
Expression _returnedBy(ClassDeclaration declaration, String name) {
  final member = declaration.body.members
      .whereType<MethodDeclaration>()
      .singleWhere((method) => method.name.lexeme == name);
  return (member.body as ExpressionFunctionBody).expression;
}

/// The statements of [method], each as its code.
List<String> _statementsOf(MethodDeclaration method) => [
      for (final statement
          in (method.body as BlockFunctionBody).block.statements)
        statement.toSource(),
    ];

/// The value of the string literal [expression].
String? _string(Expression? expression) =>
    (expression as StringLiteral?)?.stringValue;

/// The top-level constants of [unit], each with the code of its value, by
/// their names.
Map<String, String> _constantsOf(CompilationUnit unit) => {
      for (final declaration
          in unit.declarations.whereType<TopLevelVariableDeclaration>())
        if (declaration.variables.isConst)
          for (final variable in declaration.variables.variables)
            variable.name.lexeme: variable.initializer!.toSource(),
    };

/// The local variables that [function] declares, each with its value, by
/// their names.
Map<String, Expression> _variablesOf(AstNode function) {
  final visitor = _Variables();
  function.accept(visitor);
  return visitor.values;
}

final class _Variables extends RecursiveAstVisitor<void> {
  final Map<String, Expression> values = {};

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (node.initializer case final value?) values[node.name.lexeme] = value;
    super.visitVariableDeclaration(node);
  }
}

/// The URIs of the imports of [unit].
List<String> _importsOf(CompilationUnit unit) => [
      for (final directive in unit.directives.whereType<ImportDirective>())
        directive.uri.stringValue!,
    ];

/// The values of the string literals without interpolation in the
/// declarations of [unit], in the order of the code.
List<String> _stringsIn(CompilationUnit unit) {
  final visitor = _Strings();
  for (final declaration in unit.declarations) {
    declaration.accept(visitor);
  }
  return visitor.values;
}

final class _Strings extends RecursiveAstVisitor<void> {
  final List<String> values = [];

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) =>
      values.add(node.value);
}

/// The getters of the texts of the app that [unit] reads, as
/// `context.l10n.<getter>`, in the order of the code.
List<String> _textsReadIn(CompilationUnit unit) {
  final visitor = _TextReads();
  unit.accept(visitor);
  return visitor.getters;
}

final class _TextReads extends RecursiveAstVisitor<void> {
  final List<String> getters = [];

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (node.target?.toSource() == 'context.l10n') {
      getters.add(node.propertyName.name);
    }
    super.visitPropertyAccess(node);
  }
}

/// The calls of [name] in [node], such as the creations of a widget, in the
/// order of the code.
List<MethodInvocation> _calls(AstNode node, String name) {
  final visitor = _Calls(name);
  node.accept(visitor);
  return visitor.found;
}

final class _Calls extends RecursiveAstVisitor<void> {
  _Calls(this.name);

  final String name;

  final List<MethodInvocation> found = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == name) found.add(node);
    super.visitMethodInvocation(node);
  }
}

/// The named arguments of [call], such as the creation of a widget, each
/// as its code, by their names.
Map<String, String> _namedArgumentsOf(MethodInvocation call) => {
      for (final argument
          in call.argumentList.arguments.whereType<NamedArgument>())
        argument.name.lexeme: argument.argumentExpression.toSource(),
    };

/// The argument [name] of [call], such as the creation of a widget.
Expression _argument(MethodInvocation call, String name) =>
    call.argumentList.arguments
        .whereType<NamedArgument>()
        .singleWhere((argument) => argument.name.lexeme == name)
        .argumentExpression;

/// The first argument without a name of [call], as its code.
String _firstArgumentOf(MethodInvocation call) => call.argumentList.arguments
    .firstWhere((argument) => argument is! NamedArgument)
    .toSource();

/// The path of the route that the router role chose to start the app of
/// [result] on.
String? _startOf(ContractResult result) =>
    (result.choices![routerRole]! as RouterChoice).startPath;

/// The route that the router role chose to start the app of [result] on,
/// as every router gets it, whichever module provides the role.
FacadeRoute? _startRouteOf(ContractResult result) =>
    routerRole.startIn(routerRole.hookInput(result.hook!));

/// The modules that provide [role] in the app of [result], whichever they
/// are.
Set<ModuleId> _providersOf(ContractResult result, Role role) => {
      for (final module in result.resolution!.providersOf(role)) module.id,
    };

/// The inline code of [markdown]: what stands between two backticks.
Set<String> _codeOf(String markdown) => {
      for (final match in RegExp('`([^`]+)`').allMatches(markdown)) match[1]!,
    };

/// Whether [a] and [b] are the same bytes.
bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

/// The pubspec of [app].
YamlMap _pubspecOf(RenderedApp app) =>
    loadYaml(app.files['pubspec.yaml']!.text) as YamlMap;

/// The file of the brick of the module that the app gets at [path], as it
/// is in the package.
File _brickFile(String path) => File('bricks/home/__brick__/$path');

/// The width and the height in pixels of the PNG image [bytes], which its
/// header has after the signature of the format.
(int, int) _pngSizeOf(List<int> bytes) {
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  expect(bytes.sublist(1, 4), 'PNG'.codeUnits);
  expect(bytes.sublist(12, 16), 'IHDR'.codeUnits);
  return (data.getUint32(16), data.getUint32(20));
}

void main() {
  const module = HomeModule();

  group('HomeModule', () {
    test(
        'is a feature without variants, which requires the router and uses '
        'the localization role', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('home'));
      expect(descriptor.kind, ModuleKinds.feature);
      expect(descriptor.provides, isEmpty);
      // The kind makes a feature require the router.
      expect(descriptor.requires, isEmpty);
      expect(descriptor.effectiveRequires, {routerRole});
      // For the texts of its screen and the label of its destination, in
      // an app with texts.
      expect(descriptor.effectiveUses, {localizationRole});
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
      expect(destination.label.en, 'Home');
      // A constant, so that the main navigation can be one.
      expect(destination.icon.code, 'Icons.home');
      final import = destination.icon.imports.single;
      expect(import.uri, 'package:flutter/material.dart');
      expect(import.prefix, isNull);
      expect(import.show, ['Icons']);
    });

    test('has each text of its screen in English and in Ukrainian', () {
      expect(HomeModule.texts.texts, hasLength(_texts.length));
      for (final text in HomeModule.texts.texts) {
        expect(text.problems(), isEmpty, reason: '$text');
        expect(text.languages, ['en', 'uk'], reason: '$text');
      }
      expect(
        [for (final text in HomeModule.texts.texts) text.en],
        _texts.values,
      );
      expect(
        [for (final text in HomeModule.texts.texts) text.textIn('uk')],
        _ukrainian.values,
      );
    });

    test(
        'contributes its brick with the symbol and the number of the app '
        'and the texts of the screen, the image of the mark for the pubspec '
        'of the app, the label of its destination and the texts of its '
        'screen, its route and its note for coding agents, and nothing else',
        () {
      final contributions = module.contribute(ContractHarness.defaultContext);

      expect(contributions, hasLength(6));
      final brick = contributions[0] as BrickContribution;
      expect(brick.bundle, same(homeBundle));
      expect(brick.bundle.name, 'home');
      expect(
        {for (final file in brick.bundle.files) file.path},
        {_screen, ..._markFiles},
      );
      expect(brick.when, isEmpty);
      // The app of the harness is contract_app.
      expect(brick.vars.keys, [
        'app_symbol',
        'app_number',
        'text_greeting_morning',
        'text_greeting_afternoon',
        'text_greeting_evening',
        'text_ready_title',
        'text_ready_text',
        'text_next_title',
        'text_step_screen_title',
        'text_step_screen_text',
        'text_step_feature_title',
        'text_step_feature_text',
        'text_step_docs_title',
        'text_step_docs_text',
        'text_copied',
        'text_footer',
      ]);
      expect(brick.vars['app_symbol'], "'Ca'");
      expect(brick.vars['app_number'], 11);
      // Each text is a text of the app with the localization role, and its
      // English text without it.
      expect(
        [
          for (final variable in brick.vars.values.whereType<RoleVar>())
            (
              variable.role,
              (variable.present as Fragment).code,
              variable.absent,
            ),
        ],
        [
          for (final MapEntry(key: getter, value: english) in _texts.entries)
            (localizationRole, 'context.l10n.$getter', "'$english'"),
        ],
      );
      final pubspec = contributions[1] as PubspecFlutter;
      expect(pubspec.assets, [HomeModule.markFile]);
      // Nothing else of the section: the module adds no font, and the other
      // flags are for the app entry to set.
      expect(pubspec.fonts, isEmpty);
      expect(pubspec.generate, isFalse);
      expect(pubspec.usesMaterialDesign, isFalse);
      expect(pubspec.when, isEmpty);
      final label = contributions[2] as RoleData<TextsData>;
      expect(label.role, localizationRole);
      expect(label.value.texts.map((text) => text.name), ['label']);
      expect(label.when, isEmpty);
      final texts = contributions[3] as RoleData<TextsData>;
      expect(texts.role, localizationRole);
      expect(texts.value, same(HomeModule.texts));
      expect(texts.when, isEmpty);
      expect(contributions[4], isA<RoleData<RoutesData>>());
      final note = contributions[5] as SocketContribution;
      expect(note.socket, AppEntryRole.agentSections);
      expect(note.entryKey, 'Home');
      expect(note.entryValue, AgentNote(agentNote));
      expect(note.when, isEmpty);
    });
  });

  group('the cell of the app', () {
    test(
        'has the first letters of the first two words of the name of the '
        'app as its symbol, the first in upper case and the second in '
        'lower case', () {
      expect(appSymbolOf('my_app'), 'Ma');
      expect(appSymbolOf('bird_watch'), 'Bw');
      // The words after the second add nothing.
      expect(appSymbolOf('my_big_app'), 'Mb');
      // A word of one letter is a word.
      expect(appSymbolOf('a_team'), 'At');
      // A word may start with a digit, but for the first.
      expect(appSymbolOf('route_66'), 'R6');
    });

    test('has the first two letters of a name of one word as its symbol', () {
      expect(appSymbolOf('shop'), 'Sh');
      expect(appSymbolOf('app2go'), 'Ap');
      expect(appSymbolOf('x1'), 'X1');
    });

    test('has the one letter of a name of one letter as its symbol', () {
      expect(appSymbolOf('x'), 'X');
    });

    test(
        'has the number of letters and digits of the name of the app as its '
        'number', () {
      expect(appNumberOf('my_app'), 5);
      expect(appNumberOf('shop'), 4);
      expect(appNumberOf('x'), 1);
      expect(appNumberOf('route_66'), 7);
      expect(appNumberOf('my_big_app'), 8);
    });
  });

  group('the contract harness', () {
    late ContractHarness harness;
    late List<ContractResult> results;

    setUpAll(() async {
      harness = ContractHarness(ModuleRegistry(_modules));
      results = await harness.checkAll();
    });

    test(
        'builds the apps with and without home, and the app of home with '
        'and without the texts of the app', () {
      expect(results.map((result) => result.contractCase.name), [
        'flutter_core with router',
        'flutter_core',
        'home with localization',
        'home',
        'gen_l10n',
        'shared_preferences',
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
        'checks the module with the provider of each role that it requires '
        'or uses', () async {
      expect(await harness.uncheckedProviders(), isEmpty);
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
          'flutter_core':
              'the only provider of the app entry role, which every app needs',
          'go_router': 'the only provider of the router role, which home '
              'requires',
        },
      );
    });

    test(
        'has a section of its own in the guide for coding agents, which '
        'names the screen and the route as the app has them', () {
      final notes = app.entriesOf(AppEntryRole.agentSections);

      // The guide of the app with the router, and the section of home.
      expect(
        notes.where((note) => note.$1 != _module),
        withRouter.entriesOf(AppEntryRole.agentSections),
      );
      expect(
        notes.where((note) => note.$1 == _module),
        [(_module, agentHeading, AgentNote(agentNote))],
      );
      expect(
        app.files[AppEntryRole.agentsFile]!.text,
        contains('\n## Home\n\n$agentNote'),
      );
      // The screen and its route, as the router role has them; the file of
      // the screen declares its class.
      final route = _startRouteOf(result)!;
      final screen = route.route.screen;
      expect(screen.file, _screen);
      expect(
        DartFileIndexer.index(_screen, app.files[_screen]!.text)
            .declaration(screen.className)
            ?.kind,
        DeclarationKind.classType,
      );
      expect(
        agentNote,
        startsWith(
          '- `${screen.className}` in `${screen.file}`, the route '
          '`${route.fullName}` at `${route.fullPath}`, ',
        ),
      );
    });

    test(
        'has in that section where the image of the mark is, what declares '
        'it and where its files for the screens with more pixels are, and '
        'names no other code', () {
      final route = _startRouteOf(result)!;

      expect(_codeOf(agentNote), {
        route.route.screen.className,
        _screen,
        route.fullName,
        route.fullPath,
        HomeModule.markFile,
        'pubspec.yaml',
        '2.0x/',
        '3.0x/',
      });
      // The directories of the files for the screens with more pixels, next
      // to the image.
      final directory = File(HomeModule.markFile).parent.path;
      final name = HomeModule.markFile.substring(directory.length + 1);
      expect(HomeModule.markVariants, {
        2: '$directory/2.0x/$name',
        3: '$directory/3.0x/$name',
      });
    });

    test(
        'is the app with the router but for the screen, the image of the '
        'mark, its route and its section in the guide for coding agents: '
        'it adds no package', () {
      final router = _providersOf(result, routerRole);

      expect(
        app.files.keys.toSet(),
        {...withRouter.files.keys, _screen, ..._markFiles},
      );
      for (final path in [_screen, ..._markFiles]) {
        expect(app.files[path]!.owner, _module, reason: path);
      }
      // The route goes into the navigation of the role and into the files
      // of the router, and the image into the pubspec, which is checked
      // below.
      for (final MapEntry(key: path, value: file) in withRouter.files.entries) {
        if (path == RouterRole.navigationFile ||
            path == AppEntryRole.agentsFile ||
            path == 'pubspec.yaml') {
          continue;
        }
        if (file.owner case ModuleOrigin(:final module)
            when router.contains(module)) {
          continue;
        }
        expect(app.files[path]!.bytes, file.bytes, reason: path);
      }
      // The pubspec has the packages of the app with the router. Its
      // section of Flutter differs, by the image alone.
      final pubspec = _pubspecOf(app);
      final before = _pubspecOf(withRouter);
      expect(
        {...pubspec}..remove('flutter'),
        {...before}..remove('flutter'),
      );
      expect(
        {...pubspec['flutter'] as YamlMap}..remove('assets'),
        {...before['flutter'] as YamlMap},
      );
    });

    test('starts on the route of home, the only one that can start it', () {
      expect(_startOf(result), '/home');
    });

    test('opens on the screen of home at /home', () {
      // The router opens the app on the route that its role chose, which
      // the tests of each router and the tests of the router role in the
      // apps of the matrix check.
      final start = _startRouteOf(result)!;

      expect(start.fullPath, '/home');
      expect(start.fullName, 'home.home');
      expect(start.parent, isNull);
      expect(start.route.screen.className, 'HomeScreen');
      expect(start.route.screen.file, _screen);
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
  });

  group('the screen', () {
    late RenderedApp app;
    late String text;
    late CompilationUnit unit;
    late MethodDeclaration build;

    setUpAll(() async {
      app = (await _rendered(const [HomeModule.id])).app!;
      text = app.files[_screen]!.text;
      unit = parseString(content: text).unit;
      build = _methodOf(unit, '_HomeScreenState', 'build');
    });

    test(
        'is a widget with state of its own and a constant constructor, '
        'which takes its key and what tells it the time', () {
      final screen = _classOf(unit, 'HomeScreen');

      expect(text, isNot(contains('{{')));
      expect(screen.extendsClause!.superclass.name.lexeme, 'StatefulWidget');
      expect(screen.metadata, isEmpty);
      expect(screen.documentationComment, isNotNull);
      final constructor =
          screen.body.members.whereType<ConstructorDeclaration>().single;
      expect(constructor.name, isNull);
      expect(constructor.constKeyword, isNotNull);
      // The router creates the screen with its key alone, so it tells the
      // time of the device.
      expect(
        constructor.parameters.toSource(),
        '({super.key, this.now = DateTime.now})',
      );
      expect(
        [
          for (final field in screen.body.members.whereType<FieldDeclaration>())
            '${field.fields.type} ${field.fields.variables.single.name.lexeme}',
        ],
        ['DateTime Function() now'],
      );
      expect(
        '${_classOf(unit, '_HomeScreenState').extendsClause!.superclass}',
        'State<HomeScreen>',
      );
    });

    test(
        'imports only the material library and the services of Flutter: the '
        'module adds no package for its look', () {
      expect(_importsOf(unit), [
        'package:flutter/material.dart',
        'package:flutter/services.dart',
      ]);
      expect(app.files[_screen]!.addedImports, isEmpty);
    });

    test(
        'names the app as the context names it, with the symbol and the '
        'number of its cell, which the module makes from that name', () async {
      final constants = _constantsOf(unit);

      // The app of the harness is contract_app.
      expect(constants['_appName'], "'Contract App'");
      expect(constants['_appSymbol'], "'Ca'");
      expect(constants['_appNumber'], '11');

      final other = await _rendered(
        const [HomeModule.id],
        context: _contextOf('bird_watch'),
      );
      final named = _constantsOf(_parsed(other.app!, _screen));
      expect(named['_appName'], "'Bird Watch'");
      expect(named['_appSymbol'], "'${appSymbolOf('bird_watch')}'");
      expect(named['_appSymbol'], "'Bw'");
      expect(named['_appNumber'], '${appNumberOf('bird_watch')}');
      expect(named['_appNumber'], '9');

      // A name of one letter has a symbol of one letter.
      final short = await _rendered(
        const [HomeModule.id],
        context: _contextOf('x'),
      );
      final shortest = _constantsOf(_parsed(short.app!, _screen));
      expect(
        [for (final name in constants.keys.take(3)) shortest[name]],
        ["'X'", "'X'", '1'],
      );
    });

    test(
        'shows the name of the app as a header for a screen reader, and the '
        'symbol and the number in the cell of the card', () {
      final headers = [
        for (final semantics in _calls(unit, 'Semantics'))
          if (_namedArgumentsOf(semantics)['header'] == 'true')
            _firstArgumentOf(_argument(semantics, 'child') as MethodInvocation),
      ];

      // The name of the app, and the title of the steps.
      expect(headers, ['_appName', "'Next steps'"]);
      expect(
        _methodOf(unit, '_ReadyCard', 'build').toSource(),
        contains('const _ElementTile(symbol: _appSymbol, number: _appNumber)'),
      );
      expect(
        [
          for (final shown
              in _calls(_methodOf(unit, '_ElementTile', 'build'), 'Text'))
            _firstArgumentOf(shown),
        ],
        [r"'$number'", 'symbol'],
      );
    });

    test(
        'greets by the hour that it is told: with the morning before noon, '
        'with the afternoon before six, and with the evening after', () {
      final variables = _variablesOf(build);

      expect(variables['hour']!.toSource(), 'widget.now().hour');
      expect(
        variables['greeting']!.toSource(),
        "hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : "
        "'Good evening'",
      );
      expect(
        _calls(build, 'Text').map(_firstArgumentOf),
        contains('greeting'),
      );
      // Nothing else of the file asks for the time.
      expect('DateTime.now'.allMatches(text), hasLength(1));
    });

    test(
        'lists three steps, each with its path or address: its own file, '
        'the directory of the features, and the documentation of SMF', () {
      final steps = [
        for (final step
            in (_variablesOf(build)['steps']! as ListLiteral).elements)
          [
            for (final field in (step as RecordLiteral).fields)
              field.toSource(),
          ],
      ];

      expect(steps, [
        [
          'Icons.edit_outlined',
          "'Make this screen yours'",
          "'Replace this welcome with the first screen of your app.'",
          "'$_screen'",
        ],
        [
          'Icons.add_box_outlined',
          "'Add a feature'",
          "'A feature keeps its screens and routes in a folder of its own.'",
          "'lib/features/'",
        ],
        [
          'Icons.menu_book_outlined',
          "'Read the docs'",
          "'Guides for every module, and for writing your own.'",
          "'doc.saymyframe.com'",
        ],
      ]);
      // The directory in which each feature has a folder of its own, as
      // this module has.
      expect(
        ModuleKinds.feature.fileRootsOf(HomeModule.id),
        ['lib/features/home/'],
      );
      // The address of the documentation, as the package has it.
      final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as Map;
      expect(
        Uri.parse(pubspec['documentation'] as String).host,
        'doc.saymyframe.com',
      );
      // Each step is a card that copies its path or address on a tap.
      final card = _calls(build, '_StepCard').single;
      expect(_namedArgumentsOf(card), {
        'icon': 'icon',
        'title': 'title',
        'text': 'text',
        'code': 'code',
        'onTap': '() => _copy(code)',
      });
    });

    test(
        'copies the path of a step and then says so in a snack bar, in '
        'place of the one of the tap before', () {
      final copy = _methodOf(unit, '_HomeScreenState', '_copy');
      final statements = _statementsOf(copy);

      expect(statements, hasLength(4));
      expect(statements.take(3), [
        // Before the copy: the screen may be gone once it completes.
        'final messenger = ScaffoldMessenger.of(context);',
        "final copied = 'Copied';",
        'await Clipboard.setData(ClipboardData(text: code));',
      ]);
      expect(
        statements.last,
        startsWith('messenger..hideCurrentSnackBar()..showSnackBar(SnackBar('),
      );
      final said = _calls(copy, 'Text').single;
      expect(_firstArgumentOf(said), r"'$copied: $code'");
    });

    test(
        'announces a step to a screen reader as one button, which the tap '
        'on the card is', () {
      final button = [
        for (final semantics in _calls(unit, 'Semantics'))
          if (_namedArgumentsOf(semantics)['button'] == 'true') semantics,
      ].single;

      expect(_classAround(button), '_StepCard');
      final tapped = _argument(button, 'child') as MethodInvocation;
      expect(tapped.methodName.name, 'InkWell');
      expect(_namedArgumentsOf(tapped)['onTap'], 'onTap');
      // The card clips the response to the tap to its corners in a theme
      // whose cards do not.
      final card = _calls(unit, 'Card').single;
      expect(_namedArgumentsOf(card)['clipBehavior'], 'Clip.antiAlias');
      expect(_argument(card, 'child'), same(button));
    });

    test(
        'shows the mark of Say My Frame from the image that the module '
        'declares, next to the name of the app with its name for a screen '
        'reader, and in its last line without one', () {
      expect(_constantsOf(unit)['_mark'], "'${HomeModule.markFile}'");
      final images = _calls(unit, 'asset');
      expect(
        [
          for (final image in images)
            (image.target!.toSource(), _firstArgumentOf(image)),
        ],
        [('Image', '_mark'), ('Image', '_mark')],
      );
      expect(images.map(_namedArgumentsOf), [
        {'width': '48', 'height': '48', 'semanticLabel': "'Say My Frame'"},
        {'width': '20', 'height': '20', 'excludeFromSemantics': 'true'},
      ]);
    });

    test(
        'lets its parts come in once when it is first shown, and shows them '
        'at once in an app that asks for less motion', () {
      final state = _classOf(unit, '_HomeScreenState');
      final shown =
          _methodOf(unit, '_HomeScreenState', 'didChangeDependencies');
      final statements = (shown.body as BlockFunctionBody).block.statements;

      const controller = '_entrance = AnimationController(vsync: this, '
          'duration: const Duration(milliseconds: 1400))';
      expect(
        [
          for (final field in state.body.members.whereType<FieldDeclaration>())
            field.fields.variables.single.toSource(),
        ],
        [controller, '_started = false'],
      );
      // Once: the screen depends on more of its context than the motion.
      expect(
        statements.take(3).map((statement) => statement.toSource()),
        [
          'super.didChangeDependencies();',
          'if (_started) return;',
          '_started = true;',
        ],
      );
      final motion = statements.last as IfStatement;
      expect(statements, hasLength(4));
      expect(
        motion.expression.toSource(),
        'MediaQuery.disableAnimationsOf(context)',
      );
      expect(motion.thenStatement.toSource(), '{_entrance.value = 1;}');
      expect(motion.elseStatement!.toSource(), '{_entrance.forward();}');
      // Nothing of the screen moves without an end, and the screen
      // disposes of what moves its parts.
      expect(_calls(unit, 'repeat'), isEmpty);
      expect(
        _statementsOf(_methodOf(unit, '_HomeScreenState', 'dispose')),
        ['_entrance.dispose();', 'super.dispose();'],
      );
      // The seven parts, in their order from the top: the name of the app,
      // the card, the title of the steps, the three steps and the last
      // line.
      expect(
        [
          for (final part in _calls(build, '_Rise'))
            _namedArgumentsOf(part)['order'],
        ],
        ['0', '1', '2', '3 + index', '6'],
      );
    });

    test(
        'takes the styles of its texts from the theme of the app, and shows '
        'a path and the number of the cell in the monospaced font of the '
        'device', () {
      expect(
        _constantsOf(unit)['_monospace'],
        "TextStyle(fontFamily: 'monospace', fontFamilyFallback: ['Menlo', "
        "'Courier'])",
      );
      // No other text names a font.
      expect('fontFamily:'.allMatches(text), hasLength(1));
      // Each text of the file, by what it shows, with its style.
      final styles = [
        for (final shown in _calls(unit, 'Text'))
          (_firstArgumentOf(shown), _namedArgumentsOf(shown)['style']),
      ];
      expect(styles.map((style) => style.$1), [
        r"'$copied: $code'",
        'greeting',
        '_appName',
        "'Next steps'",
        "'Built with Say My Frame'",
        // The card.
        'title',
        'text',
        r"'$number'",
        'symbol',
        // A step.
        'title',
        'text',
        'code',
      ]);
      for (final (shown, style) in styles) {
        final from = switch (shown) {
          // The text of the snack bar has the style of the theme for it.
          r"'$copied: $code'" => isNull,
          r"'$number'" || 'code' => startsWith('_monospace.copyWith('),
          _ => startsWith('theme.textTheme.'),
        };
        expect(style, from, reason: shown);
      }
    });

    test(
        'keeps the symbol and the number of the cell at their size when the '
        'text of the device is larger, and leaves the cell out for a screen '
        'reader', () {
      final unscaled = _calls(unit, 'withNoTextScaling').single;

      expect(_classAround(unscaled), '_ElementTile');
      expect(unscaled.target!.toSource(), 'MediaQuery');
      // The whole cell: its box, with the number and the symbol in it.
      final cell = _argument(unscaled, 'child') as MethodInvocation;
      expect(cell.methodName.name, 'Container');
      expect(
        _namedArgumentsOf(cell),
        allOf(
          containsPair('width', '_cellSide'),
          containsPair('height', '_cellSide'),
        ),
      );
      expect(_calls(cell, 'Text'), hasLength(2));
      final excluded = _calls(unit, 'ExcludeSemantics').single;
      expect(_argument(excluded, 'child'), same(unscaled));
    });

    test(
        'shows the path of a step, and names it in the snack bar, in a text '
        'that is at most one and a half times its size and takes as many '
        'lines as it needs', () {
      final clamped = _calls(unit, 'withClampedTextScaling');

      expect(
        [
          for (final call in clamped)
            (
              call.thisOrAncestorOfType<MethodDeclaration>()!.name.lexeme,
              _classAround(call),
              call.target!.toSource(),
              _namedArgumentsOf(call)['maxScaleFactor'],
            ),
        ],
        [
          ('_copy', '_HomeScreenState', 'MediaQuery', '1.5'),
          ('build', '_StepCard', 'MediaQuery', '1.5'),
        ],
      );
      for (final call in clamped) {
        final shown = _argument(call, 'child') as MethodInvocation;
        expect(shown.methodName.name, 'Text');
        // Neither an ellipsis nor a limit of its lines.
        expect(
          _namedArgumentsOf(shown).keys,
          isNot(anyOf(contains('overflow'), contains('maxLines'))),
        );
      }
      expect(
        _firstArgumentOf(_argument(clamped.last, 'child') as MethodInvocation),
        'code',
      );
    });

    test(
        'keeps the colours of Say My Frame on its card in every theme, and '
        'the colours of the theme of the app everywhere else', () {
      final constants = _constantsOf(unit);

      expect(
        [
          for (final name in const [
            '_brandGreen',
            '_brandCream',
            '_brandAccent',
          ])
            constants[name],
        ],
        ['Color(0xFF0F3326)', 'Color(0xFFF1F1E8)', 'Color(0xFF4ADE80)'],
      );
      // The card, its cell and the cells next to it read no colour of the
      // theme.
      for (final type in const [
        '_ReadyCard',
        '_ElementTile',
        '_CellsPainter',
      ]) {
        expect(
          _classOf(unit, type).toSource(),
          isNot(contains('colorScheme')),
          reason: type,
        );
      }
      expect(
        _classOf(unit, '_ReadyCard').toSource(),
        contains('BoxDecoration(color: _brandGreen, '),
      );
      // The steps and the rest of the screen have no colour of their own.
      for (final type in const ['_StepCard', '_HomeScreenState', '_Rise']) {
        expect(
          _classOf(unit, type).toSource(),
          isNot(contains('Color(0x')),
          reason: type,
        );
      }
    });

    test(
        'has no app bar, so it tells the colour of the icons of the status '
        'bar itself, by the brightness of the theme, and keeps its list out '
        'of what covers the top and the bottom of the screen', () {
      expect(_calls(unit, 'AppBar'), isEmpty);
      final region = _calls(build, 'AnnotatedRegion').single;
      expect(
        region.typeArguments!.toSource(),
        '<SystemUiOverlayStyle>',
      );
      expect(
        _argument(region, 'value').toSource(),
        'theme.brightness == Brightness.dark ? SystemUiOverlayStyle.light : '
        'SystemUiOverlayStyle.dark',
      );
      final safeArea = _calls(build, 'SafeArea').single;
      expect(_namedArgumentsOf(safeArea)['bottom'], 'false');
      final list = _argument(safeArea, 'child') as MethodInvocation;
      expect(list.methodName.name, 'ListView');
      // The list ends above the bottom of the screen itself, by what the
      // context says of it: nothing in an app whose main navigation is
      // there.
      expect(
        _namedArgumentsOf(list)['padding'],
        'EdgeInsets.fromLTRB(20, 20, 20, 32 + '
        'MediaQuery.paddingOf(context).bottom)',
      );
    });

    test('keeps the annotations of the router role on its class', () async {
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
        screen.documentationComment!.tokens.first.lexeme,
        '/// The screen that the app starts on: a welcome to the developer of '
        'the app,',
      );
    });

    test('is the file that the example of the package shows parts of',
        () async {
      // The example generates my_app.
      final myApp = await _rendered(
        const [HomeModule.id],
        context: _contextOf('my_app'),
      );
      final generated = myApp.app!.files[_screen]!.text;
      // Git may check the example out with the line endings of Windows.
      final example =
          File('example/README.md').readAsStringSync().replaceAll('\r\n', '\n');
      final shown = [
        for (final block
            in RegExp(r'```dart\n([\s\S]*?)```').allMatches(example))
          block[1]!,
      ];

      expect(shown, hasLength(2));
      for (final part in shown) {
        expect(generated, contains(part));
      }
      // The image, as the example has it in the pubspec of the app.
      expect(
        RegExp(r'```yaml\n([\s\S]*?)```').firstMatch(example)![1],
        'flutter:\n'
        '  assets:\n'
        '    - ${HomeModule.markFile}\n',
      );
    });
  });

  group('the image of the mark', () {
    late RenderedApp app;

    setUpAll(() async {
      app = (await _rendered(const [HomeModule.id])).app!;
    });

    test(
        'is declared in the pubspec of the app, the image alone: Flutter '
        'finds its files for the screens with more pixels next to it', () {
      final flutter = _pubspecOf(app)['flutter'] as YamlMap;

      expect(flutter['assets'], [HomeModule.markFile]);
      expect(flutter.containsKey('fonts'), isFalse);
    });

    test(
        'is in the folder of the feature, where a feature keeps its files, '
        'with its files for the screens with two and with three pixels for '
        'a logical pixel in directories that Flutter names', () {
      final root = ModuleKinds.feature.fileRootsOf(HomeModule.id).single;

      expect(HomeModule.markFile, '${root}assets/smf_mark.png');
      expect(HomeModule.markVariants, {
        2: '${root}assets/2.0x/smf_mark.png',
        3: '${root}assets/3.0x/smf_mark.png',
      });
    });

    test(
        'has its files in the app as they are in the package, byte for '
        'byte, and not as text', () {
      for (final path in _markFiles) {
        final file = app.files[path]!;

        expect(file.isText, isFalse, reason: path);
        expect(
          _sameBytes(file.bytes, _brickFile(path).readAsBytesSync()),
          isTrue,
          reason: path,
        );
      }
    });

    test(
        'is a square PNG image of 48 pixels, the size that the screen shows '
        'it in, and of two and three times that for the screens with more '
        'pixels', () {
      expect(_pngSizeOf(app.files[HomeModule.markFile]!.bytes), (48, 48));
      for (final MapEntry(key: ratio, value: path)
          in HomeModule.markVariants.entries) {
        expect(
          _pngSizeOf(app.files[path]!.bytes),
          (48 * ratio, 48 * ratio),
          reason: path,
        );
      }
    });

    test('is the same in an app with the localization role', () async {
      final withTexts =
          (await _rendered(const [HomeModule.id, GenL10nModule.id])).app!;

      for (final path in _markFiles) {
        expect(
          _sameBytes(withTexts.files[path]!.bytes, app.files[path]!.bytes),
          isTrue,
          reason: path,
        );
      }
      expect(
        (_pubspecOf(withTexts)['flutter'] as YamlMap)['assets'],
        [HomeModule.markFile],
      );
    });
  });

  group('in an app with the localization role', () {
    late ContractResult result;
    late RenderedApp app;
    late RenderedApp without;

    /// The label as the layout role gets it from the routes of the module,
    /// whichever module provides the role.
    LocalizedText labelOf(ContractResult result) => routerRole
        .facadeOf(routerRole.hookInput(result.hook!))
        .destinations
        .single
        .route
        .destination!
        .label;

    setUpAll(() async {
      result = await _rendered(const [HomeModule.id, GenL10nModule.id]);
      app = result.app!;
      without = (await _rendered(const [HomeModule.id])).app!;
    });

    test(
        'the label of the destination and the texts of the screen are texts '
        'of the app, in English and in Ukrainian', () {
      final input = localizationRole.hookInput(result.hook!);

      // What the role has of the module, in the order of its texts: the
      // provider of the role renders them, and the rule
      // localization.texts_rendered of the role checks that it does.
      expect(
        [
          for (final text in localizationRole.textsIn(input))
            (
              '${text.owner}',
              text.getter,
              text.text.en,
              text.text.textIn('uk'),
            ),
        ],
        [
          ('$_module', 'homeLabel', 'Home', 'Головна'),
          for (final MapEntry(key: getter, value: english) in _texts.entries)
            ('$_module', getter, english, _ukrainian[getter]),
        ],
      );
      expect(localizationRole.localesIn(input), ['en', 'uk']);
    });

    test(
        'the label of the destination is that text of the app, so the main '
        'navigation of the app reads it from the texts', () {
      final input = localizationRole.hookInput(result.hook!);
      final label = localizationRole.textsIn(input).first;

      expect(labelOf(result), same(label.text));
      expect(
        localizationRole.appTextOf(input, _module, labelOf(result))?.getter,
        'homeLabel',
      );
    });

    test(
        'the screen reads each of its texts from the texts of the app, '
        'where the app without the role has its English text', () {
      final screen = _parsed(app, _screen);
      final plain = _parsed(without, _screen);

      // In the order of the code: what the snack bar says, the greetings,
      // the steps, and then the card, the title of the steps and the last
      // line.
      expect(_textsReadIn(screen), [
        'homeCopied',
        'homeGreetingMorning',
        'homeGreetingAfternoon',
        'homeGreetingEvening',
        'homeStepScreenTitle',
        'homeStepScreenText',
        'homeStepFeatureTitle',
        'homeStepFeatureText',
        'homeStepDocsTitle',
        'homeStepDocsText',
        'homeReadyTitle',
        'homeReadyText',
        'homeNextTitle',
        'homeFooter',
      ]);
      expect(_textsReadIn(screen).toSet(), _texts.keys.toSet());
      // The label of the destination is for the main navigation to show.
      expect(_textsReadIn(screen), isNot(contains('homeLabel')));
      // Without the role, no code reads the texts of an app, and the
      // screen has each English text once.
      expect(_textsReadIn(plain), isEmpty);
      final literals = _stringsIn(plain);
      for (final english in _texts.values) {
        expect(
          literals.where((literal) => literal == english),
          hasLength(1),
          reason: english,
        );
      }
      // With it, the screen has none of them.
      expect(
        _stringsIn(screen).toSet().intersection(_texts.values.toSet()),
        isEmpty,
      );
    });

    test(
        'the screen imports the texts of the app, and is the screen of the '
        'app without the role but for its texts', () {
      // The file with the extension that the role requires of its provider,
      // whichever module provides it.
      final texts = LocalizationRole.appTexts.importRef.resolveUri(
        ContractHarness.defaultContext.appName,
      );

      expect(
        {
          for (final added in app.files[_screen]!.addedImports)
            ('${added.contributor}', added.import.uri),
        },
        {('$_module', texts)},
      );
      // The same screen once each read of a text is its English text.
      var translated = app.files[_screen]!.text.replaceAll(
        "import '$texts';\n",
        '',
      );
      for (final MapEntry(key: getter, value: english) in _texts.entries) {
        translated =
            translated.replaceAll('context.l10n.$getter', "'$english'");
      }
      expect(translated, without.files[_screen]!.text);
    });

    test(
        'the label of the destination is its English text in an app without '
        'the localization role', () async {
      final plain = await _rendered(const [HomeModule.id]);

      expect(plain.hook!.presentRoles, isNot(contains(localizationRole)));
      expect(labelOf(plain).en, 'Home');
    });
  });

  group('the app test of the module', () {
    /// The Dart files of the app test, by their names.
    final files = {
      for (final file
          in Directory('app_tests/home/test/home').listSync().whereType<File>())
        file.uri.pathSegments.last: file.readAsStringSync(),
    };

    test(
        'looks up each text of the screen by its name in the module, and no '
        'text that the module lacks', () {
      final names = {for (final text in HomeModule.texts.texts) text.name};
      final lookedUp = {
        for (final source in files.values)
          for (final match in RegExp(
            r"(?:\btext\(|\btexts\[|\b(?:title|text|name): )'(\w+)'",
          ).allMatches(source))
            match[1]!,
      };

      // The matrix writes the texts for it by these names: a new text of
      // the module needs a look in the test.
      expect(lookedUp, names);
    });

    test(
        'knows the image of the mark and the paths of the steps as the '
        'module has them', () async {
      final helpers = parseString(content: files['app.dart']!).unit;
      final constants = _constantsOf(helpers);
      final app = (await _rendered(const [HomeModule.id])).app!;
      final build =
          _methodOf(_parsed(app, _screen), '_HomeScreenState', 'build');

      expect(constants['markAsset'], "'${HomeModule.markFile}'");
      expect(
        RegExp("code: ('[^']+')")
            .allMatches(constants['steps']!)
            .map((match) => match[1]),
        [
          for (final step
              in (_variablesOf(build)['steps']! as ListLiteral).elements)
            (step as RecordLiteral).fields.last.toSource(),
        ],
      );
    });

    test(
        'goes to the screen through the navigation of the router role, as '
        'code of the app does, so it holds in an app that starts on another '
        'screen', () {
      final helpers = files['app.dart']!;

      expect(
        helpers,
        contains(
          "import 'package:{{app_name}}/"
          "${RouterRole.navigationFile.substring('lib/'.length)}';",
        ),
      );
      expect(helpers, contains('.go(const HomeHomeLocation());'));
    });
  });

  test('starts on /home when --start names it', () async {
    final result = await _rendered(
      const [HomeModule.id],
      roleOptions: {RouterRole.startOption.name: '/home'},
    );

    expect(_startOf(result), '/home');
  });
}
