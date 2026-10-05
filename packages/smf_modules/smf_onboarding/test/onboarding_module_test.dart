@TestOn('vm')
library;

import 'dart:convert';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_gen_l10n/smf_gen_l10n.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_onboarding/bundles/onboarding_bundle.dart';
import 'package:smf_onboarding/smf_onboarding.dart';
import 'package:smf_onboarding/src/agents.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

import 'support/dart_app.dart';
import 'support/providers.dart';

/// A feature of the tests whose screen can start the app.
const _feed = StartFeature('feed');

/// The modules of the tests: flutter_core, which creates the app,
/// go_router, which routes it and asks the guard of the module, preferences
/// in memory, gen_l10n, which provides the localization role, a feature
/// that can start the app, and this module.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  GoRouterModule(),
  MemoryPreferencesModule(),
  GenL10nModule(),
  _feed,
  OnboardingModule(),
];

/// The paths of the files of the module in the app.
const _folder = 'lib/features/onboarding';
const _screen = '$_folder/onboarding_screen.dart';
const _pages = '$_folder/onboarding_pages.dart';
const _status = '$_folder/onboarding_status.dart';

/// The owner of the files of the module.
const _module = ModuleOrigin(OnboardingModule.id);

/// The getters of the texts of the module in an app with the localization
/// role, each with its English text, in the order of the texts.
const _texts = {
  'onboardingWelcome': 'Welcome! We are glad you are here.',
  'onboardingReadyTitle': 'You are all set',
  'onboardingReady': 'Enjoy the app.',
  'onboardingSkip': 'Skip',
  'onboardingNext': 'Next',
  'onboardingDone': 'Done',
};

/// The Ukrainian texts of the module, by the same getters.
const _ukrainian = {
  'onboardingWelcome': 'Вітаємо! Раді, що ви з нами.',
  'onboardingReadyTitle': 'Усе готово',
  'onboardingReady': 'Приємного користування!',
  'onboardingSkip': 'Пропустити',
  'onboardingNext': 'Далі',
  'onboardingDone': 'Готово',
};

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
        description: 'Annotates the screen of the onboarding (test)',
        kind: ModuleKinds.infrastructure,
        uses: {routerRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        SocketContribution.code(
          RouterRole.screenAnnotations(
            (feature: OnboardingModule.id, screen: 'OnboardingScreen'),
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

/// The top-level function [name] of [unit].
FunctionDeclaration _functionOf(CompilationUnit unit, String name) =>
    unit.declarations
        .whereType<FunctionDeclaration>()
        .singleWhere((declaration) => declaration.name.lexeme == name);

/// The method [name] of the class [type] of [unit].
MethodDeclaration _methodOf(CompilationUnit unit, String type, String name) =>
    _classOf(unit, type)
        .body
        .members
        .whereType<MethodDeclaration>()
        .singleWhere((method) => method.name.lexeme == name);

/// The local variables that [method] declares, each with the code of its
/// value, by their names.
Map<String, String> _variablesOf(MethodDeclaration method) {
  final visitor = _Variables();
  method.accept(visitor);
  return visitor.values;
}

final class _Variables extends RecursiveAstVisitor<void> {
  final Map<String, String> values = {};

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (node.initializer case final value?) {
      values[node.name.lexeme] = value.toSource();
    }
    super.visitVariableDeclaration(node);
  }
}

/// The `for` elements of the collections in [method], in the order of the
/// code.
List<ForElement> _forElementsOf(MethodDeclaration method) {
  final visitor = _ForElements();
  method.accept(visitor);
  return visitor.found;
}

final class _ForElements extends RecursiveAstVisitor<void> {
  final List<ForElement> found = [];

  @override
  void visitForElement(ForElement node) {
    found.add(node);
    super.visitForElement(node);
  }
}

/// The URIs of the imports of [unit].
List<String> _importsOf(CompilationUnit unit) => [
      for (final directive in unit.directives.whereType<ImportDirective>())
        directive.uri.stringValue!,
    ];

/// The values of the string literals in the declarations of [unit], in
/// the order of the code.
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

/// The route that the router role chose to start the app of [result] on,
/// as every router gets it, whichever module provides the role.
FacadeRoute? _startRouteOf(ContractResult result) =>
    routerRole.startIn(routerRole.hookInput(result.hook!));

/// The guards of the routes of the app of [result], as the router role
/// gives them to every router, in the order the app asks them.
List<FacadeGuard> _guardsOf(ContractResult result) =>
    routerRole.facadeOf(routerRole.hookInput(result.hook!)).guards;

/// The modules that provide [role] in the app of [result], whichever they
/// are.
Set<ModuleId> _providersOf(ContractResult result, Role role) => {
      for (final module in result.resolution!.providersOf(role)) module.id,
    };

/// The contributions to [socket] in the app of [result], those of the
/// render hooks of the roles included, in the order they were rendered,
/// each as its contributor and its code.
List<String> _contributionsTo(ContractResult result, SocketRef socket) => [
      for (final collected in result.app!.socketOrders[socket]?.contributions ??
          const <Collected>[])
        _described(collected),
    ];

/// The contribution [collected] to a socket as its contributor and its code.
String _described(Collected collected) {
  final contribution = collected.contribution as SocketContribution;
  return '${collected.origin}: ${contribution.fragment!.code}';
}

/// The index of the Dart file at [path] of [app].
DartFileIndex _indexOf(RenderedApp app, String path) =>
    DartFileIndexer.index(path, app.files[path]!.text);

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

/// Runs [body] as the `main` of a script in an isolate of its own, with
/// the Dart files of [app], and returns what it puts into `result`.
///
/// The script imports the preferences of the app, those of the tests, in
/// memory, and the status of the onboarding. `completed` is what the guard
/// of the module asks, and `heard` has each value that it told its
/// listeners of.
Future<Map<Object?, Object?>> _run(RenderedApp app, String body) async {
  final dartApp = DartApp.write(app);
  try {
    return (await dartApp.run('''
import 'dart:isolate';

import 'package:contract_app/core/preferences/app_preferences.dart';
import 'package:contract_app/${MemoryPreferencesModule.file}';
import 'package:contract_app/features/onboarding/onboarding_status.dart';

const key = '${OnboardingModule.completedKey}';

Future<void> main(List<String> arguments, SendPort port) async {
  final result = <String, Object?>{};
  final completed = onboardingCompleted();
  final heard = <bool>[];
  completed.addListener(() => heard.add(completed.value));
$body
  port.send(result);
}
'''))! as Map<Object?, Object?>;
  } finally {
    dartApp.delete();
  }
}

void main() {
  const module = OnboardingModule();

  group('OnboardingModule', () {
    test(
        'is a feature without variants, which requires the router and the '
        'preferences and uses the localization', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('onboarding'));
      expect(descriptor.kind, ModuleKinds.feature);
      expect(descriptor.provides, isEmpty);
      // The kind makes a feature require the router.
      expect(descriptor.requires, {preferencesRole});
      expect(descriptor.effectiveRequires, {preferencesRole, routerRole});
      expect(descriptor.effectiveUses, {localizationRole});
      expect(descriptor.dependsOn, isEmpty);
      expect(descriptor.variants, isNull);
    });

    test('forms a valid registry with the modules of the tests', () {
      expect(ModuleRegistry.problemsOf(_modules), isEmpty);
    });

    test(
        'declares one route: the onboarding at / of the module, which is no '
        'destination and on which the app does not start', () {
      final data = [
        for (final contribution
            in module.contribute(ContractHarness.defaultContext))
          if (contribution is RoleData<RoutesData>) contribution,
      ].single;

      expect(data.role, routerRole);
      final route = data.value.routes.single;
      expect(route.path, '/');
      expect(route.name, 'onboarding');
      expect(route.screen.className, 'OnboardingScreen');
      expect(route.screen.file, _screen);
      expect(route.params, isEmpty);
      expect(route.children, isEmpty);
      expect(route.destination, isNull);
      expect(route.startCandidate, isFalse);
    });

    test(
        'declares the guard firstRun, which shows its route until the '
        'function of the status of the onboarding says otherwise', () {
      final data = [
        for (final contribution
            in module.contribute(ContractHarness.defaultContext))
          if (contribution is RoleData<RoutesData>) contribution,
      ].single;

      final guard = data.value.guards.single;
      expect(guard.name, 'firstRun');
      expect(guard.redirectTo, data.value.routes.single.name);
      expect(guard.allows.name, 'onboardingCompleted');
      expect(
        guard.allows.import,
        const ImportRef.app('features/onboarding/onboarding_status.dart'),
      );
    });

    test('has each of its texts in English and in Ukrainian', () {
      expect(OnboardingModule.texts.texts, hasLength(_texts.length));
      for (final text in OnboardingModule.texts.texts) {
        expect(text.problems(), isEmpty, reason: '$text');
        expect(text.languages, ['en', 'uk'], reason: '$text');
      }
      expect(
        [for (final text in OnboardingModule.texts.texts) text.en],
        _texts.values,
      );
      expect(
        [for (final text in OnboardingModule.texts.texts) text.textIn('uk')],
        _ukrainian.values,
      );
    });

    test(
        'contributes its brick with the key of the preferences and the '
        'texts, its route with the guard, its restorer, its texts and its '
        'note for coding agents, and nothing else', () {
      final contributions = module.contribute(ContractHarness.defaultContext);

      expect(contributions, hasLength(5));
      final brick = contributions[0] as BrickContribution;
      expect(brick.bundle, same(onboardingBundle));
      expect(brick.bundle.name, 'onboarding');
      expect(
        [for (final file in brick.bundle.files) file.path]..sort(),
        [_pages, _screen, _status],
      );
      expect(brick.when, isEmpty);
      expect(brick.vars.keys, [
        'completed_key',
        'text_welcome',
        'text_ready_title',
        'text_ready',
        'text_skip',
        'text_next',
        'text_done',
      ]);
      expect(brick.vars['completed_key'], "'onboarding.completed'");
      expect(OnboardingModule.completedKey, 'onboarding.completed');
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
      expect(contributions[1], isA<RoleData<RoutesData>>());
      final restorer = contributions[2] as SocketContribution;
      expect(restorer.socket, PreferencesRole.restorers);
      expect(restorer.fragment!.code, 'restoreOnboarding');
      expect(
        restorer.fragment!.imports,
        [const ImportRef.app('features/onboarding/onboarding_status.dart')],
      );
      // The module requires the preferences, so every app with it has them.
      expect(restorer.when, isEmpty);
      final texts = contributions[3] as RoleData<TextsData>;
      expect(texts.role, localizationRole);
      expect(texts.value, same(OnboardingModule.texts));
      final note = contributions[4] as SocketContribution;
      expect(note.socket, AppEntryRole.agentSections);
      expect(note.entryKey, agentHeading);
      expect(note.entryValue, AgentNote(agentNote));
      expect(note.when, isEmpty);
    });
  });

  group('the contract harness', () {
    late List<ContractResult> results;

    setUpAll(() async {
      results = await ContractHarness(ModuleRegistry(_modules)).checkAll();
    });

    test(
        'builds the app of the module with the localization and without, '
        'each with the router and the preferences that it requires', () {
      expect(results.map((result) => result.contractCase.name), [
        'flutter_core with router',
        'flutter_core',
        'memory_preferences',
        'gen_l10n',
        'feed',
        'onboarding with localization',
        'onboarding',
      ]);
      for (final result in results) {
        if (!result.contractCase.name.startsWith('onboarding')) continue;
        expect(
          [
            for (final role in <Role>[
              routerRole,
              preferencesRole,
              localizationRole,
            ])
              _providersOf(result, role),
          ],
          [
            {GoRouterModule.id},
            {MemoryPreferencesModule.id},
            if (result.contractCase.name == 'onboarding')
              isEmpty
            else
              {GenL10nModule.id},
          ],
          reason: '${result.contractCase}',
        );
      }
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

  group('the app with the onboarding', () {
    late ContractResult result;
    late RenderedApp app;
    late RenderedApp without;

    setUpAll(() async {
      result = await _rendered(const [OnboardingModule.id]);
      app = result.app!;
      without = (await _rendered(
        const [GoRouterModule.id, MemoryPreferencesModule.id],
      ))
          .app!;
    });

    test('gets the only router and the only preferences, which it requires',
        () {
      expect(
        {
          for (final module in result.resolution!.modules)
            '${module.id}': '${module.reason}',
        },
        {
          'onboarding': 'requested',
          'flutter_core':
              'the only provider of the app entry role, which every app needs',
          'memory_preferences': 'the only provider of the preferences role, '
              'which onboarding requires',
          'go_router': 'the only provider of the router role, which '
              'onboarding requires',
        },
      );
    });

    test(
        'is the app of the router and of the preferences but for its files, '
        'its route with the guard, its restorer and its note', () {
      // The provider of the router renders the route and asks the guard in
      // files of its own, whichever they are.
      final changedBy = _providersOf(result, routerRole);

      expect(
        app.files.keys.toSet(),
        {...without.files.keys, _pages, _screen, _status},
      );
      for (final path in [_pages, _screen, _status]) {
        expect(app.files[path]!.owner, _module, reason: path);
      }
      final changed = <String>[];
      for (final MapEntry(key: path, value: file) in without.files.entries) {
        expect(app.files[path]!.owner, file.owner, reason: path);
        if (_sameBytes(app.files[path]!.bytes, file.bytes)) continue;
        if (file.owner case ModuleOrigin(:final module)
            when changedBy.contains(module)) {
          continue;
        }
        changed.add(path);
      }
      // The templates of the roles render what the module gives them: the
      // navigation and the guards of the router role, the restorers of the
      // preferences role and the guide of the app entry. The pubspec is
      // that of the app without the module, which adds no package.
      expect(
        changed,
        unorderedEquals([
          RouterRole.navigationFile,
          RouterRole.appRouterFile,
          PreferencesRole.file,
          AppEntryRole.agentsFile,
        ]),
      );
      // The guide has the notes of the app without the module, the section
      // of the module, and the note of the router role about the guards of
      // the routes, which an app without a guard lacks. The note of the
      // module leaves to it what a router does with a guard.
      final notes = app.entriesOf(AppEntryRole.agentSections);
      final notesWithout = without.entriesOf(AppEntryRole.agentSections);
      bool ofGuards((ContributionOrigin, String, AgentNote) note) =>
          note.$1 == const RoleTemplateOrigin(routerRole) &&
          note.$3.text.contains('`${RouterRole.routeGuards}`');
      expect(notesWithout.where(ofGuards), isEmpty);
      expect(notes.where(ofGuards), hasLength(1));
      expect(
        notes.where((note) => note.$1 != _module && !ofGuards(note)),
        notesWithout,
      );
    });

    test(
        'keeps the user in the onboarding with one guard of the routes, '
        'whose target and whole flow is its route', () {
      final guard = _guardsOf(result).single;

      expect(guard.fullName, 'onboarding.firstRun');
      expect(guard.feature.module, OnboardingModule.id);
      expect(guard.target.fullName, 'onboarding.onboarding');
      expect(guard.target.fullPath, '/onboarding');
      expect(guard.target.hasRequiredParams, isFalse);
      expect(guard.flow, [guard.target]);
    });

    test('offers its route to the navigation of the app', () {
      final unit = _parsed(app, RouterRole.navigationFile);
      final location = _classOf(unit, 'OnboardingOnboardingLocation');

      expect(location.extendsClause!.superclass.name.lexeme, 'AppLocation');
      expect(
        _classOf(unit, 'OnboardingRoutes')
            .body
            .members
            .whereType<MethodDeclaration>()
            .map((method) => method.name.lexeme),
        ['onboarding'],
      );
    });

    test(
        'starts on the fallback screen of the app entry once the onboarding '
        'is finished, since the onboarding cannot start the app', () {
      expect(_startRouteOf(result), isNull);
      // No question to answer, so no option of the router either.
      expect(result.answers, isEmpty);
    });

    test(
        'starts on the screen of a feature that can start the app, in '
        'whichever order the modules are', () async {
      for (final modules in [
        [OnboardingModule.id, _feed.id],
        [_feed.id, OnboardingModule.id],
      ]) {
        final result = await _rendered(modules);

        expect(_startRouteOf(result)!.fullPath, '/feed', reason: '$modules');
        expect(
          _guardsOf(result).map((guard) => guard.fullName),
          ['onboarding.firstRun'],
          reason: '$modules',
        );
      }
    });

    test('cannot start on the onboarding, also when it is asked to', () async {
      // As `--start /onboarding` asks on the command line.
      final asked = await ContractHarness(ModuleRegistry(_modules)).check(
        const ContractCase(
          'the onboarding as the start',
          requested: [OnboardingModule.id],
          roleOptions: {'start': '/onboarding'},
        ),
      );

      expect(
        asked.errors.map((issue) => issue.message),
        [
          contains(
            'The app cannot start on /onboarding, because the route is in '
            'the flow of the guard onboarding.firstRun',
          ),
        ],
      );
    });

    test(
        'gives the preferences its restorer, which they call when the '
        'start-up of the app opens them, before the first frame', () {
      expect(
        _contributionsTo(result, PreferencesRole.restorers),
        ['onboarding: restoreOnboarding'],
      );
      expect(
        _contributionsTo(result, AppEntryRole.bootstrapPlatform),
        ['role:preferences: await initPreferences();'],
      );
      final file = app.files[PreferencesRole.file]!;
      expect(
        [
          for (final added in file.addedImports)
            if ('${added.contributor}' == '$_module')
              (added.import.uri, added.import.prefix),
        ],
        [
          (
            'package:contract_app/features/onboarding/onboarding_status.dart',
            null,
          ),
        ],
      );
    });
  });

  group('the status of the onboarding', () {
    late RenderedApp app;
    late CompilationUnit unit;

    setUpAll(() async {
      app = (await _rendered(const [OnboardingModule.id])).app!;
      unit = _parsed(app, _status);
    });

    test(
        'is one object of the app, with what the guard asks and the restorer '
        'of the preferences next to it', () {
      final status = _classOf(unit, 'OnboardingStatus');

      expect(app.files[_status]!.text, isNot(contains('{{')));
      expect(_importsOf(unit), [
        'package:flutter/foundation.dart',
        '../../core/preferences/app_preferences.dart',
      ]);
      // The one object, which nothing else can create.
      final variable = unit.declarations
          .whereType<TopLevelVariableDeclaration>()
          .single
          .variables;
      expect(variable.isFinal, isTrue);
      expect(
        variable.variables.single.toSource(),
        'onboardingStatus = OnboardingStatus._()',
      );
      expect(
        [
          for (final constructor
              in status.body.members.whereType<ConstructorDeclaration>())
            constructor.name?.lexeme,
        ],
        ['_'],
      );
      expect(
        [
          for (final member
              in status.body.members.whereType<MethodDeclaration>())
            if (!member.name.lexeme.startsWith('_'))
              '${member.returnType} ${member.name.lexeme}',
        ],
        [
          'ValueListenable<bool> completed',
          'Future<void> complete',
          'Future<void> restart',
        ],
      );
      // The function of the guard takes nothing, and the restorer takes the
      // preferences.
      final guard = _functionOf(unit, 'onboardingCompleted');
      expect('${guard.returnType}', 'ValueListenable<bool>');
      expect(guard.functionExpression.parameters!.parameters, isEmpty);
      final restorer = _functionOf(unit, 'restoreOnboarding');
      expect('${restorer.returnType}', 'void');
      expect(
        '${restorer.functionExpression.parameters}',
        '(AppPreferences preferences)',
      );
    });

    test('saves under the key of the module', () {
      expect(_stringsIn(unit), [OnboardingModule.completedKey]);
    });

    test('type-checks with the preferences of the app', () async {
      final dartApp = DartApp.write(app);
      try {
        expect(
          await dartApp.analysisProblems([
            _status,
            PreferencesRole.file,
            'lib/${MemoryPreferencesModule.file}',
          ]),
          isEmpty,
        );
      } finally {
        dartApp.delete();
      }
    });

    test(
        'is not finished on the first launch, is finished at once and saved '
        'when the user finishes, and is restored on the next launch', () async {
      final sent = await _run(app, '''
  result['before the app starts'] = completed.value;
  result['the guard asks the status'] =
      identical(completed, onboardingStatus.completed);

  // The first launch: the preferences have nothing saved.
  await initPreferences();
  result['the first launch'] = [completed.value, [...heard]];

  // The user finishes the onboarding.
  final saving = onboardingStatus.complete();
  result['finished, at once'] = [
    completed.value,
    [...heard],
    savedPreferences[key],
  ];
  await saving;
  result['once it is saved'] = savedPreferences[key];

  // Finishing again tells no listener.
  await onboardingStatus.complete();
  result['finished again'] = [completed.value, [...heard]];

  // The next launch opens the preferences anew.
  await initPreferences();
  result['the next launch'] = [completed.value, [...heard]];
''');

      expect(sent, {
        'before the app starts': false,
        'the guard asks the status': true,
        'the first launch': [false, <bool>[]],
        // Finished before the write completes, so that the router leaves
        // the onboarding in the handler of the tap.
        'finished, at once': [
          true,
          [true],
          null,
        ],
        'once it is saved': true,
        'finished again': [
          true,
          [true],
        ],
        'the next launch': [
          true,
          [true],
        ],
      });
    });

    test(
        'takes what the preferences have saved when the app starts, and '
        'keeps its value when they have nothing saved or a value of another '
        'type', () async {
      final sent = await _run(app, '''
  // A launch after the user finished the onboarding.
  savedPreferences[key] = true;
  await initPreferences();
  result['a launch with it saved'] = [completed.value, [...heard]];

  // What is saved is no flag: the read of the preferences returns null.
  savedPreferences[key] = 'yes';
  await initPreferences();
  result['another type saved'] = [completed.value, [...heard]];

  savedPreferences.remove(key);
  await initPreferences();
  result['nothing saved'] = [completed.value, [...heard]];

  // Saved as not finished, as once the app started the onboarding again.
  savedPreferences[key] = false;
  await initPreferences();
  result['saved as not finished'] = [completed.value, [...heard]];
''');

      expect(sent, {
        'a launch with it saved': [
          true,
          [true],
        ],
        'another type saved': [
          true,
          [true],
        ],
        'nothing saved': [
          true,
          [true],
        ],
        'saved as not finished': [
          false,
          [true, false],
        ],
      });
    });

    test(
        'starts again at once and saves that, so that the next launch shows '
        'the onboarding, until the user finishes it again', () async {
      final sent = await _run(app, '''
  // A launch after the user finished the onboarding.
  savedPreferences[key] = true;
  await initPreferences();
  result['a launch with it finished'] = [completed.value, [...heard]];

  // The app starts the onboarding again, as for a user who asks to see it.
  final saving = onboardingStatus.restart();
  result['started again, at once'] = [
    completed.value,
    [...heard],
    savedPreferences[key],
  ];
  await saving;
  result['once it is saved'] = savedPreferences[key];

  // Starting it again once more tells no listener.
  await onboardingStatus.restart();
  result['started again once more'] = [completed.value, [...heard]];

  // The app is closed in the middle: the next launch finds it not finished.
  await initPreferences();
  result['the next launch'] = [completed.value, [...heard]];

  await onboardingStatus.complete();
  result['finished again'] = [
    completed.value,
    [...heard],
    savedPreferences[key],
  ];
''');

      expect(sent, {
        'a launch with it finished': [
          true,
          [true],
        ],
        // Started again before the write completes, so that the router
        // shows the onboarding in the handler of the tap.
        'started again, at once': [
          false,
          [true, false],
          true,
        ],
        'once it is saved': false,
        'started again once more': [
          false,
          [true, false],
        ],
        'the next launch': [
          false,
          [true, false],
        ],
        'finished again': [
          true,
          [true, false, true],
          true,
        ],
      });
    });

    test(
        'changes only memory when it is finished before the preferences '
        'are open, which a start with nothing saved keeps', () async {
      final sent = await _run(app, '''
  // As a test does for the tests of other screens, before the app starts.
  await onboardingStatus.complete();
  result['finished before the start'] = [
    completed.value,
    savedPreferences.containsKey(key),
  ];

  await initPreferences();
  result['the start keeps it'] = [
    completed.value,
    [...heard],
    savedPreferences.containsKey(key),
  ];

  // From then on it saves through the preferences that the start opened.
  await onboardingStatus.complete();
  result['finished after the start'] = savedPreferences[key];
''');

      expect(sent, {
        'finished before the start': [true, false],
        'the start keeps it': [
          true,
          [true],
          false,
        ],
        'finished after the start': true,
      });
    });

    test(
        'changes only memory when it starts again before the preferences '
        'are open', () async {
      final sent = await _run(app, '''
  await onboardingStatus.complete();
  await onboardingStatus.restart();
  result['started again before the start'] = [
    completed.value,
    [...heard],
    savedPreferences.containsKey(key),
  ];
''');

      expect(sent, {
        'started again before the start': [
          false,
          [true, false],
          false,
        ],
      });
    });

    test(
        'is finished, or started again, while the app runs when the '
        'preferences fail to save it, and completes with their error',
        () async {
      final sent = await _run(app, '''
  await initPreferences();
  writeError = StateError('The device is full.');
  Object? error;
  final saving = onboardingStatus.complete();
  result['finished, at once'] = [completed.value, [...heard]];
  try {
    await saving;
  } on StateError catch (thrown) {
    error = thrown.message;
  }
  result['the error of the preferences'] = error;
  result['saved'] = savedPreferences.containsKey(key);

  // The same when it starts again.
  error = null;
  final starting = onboardingStatus.restart();
  result['started again, at once'] = [completed.value, [...heard]];
  try {
    await starting;
  } on StateError catch (thrown) {
    error = thrown.message;
  }
  result['the error of the preferences again'] = error;
''');

      expect(sent, {
        'finished, at once': [
          true,
          [true],
        ],
        'the error of the preferences': 'The device is full.',
        'saved': false,
        'started again, at once': [
          false,
          [true, false],
        ],
        'the error of the preferences again': 'The device is full.',
      });
    });
  });

  group('the screen of the onboarding', () {
    late RenderedApp app;
    late CompilationUnit unit;

    setUpAll(() async {
      app = (await _rendered(const [OnboardingModule.id])).app!;
      unit = _parsed(app, _screen);
    });

    test(
        'is a widget with state of its own and a constant constructor that '
        'takes nothing but its key', () {
      final screen = _classOf(unit, 'OnboardingScreen');

      expect(app.files[_screen]!.text, isNot(contains('{{')));
      expect(screen.extendsClause!.superclass.name.lexeme, 'StatefulWidget');
      expect(screen.metadata, isEmpty);
      expect(screen.documentationComment, isNotNull);
      final constructor =
          screen.body.members.whereType<ConstructorDeclaration>().single;
      expect(constructor.name, isNull);
      expect(constructor.constKeyword, isNotNull);
      expect(constructor.parameters.toSource(), '({super.key})');
      // The page that the user sees is the state of a PageController.
      final state = _classOf(unit, '_OnboardingScreenState');
      expect(
        '${state.extendsClause!.superclass}',
        'State<OnboardingScreen>',
      );
      expect(
        [
          for (final field in state.body.members.whereType<FieldDeclaration>())
            field.fields.variables.single.toSource(),
        ],
        ['_controller = PageController()', '_page = 0'],
      );
    });

    test(
        'only finishes the onboarding and does not navigate: it knows '
        'neither the router nor the navigation of the app', () {
      expect(_importsOf(unit), [
        'package:flutter/material.dart',
        'onboarding_pages.dart',
        'onboarding_status.dart',
      ]);
    });

    test(
        'has Skip, which finishes the onboarding, before a button that '
        'shows the next page as Next, and finishes the onboarding as Done on '
        'the last page', () {
      expect(_buttonsOf(unit), [
        ('TextButton', 'onboardingStatus.complete', "Text('Skip')"),
        (
          'FilledButton',
          'isLast ? onboardingStatus.complete : _next',
          "Text(isLast ? 'Done' : 'Next')",
        ),
      ]);
      // Skip is not on the last page.
      final skip = _buttonCalls(unit).first;
      expect((skip.parent! as IfElement).expression.toSource(), '!isLast');
    });

    test(
        'shows the pages of the list of the pages, however many it has: the '
        'last page and the dots come from its length, and Next shows the '
        'page after the one that the user sees', () {
      final pageView = _calls(unit, 'PageView').single;
      final pages = _calls(unit, 'onboardingPages').single;

      expect(_argument(pageView, 'children').toSource(), 'pages');
      // The list of the pages, in the context of the screen.
      expect(pages.toSource(), 'onboardingPages(context)');
      expect(
        (pages.parent! as VariableDeclaration).name.lexeme,
        'pages',
      );
      // The page that the user sees, also after a swipe.
      expect(
        _argument(pageView, 'onPageChanged').toSource(),
        '(page) => setState(() => _page = page)',
      );
      final build = _methodOf(unit, '_OnboardingScreenState', 'build');
      expect(
        _variablesOf(build),
        containsPair('isLast', '_page == pages.length - 1'),
      );
      // A dot for each page, with the one of the page that the user sees
      // in another colour.
      final dots = _forElementsOf(build).single;
      expect(
        dots.forLoopParts.toSource(),
        'var index = 0; index < pages.length; index++',
      );
      expect(dots.body.toSource(), contains('index == _page ? '));
      expect(
        _methodOf(unit, '_OnboardingScreenState', '_next').body.toSource(),
        startsWith('=> _controller.nextPage('),
      );
    });

    test(
        'starts the onboarding again when it is shown although the '
        'onboarding is finished, once its first frame is over', () {
      final initState = _methodOf(unit, '_OnboardingScreenState', 'initState');
      final statements = (initState.body as BlockFunctionBody).block.statements;

      expect(statements.first.toSource(), 'super.initState();');
      final whenFinished = statements.last as IfStatement;
      expect(statements, hasLength(2));
      expect(
        whenFinished.expression.toSource(),
        'onboardingStatus.completed.value',
      );
      expect(whenFinished.elseStatement, isNull);
      // The router acts on it at once, which it must not do while a frame
      // is built: the screen waits for the end of the frame.
      final restart = _calls(initState, 'restart').single;
      expect(restart.toSource(), 'onboardingStatus.restart()');
      final callback =
          _calls(whenFinished.thenStatement, 'addPostFrameCallback').single;
      expect(
        callback.toSource(),
        startsWith('WidgetsBinding.instance.addPostFrameCallback('),
      );
      expect(
        restart.thisOrAncestorMatching((node) => node == callback),
        isNotNull,
      );
      // Nothing else of the screen starts it again, and its build neither
      // starts nor finishes it.
      expect(_calls(unit, 'restart'), [restart]);
      final build = _methodOf(unit, '_OnboardingScreenState', 'build');
      expect(_calls(build, 'complete'), isEmpty);
    });

    test('keeps the annotations of the router role on its class', () async {
      final result = await _rendered(
        const [OnboardingModule.id, _Annotating.id],
        registry: const [..._modules, _Annotating()],
      );
      final screen =
          _classOf(_parsed(result.app!, _screen), 'OnboardingScreen');

      expect(
        screen.metadata.map((annotation) => annotation.toSource()),
        [_annotation],
      );
      expect(screen.documentationComment, isNotNull);
    });
  });

  group('the pages of the onboarding', () {
    late RenderedApp app;
    late CompilationUnit unit;

    setUpAll(() async {
      app = (await _rendered(const [OnboardingModule.id])).app!;
      unit = _parsed(app, _pages);
    });

    test(
        'are one list of the app: a welcome with the name of the app, and a '
        'page that ends the onboarding', () {
      final pages = _functionOf(unit, 'onboardingPages');

      expect(app.files[_pages]!.text, isNot(contains('{{')));
      expect(_importsOf(unit), ['package:flutter/material.dart']);
      expect('${pages.returnType}', 'List<Widget>');
      expect(
        '${pages.functionExpression.parameters}',
        '(BuildContext context)',
      );
      expect(
        [
          for (final page in _calls(unit, 'OnboardingPage'))
            (
              _argument(page, 'title').toSource(),
              _argument(page, 'text').toSource(),
            ),
        ],
        [
          ("'Contract App'", "'Welcome! We are glad you are here.'"),
          ("'You are all set'", "'Enjoy the app.'"),
        ],
      );
    });

    test('name the app as the context names it', () async {
      final result = await _rendered(
        const [OnboardingModule.id],
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

      final first =
          _calls(_parsed(result.app!, _pages), 'OnboardingPage').first;
      expect(_argument(first, 'title').toSource(), "'Bird Watch'");
    });

    test(
        'are widgets with a constant constructor, which scroll when the '
        'page is too small for them', () {
      final page = _classOf(unit, 'OnboardingPage');

      expect(page.extendsClause!.superclass.name.lexeme, 'StatelessWidget');
      final constructor =
          page.body.members.whereType<ConstructorDeclaration>().single;
      expect(constructor.constKeyword, isNotNull);
      expect(
        constructor.parameters.toSource(),
        '({required this.icon, required this.title, required this.text, '
        'super.key})',
      );
      final scroll = _calls(unit, 'SingleChildScrollView').single;
      expect(
        (scroll.parent!.parent!.parent! as MethodInvocation).methodName.name,
        'Center',
      );
    });

    test('have their title as a header for a screen reader', () {
      final header = _calls(unit, 'Semantics').single;

      expect(_argument(header, 'header').toSource(), 'true');
      final title = _argument(header, 'child') as MethodInvocation;
      expect(title.methodName.name, 'Text');
      expect(title.argumentList.arguments.first.toSource(), 'title');
      // The text below the title is none.
      expect(
        [
          for (final shown in _calls(unit, 'Text'))
            shown.argumentList.arguments.first.toSource(),
        ],
        ['title', 'text'],
      );
    });
  });

  group('in an app with the localization role', () {
    late ContractResult result;
    late RenderedApp app;
    late RenderedApp without;

    setUpAll(() async {
      result = await _rendered(
        const [OnboardingModule.id, GenL10nModule.id],
      );
      app = result.app!;
      without = (await _rendered(const [OnboardingModule.id])).app!;
    });

    test(
        'the texts of the module are texts of the app, in English and in '
        'Ukrainian', () {
      final input = localizationRole.hookInput(result.hook!);

      expect(
        [
          for (final text in localizationRole.textsIn(input))
            ('${text.owner}', text.getter, text.text.en),
        ],
        [
          for (final MapEntry(key: getter, value: english) in _texts.entries)
            ('$_module', getter, english),
        ],
      );
      expect(localizationRole.localesIn(input), ['en', 'uk']);
    });

    test(
        'the provider of the role writes each text of the module into the '
        'file of each language of the app, the English ones and the '
        'Ukrainian ones', () {
      final texts = localizationRole.textsIn(
        localizationRole.hookInput(result.hook!),
      );
      Map<String, Object?> arbOf(String language) => jsonDecode(
            app.files['${GenL10nModule.arbDirectory}/app_$language.arb']!.text,
          ) as Map<String, Object?>;

      // No other module of the app has a text, so each file has the texts
      // of the module alone, after its language.
      expect(arbOf('en'), {'@@locale': 'en', ..._texts});
      expect(texts.map((text) => text.getter), _texts.keys);
      expect(arbOf('uk'), {'@@locale': 'uk', ..._ukrainian});
      // In the order of the texts of the module.
      for (final language in ['en', 'uk']) {
        expect(
          arbOf(language).keys.skip(1),
          _texts.keys,
          reason: language,
        );
      }
    });

    test(
        'the pages and the screen read each text of the module from the '
        'texts of the app, where the app without the role has its English '
        'text', () {
      final pages = _parsed(app, _pages);
      final screen = _parsed(app, _screen);

      expect(_textsReadIn(pages), [
        'onboardingWelcome',
        'onboardingReadyTitle',
        'onboardingReady',
      ]);
      expect(_textsReadIn(screen), [
        'onboardingSkip',
        'onboardingDone',
        'onboardingNext',
      ]);
      expect(
        [
          for (final page in _calls(pages, 'OnboardingPage'))
            (
              _argument(page, 'title').toSource(),
              _argument(page, 'text').toSource(),
            ),
        ],
        [
          // The name of the app is the same in every language.
          ("'Contract App'", 'context.l10n.onboardingWelcome'),
          ('context.l10n.onboardingReadyTitle', 'context.l10n.onboardingReady'),
        ],
      );
      expect(_buttonsOf(screen), [
        (
          'TextButton',
          'onboardingStatus.complete',
          'Text(context.l10n.onboardingSkip)',
        ),
        (
          'FilledButton',
          'isLast ? onboardingStatus.complete : _next',
          'Text(isLast ? context.l10n.onboardingDone : '
              'context.l10n.onboardingNext)',
        ),
      ]);
      // Without the role, no code reads the texts of an app.
      for (final path in [_pages, _screen]) {
        expect(_textsReadIn(_parsed(without, path)), isEmpty, reason: path);
      }
    });

    test(
        'the pages and the screen import the texts of the app, and the '
        'status is the file of the app without the role', () {
      // The file with the extension that the role requires of its provider,
      // whichever module provides it.
      final texts = LocalizationRole.appTexts.importRef.resolveUri(
        ContractHarness.defaultContext.appName,
      );
      for (final path in [_pages, _screen]) {
        expect(
          {
            for (final added in app.files[path]!.addedImports)
              ('${added.contributor}', added.import.uri),
          },
          {('$_module', texts)},
          reason: path,
        );
        expect(without.files[path]!.addedImports, isEmpty, reason: path);
      }
      expect(app.files[_status]!.bytes, without.files[_status]!.bytes);
    });
  });

  group('the note of the module for coding agents', () {
    late ContractResult result;
    late RenderedApp app;

    setUpAll(() async {
      result = await _rendered(const [OnboardingModule.id]);
      app = result.app!;
    });

    test('is a section of its own in the guide of the app', () {
      expect(
        [
          for (final (origin, heading, note)
              in app.entriesOf(AppEntryRole.agentSections))
            if (origin == _module) (heading, note),
        ],
        [(agentHeading, AgentNote(agentNote))],
      );
      expect(agentHeading, 'Onboarding');
      expect(
        app.files[AppEntryRole.agentsFile]!.text,
        contains('\n## $agentHeading\n\n${agentNote.trim()}\n'),
      );
    });

    test(
        'names the guard, the screen and its route as the router role has '
        'them, and the list of the guards of the role', () {
      final code = _codeOf(agentNote);
      final guard = _guardsOf(result).single;
      final route = guard.target;

      expect(
        code,
        containsAll([
          guard.fullName,
          RouterRole.routeGuards,
          route.route.screen.className,
          route.route.screen.file,
          route.fullName,
          route.fullPath,
        ]),
      );
      expect(route.route.screen.file, _screen);
      expect(
        _indexOf(app, _screen).declaration(route.route.screen.className)?.kind,
        DeclarationKind.classType,
      );
      // The list of the guards, which the template of the router role
      // generates in an app with the module, with the guard by its name.
      expect(
        _indexOf(app, RouterRole.appRouterFile)
            .declaration(RouterRole.routeGuards)
            ?.kind,
        DeclarationKind.variable,
      );
      expect(
        _stringsIn(_parsed(app, RouterRole.appRouterFile)),
        contains(guard.fullName),
      );
    });

    test(
        'names the list of the pages, the status with what finishes the '
        'onboarding and what starts it again, and the key of the module, as '
        'the files of the app declare them', () {
      final code = _codeOf(agentNote);

      expect(
        code,
        containsAll([
          'onboardingPages()',
          _pages,
          'onboardingStatus',
          _status,
          'complete()',
          'restart()',
          'onboardingStatus.complete()',
          OnboardingModule.completedKey,
        ]),
      );
      expect(
        _indexOf(app, _pages).declaration('onboardingPages')?.kind,
        DeclarationKind.function,
      );
      final status = _indexOf(app, _status);
      expect(
        status.declaration('onboardingStatus')?.kind,
        DeclarationKind.variable,
      );
      final members = {
        for (final member in status.declaration('OnboardingStatus')!.members)
          member.name: member.kind,
      };
      expect(members, containsPair('complete', MemberKind.method));
      expect(members, containsPair('restart', MemberKind.method));
      // What the two save, and under which key, is what the status does
      // when it runs, which its own tests check.
      expect(
        _stringsIn(_parsed(app, _status)),
        [OnboardingModule.completedKey],
      );
    });
  });
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

/// The argument [name] of [call], such as the creation of a widget.
Expression _argument(MethodInvocation call, String name) =>
    call.argumentList.arguments
        .whereType<NamedArgument>()
        .singleWhere((argument) => argument.name.lexeme == name)
        .argumentExpression;

/// The creations of the buttons of the screen in [unit], in the order of
/// the code: those with an `onPressed`.
List<MethodInvocation> _buttonCalls(CompilationUnit unit) {
  final visitor = _Buttons();
  unit.accept(visitor);
  return visitor.found;
}

/// The buttons of the screen in [unit], in the order of the code: the
/// widget of each, what a tap on it calls, and what it shows.
List<(String, String, String)> _buttonsOf(CompilationUnit unit) => [
      for (final button in _buttonCalls(unit))
        (
          button.methodName.name,
          _argument(button, 'onPressed').toSource(),
          _argument(button, 'child').toSource(),
        ),
    ];

final class _Buttons extends RecursiveAstVisitor<void> {
  final List<MethodInvocation> found = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final named = node.argumentList.arguments.whereType<NamedArgument>();
    if (named.any((argument) => argument.name.lexeme == 'onPressed')) {
      found.add(node);
    }
    super.visitMethodInvocation(node);
  }
}
