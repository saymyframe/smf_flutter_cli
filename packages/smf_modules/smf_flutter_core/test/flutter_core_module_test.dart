import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_flutter_core/src/agents.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'support.dart';

/// The method `build` of the class `App` in [text], the text of
/// `lib/app.dart`.
MethodDeclaration _buildOfApp(String text) => parseString(content: text)
    .unit
    .declarations
    .whereType<ClassDeclaration>()
    .singleWhere(
      (declaration) => declaration.namePart.typeName.lexeme == 'App',
    )
    .body
    .members
    .whereType<MethodDeclaration>()
    .singleWhere((method) => method.name.lexeme == 'build');

/// The widget that `main()` passes to `runApp()` in [text], the text of
/// `lib/main.dart`, as written.
String _runAppArgumentOf(String text) {
  final main = parseString(content: text)
      .unit
      .declarations
      .whereType<FunctionDeclaration>()
      .singleWhere((function) => function.name.lexeme == 'main');
  final body = main.functionExpression.body as BlockFunctionBody;
  return [
    for (final statement in body.block.statements)
      if (statement
          case ExpressionStatement(
            expression: MethodInvocation(
              methodName: SimpleIdentifier(name: 'runApp'),
              :final argumentList,
            ),
          ))
        argumentList.arguments.single.toSource(),
  ].single;
}

/// The named arguments of [call] in their order, each as `name: expression`
/// with the expression as written.
List<String> _namedOf(MethodInvocation call) => [
      for (final argument in call.argumentList.arguments)
        if (argument case NamedArgument(:final name, :final argumentExpression))
          '${name.lexeme}: ${argumentExpression.toSource()}',
    ];

/// A module that gives the root of the app every argument that the app
/// entry role takes from the modules.
final class _RootArgumentsModule extends SmfModule {
  const _RootArgumentsModule();

  static const id = ModuleId('root_arguments');

  /// An expression for each argument, or for an item of its list.
  static const arguments = {
    'theme': 'ThemeData.light()',
    'darkTheme': 'ThemeData.dark()',
    'themeMode': 'ThemeMode.system',
    'locale': "const Locale('en')",
    'localizationsDelegates': 'DefaultMaterialLocalizations.delegate',
    'supportedLocales': "const Locale('en')",
  };

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Every argument of the root of the app',
        kind: ModuleKinds.infrastructure,
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        for (final MapEntry(key: name, value: expression) in arguments.entries)
          SocketContribution.arg(
            AppEntryRole.appArgs,
            name,
            Fragment(
              expression,
              imports: const [ImportRef('package:flutter/material.dart')],
            ),
          ),
      ];
}

void main() {
  const module = FlutterCoreModule();

  group('FlutterCoreModule', () {
    test('is the scaffold that provides the app entry and uses a router', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, FlutterCoreModule.id);
      expect(descriptor.kind, ModuleKinds.scaffold);
      expect(descriptor.provides, {appEntryRole});
      expect(descriptor.uses, {routerRole});
      expect(descriptor.dependsOn, isEmpty);
      expect(descriptor.requires, isEmpty);
    });

    test('forms a valid registry on its own and with other modules', () {
      expect(ModuleRegistry.problemsOf(const [module]), isEmpty);
      expect(ModuleRegistry.problemsOf(testRegistry().modules), isEmpty);
    });

    test('names the Android and iOS projects after the app', () {
      final brick = module
          .contribute(ContractHarness.defaultContext)
          .whereType<BrickContribution>()
          .single;

      expect(brick.vars, {
        'android_namespace': 'com.example.contract_app',
        'android_application_id': 'com.example.contract_app',
        'android_package_path': 'com/example/contract_app',
        'ios_bundle_id': 'com.example.contract-app',
      });
    });
  });

  group('the contract harness', () {
    late List<ContractResult> results;

    setUpAll(() async {
      results = await ContractHarness(testRegistry()).checkAll();
    });

    test('builds the app with and without a router', () {
      expect(
        results.map((result) => result.contractCase.name),
        containsAll(['flutter_core with router', 'flutter_core']),
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

  group('an app of flutter_core alone', () {
    late RenderedApp app;
    late Map<String, String> texts;

    setUpAll(() async {
      final result = await renderedApp(const [FlutterCoreModule.id]);
      app = result.app!;
      texts = app.texts;
    });

    test('has the Dart entry point, the root widget and a widget test', () {
      expect(
        texts.keys,
        containsAll(const [
          'lib/main.dart',
          'lib/bootstrap.dart',
          'lib/app.dart',
          'lib/core/app/fallback_start_screen.dart',
          'test/core/app/fallback_start_screen_test.dart',
          'analysis_options.yaml',
          'pubspec.yaml',
          'README.md',
          '.gitignore',
          '.metadata',
        ]),
      );
    });

    test('runs the app after bootstrap() without wrappers', () {
      expect(
        texts['lib/main.dart'],
        allOf(
          contains('WidgetsFlutterBinding.ensureInitialized();\n'
              '  await bootstrap();\n'),
          contains('runApp(\n    const App(),\n  );'),
        ),
      );
    });

    test('has an empty bootstrap() without imports', () {
      final bootstrap = texts['lib/bootstrap.dart']!;

      expect(bootstrap, contains('Future<void> bootstrap() async {'));
      expect(bootstrap, isNot(contains('import ')));
    });

    test('shows the fallback start screen in a MaterialApp', () {
      final app = texts['lib/app.dart']!;

      expect(app, contains("import 'core/app/fallback_start_screen.dart';"));
      expect(app, isNot(contains('app_router.dart')));
      expect(app, contains('MaterialApp(\n'));
      expect(app, contains("title: 'Contract App',"));
      expect(
        app,
        contains('builder: (context, child) =>\n            child!,'),
      );
      expect(app, contains('home: const FallbackStartScreen(),'));
      expect(app, isNot(contains('routerConfig')));
    });

    test('names the app on the fallback start screen and in its test', () {
      expect(
        texts['lib/core/app/fallback_start_screen.dart'],
        contains("Text('Contract App')"),
      );
      final test = texts['test/core/app/fallback_start_screen_test.dart']!;
      expect(
        test,
        contains(
          "import 'package:contract_app/core/app/fallback_start_screen.dart';",
        ),
      );
      expect(test, contains("find.text('Contract App')"));
    });

    test('depends on Flutter 3.44 and the lints of a new Flutter app', () {
      final pubspec = loadYaml(texts['pubspec.yaml']!) as YamlMap;

      expect(pubspec['name'], 'contract_app');
      expect(pubspec['publish_to'], 'none');
      expect(pubspec['environment'], {
        'sdk': '^3.12.0',
        'flutter': '>=3.44.0',
      });
      expect(pubspec['dependencies'], {
        'flutter': {'sdk': 'flutter'},
      });
      expect(pubspec['dev_dependencies'], {
        'flutter_test': {'sdk': 'flutter'},
        'flutter_lints': '^6.0.0',
      });
      expect(pubspec['flutter'], {'uses-material-design': true});
    });

    test(
        'analyzes the app with the lints of a new Flutter app, without what '
        'the Flutter tools write', () {
      final options = loadYaml(texts['analysis_options.yaml']!) as YamlMap;

      // On macOS, Flutter copies into build/ the Swift packages of plugins
      // that depend on other plugins, with their examples.
      expect(options, {
        'include': 'package:flutter_lints/flutter.yaml',
        'analyzer': {
          'exclude': ['build/**'],
        },
      });
    });

    test('names the app in a README without sections', () {
      expect(texts['README.md'], '# contract_app\n\nA new Flutter project.\n');
    });

    test(
        'has the guide for coding agents of the app entry role, with the '
        'section of the role', () {
      final guide = app.files[AppEntryRole.agentsFile]!;

      // The template of the role generates the guide, whichever module
      // provides the role.
      expect(guide.owner, const RoleTemplateOrigin(appEntryRole));
      expect(
        app.files[AppEntryRole.claudeFile]!.owner,
        const RoleTemplateOrigin(appEntryRole),
      );
      expect(texts[AppEntryRole.claudeFile], '@AGENTS.md\n');
      expect(guide.text, startsWith('# AGENTS.md\n\n'));
      expect(
        RegExp(r'^## (.+)$', multiLine: true)
            .allMatches(guide.text)
            .map((heading) => heading[1]),
        [appEntryRole.description],
      );
    });

    test(
        'adds its note to the section of the app entry in the guide, after '
        'that of the role', () {
      final notes = app.entriesOf(AppEntryRole.agentSections);

      // The socket takes its contributors by their ids.
      expect(
        [
          for (final (origin, heading, note) in notes)
            (origin, heading, note.isOfRole),
        ],
        [
          (
            const ModuleOrigin(FlutterCoreModule.id),
            appEntryRole.description,
            false,
          ),
          (
            const RoleTemplateOrigin(appEntryRole),
            appEntryRole.description,
            true,
          ),
        ],
      );
      expect(notes.first.$3, AgentNote(agentNote));
      // The section has what the role says first, then the note of the
      // module.
      expect(
        texts[AppEntryRole.agentsFile],
        endsWith('\n\n${notes.last.$3.text}\n\n${agentNote.trim()}\n'),
      );
    });

    test(
        'names in its note the root widget, the tests and the platforms that '
        'the app has', () {
      // The root widget, which creates the one MaterialApp of lib/.
      const root = 'lib/app.dart';
      final creating = [
        for (final MapEntry(key: path, value: text) in texts.entries)
          if (path.startsWith('lib/') && path.endsWith('.dart'))
            for (final call in DartFileIndexer.index(path, text).invocations)
              if (call.name == 'MaterialApp') path,
      ];
      expect(creating, [root]);
      expect(
        DartFileIndexer.index(root, texts[root]!).declaration('App')?.kind,
        DeclarationKind.classType,
      );
      // The test of a file of lib/ has its path in test/.
      final tests = texts.keys.where((path) => path.startsWith('test/'));
      expect(tests, isNotEmpty);
      for (final path in tests) {
        final tested = path
            .replaceFirst('test/', 'lib/')
            .replaceFirst(RegExp(r'_test\.dart$'), '.dart');
        expect(texts.keys, contains(tested), reason: path);
      }
      // Android and iOS, and no other platform.
      expect(
        {
          for (final path in app.files.keys)
            if (path.contains('/')) path.split('/').first,
        },
        {'android', 'ios', 'lib', 'test'},
      );
      for (final given in const [
        '`lib/app.dart`',
        '`App`',
        '`MaterialApp`',
        '`lib/<path>.dart`',
        '`test/<path>_test.dart`',
        '`android/`',
        '`ios/`',
      ]) {
        expect(agentNote, contains(given), reason: given);
      }
    });

    test(
        'names in its note the commands that check a change, which format '
        'only the code of the app and run its tests', () {
      final commands = RegExp(r'```bash\n([^`]+)```').firstMatch(agentNote);

      // Not `dart format .`: after `flutter pub get` on macOS, `build/` has
      // copies of the plugins that depend on other plugins, with their Dart
      // files, which that command would format too.
      expect(commands![1]!.trim().split('\n'), [
        'dart format lib test',
        'flutter analyze',
        'flutter test',
      ]);
      // The two directories with the Dart code of the app, and a test for
      // `flutter test` to run: what the role does not guarantee, and so
      // does not say.
      expect(
        {
          for (final path in texts.keys)
            if (path.endsWith('.dart')) path.split('/').first,
        },
        {'lib', 'test'},
      );
      expect(
        texts.keys.where((path) => path.startsWith('test/')),
        isNotEmpty,
      );
    });
  });

  group('an app of flutter_core with a router', () {
    test('passes the router to a MaterialApp.router', () async {
      final result = await renderedApp(const [
        FlutterCoreModule.id,
        TestRouterModule.id,
      ]);
      final app = result.app!.texts['lib/app.dart']!;

      expect(app, contains("import 'core/router/app_router.dart';"));
      expect(app, isNot(contains('fallback_start_screen.dart')));
      expect(app, contains('MaterialApp.router(\n'));
      expect(app, contains('routerConfig: appRouter.config,'));
      expect(app, isNot(contains('home:')));
    });
  });

  group('an app with something in every socket', () {
    late Map<String, String> texts;

    setUpAll(() async {
      final result = await renderedApp(const [
        FlutterCoreModule.id,
        EverySocketModule.id,
      ]);
      texts = result.app!.texts;
    });

    test('starts up in the order of the phases of bootstrap()', () {
      final bootstrap = texts['lib/bootstrap.dart']!;
      final offsets = [
        for (final phase in ['early', 'platform', 'di', 'late'])
          bootstrap.indexOf("debugPrint('$phase');"),
      ];

      expect(offsets, everyElement(greaterThan(0)));
      expect(offsets, orderedEquals([...offsets]..sort()));
      // The code of every phase runs in bootstrap(), which main() awaits,
      // and nowhere else.
      final calls = DartFileIndexer.index('lib/bootstrap.dart', bootstrap)
          .invocationsOf('debugPrint');
      expect(
        [for (final call in calls) call.enclosingDeclaration],
        List.filled(4, 'bootstrap'),
      );
      expect(
        bootstrap,
        startsWith("import 'package:flutter/foundation.dart';\n\n"
            "@pragma('vm:entry-point')\n"
            'Future<void> onBackgroundMessage() async {}\n'),
      );
    });

    test('has the sections of the modules in its README', () {
      expect(
        texts['README.md'],
        '# contract_app\n'
        '\n'
        'A new Flutter project.\n'
        '\n'
        '## Every socket\n'
        '\n'
        'The app has something in every socket of its entry.\n',
      );
    });

    test('has the notes of the modules in its guide for coding agents', () {
      expect(
        texts[AppEntryRole.agentsFile],
        endsWith(
          '\n'
          '## Every socket\n'
          '\n'
          'Leave what the sockets of `lib/bootstrap.dart` got.\n',
        ),
      );
    });

    test('wraps the root widget and every route', () {
      expect(
        texts['lib/main.dart'],
        contains('RepaintBoundary(child: const App()),'),
      );
      final app = texts['lib/app.dart']!;
      expect(app, contains("supportedLocales: [Locale('en')],"));
      expect(
        app,
        contains('MediaQuery.withNoTextScaling(child: child!),'),
      );
    });
  });

  group('the arguments that the modules give the root of the app', () {
    for (final (router, creation) in [
      (null, 'MaterialApp'),
      (TestRouterModule.id, 'MaterialApp.router'),
    ]) {
      test(
          'are those of the $creation that the build() of App returns, and '
          'main() runs App inside the root wrappers, so they read its '
          'context below them', () async {
        final result = await renderedApp([
          FlutterCoreModule.id,
          if (router != null) router,
          EverySocketModule.id,
        ]);
        final files = result.app!.texts;
        final build = _buildOfApp(files['lib/app.dart']!);
        final body = build.body as ExpressionFunctionBody;
        final root = body.expression as MethodInvocation;

        // The context of the arguments is the one that build() gets, so
        // App rebuilds when an inherited widget that they read notifies.
        expect(build.parameters!.toSource(), '(BuildContext context)');
        expect(
          [
            if (root.target case final target?) target.toSource(),
            root.methodName.name,
          ].join('.'),
          creation,
        );
        // Among the arguments of the root itself, in the order of the
        // socket.
        expect(
          _namedOf(root),
          containsAllInOrder([
            'themeMode: ${EverySocketModule.themeMode}',
            'locale: ${EverySocketModule.locale}',
            "supportedLocales: [Locale('en')]",
          ]),
        );
        // The widgets that the modules put around the root are ancestors
        // of that context.
        expect(
          _runAppArgumentOf(files['lib/main.dart']!),
          'RepaintBoundary(child: const App())',
        );
      });
    }

    test(
        'are each named in the note of the module for coding agents, which '
        'tells that they are arguments of that MaterialApp', () async {
      // An app whose module gives the root every argument that the role
      // takes from the modules.
      final result = await ContractHarness(
        ModuleRegistry(const [FlutterCoreModule(), _RootArgumentsModule()]),
      ).check(
        const ContractCase(
          'every argument of the root',
          requested: [FlutterCoreModule.id, _RootArgumentsModule.id],
        ),
      );
      expect(result.errors, isEmpty);
      final build = _buildOfApp(result.app!.texts['lib/app.dart']!);
      final body = build.body as ExpressionFunctionBody;
      final root = body.expression as MethodInvocation;
      final named = [
        for (final argument in root.argumentList.arguments)
          if (argument case NamedArgument(:final name)) name.lexeme,
      ];

      expect(root.methodName.name, 'MaterialApp');
      final arguments = AppEntryRole.appArgs.kind.args;
      expect(_RootArgumentsModule.arguments.keys, arguments.keys);
      expect(named, containsAll(arguments.keys));
      for (final MapEntry(key: name, value: shape) in arguments.entries) {
        if (shape == ArgShape.scalar) {
          expect(agentNote, contains('`$name`'), reason: name);
        } else {
          // The lists are those of the localizations, which the note names
          // as what they are.
          expect(
            ['localizationsDelegates', 'supportedLocales'],
            contains(name),
          );
        }
      }
      expect(agentNote, contains('localizations of the app'));
    });
  });
}
