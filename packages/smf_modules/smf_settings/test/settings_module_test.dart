import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:smf_bottom_tabs/smf_bottom_tabs.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_gen_l10n/smf_gen_l10n.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:smf_settings/smf_settings.dart';
import 'package:smf_settings/src/agents.dart';
import 'package:smf_shared_preferences/smf_shared_preferences.dart';
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
/// destinations, this module, the contributors of settings, which are a
/// feature, a library, and the provider of a role whose template has a
/// setting, gen_l10n, which keeps the texts of the app, for the title of
/// the screen, and shared_preferences, in which an app with texts remembers
/// its language.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  GoRouterModule(),
  BottomTabsModule(),
  _feed,
  SettingsModule(),
  _look,
  ZoomModule(),
  GenL10nModule(),
  SharedPreferencesModule(),
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

/// The widgets and other objects that a piece of code creates, and the
/// methods that it calls, by the name of each, such as `Text` or
/// `MediaQuery.withClampedTextScaling`, with the arguments of each. A call
/// on an object has the code of the object before the name, with a dot
/// between them, also where the code has `?.`.
final class _Creations extends RecursiveAstVisitor<void> {
  /// The creations in [node].
  _Creations.of(AstNode node) {
    node.accept(this);
  }

  /// The arguments of each creation, by what creates it.
  final Map<String, List<ArgumentList>> byName = {};

  /// The arguments of the only creation of [name].
  ArgumentList only(String name) => byName[name]!.single;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    final name = target == null
        ? node.methodName.name
        : '${target.toSource()}.${node.methodName.name}';
    byName.putIfAbsent(name, () => []).add(node.argumentList);
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    byName
        .putIfAbsent(node.constructorName.toSource(), () => [])
        .add(node.argumentList);
    super.visitInstanceCreationExpression(node);
  }
}

/// The argument [name] of [arguments], those of the creation of a widget.
Expression _argument(ArgumentList arguments, String name) => arguments.arguments
    .whereType<NamedArgument>()
    .singleWhere((argument) => argument.name.lexeme == name)
    .argumentExpression;

/// The names of the arguments of [arguments] that have one.
Set<String> _namesOf(ArgumentList arguments) => {
      for (final argument in arguments.arguments.whereType<NamedArgument>())
        argument.name.lexeme,
    };

/// What the settings screen of [app] creates when it builds.
_Creations _builtBy(RenderedApp app) => _Creations.of(
      _classOf(_parsed(app, _screen), 'SettingsScreen')
          .body
          .members
          .whereType<MethodDeclaration>()
          .singleWhere((method) => method.name.lexeme == 'build'),
    );

/// The list of the entries of the settings screen of [app], as the screen
/// creates it: the `children` of its group of the entries.
ListLiteral _rowsOf(RenderedApp app) =>
    _argument(_builtBy(app).only('_Group'), 'children') as ListLiteral;

/// The names of what the file of the settings screen of [app] declares at
/// its top level.
List<String> _declaredBy(RenderedApp app) => [
      for (final declaration in _parsed(app, _screen).declarations)
        switch (declaration) {
          ClassDeclaration() => declaration.namePart.typeName.lexeme,
          TopLevelVariableDeclaration() =>
            declaration.variables.variables.single.name.lexeme,
          _ => '$declaration',
        },
    ];

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
/// [result] in English, in their order, as the layout role has them.
List<String> _labelsOf(ContractResult result) => [
      for (final route
          in layoutRole.destinationsIn(layoutRole.hookInput(result.hook!)))
        route.route.destination!.label.en,
    ];

/// The code that reads the title of the settings screen of [app]: what the
/// screen gives its only text, which it marks as a header.
String _titleOf(RenderedApp app) {
  final built = _builtBy(app);
  expect(_argument(built.only('Semantics'), 'header').toSource(), 'true');
  return built.only('Text').arguments.first.toSource();
}

/// The inline code of [markdown]: what stands between two backticks.
Set<String> _codeOf(String markdown) => {
      for (final match in RegExp('`([^`]+)`').allMatches(markdown)) match[1]!,
    };

/// The methods and getters that the class [name] of [unit] declares.
Set<String> _membersOf(CompilationUnit unit, String name) => {
      for (final member in _classOf(unit, name).body.members)
        if (member is MethodDeclaration) member.name.lexeme,
    };

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
        'role, requires the router and uses the localization role', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('settings'));
      expect(descriptor.kind, ModuleKinds.feature);
      expect(descriptor.provides, {settingsScreenRole});
      // The kind makes a feature require the router, and so does the role.
      expect(descriptor.requires, isEmpty);
      expect(descriptor.effectiveRequires, {routerRole});
      // For the title of its screen, in an app with texts.
      expect(descriptor.effectiveUses, {localizationRole});
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
      expect(destination.label.en, 'Settings');
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
        'builds the app of the module with and without the texts of the app, '
        'and those of the contributors of settings with and without the '
        'settings screen', () {
      expect(results.map((result) => result.contractCase.name), [
        'flutter_core with router, localization',
        'flutter_core with router',
        // The app of the provider of the localization alone.
        'flutter_core with localization',
        'flutter_core',
        'go_router with layout',
        'bottom_tabs with localization',
        'feed with settings_screen',
        'feed',
        'settings with localization',
        'settings',
        'look with settings_screen',
        'look',
        'pinch_zoom with settings_screen',
        'pinch_zoom',
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
        'gets the brick of the screen with its title, the title as a text of '
        'the module, the route and its name for the role, and the note of '
        'the module for coding agents, and nothing else', () {
      final contributions = [
        for (final collected in result.collection!.ofModule(SettingsModule.id))
          collected.contribution,
      ];

      expect(contributions, hasLength(5));
      final note = contributions.whereType<SocketContribution>().single;
      expect(note.socket, AppEntryRole.agentSections);
      expect(note.entryKey, settingsScreenRole.description);
      expect(note.entryValue, AgentNote(agentNote));
      expect(note.when, isEmpty);
      final brick = contributions.whereType<BrickContribution>().single;
      expect(brick.bundle.name, 'settings');
      expect(brick.bundle.files.map((file) => file.path), [_screen]);
      // The title depends on whether the app has texts.
      expect(brick.vars.keys, ['text_title']);
      final title = brick.vars['text_title']! as RoleVar;
      expect(title.role, localizationRole);
      expect(title.absent, "'Settings'");
      expect((title.present as Fragment).code, 'context.l10n.settingsTitle');
      expect(contributions.whereType<RoleData<RoutesData>>(), hasLength(1));
      expect(contributions.whereType<RoleData<SettingsData>>(), hasLength(1));
      expect(contributions.whereType<RoleData<TextsData>>(), hasLength(1));
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
        // The guide for coding agents gets the section of the screen.
        if (path == AppEntryRole.agentsFile) continue;
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

    test('starts on the settings screen only when the app is asked to',
        () async {
      // As `--start /settings` asks on the command line.
      final asked = await ContractHarness(ModuleRegistry(_modules)).check(
        const ContractCase(
          'settings as the start',
          requested: [SettingsModule.id],
          roleOptions: {'start': '/settings'},
        ),
      );

      expect(asked.errors.map((issue) => '$issue'), isEmpty);
      expect(_startRouteOf(asked)!.fullPath, '/settings');
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
        'shows its title and, since no module of the app has a setting, a '
        'note for the developer of the app, without the code of the group '
        'of the entries', () {
      final text = app.files[_screen]!.text;
      final unit = parseString(content: text).unit;
      final screen = _classOf(unit, 'SettingsScreen');

      expect(text, isNot(contains('{{')));
      expect(_entriesOf(result), isEmpty);
      expect(
        unit.directives.map((directive) => directive.toSource()),
        [
          "import 'package:flutter/material.dart';",
          "import 'package:flutter/services.dart';",
        ],
      );
      // The path that the note names, the screen and the note, and nothing
      // of a screen with entries.
      expect(_declaredBy(app), ['_file', 'SettingsScreen', '_NoSettings']);
      expect(screen.extendsClause!.superclass.name.lexeme, 'StatelessWidget');
      expect(screen.metadata, isEmpty);
      final constructor =
          screen.body.members.whereType<ConstructorDeclaration>().single;
      expect(constructor.name, isNull);
      expect(constructor.constKeyword, isNotNull);
      expect(constructor.parameters.toSource(), '({super.key})');
      expect(_titleOf(app), "'Settings'");
      final built = _builtBy(app);
      expect(built.byName.keys, isNot(contains('ListView')));
      expect(
        _argument(built.only('SliverFillRemaining'), 'child').toSource(),
        '_NoSettings()',
      );
      // No blank line where the code of the other screen would be.
      expect(text, isNot(contains('\n\n\n')));
      expect(
        text,
        contains(
          '        bottom: false,\n'
          '        child: CustomScrollView(\n',
        ),
      );
    });

    test(
        'names in its note the file of the screen, which a tap copies, and '
        'shows the path in full, at a text size that grows only by half', () {
      final unit = _parsed(app, _screen);
      final note = _Creations.of(_classOf(unit, '_NoSettings'));

      // The path is that of the file itself.
      final path = unit.declarations
          .whereType<TopLevelVariableDeclaration>()
          .single
          .variables;
      expect(path.isConst, isTrue);
      expect(_string(path.variables.single.initializer), _screen);
      expect(app.files.keys, contains(_screen));

      // The texts of the note: that the app has no settings yet, where a
      // setting goes, the path, and what the screen says once it copied the
      // path.
      const hint = 'A module with a setting adds its entry here. You can '
          'add your own in this file.';
      expect(
        [
          for (final shown in note.byName['Text']!)
            switch (shown.arguments.first) {
              // A text without values, as the screen shows it.
              StringLiteral(:final stringValue?) => stringValue,
              final code => code.toSource(),
            },
        ],
        [r"'Copied: $_file'", 'No settings yet', hint, '_file'],
      );
      expect(
        note.only('Clipboard.setData').arguments.single.toSource(),
        'const ClipboardData(text: _file)',
      );
      // The path wraps: nothing cuts it or keeps it on one line.
      final shown = note.byName['Text']!.last;
      expect(_namesOf(shown), {'style'});
      final clamped = note.only('MediaQuery.withClampedTextScaling');
      expect(_argument(clamped, 'maxScaleFactor').toSource(), '1.5');
      expect(
        (_argument(clamped, 'child') as MethodInvocation).argumentList,
        same(shown),
      );
      // In the monospaced font of the device, which is Menlo on iOS.
      final style = note.only('theme.textTheme.bodyMedium.copyWith');
      expect(_argument(style, 'fontFamily').toSource(), "'monospace'");
      expect(
        _argument(style, 'fontFamilyFallback').toSource(),
        "const ['Menlo', 'Courier']",
      );
    });

    test(
        'shows the note at once in an app that is asked for less motion, '
        'and lets it come in once otherwise', () {
      final note = _Creations.of(
        _classOf(_parsed(app, _screen), '_NoSettings'),
      );

      expect(
        _argument(note.only('TweenAnimationBuilder'), 'duration').toSource(),
        'MediaQuery.disableAnimationsOf(context) ? Duration.zero : '
        'Durations.long2',
      );
      // An animation that ends, so that a test of the app can wait for the
      // screen to settle.
      expect(note.byName.keys, isNot(contains('repeat')));
    });
  });

  group('the note of the module for coding agents', () {
    late ContractResult result;
    late RenderedApp app;
    late RenderedApp withEntries;

    setUpAll(() async {
      result = await _rendered(const [SettingsModule.id]);
      app = result.app!;
      withEntries =
          (await _rendered([_feed.id, SettingsModule.id, _look.id])).app!;
    });

    test(
        'is in the section of the settings screen of the guide, after what '
        'the role says, and only the section is new in the guide', () async {
      const settings = ModuleOrigin(SettingsModule.id);
      const role = RoleTemplateOrigin(settingsScreenRole);
      final heading = settingsScreenRole.description;
      final notes = app.entriesOf(AppEntryRole.agentSections);

      // The section has what the role says and what the module adds.
      final ofRole = notes.singleWhere((note) => note.$1 == role).$3;
      expect(ofRole.isOfRole, isTrue);
      expect(
        notes.where((note) => note.$2 == heading),
        unorderedEquals([
          (role, heading, ofRole),
          (settings, heading, AgentNote(agentNote)),
        ]),
      );
      expect(
        app.files[AppEntryRole.agentsFile]!.text,
        contains(
          '\n## $heading\n'
          '\n'
          '${ofRole.text}\n'
          '\n'
          '${agentNote.trim()}\n',
        ),
      );

      // The other notes are those of the app without the module.
      final without = (await _rendered(const [GoRouterModule.id])).app!;
      expect(
        without.files[AppEntryRole.agentsFile]!.text,
        isNot(contains('## $heading')),
      );
      expect(
        notes.where((note) => note.$2 != heading),
        without.entriesOf(AppEntryRole.agentSections),
      );
    });

    test(
        'names in inline code only the screen with its file and its route, '
        'the prefixes of the files of the entries, and the two calls of the '
        'navigation', () {
      final route = settingsScreenRole
          .screenIn(settingsScreenRole.hookInput(result.hook!))!;
      final screen = route.route.screen;

      // Every name of code in the note, so that it cannot name more, such
      // as another file of the app or a class of a router.
      expect(_codeOf(agentNote), {
        screen.className,
        screen.file,
        route.fullName,
        route.fullPath,
        'entry0',
        'entry1',
        'context.nav.settings.settings().push<void>()',
        'go()',
      });
    });

    test(
        'names the screen with its file and its route, and the prefixes of '
        'the files of the entries, as the app has them', () {
      final route = settingsScreenRole
          .screenIn(settingsScreenRole.hookInput(result.hook!))!;
      final screen = route.route.screen;

      // The screen and its route, as the roles have them; the file of the
      // screen declares its class.
      expect(screen.file, _screen);
      expect(_classOf(_parsed(app, _screen), screen.className), isNotNull);
      expect(
        agentNote,
        startsWith(
          '- `${screen.className}` in `${screen.file}`, the route '
          '`${route.fullName}` at `${route.fullPath}`, ',
        ),
      );
      // The prefixes of the files of the entries, in an app with two such
      // files.
      expect(
        _importsOf(withEntries).values.whereType<String>(),
        unorderedEquals(['entry0', 'entry1']),
      );
    });

    test(
        'tells how code opens the screen in an app without a main '
        'navigation, through the navigation of the router role', () {
      final navigation = _parsed(app, RouterRole.navigationFile);

      // What the call names is what the navigation of the app declares.
      expect(_membersOf(navigation, 'AppNav'), contains('settings'));
      expect(_membersOf(navigation, 'SettingsRoutes'), contains('settings'));
      expect(_membersOf(navigation, 'NavLink'), containsAll(['push', 'go']));
    });
  });

  group('the title of the settings screen', () {
    test(
        'is a text that the module gives the localization role, in English '
        'and in Ukrainian', () async {
      final result =
          await _rendered(const [SettingsModule.id, GenL10nModule.id]);
      final input = localizationRole.hookInput(result.hook!);

      // The role has texts of its own too, for its entry of the screen.
      final title = localizationRole
          .textsIn(input)
          .where((text) => text.owner == const ModuleOrigin(SettingsModule.id))
          .single;
      expect(title.getter, 'settingsTitle');
      expect(title.text.en, 'Settings');
      expect(title.text.translations, {'uk': 'Налаштування'});
      expect(localizationRole.localesIn(input), ['en', 'uk']);
    });

    test(
        'is read from the texts of the app by the screen in an app with the '
        'localization role, as a header', () async {
      final result =
          await _rendered(const [SettingsModule.id, GenL10nModule.id]);
      final app = result.app!;

      // The text depends on the language of the context.
      expect(_titleOf(app), 'context.l10n.settingsTitle');
      // The file of the texts of the app, which the pipeline imports for
      // the code of the title, next to the library of the widgets. The
      // imports with a prefix are those of the entries of the screen.
      expect(
        [
          for (final MapEntry(key: uri, value: prefix)
              in _importsOf(app).entries)
            if (prefix == null) uri,
        ],
        [
          LocalizationRole.appTexts.importRef
              .resolveUri(ContractHarness.defaultContext.appName),
          'package:flutter/material.dart',
        ],
      );
    });

    test('is its English text in an app without the localization role',
        () async {
      final result = await _rendered(const [SettingsModule.id]);

      expect(result.hook!.presentRoles, isNot(contains(localizationRole)));
      expect(_titleOf(result.app!), "'Settings'");
      expect(_importsOf(result.app!).keys, [
        'package:flutter/material.dart',
        'package:flutter/services.dart',
      ]);
    });
  });

  group('the label of the destination of the screen', () {
    /// The label as the layout role gets it from the routes of the module,
    /// whichever module provides the role.
    LocalizedText labelOf(ContractResult result) => routerRole
        .facadeOf(routerRole.hookInput(result.hook!))
        .destinations
        .single
        .route
        .destination!
        .label;

    test(
        'is the title of the screen, the one text that the module gives the '
        'localization role', () async {
      final result =
          await _rendered(const [SettingsModule.id, GenL10nModule.id]);
      final input = localizationRole.hookInput(result.hook!);

      // The role has texts of its own too, for its entry of the screen.
      final title = localizationRole
          .textsIn(input)
          .where((text) => text.owner == const ModuleOrigin(SettingsModule.id))
          .single;
      // The label of the destination is that text, so the main navigation
      // of an app with texts reads it from them.
      expect(labelOf(result), same(title.text));
      expect(
        localizationRole
            .appTextOf(
              input,
              const ModuleOrigin(SettingsModule.id),
              labelOf(result),
            )
            ?.getter,
        'settingsTitle',
      );
    });

    test('is its English text in an app without the localization role',
        () async {
      final result = await _rendered(const [SettingsModule.id]);

      expect(result.hook!.presentRoles, isNot(contains(localizationRole)));
      expect(labelOf(result).en, 'Settings');
    });

    test(
        'is read from the texts of the app by the main navigation of an app '
        'with a layout and texts, and is the English text without texts',
        () async {
      String labelsOf(ContractResult result) =>
          result.app!.files[LayoutRole.destinationFile]!.text;
      const function = 'String _settingsSettingsLabel(BuildContext context)';

      final withTexts = await _rendered(
        const [SettingsModule.id, BottomTabsModule.id, GenL10nModule.id],
      );
      expect(
        labelsOf(withTexts),
        contains('$function => context.l10n.settingsTitle;'),
      );

      final without =
          await _rendered(const [SettingsModule.id, BottomTabsModule.id]);
      expect(labelsOf(without), contains("$function => 'Settings';"));
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
        'are the rows of the group of the screen, each created once as a '
        'constant, in the order of the role', () {
      final rows = _rowsOf(app);

      // The group is a constant, and so are the entries in it.
      expect(
        rows.thisOrAncestorOfType<InstanceCreationExpression>()!.toSource(),
        startsWith('const _Group(children: ['),
      );
      expect(rows.elements.map((row) => row.toSource()), [
        'entry0.FeedSetting()',
        'entry1.ThemeSetting()',
        'entry1.FontSetting()',
        'entry2.ZoomSetting()',
      ]);
    });

    test(
        'are below the title in a list of the screen, in one group: a card '
        'that stretches each to its width, with a line between them', () {
      final unit = _parsed(app, _screen);
      final built = _builtBy(app);

      // The screen and its group, and nothing of a screen without settings.
      expect(_declaredBy(app), ['SettingsScreen', '_Group']);
      final list = _argument(built.only('ListView'), 'children') as ListLiteral;
      expect(
        [
          for (final item in list.elements)
            (item as Expression).toSource().split('(').first,
        ],
        ['title', 'const SizedBox', 'const _Group'],
      );
      final group = _Creations.of(_classOf(unit, '_Group'));
      final column = group.only('Column');
      expect(
        (_argument(group.only('Card'), 'child') as MethodInvocation)
            .argumentList,
        same(column),
      );
      expect(
        _argument(column, 'crossAxisAlignment').toSource(),
        'CrossAxisAlignment.stretch',
      );
      expect(
        _argument(column, 'children').toSource(),
        '[for (final (index, child) in children.indexed) ...[if (index > 0) '
        'const Divider(height: 1, indent: 56), child]]',
      );
      // No blank line around the entries.
      expect(app.files[_screen]!.text, isNot(contains('\n\n\n')));
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
        _rowsOf(reversed.app!).elements.map((row) => row.toSource()),
        [
          'entry0.ThemeSetting()',
          'entry0.FontSetting()',
          'entry1.FeedSetting()',
          'entry2.ZoomSetting()',
        ],
      );
    });

    test(
        'have those of the templates of roles after those of the modules, in '
        'the order of the first provider of each role', () async {
      const registry = [..._modules, ContrastModule()];
      const contrast = 'ContrastSetting of lib/${ContrastRole.settingFile}';
      const zoom = 'ZoomSetting of lib/${ZoomRole.settingFile}';
      final look = [
        'ThemeSetting of lib/${_look.settingsFile}',
        'FontSetting of lib/${_look.settingsFile}',
      ];

      // The module with settings is selected last, and its entries are
      // first all the same.
      final result = await _rendered(
        [ContrastModule.id, SettingsModule.id, ZoomModule.id, _look.id],
        registry: registry,
      );
      expect(_entriesOf(result), [...look, contrast, zoom]);

      final swapped = await _rendered(
        [ZoomModule.id, SettingsModule.id, ContrastModule.id, _look.id],
        registry: registry,
      );
      expect(_entriesOf(swapped), [...look, zoom, contrast]);
      expect(
        _rowsOf(swapped.app!).elements.map((row) => row.toSource()),
        [
          'entry0.ThemeSetting()',
          'entry0.FontSetting()',
          'entry1.ZoomSetting()',
          'entry2.ContrastSetting()',
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

    test(
        'are in every app of the module with the localization role, whose '
        'template brings the setting of the language, so the note of a '
        'screen without settings, which is in English, is in no app with '
        'texts', () async {
      final results =
          await ContractHarness(ModuleRegistry(_modules)).checkAll();
      final withScreen = [
        for (final result in results)
          if (result.hook!.presentRoles.contains(settingsScreenRole)) result,
      ];

      // Some with the texts of the app, and some without.
      expect(
        {
          for (final result in withScreen)
            result.hook!.presentRoles.contains(localizationRole),
        },
        {true, false},
      );
      for (final result in withScreen) {
        final name = result.contractCase.name;
        final declared = _declaredBy(result.app!);
        // The screen has the group or the note, by the entries of the role.
        expect(
          declared,
          _entriesOf(result).isEmpty
              ? ['_file', 'SettingsScreen', '_NoSettings']
              : ['SettingsScreen', '_Group'],
          reason: name,
        );
        if (result.hook!.presentRoles.contains(localizationRole)) {
          expect(declared, contains('_Group'), reason: name);
        }
      }
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

    test(
        'has the screen as its only destination in an app with no other '
        'screen, which still starts on the fallback screen', () async {
      final result = await _rendered([SettingsModule.id, BottomTabsModule.id]);

      expect(_labelsOf(result), ['Settings']);
      expect(_startRouteOf(result), isNull);
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

  test(
      'has an app bar, for its back button, only where a screen below it is '
      'there to go back to, with entries and without', () async {
    for (final modules in [
      const [SettingsModule.id],
      [SettingsModule.id, _look.id],
    ]) {
      final built = _builtBy((await _rendered(modules)).app!);

      expect(
        _argument(built.only('Scaffold'), 'appBar').toSource(),
        'back ? AppBar() : null',
        reason: '$modules',
      );
      // As an app bar decides whether it has a back button.
      expect(
        built
            .only('ModalRoute.of')
            .thisOrAncestorOfType<VariableDeclaration>()!
            .toSource(),
        'back = ModalRoute.of(context)?.impliesAppBarDismissal ?? false',
        reason: '$modules',
      );
      // Without an app bar, the icons of the status bar are those that the
      // root of the app tells for every screen: the screen tells none.
      expect(
        built.byName.keys,
        isNot(contains('AnnotatedRegion')),
        reason: '$modules',
      );
    }
  });

  test(
      'has in its example the screen of an app with a setting, as '
      '`smf create` writes it', () async {
    // The app of the example, by its name.
    final result = await _rendered(
      [SettingsModule.id, _look.id],
      context: const ModuleContext(
        appName: 'my_app',
        orgName: 'com.example',
        appIdentity: AppIdentity(
          platforms: ['android', 'ios'],
          androidApplicationId: 'com.example.my_app',
          iosBundleId: 'com.example.myApp',
          androidNamespace: 'com.example.my_app',
        ),
      ),
    );
    // Git may check the example out with the line endings of Windows.
    final example =
        File('example/README.md').readAsStringSync().replaceAll('\r\n', '\n');
    final shown = RegExp(r'```dart\n([\s\S]*?)```').allMatches(example).single;

    /// The code of [text] but for the imports and the list of its entries,
    /// which differ with the modules of an app, and for how it is
    /// formatted.
    String codeOf(String text) {
      final unit = parseString(content: text).unit;
      return unit.declarations
          .map((declaration) => declaration.toSource())
          .join('\n')
          .replaceAll(RegExp(r'const _Group\(children: \[[^\]]*\]\)'), '');
    }

    expect(codeOf(shown[1]!), codeOf(result.app!.files[_screen]!.text));
    // The comments, which the code leaves out.
    List<String> commentsOf(String text) => [
          for (final line in text.split('\n'))
            if (line.trimLeft().startsWith('//')) line.trim(),
        ];
    expect(commentsOf(shown[1]!), commentsOf(result.app!.files[_screen]!.text));
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
