import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:smf_bottom_tabs/smf_bottom_tabs.dart';
import 'package:smf_bottom_tabs/src/agents.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_gen_l10n/smf_gen_l10n.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:smf_shared_preferences/smf_shared_preferences.dart';
import 'package:test/test.dart';

import 'support/features.dart';

/// The features of the tests, whose destinations are Inbox, the start
/// screen, and Search. The first gives the localization role its label, a
/// text in two languages, and the second does not list that role.
const _inbox = TabFeature('inbox', startCandidate: true, localized: true);
const _search = TabFeature('search');

/// The modules of the tests: flutter_core, which creates the app, go_router,
/// which builds its main navigation, this module, two features, gen_l10n,
/// which keeps the texts of the app, for the labels of the destinations,
/// and shared_preferences, in which the app remembers its language.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  GoRouterModule(),
  BottomTabsModule(),
  _inbox,
  _search,
  GenL10nModule(),
  SharedPreferencesModule(),
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

/// The class [name] of [unit].
ClassDeclaration _classOf(CompilationUnit unit, String name) =>
    unit.declarations.whereType<ClassDeclaration>().singleWhere(
          (declaration) => declaration.namePart.typeName.lexeme == name,
        );

/// The method [name] of [declaration].
MethodDeclaration _methodOf(ClassDeclaration declaration, String name) =>
    declaration.body.members
        .whereType<MethodDeclaration>()
        .singleWhere((method) => method.name.lexeme == name);

/// The calls in a piece of code by what they call, such as `Semantics` or
/// `MediaQuery.withClampedTextScaling`: the widgets that a build method
/// creates, with or without `const`, and the functions that it calls.
final class _Calls extends RecursiveAstVisitor<void> {
  final Map<String, List<ArgumentList>> byName = {};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.realTarget;
    final name = node.methodName.name;
    byName
        .putIfAbsent(
          target == null ? name : '${target.toSource()}.$name',
          () => [],
        )
        .add(node.argumentList);
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

/// The calls in [node], by what they call.
Map<String, List<ArgumentList>> _callsIn(AstNode node) {
  final calls = _Calls();
  node.accept(calls);
  return calls.byName;
}

/// The arguments of [call], each as its code: a named one under its name,
/// and the others under their positions.
Map<String, String> _argumentsOf(ArgumentList call) {
  var position = 0;
  return {
    for (final argument in call.arguments)
      if (argument case NamedArgument(:final name, :final argumentExpression))
        name.lexeme: argumentExpression.toSource()
      else
        '${position++}': argument.argumentExpression.toSource(),
  };
}

/// The value of the top-level constant [name] of [unit], as its code.
String _constantOf(CompilationUnit unit, String name) => unit.declarations
    .whereType<TopLevelVariableDeclaration>()
    .expand((declaration) => declaration.variables.variables)
    .singleWhere((variable) => variable.name.lexeme == name)
    .initializer!
    .toSource();

/// The labels of the destinations of the main navigation of the app of
/// [result] in English, in their order, as the layout role has them, whose
/// list of the destinations the router gives the shell of the layout,
/// whichever module provides it.
List<String> _labelsOf(ContractResult result) => [
      for (final route
          in layoutRole.destinationsIn(layoutRole.hookInput(result.hook!)))
        route.route.destination!.label.en,
    ];

/// The modules that provide [role] in the app of [result], whichever they
/// are.
Set<ModuleId> _providersOf(ContractResult result, Role role) => {
      for (final module in result.resolution!.providersOf(role)) module.id,
    };

void main() {
  const module = BottomTabsModule();

  group('BottomTabsModule', () {
    test('is a layout, which requires the router', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('bottom_tabs'));
      expect(descriptor.kind, ModuleKinds.layout);
      expect(descriptor.provides, {layoutRole});
      // The layout role requires the router, and uses the localization
      // role, for the labels of the destinations.
      expect(descriptor.requires, isEmpty);
      expect(descriptor.effectiveRequires, {routerRole});
      expect(descriptor.uses, isEmpty);
      expect(descriptor.effectiveUses, {localizationRole});
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

    test(
        'builds the apps with and without the layout, and the app of the '
        'layout with and without the texts of the app', () {
      // The app of this module is the app of go_router with the layout.
      expect(results.map((result) => result.contractCase.name), [
        'flutter_core with router',
        'flutter_core',
        'go_router with layout',
        'bottom_tabs with localization',
        'inbox with localization',
        'inbox',
        'search',
        'gen_l10n',
        'shared_preferences',
      ]);
    });

    test(
        'checks each module with the provider of each role it requires or '
        'uses', () async {
      expect(
        await ContractHarness(ModuleRegistry(_modules)).uncheckedProviders(),
        isEmpty,
      );
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
          'flutter_core':
              'the only provider of the app entry role, which every app needs',
          'go_router': 'the only provider of the router role, which '
              'bottom_tabs requires',
        },
      );
    });

    test(
        'gets the brick of the shell and its note for coding agents, and '
        'nothing else', () {
      final contributions = [
        for (final collected
            in result.collection!.ofModule(BottomTabsModule.id))
          collected.contribution,
      ];

      expect(contributions, hasLength(2));
      final brick = contributions.first as BrickContribution;
      expect(brick.bundle.name, 'bottom_tabs');
      expect(brick.bundle.files.map((file) => file.path), [_shell]);
      expect(brick.vars, isEmpty);
      final note = contributions.last as SocketContribution;
      expect(note.socket, AppEntryRole.agentSections);
      expect(note.entryKey, layoutRole.description);
      expect(note.entryValue, AgentNote(agentNote));
      expect(note.when, isEmpty);
    });

    test(
        'tells coding agents of the bar that its shell draws, of where the '
        'bar takes its colours, of what a tab says to a screen reader and of '
        'the most destinations that it takes', () {
      final text = app.files[_shell]!.text;
      final index = DartFileIndexer.index(_shell, text);

      // The bar of the shell and its tabs, which the shell leaves out with
      // fewer than two destinations.
      expect(index.invocationsOf('_TabBar', within: 'AppShell'), hasLength(1));
      expect(index.invocationsOf('_Tab', within: '_TabBar'), hasLength(1));
      expect(text, contains('destinations.length < 2'));
      expect(agentNote, contains('fewer than two'));
      // The names that the note gives as code are names of the file.
      for (final name in [LayoutRole.appShell.name, '_TabBar', '_Tab']) {
        expect(agentNote, contains('`$name`'), reason: name);
        expect(index.declaration(name), isNotNull, reason: name);
      }
      // The colours of a tab, which it reads from the theme.
      for (final name in ['colorScheme', 'secondary', 'onSurfaceVariant']) {
        expect(agentNote, contains('`$name`'), reason: name);
        expect(
          index.memberAccesses.where(
            (access) =>
                access.name == name && access.enclosingDeclaration == '_Tab',
          ),
          isNotEmpty,
          reason: name,
        );
      }
      // The bar is drawn by the file, so no theme of a bar of Flutter
      // changes it.
      expect(
        index.invocations.map((invocation) => invocation.name),
        isNot(anyElement(endsWith('NavigationBar'))),
      );
      // What a tab says to a screen reader.
      expect(agentNote, contains('`Semantics`'));
      expect(index.invocationsOf('Semantics', within: '_Tab'), hasLength(1));
      // As many as the module lets smf create put into the app.
      expect(BottomTabsModule.maxDestinations, 5);
      expect(agentNote, contains('Keep to five destinations'));
    });

    test(
        'is the app without it but for the shell, the destinations, the '
        'router and the section of the layout in the guide for coding agents',
        () {
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
      // The pubspec too: the shell needs nothing but Flutter. The router
      // builds its main navigation around the shell.
      final router = _providersOf(result, routerRole);
      final ofRouter = <String>[];
      for (final MapEntry(key: path, value: file) in without.files.entries) {
        if (path == AppEntryRole.agentsFile) continue;
        if (file.owner case ModuleOrigin(:final module)
            when router.contains(module)) {
          if (app.files[path]!.text != file.text) ofRouter.add(path);
          continue;
        }
        expect(app.files[path]!.bytes, file.bytes, reason: path);
      }
      expect(ofRouter, isNotEmpty);
      // The guide has the notes of the app without the layout, and those of
      // the layout under the heading of the role. The router, which builds
      // the main navigation, may tell of it too.
      final layout = <ContributionOrigin>{
        const RoleTemplateOrigin(layoutRole),
        const ModuleOrigin(BottomTabsModule.id),
      };
      bool byRouter(ContributionOrigin origin) => switch (origin) {
            ModuleOrigin(:final module) => router.contains(module),
            _ => false,
          };
      final notes = app.entriesOf(AppEntryRole.agentSections);
      expect(
        notes.where((note) => !layout.contains(note.$1) && !byRouter(note.$1)),
        without
            .entriesOf(AppEntryRole.agentSections)
            .where((note) => !byRouter(note.$1)),
      );
      // The template of a role contributes after its providers; the guide
      // shows what the role says first.
      expect(
        [
          for (final (origin, heading, note) in notes)
            if (layout.contains(origin)) (origin, heading, note.isOfRole),
        ],
        [
          (
            const ModuleOrigin(BottomTabsModule.id),
            layoutRole.description,
            false,
          ),
          (const RoleTemplateOrigin(layoutRole), layoutRole.description, true),
        ],
      );
      expect(
        [
          for (final (origin, _, note) in notes)
            if (origin == const ModuleOrigin(BottomTabsModule.id)) note,
        ],
        [AgentNote(agentNote)],
      );
    });

    test(
        'shows a bar with a tab for each destination below the screen of the '
        'selected one, and no bar with fewer than two', () {
      final unit = _parsed(app, _shell);
      final shell = _classOf(unit, 'AppShell');

      expect(
        unit.directives.map((directive) => directive.toSource()),
        [
          "import 'package:flutter/material.dart';",
          "import 'package:flutter/services.dart';",
          "import 'destination.dart';",
        ],
      );
      // The shell, which the role requires, and what it is made of, all
      // private to the file.
      expect(
        unit.declarations
            .whereType<ClassDeclaration>()
            .map((declaration) => declaration.namePart.typeName.lexeme),
        [
          'AppShell',
          '_TabBar',
          '_Tab',
          '_BranchTransition',
          '_BranchTransitionState',
        ],
      );
      expect(shell.extendsClause!.superclass.name.lexeme, 'StatelessWidget');
      final constructor =
          shell.body.members.whereType<ConstructorDeclaration>().single;
      expect(constructor.name, isNull);
      expect(constructor.constKeyword, isNotNull);
      expect(
        constructor.parameters.toSource(),
        '({required this.destinations, required this.currentIndex, '
        'required this.onSelect, required this.body, super.key})',
      );
      expect(
        {
          for (final field in shell.body.members.whereType<FieldDeclaration>())
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
      // The screen of the selected destination, which the shell lets fade
      // in when the destination changes, above the bar.
      expect(
        (_methodOf(shell, 'build').body as ExpressionFunctionBody)
            .expression
            .toSource(),
        'Scaffold(body: _BranchTransition(index: currentIndex, child: body), '
        'bottomNavigationBar: destinations.length < 2 ? null : '
        '_TabBar(destinations: destinations, currentIndex: currentIndex, '
        'onTap: _tapped))',
      );
      // A tab for each destination, in their order, which share the width
      // of the bar. The tab of the selected destination knows it.
      final bar = _callsIn(_methodOf(_classOf(unit, '_TabBar'), 'build'));
      expect(
        bar['Row']!.single.arguments.single.toSource(),
        'children: [for (final (index, destination) in destinations.indexed) '
        'Expanded(child: _Tab(destination: destination, selected: index == '
        'currentIndex, onTap: () => onTap(index)))]',
      );
    });

    test(
        'draws the bar in the colours of the theme, with a hairline above '
        'the tabs, and the selected tab in the accent colour', () {
      final unit = _parsed(app, _shell);
      final bar = _callsIn(_methodOf(_classOf(unit, '_TabBar'), 'build'));
      final tab = _callsIn(_methodOf(_classOf(unit, '_Tab'), 'build'));

      // A Material of its own, on which the ink of a tab shows, above the
      // inset at the bottom of the device.
      expect(_argumentsOf(bar['Material']!.single), {
        'color': 'colors.surface',
        'shape': 'Border(top: BorderSide(color: colors.outlineVariant))',
        'child': startsWith('SafeArea(top: false, child: Row('),
      });
      // The icon and the label take their colour over time, and nothing
      // else of a tab depends on whether it is selected, so a tab keeps
      // its size.
      expect(
        _argumentsOf(tab['ColorTween']!.single),
        {'end': 'selected ? colors.secondary : colors.onSurfaceVariant'},
      );
      expect(
        _argumentsOf(tab['Icon']!.single),
        {'0': 'destination.icon', 'size': '24', 'color': 'color'},
      );
      expect(_argumentsOf(tab['Text']!.single), {
        '0': 'label',
        'maxLines': '1',
        'overflow': 'TextOverflow.ellipsis',
        'style': 'theme.textTheme.labelMedium?.copyWith(color: color)',
      });
      final index = DartFileIndexer.index(_shell, app.files[_shell]!.text);
      expect(
        index.references.where(
          (reference) =>
              reference.name == 'selected' &&
              reference.enclosingDeclaration == '_Tab',
        ),
        // In the tween of the colour and in what the tab says to a screen
        // reader.
        hasLength(2),
      );
    });

    test(
        'gives the device a tick when the user taps the tab of another '
        'destination, and the router each tap', () {
      final unit = _parsed(app, _shell);
      final tapped = _methodOf(_classOf(unit, 'AppShell'), '_tapped');

      expect(tapped.parameters!.toSource(), '(int index)');
      expect(
        tapped.body.toSource(),
        '{if (index != currentIndex) HapticFeedback.selectionClick(); '
        'onSelect(index);}',
      );
      // The tab takes a tap on the whole of it, with the ink of the theme.
      final tab = _callsIn(_methodOf(_classOf(unit, '_Tab'), 'build'));
      expect(
        _argumentsOf(tab['InkResponse']!.single),
        containsPair('onTap', 'onTap'),
      );
    });

    test(
        'says each tab to a screen reader as one button with the label of '
        'its destination, selected or not', () {
      final unit = _parsed(app, _shell);
      final tab = _callsIn(_methodOf(_classOf(unit, '_Tab'), 'build'));

      final semantics = _argumentsOf(tab['Semantics']!.single);
      expect(semantics.keys, [
        'container',
        'button',
        'selected',
        'label',
        'child',
      ]);
      expect(
        {...semantics}..remove('child'),
        {
          'container': 'true',
          'button': 'true',
          'selected': 'selected',
          'label': 'label',
        },
      );
      // The tap of the tab is below that node, and so is what the tab
      // shows, which a screen reader does not read a second time.
      expect(semantics['child'], contains('InkResponse(onTap: onTap,'));
      final excluded = tab['ExcludeSemantics']!.single.toSource();
      expect(excluded, contains('Icon(destination.icon,'));
      expect(excluded, contains('Text(label,'));
      // The tooltip of the tab says its label a second time, so it stays
      // out of what the tab says.
      expect(
        _argumentsOf(tab['Tooltip']!.single),
        containsPair('excludeFromSemantics', 'true'),
      );
    });

    test(
        'fits large text: the bar grows from 64 with its labels, which the '
        'text size of the device scales at most 1.3 times, and a long press '
        'shows a label in a tooltip', () {
      final unit = _parsed(app, _shell);
      final tab = _callsIn(_methodOf(_classOf(unit, '_Tab'), 'build'));

      expect(_constantOf(unit, '_barHeight'), '64');
      expect(_constantOf(unit, '_maxLabelScale'), '1.3');
      // The least height of a tab, and so of the bar, which has no height
      // of its own.
      expect(
        _argumentsOf(tab['BoxConstraints']!.single),
        {'minHeight': '_barHeight'},
      );
      expect(
        app.files[_shell]!.text,
        isNot(anyOf(contains('height: _barHeight'), contains('height: 64'))),
      );
      // The column of the icon and the label is as high as they are, in
      // the middle of the tab.
      expect(_argumentsOf(tab['Column']!.single), {
        'mainAxisSize': 'MainAxisSize.min',
        'mainAxisAlignment': 'MainAxisAlignment.center',
        'children': anything,
      });
      final clamped =
          _argumentsOf(tab['MediaQuery.withClampedTextScaling']!.single);
      expect(clamped['maxScaleFactor'], '_maxLabelScale');
      expect(clamped['child'], startsWith('Text(label,'));
      // The tooltip is above the bar, with the label that the tab builds
      // with.
      final tooltip = _argumentsOf(tab['Tooltip']!.single);
      expect(tooltip['message'], 'label');
      expect(tooltip['preferBelow'], 'false');
    });

    test(
        'moves nothing for a user who asks for less motion, and nothing '
        'without an end', () {
      final text = app.files[_shell]!.text;
      final unit = _parsed(app, _shell);
      final index = DartFileIndexer.index(_shell, text);

      // The tab and the transition of the screen ask.
      expect(
        [
          for (final invocation in index.invocationsOf('disableAnimationsOf'))
            (
              invocation.target,
              invocation.enclosingDeclaration,
              invocation.enclosingMember,
            ),
        ],
        [
          ('MediaQuery', '_Tab', 'build'),
          ('MediaQuery', '_BranchTransitionState', 'didUpdateWidget'),
        ],
      );
      final tab = _methodOf(_classOf(unit, '_Tab'), 'build');
      expect(
        tab.toSource(),
        contains(
          'final duration = MediaQuery.disableAnimationsOf(context) ? '
          'Duration.zero : Durations.medium2;',
        ),
      );
      expect(
        _argumentsOf(_callsIn(tab)['TweenAnimationBuilder']!.single),
        containsPair('duration', 'duration'),
      );
      // The screen of another destination fades in once, from the start,
      // or is shown at once. The same destination moves nothing.
      expect(
        _methodOf(_classOf(unit, '_BranchTransitionState'), 'didUpdateWidget')
            .body
            .toSource(),
        '{super.didUpdateWidget(oldWidget); if (oldWidget.index == '
        'widget.index) return; if (MediaQuery.disableAnimationsOf(context)) '
        '{_controller.value = 1;} else {_controller.forward(from: 0);}}',
      );
      // The controller of the transition starts at its end, so the first
      // screen is shown as it is, and nothing runs it but that forward.
      expect(
        _argumentsOf(_callsIn(unit)['AnimationController']!.single),
        {'vsync': 'this', 'duration': 'Durations.medium2', 'value': '1'},
      );
      expect(
        index.invocations
            .where((invocation) => invocation.target == '_controller')
            .map((invocation) => invocation.name),
        ['forward', 'dispose'],
      );
      expect(index.invocationsOf('repeat'), isEmpty);
    });

    test(
        'shows the label of each destination as the destination returns it '
        'when its tab builds, so in the language that the app is in', () {
      final index = DartFileIndexer.index(_shell, app.files[_shell]!.text);

      // In the build of the tab, with its context, and nowhere else: the
      // shell keeps no label. The text of the tab, its tooltip and what it
      // says to a screen reader all take the label from there.
      final labels = index.invocationsOf('label');
      expect(labels.single.target, 'destination');
      expect(labels.single.enclosingDeclaration, '_Tab');
      expect(labels.single.enclosingMember, 'build');
      expect(
        app.files[_shell]!.text,
        contains('final label = destination.label(context);'),
      );
      // A tab has no state to keep a label in.
      expect(
        _classOf(_parsed(app, _shell), '_Tab')
            .extendsClause!
            .superclass
            .name
            .lexeme,
        'StatelessWidget',
      );
    });

    test(
        'gets the label of a feature from the texts of the app in an app '
        'with them, when the feature gave them its label, and in English '
        'otherwise', () async {
      final withTexts = await _rendered([
        _inbox.id,
        _search.id,
        BottomTabsModule.id,
        GenL10nModule.id,
      ]);
      // The texts of the app, as the localization role has them: the label
      // of the feature that gave it one.
      final input = localizationRole.hookInput(withTexts.hook!);
      expect(
        [for (final text in localizationRole.textsIn(input)) text.getter],
        ['inboxLabel'],
      );
      expect(localizationRole.localesIn(input), ['en', 'uk']);

      // The list of the destinations of the layout role, which the router
      // gives the shell.
      String labelsOf(RenderedApp app) =>
          app.files[LayoutRole.destinationFile]!.text;
      expect(
        labelsOf(withTexts.app!),
        allOf(
          contains(
            'String _inboxInboxLabel(BuildContext context) => '
            'context.l10n.inboxLabel;',
          ),
          contains(
            "String _searchSearchLabel(BuildContext context) => 'Search';",
          ),
        ),
      );
      // Without the texts of the app, each label is its English text.
      expect(result.hook!.presentRoles, isNot(contains(localizationRole)));
      expect(
        labelsOf(app),
        allOf(
          contains(
            "String _inboxInboxLabel(BuildContext context) => 'Inbox';",
          ),
          contains(
            "String _searchSearchLabel(BuildContext context) => 'Search';",
          ),
        ),
      );
      // The shell is the same in both apps.
      expect(
        withTexts.app!.files[_shell]!.text,
        app.files[_shell]!.text,
      );
    });

    test(
        'is built by the router with the destinations of the features, in '
        'their order', () async {
      expect(_labelsOf(result), ['Inbox', 'Search']);

      final reversed =
          await _rendered([_search.id, _inbox.id, BottomTabsModule.id]);
      expect(_labelsOf(reversed), ['Search', 'Inbox']);
    });

    test('is built with one destination too, whose bar the shell hides',
        () async {
      final result = await _rendered([_inbox.id, BottomTabsModule.id]);

      expect(_labelsOf(result), ['Inbox']);
    });

    test('has no shell to show without destinations', () async {
      final result = await _rendered(const [BottomTabsModule.id]);

      expect(result.app!.files.keys, contains(_shell));
      expect(_labelsOf(result), isEmpty);
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
        _labelsOf(result),
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
