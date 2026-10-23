@TestOn('vm')
library;

import 'dart:io';

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
/// that can start the app, this module, and a module with a step of the
/// onboarding, which this module shows.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  GoRouterModule(),
  MemoryPreferencesModule(),
  GenL10nModule(),
  _feed,
  OnboardingModule(),
  StepsModule(),
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
  'onboardingDone': 'Get started',
};

/// The Ukrainian texts of the module, by the same getters.
const _ukrainian = {
  'onboardingWelcome': 'Вітаємо! Раді, що ви з нами.',
  'onboardingReadyTitle': 'Усе готово',
  'onboardingReady': 'Приємного користування!',
  'onboardingSkip': 'Пропустити',
  'onboardingNext': 'Далі',
  'onboardingDone': 'Почати',
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

/// The local variables that [function] declares, a method or a function,
/// each with the code of its value, by their names.
Map<String, String> _variablesOf(AstNode function) {
  final visitor = _Variables();
  function.accept(visitor);
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

/// The identifiers [name] in the code of [node], in the order of the code.
List<SimpleIdentifier> _identifiersIn(AstNode node, String name) {
  final visitor = _Identifiers(name);
  node.accept(visitor);
  return visitor.found;
}

final class _Identifiers extends RecursiveAstVisitor<void> {
  _Identifiers(this.name);

  final String name;

  final List<SimpleIdentifier> found = [];

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    // A reference in a comment, such as `[name]`, is not code.
    if (node.name == name && node.thisOrAncestorOfType<Comment>() == null) {
      found.add(node);
    }
    super.visitSimpleIdentifier(node);
  }
}

/// What [node] assigns to variables, each by the code of the variable, as
/// the code of its value.
Map<String, String> _assignmentsOf(AstNode node) {
  final visitor = _Assignments();
  node.accept(visitor);
  return visitor.values;
}

final class _Assignments extends RecursiveAstVisitor<void> {
  final Map<String, String> values = {};

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    values[node.leftHandSide.toSource()] = node.rightHandSide.toSource();
    super.visitAssignmentExpression(node);
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
        'is a feature without variants, which provides the onboarding '
        'screen, requires the router and the preferences and uses the '
        'localization', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('onboarding'));
      expect(descriptor.kind, ModuleKinds.feature);
      expect(descriptor.provides, {onboardingScreenRole});
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
        'function of the status of the onboarding says otherwise, comes '
        'before the guards of a later stage, and brings the user back', () {
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
      // The onboarding comes before a guard that asks who the user is,
      // whatever the order of the modules, and restart() brings the user
      // back to the screen that they were on.
      expect(guard.stage, GuardStage.welcome);
      expect(guard.resumes, isTrue);
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
        'contributes its brick with the key of the preferences, the symbol '
        'of the app and the texts, its route with the guard, that route as '
        'the onboarding screen, its restorer, its texts and its note for '
        'coding agents, and nothing else', () {
      final contributions = module.contribute(ContractHarness.defaultContext);

      expect(contributions, hasLength(6));
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
        'symbol',
        'text_welcome',
        'text_ready_title',
        'text_ready',
        'text_skip',
        'text_next',
        'text_done',
      ]);
      expect(brick.vars['completed_key'], "'onboarding.completed'");
      expect(OnboardingModule.completedKey, 'onboarding.completed');
      // The symbol of the app of the context, contract_app, as a Dart
      // string.
      expect(brick.vars['symbol'], "'Ca'");
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
      final routes = contributions[1] as RoleData<RoutesData>;
      final screen = contributions[2] as RoleData<OnboardingData>;
      expect(screen.role, onboardingScreenRole);
      expect(
        (screen.value as OnboardingScreenRoute).name,
        routes.value.routes.single.name,
      );
      expect(screen.when, isEmpty);
      final restorer = contributions[3] as SocketContribution;
      expect(restorer.socket, PreferencesRole.restorers);
      expect(restorer.fragment!.code, 'restoreOnboarding');
      expect(
        restorer.fragment!.imports,
        [const ImportRef.app('features/onboarding/onboarding_status.dart')],
      );
      // The module requires the preferences, so every app with it has them.
      expect(restorer.when, isEmpty);
      final texts = contributions[4] as RoleData<TextsData>;
      expect(texts.role, localizationRole);
      expect(texts.value, same(OnboardingModule.texts));
      final note = contributions[5] as SocketContribution;
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
        'each with the router and the preferences that it requires, and the '
        'app of a module with a step with this module as its onboarding '
        'screen', () {
      expect(results.map((result) => result.contractCase.name), [
        'flutter_core with router, localization',
        'flutter_core with router',
        // The app of the provider of the localization alone.
        'flutter_core with localization',
        'flutter_core',
        'memory_preferences',
        'feed',
        'onboarding with localization',
        'onboarding',
        // The module with a step, with this module, which shows it, and
        // without an onboarding.
        'steps with onboarding_screen',
        'steps',
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
      expect(
        {
          for (final result in results)
            if (result.contractCase.name.startsWith('steps'))
              result.contractCase.name: _providersOf(
                result,
                onboardingScreenRole,
              ),
        },
        {
          'steps with onboarding_screen': {OnboardingModule.id},
          'steps': isEmpty,
        },
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
        'its route with the guard, its restorer, its note, and the steps of '
        'the onboarding screen role, which it provides', () {
      // The provider of the router renders the route and asks the guard in
      // files of its own, whichever they are.
      final changedBy = _providersOf(result, routerRole);

      expect(
        app.files.keys.toSet(),
        {
          ...without.files.keys,
          _pages,
          _screen,
          _status,
          OnboardingScreenRole.stepsFile,
        },
      );
      for (final path in [_pages, _screen, _status]) {
        expect(app.files[path]!.owner, _module, reason: path);
      }
      // The list of the steps, which the template of the role generates in
      // every app with the role, empty in an app whose modules add none.
      expect(
        app.files[OnboardingScreenRole.stepsFile]!.owner,
        const RoleTemplateOrigin(onboardingScreenRole),
      );
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
      // of the module, the note of the onboarding screen role, and the note
      // of the router role about the guards of the routes, which an app
      // without a guard lacks. The note of the module leaves to them what a
      // router does with a guard and what a step of the onboarding is.
      final notes = app.entriesOf(AppEntryRole.agentSections);
      final notesWithout = without.entriesOf(AppEntryRole.agentSections);
      bool ofGuards((ContributionOrigin, String, AgentNote) note) =>
          note.$1 == const RoleTemplateOrigin(routerRole) &&
          note.$3.text.contains('`${RouterRole.routeGuards}`');
      const ofSteps = RoleTemplateOrigin(onboardingScreenRole);
      expect(notesWithout.where(ofGuards), isEmpty);
      expect(notes.where(ofGuards), hasLength(1));
      expect(
        [
          for (final (origin, heading, _) in notes)
            if (origin == ofSteps) heading,
        ],
        [onboardingScreenRole.description],
      );
      expect(
        notes.where(
          (note) => note.$1 != _module && note.$1 != ofSteps && !ofGuards(note),
        ),
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

  group('the app with the onboarding and a module with a step', () {
    late ContractResult result;
    late RoleHookInput<Object> input;

    setUpAll(() async {
      result = await _rendered(const [OnboardingModule.id, StepsModule.id]);
      input = onboardingScreenRole.hookInput(result.hook!);
    });

    test(
        'has the onboarding of the module as its onboarding screen, at the '
        'route of the module, where code that knows only the role finds it',
        () {
      final screen = onboardingScreenRole.screenIn(input)!;

      expect(
        _providersOf(result, onboardingScreenRole),
        {OnboardingModule.id},
      );
      expect(screen.fullName, 'onboarding.onboarding');
      expect(screen.fullPath, '/onboarding');
      expect(screen.hasRequiredParams, isFalse);
      expect(screen.route.screen.className, 'OnboardingScreen');
      expect(screen.route.screen.file, _screen);
    });

    test(
        'shows the step of the other module: its screen reads the list of '
        'the steps that the template of the role generates with the step, '
        'as the rule onboarding_screen.steps_shown of the role checks', () {
      expect(
        [for (final step in onboardingScreenRole.stepsIn(input)) step.fullName],
        ['steps.ask'],
      );
      final list = _parsed(result.app!, OnboardingScreenRole.stepsFile)
          .declarations
          .whereType<TopLevelVariableDeclaration>()
          .single
          .variables
          .variables
          .single;
      expect(list.name.lexeme, OnboardingScreenRole.appOnboardingSteps);
      expect((list.initializer! as ListLiteral).elements, hasLength(1));
      expect(
        _identifiersIn(
          _parsed(result.app!, _screen),
          OnboardingScreenRole.appOnboardingSteps,
        ),
        hasLength(1),
      );
      // The rule that reports a provider whose files do not read the list,
      // which finds nothing to report here.
      expect(
        [for (final rule in onboardingScreenRole.structuralRules) rule.id],
        contains('onboarding_screen.steps_shown'),
      );
      expect(result.errors, isEmpty);
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
        'are open, which a start that finds it saved as finished undoes',
        () async {
      final sent = await _run(app, '''
  await onboardingStatus.complete();
  await onboardingStatus.restart();
  result['started again before the start'] = [
    completed.value,
    [...heard],
    savedPreferences.containsKey(key),
  ];

  // The start-up takes what an earlier launch saved.
  savedPreferences[key] = true;
  await initPreferences();
  result['a start with it saved as finished'] = [
    completed.value,
    [...heard],
    savedPreferences[key],
  ];
''');

      expect(sent, {
        'started again before the start': [
          false,
          [true, false],
          false,
        ],
        'a start with it saved as finished': [
          true,
          [true, false, true],
          true,
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
    late MethodDeclaration build;

    setUpAll(() async {
      app = (await _rendered(const [OnboardingModule.id])).app!;
      unit = _parsed(app, _screen);
      build = _methodOf(unit, '_OnboardingScreenState', 'build');
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
      // The page that the user sees is the state of a PageController, next
      // to the steps that the screen shows and whether the action of one
      // runs.
      final state = _classOf(unit, '_OnboardingScreenState');
      expect(
        '${state.extendsClause!.superclass}',
        'State<OnboardingScreen>',
      );
      expect(
        {
          for (final field in state.body.members.whereType<FieldDeclaration>())
            field.fields.variables.single.name.lexeme:
                field.fields.variables.single.initializer?.toSource(),
        },
        {
          '_controller': 'PageController()',
          '_steps': isNotNull,
          '_page': '0',
          '_running': 'false',
        },
      );
    });

    test(
        'only finishes the onboarding and does not navigate: it knows '
        'neither the router nor the navigation of the app, no package but '
        'Flutter, and of the files of the roles only the steps of the '
        'onboarding', () {
      expect(_importsOf(unit), [
        'dart:ui',
        'package:flutter/material.dart',
        'package:flutter/services.dart',
        '../../core/onboarding/onboarding_steps.dart',
        'onboarding_pages.dart',
        'onboarding_status.dart',
      ]);
      // The file that the template of the role generates in every app with
      // the role, whichever module provides it.
      expect(
        OnboardingScreenRole.stepsFile,
        'lib/core/onboarding/onboarding_steps.dart',
      );
      expect(
        onboardingScreenRole.interface.files,
        contains(OnboardingScreenRole.stepsFile),
      );
    });

    test(
        'asks the steps of the app once, when it is first built, and keeps '
        'those whose showIf keeps them while it is shown', () {
      final steps = _classOf(unit, '_OnboardingScreenState')
          .body
          .members
          .whereType<FieldDeclaration>()
          .singleWhere(
            (field) => field.fields.variables.single.name.lexeme == '_steps',
          );

      expect(steps.fields.lateKeyword, isNotNull);
      expect(steps.fields.isFinal, isTrue);
      expect('${steps.fields.type}', 'List<OnboardingStep>');
      final each = (steps.fields.variables.single.initializer! as ListLiteral)
          .elements
          .single as ForElement;
      expect(
        each.forLoopParts.toSource(),
        'final step in ${OnboardingScreenRole.appOnboardingSteps}',
      );
      expect(each.body.toSource(), 'if (step.showIf?.call() ?? true) step');
      // Nothing else reads the list, or asks a step again.
      expect(
        _identifiersIn(unit, OnboardingScreenRole.appOnboardingSteps),
        hasLength(1),
      );
      expect(_identifiersIn(unit, 'showIf'), hasLength(1));
    });

    test(
        'shows each step that it keeps on a page in the look of its own '
        'pages, before the last page of the list, with the labels of the '
        'step in the language of the app', () {
      final variables = _variablesOf(build);

      expect(variables, containsPair('own', 'onboardingPages(context)'));
      expect(
        variables,
        containsPair('first', 'own.isEmpty ? 0 : own.length - 1'),
      );
      expect(
        variables,
        containsPair(
          'pages',
          '[...own.take(first), for (final step in _steps) '
              'OnboardingPage(icon: step.icon, title: step.title(context), '
              'text: step.text(context)), ...own.skip(first)]',
        ),
      );
      // The step on the page that the user sees.
      expect(
        variables,
        containsPair(
          'step',
          '_page >= first && _page < first + _steps.length ? '
              '_steps[_page - first] : null',
        ),
      );
    });

    test(
        'has Skip, which finishes the onboarding, above the pages, and one '
        'button of the whole width below them: Next, which shows the next '
        'page, Get started, which finishes the onboarding on the last page, '
        'and the action of a step on its page', () {
      final [skip, button, ...] = _buttonCalls(unit);

      expect(skip.methodName.name, 'TextButton');
      expect(
        _argument(skip, 'onPressed').toSource(),
        'onboardingStatus.complete',
      );
      expect(_wordsOf(_argument(skip, 'child')), ["'Skip'"]);
      expect(button.methodName.name, 'FilledButton');
      expect(_argument(button, 'onPressed').toSource(), 'onPressed');
      // What the button does and says, on a page of the module and on the
      // page of a step.
      final choice = (build.body as BlockFunctionBody)
          .block
          .statements
          .whereType<IfStatement>()
          .single;
      expect(choice.expression.toSource(), 'step == null');
      expect(_assignmentsOf(choice.thenStatement), {
        'onPressed': 'isLast ? onboardingStatus.complete : _next',
        'label': "isLast ? 'Get started' : 'Next'",
      });
      expect(_assignmentsOf(choice.elseStatement!), {
        'onPressed': '_running ? (spins ? () {} : null) : () => _run(step)',
        'label': 'step.action(context)',
      });
      final switcher = _argument(button, 'child') as MethodInvocation;
      expect(switcher.methodName.name, 'AnimatedSwitcher');
      expect(
        _argument(switcher, 'child').toSource(),
        '_ButtonLabel(label, spins: spins, '
        'key: ValueKey<Object>(step ?? isLast))',
      );
      // In the order of the column of the screen.
      final pages = _calls(unit, 'PageView').single;
      expect(skip.offset, lessThan(pages.offset));
      expect(pages.offset, lessThan(button.offset));
      // The column of the button stretches it to its width.
      expect(
        _argument(_enclosing(button, 'Column'), 'crossAxisAlignment')
            .toSource(),
        'CrossAxisAlignment.stretch',
      );
    });

    test(
        'calls the action of a step on a tap, keeps its pages where they are '
        'while the action runs, and shows the next page once its future '
        'completes, also when it fails, leaving the error to the handlers '
        'of the errors of the app', () {
      final run = _methodOf(unit, '_OnboardingScreenState', '_run');
      final [start, attempt as TryStatement] =
          (run.body as BlockFunctionBody).block.statements;

      expect(start.toSource(), 'setState(() => _running = true);');
      expect(attempt.body.toSource(), '{await step.run(context);}');
      // Nothing catches the error.
      expect(attempt.catchClauses, isEmpty);
      expect(
        attempt.finallyBlock!.toSource(),
        '{if (mounted) {setState(() => _running = false); _next();}}',
      );
      final ignoring =
          _enclosing(_calls(unit, 'PageView').single, 'IgnorePointer');
      expect(_argument(ignoring, 'ignoring').toSource(), '_running');
    });

    test(
        'spins while the action of a step runs, keeping the label in its '
        'place, and takes no tap instead in an app that asks for less '
        'motion', () {
      expect(
        _variablesOf(build),
        containsPair(
          'spins',
          '_running && !MediaQuery.disableAnimationsOf(context)',
        ),
      );
      final label = _methodOf(unit, '_ButtonLabel', 'build');
      final spinner = _calls(label, 'CircularProgressIndicator').single;
      expect(
        spinner.thisOrAncestorOfType<IfElement>()!.expression.toSource(),
        'spins',
      );
      expect(
        _calls(label, 'maintain').single.toSource(),
        'Visibility.maintain(visible: !spins, child: OnboardingWords(label))',
      );
    });

    test(
        'shows the later of the step whose page is shown below its button, '
        'in a place as high as the tallest later, so that the pages keep '
        'their height from page to page', () {
      final later = _buttonCalls(unit)[2];

      expect(later.methodName.name, 'TextButton');
      expect(
        _argument(later, 'onPressed').toSource(),
        '_running ? null : _next',
      );
      expect(_wordsOf(_argument(later, 'child')), ['other.later!(context)']);
      expect(
        _variablesOf(build),
        containsPair(
          'withLater',
          '[for (final other in _steps) if (other.later != null) other]',
        ),
      );
      final place = _enclosing(later, 'IndexedStack');
      expect(
        _argument(place, 'index').toSource(),
        'step?.later == null ? withLater.length : withLater.indexOf(step!)',
      );
      // Only in an app with such a step: the pages of the others keep the
      // look that they have without steps.
      expect(
        place.thisOrAncestorOfType<IfElement>()!.expression.toSource(),
        'withLater.isNotEmpty',
      );
    });

    test(
        'lets the labels of the buttons below the pages, and not Skip, grow '
        'only by half with the text size of the device', () {
      final clamped = _calls(unit, 'withClampedTextScaling').single;
      final [skip, button, later] = _buttonCalls(unit);

      expect(_argument(clamped, 'maxScaleFactor').toSource(), '1.5');
      expect(_enclosing(button, 'withClampedTextScaling'), clamped);
      expect(_enclosing(later, 'withClampedTextScaling'), clamped);
      expect(
        skip.thisOrAncestorMatching(
          (node) =>
              node is MethodInvocation &&
              node.methodName.name == 'withClampedTextScaling',
        ),
        isNull,
      );
    });

    test(
        'gives the texts of a page and the label of every button the one '
        'text that keeps its words whole: a title with half more of its size '
        'at most and the text below it, in the width of the page but for its '
        'sides, and a label with the text size of its place', () {
      final pages = _parsed(app, _pages);
      final page = _methodOf(pages, 'OnboardingPage', 'build');
      final turning = _methodOf(pages, 'OnboardingPage', '_build');

      // The title, in the style that the theme has for it, and the text
      // below it. They are below a parent that asks for the height of its
      // children before it lays them out, so they get the width that they
      // have.
      final [title, text] = _calls(page, 'OnboardingWords');
      expect(_argumentsOf(title), {
        '0': 'title',
        'style': 'theme.textTheme.displaySmall',
        'maxScaleFactor': '1.5',
        'width': 'constraints.maxWidth - 2 * _sides',
      });
      expect(_argumentsOf(text), {
        '0': 'text',
        'style': 'theme.textTheme.bodyLarge?.copyWith(fontSize: 18, '
            'color: theme.colorScheme.onSurfaceVariant)',
        'width': 'constraints.maxWidth - 2 * _sides',
      });
      final sides = _classOf(pages, 'OnboardingPage')
          .body
          .members
          .whereType<FieldDeclaration>()
          .singleWhere((field) => field.isStatic);
      expect(sides.fields.isConst, isTrue);
      expect(sides.fields.variables.single.toSource(), '_sides = 28');
      final texts = _calls(turning, 'Padding').single;
      expect(
        _argument(texts, 'padding').toSource(),
        'const EdgeInsets.fromLTRB(_sides, 8, _sides, 8)',
      );
      expect(_enclosing(texts, 'IntrinsicHeight'), isNotNull);
      // The labels of Skip, of the later of a step and of the button below
      // the pages: with no style of their own, so each is as the theme has
      // the label of its button, and it grows as the text size of its
      // place asks.
      final [skip, button, later] = _buttonCalls(unit);
      expect(
        [
          for (final label in _calls(unit, 'OnboardingWords'))
            _argumentsOf(label),
        ],
        [
          {'0': "'Skip'"},
          {'0': 'other.later!(context)'},
          {'0': 'label'},
        ],
      );
      expect(_wordsOf(_argument(skip, 'child')), ["'Skip'"]);
      expect(_wordsOf(_argument(later, 'child')), ['other.later!(context)']);
      expect(
        _argument(_argument(button, 'child') as MethodInvocation, 'child')
            .toSource(),
        startsWith('_ButtonLabel(label, '),
      );
      expect(_calls(unit, 'Text'), isEmpty);
      // One piece measures the words, for the titles and the labels: in the
      // width that it is given, and in that of its parent without one.
      for (final measure in ['LayoutBuilder', 'TextPainter']) {
        expect(_calls(unit, measure), isEmpty, reason: measure);
      }
      final words = _classOf(pages, 'OnboardingWords');
      expect(_calls(words, 'TextPainter'), hasLength(1));
      expect(
        _methodOf(pages, 'OnboardingWords', 'build').body.toSource(),
        '{if (width case final width?) return _within(context, width); '
        'return LayoutBuilder(builder: (context, constraints) => '
        '_within(context, constraints.maxWidth));}',
      );
      expect(_argumentsOf(_calls(words, 'Text').single).keys, [
        '0',
        'style',
        'textScaler',
      ]);
    });

    test(
        'takes Skip out of its tree on the last page, once it has faded '
        'away, and lets no tap reach it there', () {
      final skip = _buttonCalls(unit).first;

      final onLastPage = skip.parent! as ConditionalExpression;
      expect(onLastPage.condition.toSource(), 'isLast');
      expect(onLastPage.thenExpression.toSource(), 'const SizedBox.shrink()');
      expect(onLastPage.elseExpression, skip);
      // What fades the one out and the other in, and keeps only the one
      // that it faded in.
      final switcher = _enclosing(skip, 'AnimatedSwitcher');
      expect(_argument(switcher, 'child'), onLastPage);
      final ignoring = _enclosing(switcher, 'IgnorePointer');
      expect(_argument(ignoring, 'ignoring').toSource(), 'isLast');
      expect(_argument(ignoring, 'child'), switcher);
    });

    test(
        'shows its pages, however many they are, each in the scope of its '
        'place among them: the last page and the marks come from the '
        'number of the pages, and Next shows the page after the one that '
        'the user sees', () {
      final pageView = _calls(unit, 'PageView').single;

      // Each page in a scope with its index and the controller of the
      // pages, from which the parts of a page read how far the pages are
      // turned.
      final each = (_argument(pageView, 'children') as ListLiteral)
          .elements
          .single as ForElement;
      expect(
        each.forLoopParts.toSource(),
        'final (index, page) in pages.indexed',
      );
      expect(
        each.body.toSource(),
        'OnboardingPageScope(index: index, controller: _controller, '
        'child: page)',
      );
      expect(_argument(pageView, 'controller').toSource(), '_controller');
      // The page that the user sees, also after a swipe.
      expect(
        _calls(_argument(pageView, 'onPageChanged'), 'setState')
            .single
            .toSource(),
        'setState(() => _page = page)',
      );
      expect(
        _variablesOf(build),
        containsPair('isLast', '_page == pages.length - 1'),
      );
      // A mark for each page, which follow the controller of the pages.
      expect(
        _calls(build, '_PageMarks').single.argumentList.toSource(),
        '(controller: _controller, count: pages.length)',
      );
      expect(
        _forElementsOf(_methodOf(unit, '_PageMarks', 'build'))
            .single
            .forLoopParts
            .toSource(),
        'var index = 0; index < count; index++',
      );
      expect(
        _calls(_methodOf(unit, '_OnboardingScreenState', '_next'), 'nextPage')
            .single
            .toSource(),
        startsWith('_controller.nextPage('),
      );
    });

    test(
        'changes what it shows at once in an app that asks for less motion: '
        'the page that Next shows, Skip and the label of the button', () {
      final build = _methodOf(unit, '_OnboardingScreenState', 'build');
      final next = _methodOf(unit, '_OnboardingScreenState', '_next');

      expect(
        _variablesOf(build),
        containsPair(
          'fade',
          'MediaQuery.disableAnimationsOf(context) ? Duration.zero : '
              'Durations.short4',
        ),
      );
      // Skip, and the label of the button.
      expect(
        [
          for (final switcher in _calls(build, 'AnimatedSwitcher'))
            _argument(switcher, 'duration').toSource(),
        ],
        ['fade', 'fade'],
      );
      final whenLess = (next.body as BlockFunctionBody).block.statements.single
          as IfStatement;
      expect(
        whenLess.expression.toSource(),
        'MediaQuery.disableAnimationsOf(context)',
      );
      expect(
        _calls(whenLess.thenStatement, 'jumpToPage').single.toSource(),
        '_controller.jumpToPage(_page + 1)',
      );
      expect(_calls(whenLess.elseStatement!, 'nextPage'), hasLength(1));
    });

    test(
        'has no app bar and leaves the icons of the status bar to the root '
        'of the app, which tells them for every screen', () {
      expect(_calls(unit, 'AppBar'), isEmpty);
      // The app entry role tells the system the icons that suit the theme,
      // around every route: the screen does not, and names no style of the
      // system.
      expect(_calls(unit, 'AnnotatedRegion'), isEmpty);
      expect(unit.toSource(), isNot(contains('SystemUiOverlayStyle')));
    });

    test('names no font: its texts take that of the theme of the app', () {
      expect(_namedArguments(unit, 'fontFamily'), isEmpty);
      expect(_namedArguments(unit, 'fontFamilyFallback'), isEmpty);
    });

    test(
        'only finishes the onboarding and never starts it again, since the '
        'router shows the screen only while the onboarding is not finished',
        () {
      // A navigation to its route once the onboarding is finished shows
      // the screen that the app starts on, so the screen is never shown
      // with nothing to finish: it has no state to set right when it is
      // first built, and restart() of the status is for the code of the
      // app.
      expect(_calls(unit, 'restart'), isEmpty);
      expect(
        _classOf(unit, '_OnboardingScreenState')
            .body
            .members
            .whereType<MethodDeclaration>()
            .map((method) => method.name.lexeme),
        isNot(contains('initState')),
      );
      // Its build neither starts nor finishes the onboarding.
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
        'are one list of the app: a welcome with the symbol and the name of '
        'the app, and a page with an icon that ends the onboarding', () {
      final pages = _functionOf(unit, 'onboardingPages');

      expect(app.files[_pages]!.text, isNot(contains('{{')));
      expect(_importsOf(unit), ['package:flutter/material.dart']);
      expect('${pages.returnType}', 'List<Widget>');
      expect(
        '${pages.functionExpression.parameters}',
        '(BuildContext context)',
      );
      expect(_pageArguments(unit), [
        {
          'symbol': "'Ca'",
          'title': "'Contract App'",
          'text': "'Welcome! We are glad you are here.'",
        },
        {
          'icon': 'Icons.check_rounded',
          'title': "'You are all set'",
          'text': "'Enjoy the app.'",
        },
      ]);
    });

    test('name the app, and give its symbol, as the context names it',
        () async {
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

      final first = _pageArguments(_parsed(result.app!, _pages)).first;
      expect(first, containsPair('title', "'Bird Watch'"));
      expect(first, containsPair('symbol', "'Bw'"));
    });

    test(
        'are widgets with a constant constructor, which take a symbol or an '
        'icon for their cell, and scroll when the page is too small for '
        'them', () {
      final page = _classOf(unit, 'OnboardingPage');

      expect(page.extendsClause!.superclass.name.lexeme, 'StatelessWidget');
      final constructor =
          page.body.members.whereType<ConstructorDeclaration>().single;
      expect(constructor.constKeyword, isNotNull);
      expect(
        constructor.parameters.toSource(),
        '({required this.title, required this.text, this.symbol, this.icon, '
        'super.key})',
      );
      // A page shows one of the two.
      expect(
        (constructor.initializers.single as AssertInitializer)
            .condition
            .toSource(),
        'symbol != null || icon != null',
      );
      // The page is at least as high as the room that the screen gives it,
      // of which the cells take what the texts leave, and scrolls in less.
      final scroll = _calls(unit, 'SingleChildScrollView').single;
      final box = _argument(scroll, 'child') as MethodInvocation;
      expect(box.methodName.name, 'ConstrainedBox');
      expect(
        _argument(box, 'constraints').toSource(),
        'BoxConstraints(minHeight: constraints.maxHeight)',
      );
      // In the constraints that the page has.
      final layout =
          _calls(_methodOf(unit, 'OnboardingPage', 'build'), 'LayoutBuilder')
              .single;
      expect(
        _argument(layout, 'builder').toSource(),
        startsWith('(context, constraints) {'),
      );
      expect(
        _methodOf(unit, 'OnboardingPage', '_build').parameters!.toSource(),
        '(BoxConstraints constraints, Widget texts, {required double turned, '
        'required int index})',
      );
      expect(
        (_methodOf(unit, 'OnboardingPage', '_build').body as BlockFunctionBody)
            .block
            .statements
            .last
            .toSource(),
        startsWith('return SingleChildScrollView('),
      );
    });

    test(
        'have their title as a header for a screen reader, which passes '
        'over the cells, a picture', () {
      final header = _calls(unit, 'Semantics').single;

      expect(_argument(header, 'header').toSource(), 'true');
      final title = _argument(header, 'child') as MethodInvocation;
      expect(title.methodName.name, 'OnboardingWords');
      expect(title.argumentList.arguments.first.toSource(), 'title');
      // The text below the title is none.
      final build = _methodOf(unit, 'OnboardingPage', 'build');
      expect(_wordsOf(build), ['title', 'text']);
      expect(_textsOf(build), isEmpty);
      // The cells, with the symbol and the number of the page.
      final picture = _calls(unit, 'ExcludeSemantics').single;
      expect(
        (_argument(picture, 'child') as MethodInvocation).methodName.name,
        '_Cells',
      );
      expect(_calls(unit, '_Cells'), hasLength(1));
    });

    test(
        'stand still outside the screen of the onboarding, and move with '
        'its pages in the scope that the screen puts around each', () {
      final scope = _classOf(unit, 'OnboardingPageScope');
      final build = _methodOf(unit, 'OnboardingPage', 'build');

      expect(scope.extendsClause!.superclass.name.lexeme, 'InheritedWidget');
      expect(
        scope.body.members
            .whereType<ConstructorDeclaration>()
            .single
            .parameters
            .toSource(),
        '({required this.index, required this.controller, '
        'required super.child, super.key})',
      );
      expect(
        _variablesOf(build),
        containsPair('scope', 'OnboardingPageScope.maybeOf(context)'),
      );
      final withoutScope = _ifsOf(build).single;
      expect(withoutScope.expression.toSource(), 'scope == null');
      expect(
        withoutScope.thenStatement.toSource(),
        '{return _build(constraints, texts, turned: 0, index: 0);}',
      );
      // With a scope, the page follows the controller of the pages.
      final following = _calls(build, 'AnimatedBuilder').single;
      expect(_argument(following, 'animation').toSource(), 'scope.controller');
      expect(
        _calls(following, '_build').single.argumentList.toSource(),
        '(constraints, texts!, turned: scope.turned, index: scope.index)',
      );
    });

    test(
        'build their texts once for a width, and not on each frame while the '
        'pages turn: the builder of the frames gets them as its child', () {
      final build = _methodOf(unit, 'OnboardingPage', 'build');
      final turning = _methodOf(unit, 'OnboardingPage', '_build');
      final following = _calls(build, 'AnimatedBuilder').single;

      // The texts are a variable of the builder of the constraints, outside
      // the builder of the frames, which gets them as its child.
      final texts = _variablesOf(build)['texts']!;
      expect(texts, startsWith('Column('));
      expect(_argument(following, 'child').toSource(), 'texts');
      expect(
        _argument(following, 'builder').toSource(),
        startsWith('(context, texts) => _build('),
      );
      expect(
        _calls(_argument(following, 'builder'), 'OnboardingWords'),
        isEmpty,
      );
      // The frames move and fade the texts, and build none.
      expect(_calls(turning, 'OnboardingWords'), isEmpty);
      expect(_textsOf(turning), isEmpty);
      final moved = _calls(turning, 'translate').single;
      expect(_argument(moved, 'child').toSource(), 'texts');
      expect(
        _argument(_enclosing(moved, 'Opacity'), 'opacity').toSource(),
        'shown',
      );
    });

    test(
        'read how far the pages are turned from their controller whenever '
        'it knows its page, so that a page built right after the pages got '
        'a new scroll position stays where it is', () {
      // A new scroll position has the page of the old one, but no
      // dimensions of its own before its first layout: code that waits for
      // those takes a page that the user sees for one not reached yet.
      expect(
        _methodOf(unit, 'OnboardingPageScope', 'turnedOf').body.toSource(),
        '=> (controller.hasClients ? controller.page : null) ?? '
        'controller.initialPage.toDouble();',
      );
      expect(
        _methodOf(unit, 'OnboardingPageScope', 'turned').body.toSource(),
        '=> (turnedOf(controller) - index).clamp(-1, 1);',
      );
      // The background and the marks of the screen read it the same way.
      expect(
        [
          for (final read in _calls(_parsed(app, _screen), 'turnedOf'))
            read.toSource(),
        ],
        [
          'OnboardingPageScope.turnedOf(_controller)',
          'OnboardingPageScope.turnedOf(controller)',
        ],
      );
      for (final path in [_pages, _screen]) {
        expect(
          app.files[path]!.text,
          isNot(contains('haveDimensions')),
          reason: path,
        );
      }
    });

    test(
        'keep the letters and the number of their cell at their size, '
        'whatever the text size of the device, since the cell does not grow',
        () {
      final cell = _methodOf(unit, '_Cell', 'build');
      final unscaled = _calls(cell, 'withNoTextScaling').single;

      expect(unscaled.toSource(), startsWith('MediaQuery.withNoTextScaling('));
      // The cell of a fixed size, with both of its texts.
      final box = _argument(unscaled, 'child') as MethodInvocation;
      expect(box.methodName.name, 'Container');
      expect(
        [
          for (final side in ['width', 'height'])
            _argument(box, side).toSource(),
        ],
        ['164', '164'],
      );
      expect(_textsOf(box), [r"'$number'", 'symbol!']);
      // No other text of the file is kept from the text size of the device:
      // the title and the text below it, which keep their words whole.
      expect(_calls(unit, 'withNoTextScaling'), [unscaled]);
      expect(_wordsOf(unit), ['title', 'text']);
      expect(_textsOf(unit), ['text', r"'$number'", 'symbol!']);
      expect(
        _calls(_classOf(unit, 'OnboardingWords'), 'Text').single.toSource(),
        startsWith('Text(text, '),
      );
    });

    test(
        'name each class of the module after the onboarding, so that no '
        'class of another feature of the app has the name of one, such as '
        'the text that keeps its words whole', () {
      final classes = [
        for (final path in [_pages, _screen, _status])
          for (final declaration
              in _parsed(app, path).declarations.whereType<ClassDeclaration>())
            declaration.namePart.typeName.lexeme,
      ];

      expect(classes, contains('OnboardingWords'));
      expect(
        classes.where((name) => !name.startsWith('_')),
        everyElement(startsWith('Onboarding')),
      );
    });

    test(
        'name no font but the monospaced one of the device, for the number '
        'of a cell: every other text takes the font of the theme of the app',
        () {
      final family = _namedArguments(unit, 'fontFamily').single;

      // Android has its monospaced font under the first name, and iOS under
      // the next.
      expect(family.argumentExpression.toSource(), "'monospace'");
      expect(
        _namedArguments(unit, 'fontFamilyFallback')
            .single
            .argumentExpression
            .toSource(),
        "const ['Menlo', 'Courier']",
      );
      final styled = family.thisOrAncestorMatching<MethodInvocation>(
        (node) => node is MethodInvocation && node.methodName.name == 'Text',
      )!;
      expect(styled.argumentList.arguments.first.toSource(), r"'$number'");
    });

    test(
        'bring their cells in once, and at once in an app that asks for '
        'less motion', () {
      final entering = _calls(unit, 'TweenAnimationBuilder').single;

      expect(
        _argument(entering, 'tween').toSource(),
        'Tween(begin: 0, end: 1)',
      );
      expect(
        _argument(entering, 'duration').toSource(),
        'MediaQuery.disableAnimationsOf(context) ? Duration.zero : '
        'const Duration(milliseconds: 1000)',
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

      // What the role has of the module, in the order of its texts: the
      // provider of the role renders them, and the rule
      // localization.texts_rendered of the role checks that it does.
      expect(
        [
          for (final text in localizationRole.textsIn(input))
            if (text.owner == _module)
              (
                '${text.owner}',
                text.getter,
                text.text.en,
                text.text.textIn('uk'),
              ),
        ],
        [
          for (final MapEntry(key: getter, value: english) in _texts.entries)
            ('$_module', getter, english, _ukrainian[getter]),
        ],
      );
      expect(localizationRole.localesIn(input), ['en', 'uk']);
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
        'onboardingDone',
        'onboardingNext',
        'onboardingSkip',
      ]);
      expect(_pageArguments(pages), [
        // The symbol and the name of the app are the same in every
        // language.
        {
          'symbol': "'Ca'",
          'title': "'Contract App'",
          'text': 'context.l10n.onboardingWelcome',
        },
        {
          'icon': 'Icons.check_rounded',
          'title': 'context.l10n.onboardingReadyTitle',
          'text': 'context.l10n.onboardingReady',
        },
      ]);
      // Skip, and the label of the button below the pages on a page of the
      // module.
      expect(
        _wordsOf(_argument(_buttonCalls(screen).first, 'child')),
        ['context.l10n.onboardingSkip'],
      );
      final onPageOfModule = (_methodOf(
        screen,
        '_OnboardingScreenState',
        'build',
      ).body as BlockFunctionBody)
          .block
          .statements
          .whereType<IfStatement>()
          .single
          .thenStatement;
      expect(
        _assignmentsOf(onPageOfModule),
        containsPair(
          'label',
          'isLast ? context.l10n.onboardingDone : '
              'context.l10n.onboardingNext',
        ),
      );
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
        'names the list of the pages, the widget of a page with what its '
        'cell takes, the list of the steps with what a step has, the status '
        'with what finishes the onboarding and what starts it again, and '
        'the key of the module, as the files of the app declare them', () {
      final code = _codeOf(agentNote);

      expect(
        code,
        containsAll([
          'onboardingPages()',
          _pages,
          'OnboardingPage',
          'symbol',
          'icon',
          'onboardingStatus',
          _status,
          'complete()',
          'restart()',
          'onboardingStatus.complete()',
          OnboardingModule.completedKey,
          OnboardingScreenRole.appOnboardingSteps,
          OnboardingScreenRole.stepsFile,
          'later',
          'run',
        ]),
      );
      // The list of the steps, which the template of the role generates in
      // every app with the module, and the fields of a step.
      final steps = _indexOf(app, OnboardingScreenRole.stepsFile);
      expect(
        steps.declaration(OnboardingScreenRole.appOnboardingSteps)?.kind,
        DeclarationKind.variable,
      );
      expect(
        {
          for (final member
              in steps.declaration(OnboardingScreenRole.step.name)!.members)
            member.name: member.kind,
        },
        allOf(
          containsPair('later', MemberKind.field),
          containsPair('run', MemberKind.field),
        ),
      );
      final pages = _indexOf(app, _pages);
      expect(
        pages.declaration('onboardingPages')?.kind,
        DeclarationKind.function,
      );
      final page = pages.declaration('OnboardingPage')!;
      expect(page.kind, DeclarationKind.classType);
      final ofCell = {
        for (final member in page.members) member.name: member.kind,
      };
      expect(ofCell, containsPair('symbol', MemberKind.field));
      expect(ofCell, containsPair('icon', MemberKind.field));
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

    test(
        'tells a test of another screen to finish the onboarding before the '
        'app starts, as the mocks of the app test of the module do', () {
      final mocks = parseString(
        content: File('app_tests/onboarding/test/onboarding_mocks.dart')
            .readAsStringSync(),
      ).unit;

      expect(_codeOf(agentNote), contains('onboardingStatus.complete()'));
      final calls = _Calls('complete');
      _functionOf(mocks, 'finishOnboarding').accept(calls);
      expect(
        calls.found.map((call) => call.toSource()),
        ['onboardingStatus.complete()'],
      );
      // The file of the status, which the note names.
      expect(
        _importsOf(mocks),
        contains(
          'package:{{app_name}}/features/onboarding/onboarding_status.dart',
        ),
      );
    });
  });

  group('the probe of the module for the start check', () {
    late FunctionDeclaration probe;

    setUpAll(() {
      probe = _functionOf(
        parseString(
          content: File(
            'app_tests/onboarding/integration_test/onboarding/probe.dart',
          ).readAsStringSync(),
        ).unit,
        'probeOnboarding',
      );
    });

    test(
        'expects what redirectOf() of the router role says of the route of '
        'the onboarding, which it asks before it goes there: the screen of '
        'the onboarding, or none of it while a guard before that of the '
        'module keeps the user from the route', () {
      final variables = _variablesOf(probe);
      final asked = _calls(probe, RouterRole.redirectOf).single;
      final go = _calls(probe, 'go').single;

      expect(variables['location'], 'OnboardingOnboardingLocation()');
      expect(
        asked.argumentList.arguments.single.toSource(),
        'location.routeName',
      );
      expect(go.argumentList.arguments.single.toSource(), 'location');
      expect(asked.offset, lessThan(go.offset));
      expect(
        variables,
        containsPair('kept', 'redirectOf(location.routeName) != null'),
      );
      // What the route must show depends on it.
      final conditions = <String, String?>{
        for (final added in _calls(probe, 'add'))
          if (added.thisOrAncestorOfType<IfStatement>() case final condition?)
            condition.expression.toSource():
                (added.argumentList.arguments.single as StringLiteral)
                    .stringValue,
      };
      expect(
        conditions,
        containsPair(
          'kept && _shows<OnboardingScreen>()',
          'A guard of the routes before that of the onboarding keeps the '
              'user from its route, but the route shows the screen of the '
              'onboarding.',
        ),
      );
      expect(
        conditions,
        containsPair(
          '!kept && !_shows<OnboardingScreen>()',
          'While the onboarding is not finished, its route does not show '
              'its screen.',
        ),
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

/// What the `Text` widgets that [node] creates show, in the order of the
/// code: the code of the first argument of each.
List<String> _textsOf(AstNode node) => [
      for (final text in _calls(node, 'Text'))
        text.argumentList.arguments.first.toSource(),
    ];

/// The `if` statements in [node], in the order of the code.
List<IfStatement> _ifsOf(AstNode node) {
  final visitor = _Ifs();
  node.accept(visitor);
  return visitor.found;
}

final class _Ifs extends RecursiveAstVisitor<void> {
  final List<IfStatement> found = [];

  @override
  void visitIfStatement(IfStatement node) {
    found.add(node);
    super.visitIfStatement(node);
  }
}

/// What the texts that keep their words whole, which [node] creates, show,
/// in the order of the code: the code of the first argument of each.
List<String> _wordsOf(AstNode node) => [
      for (final text in _calls(node, 'OnboardingWords'))
        text.argumentList.arguments.first.toSource(),
    ];

/// The arguments of [call], each by its name, or by its place for one
/// without a name, as their code.
Map<String, String> _argumentsOf(MethodInvocation call) => {
      for (final (index, argument) in call.argumentList.arguments.indexed)
        if (argument is NamedArgument)
          argument.name.lexeme: argument.argumentExpression.toSource()
        else
          '$index': argument.toSource(),
    };

/// The call of [name] that [node] is in, such as the creation of the widget
/// around that of [node].
MethodInvocation _enclosing(AstNode node, String name) =>
    node.parent!.thisOrAncestorMatching<MethodInvocation>(
      (ancestor) =>
          ancestor is MethodInvocation && ancestor.methodName.name == name,
    )!;

/// The arguments named [name] in [unit], in the order of the code.
List<NamedArgument> _namedArguments(CompilationUnit unit, String name) {
  final visitor = _NamedArguments(name);
  unit.accept(visitor);
  return visitor.found;
}

final class _NamedArguments extends RecursiveAstVisitor<void> {
  _NamedArguments(this.name);

  final String name;

  final List<NamedArgument> found = [];

  @override
  void visitNamedArgument(NamedArgument node) {
    if (node.name.lexeme == name) found.add(node);
    super.visitNamedArgument(node);
  }
}

/// The pages that the list of the pages in [unit] creates, in its order:
/// the code of each argument of each `OnboardingPage`, by its name.
List<Map<String, String>> _pageArguments(CompilationUnit unit) => [
      for (final page in _calls(unit, 'OnboardingPage'))
        {
          for (final argument
              in page.argumentList.arguments.whereType<NamedArgument>())
            argument.name.lexeme: argument.argumentExpression.toSource(),
        },
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
