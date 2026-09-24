import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mustachex/mustachex.dart';
import 'package:path/path.dart' as p;
import 'package:smf_contribution_engine/smf_contribution_engine.dart';
import 'package:test/test.dart';

import '../ast_helpers.dart';
import '../fixtures.dart';

const _mainFile = 'lib/main.dart';
const _ensureInitialized = 'WidgetsFlutterBinding.ensureInitialized();';
const _runApp = 'runApp(const MainApp());';

class _RecordingLogger extends Logger {
  final events = <String>[];

  @override
  Progress progress(String message, {ProgressOptions? options}) {
    events.add('progress: $message');
    return _RecordingProgress(events);
  }
}

class _RecordingProgress implements Progress {
  _RecordingProgress(this.events);

  final List<String> events;

  @override
  void complete([String? update]) => events.add('complete: $update');

  @override
  void fail([String? update]) => events.add('fail: $update');

  @override
  void update(String update) => events.add('update: $update');

  @override
  void cancel() => events.add('cancel');
}

/// A contribution of a type the engine does not know.
class _AppendLine extends Contribution {
  const _AppendLine(this.line) : super(file: _mainFile);

  final String line;

  @override
  Future<String> apply(String original) async => '$original$line\n';
}

/// A subclass of a contribution type the engine knows, doing a bit more.
class _SignedImport extends InsertImport {
  const _SignedImport({required super.import}) : super(file: _mainFile);

  @override
  Future<String> apply(String original) async =>
      '${await super.apply(original)}// Signed.\n';
}

InsertIntoFunction _afterEnsureInitialized(String insert) => InsertIntoFunction(
      file: _mainFile,
      function: 'main',
      afterStatement: 'WidgetsFlutterBinding.ensureInitialized',
      insert: insert,
    );

void main() {
  group('PatchEngine', () {
    late Directory projectRoot;

    File fileAt(String relativePath) =>
        File(p.join(projectRoot.path, relativePath));

    Future<void> writeFile(String relativePath, String content) async {
      final file = fileAt(relativePath);
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
    }

    Future<String> readMain() => fileAt(_mainFile).readAsString();

    Future<void> applyAll(
      List<Contribution> contributions, {
      Map<String, dynamic>? mustacheVariables,
      Logger? logger,
    }) =>
        PatchEngine(
          contributions,
          projectRoot: projectRoot.path,
          mustacheVariables: mustacheVariables,
          logger: logger,
        ).applyAll();

    setUp(() async {
      projectRoot = await Directory.systemTemp.createTemp('smf_patch_engine');
      await writeFile(_mainFile, monolithMainDart);
    });

    tearDown(() => projectRoot.delete(recursive: true));

    test('applies the contributions and writes the file back', () async {
      await applyAll([
        const InsertImport(
          file: _mainFile,
          import: "import 'package:firebase_core/firebase_core.dart';",
        ),
        _afterEnsureInitialized('await Firebase.initializeApp();'),
      ]);

      final result = await readMain();
      expect(directivesOf(result), [
        "import 'package:flutter/material.dart';",
        "import 'package:firebase_core/firebase_core.dart';",
      ]);
      expect(functionStatements(result, 'main'), [
        _ensureInitialized,
        'await Firebase.initializeApp();',
        _runApp,
      ]);
    });

    test('applies contributions to a file in list order', () async {
      await applyAll([
        const InsertImport(file: _mainFile, import: "import 'a.dart';"),
        _afterEnsureInitialized('first();'),
        const InsertImport(file: _mainFile, import: "import 'b.dart';"),
        _afterEnsureInitialized('second();'),
      ]);

      final result = await readMain();
      expect(directivesOf(result), [
        "import 'package:flutter/material.dart';",
        "import 'a.dart';",
        "import 'b.dart';",
      ]);
      // Each insert lands right after the anchor, ahead of earlier inserts.
      expect(functionStatements(result, 'main'), [
        _ensureInitialized,
        'second();',
        'first();',
        _runApp,
      ]);
    });

    test('patches every targeted file and leaves the others alone', () async {
      const routerFile = 'lib/core/router/app_router.dart';
      const untouchedFile = 'lib/app.dart';
      await writeFile(
        routerFile,
        "import 'package:go_router/go_router.dart';\n",
      );
      await writeFile(untouchedFile, 'class App {}\n');

      await applyAll([
        const InsertImport(file: _mainFile, import: "import 'a.dart';"),
        const InsertImport(file: routerFile, import: "import 'b.dart';"),
      ]);

      expect(directivesOf(await readMain()), contains("import 'a.dart';"));
      expect(
        directivesOf(await fileAt(routerFile).readAsString()),
        contains("import 'b.dart';"),
      );
      expect(await fileAt(untouchedFile).readAsString(), 'class App {}\n');
    });

    test('renders mustache placeholders in the inserted code', () async {
      await applyAll(
        [
          const InsertImport(
            file: _mainFile,
            import: "import 'package:{{app_name_sc}}/core/di/core_di.dart';",
          ),
          _afterEnsureInitialized("debugPrint('{{app_name_pc}} started');"),
        ],
        mustacheVariables: {'app_name': 'shop app'},
      );

      final result = await readMain();
      expect(
        directivesOf(result),
        contains("import 'package:shop_app/core/di/core_di.dart';"),
      );
      expect(
        functionStatements(result, 'main'),
        contains("debugPrint('ShopApp started');"),
      );
    });

    test('fails without touching the file when a placeholder has no value',
        () async {
      final run = applyAll([
        const InsertImport(
          file: _mainFile,
          import: "import 'package:{{app_name_sc}}/core/di/core_di.dart';",
        ),
      ]);

      await expectLater(run, throwsA(isA<MissingVariableException>()));
      expect(await readMain(), monolithMainDart);
    });

    test('fails without touching the file when a contribution fails', () async {
      final run = applyAll([
        const InsertImport(file: _mainFile, import: "import 'a.dart';"),
        const InsertIntoFunction(
          file: _mainFile,
          function: 'bootstrap',
          afterStatement: 'runApp',
          insert: 'setUp();',
        ),
      ]);

      await expectLater(run, throwsA(isA<Exception>()));
      expect(await readMain(), monolithMainDart);
    });

    test('throws when a targeted file does not exist', () {
      expect(
        applyAll([
          const InsertImport(
            file: 'lib/missing.dart',
            import: "import 'a.dart';",
          ),
        ]),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('reports progress for each file', () async {
      const otherFile = 'lib/app.dart';
      await writeFile(otherFile, 'class App {}\n');
      final logger = _RecordingLogger();

      await applyAll(
        [
          const InsertImport(file: _mainFile, import: "import 'a.dart';"),
          const InsertImport(file: otherFile, import: "import 'b.dart';"),
          const InsertImport(file: _mainFile, import: "import 'c.dart';"),
        ],
        logger: logger,
      );

      expect(logger.events, [
        'progress: Generating shared content for $_mainFile',
        'complete: Generated shared content for $_mainFile',
        'progress: Generating shared content for $otherFile',
        'complete: Generated shared content for $otherFile',
      ]);
    });

    test('applies the firebase_core, get_it and go_router contributions',
        () async {
      // Copied from the sharedFileContributions of the three modules.
      await applyAll(
        [
          const InsertImport(
            file: _mainFile,
            import: "import 'package:firebase_core/firebase_core.dart';",
          ),
          _afterEnsureInitialized('await Firebase.initializeApp();'),
          const InsertImport(
            file: _mainFile,
            import: "import 'package:{{app_name_sc}}/core/di/core_di.dart';",
          ),
          _afterEnsureInitialized('setUpCoreDI();'),
          const InsertImport(
            file: _mainFile,
            import:
                "import 'package:{{app_name_sc}}/core/router/app_router.dart';",
          ),
          const ReplaceWidget(
            file: _mainFile,
            fromWidget: 'MaterialApp',
            toWidget: 'MaterialApp.router',
            className: 'MainApp',
            methodName: 'build',
          ),
          const ModifyWidgetArguments(
            file: _mainFile,
            widgetName: 'router',
            removeArgs: ['home'],
            addArgs: {'routerConfig': 'router'},
          ),
        ],
        mustacheVariables: {'app_name': 'my_app'},
      );

      final result = await readMain();
      expect(directivesOf(result), [
        "import 'package:flutter/material.dart';",
        "import 'package:firebase_core/firebase_core.dart';",
        "import 'package:my_app/core/di/core_di.dart';",
        "import 'package:my_app/core/router/app_router.dart';",
      ]);
      expect(functionStatements(result, 'main'), [
        _ensureInitialized,
        'setUpCoreDI();',
        'await Firebase.initializeApp();',
        _runApp,
      ]);
      expect(methodStatements(result, 'MainApp', 'build'), [
        'return MaterialApp.router(routerConfig: router);',
      ]);
    });

    test(
      'leaves mustache-like text in the existing code alone',
      () async {
        final source = monolithMainDart.replaceFirst(
          "Text('Hello World!')",
          "Text('Hello {{name}}!')",
        );
        await writeFile(_mainFile, source);

        await applyAll(
          [const InsertImport(file: _mainFile, import: "import 'a.dart';")],
          mustacheVariables: {'app_name': 'my_app'},
        );

        expect(await readMain(), contains("Text('Hello {{name}}!')"));
      },
    );

    test(
      'does not duplicate a templated import when run twice',
      () async {
        const contribution = InsertImport(
          file: _mainFile,
          import: "import 'package:{{app_name_sc}}/core/di/core_di.dart';",
        );

        await applyAll([contribution],
            mustacheVariables: {'app_name': 'my_app'});
        final once = await readMain();
        await applyAll([contribution],
            mustacheVariables: {'app_name': 'my_app'});

        expect(await readMain(), once);
      },
    );

    test(
      'renders placeholders that are used outside string literals',
      () async {
        await applyAll(
          [_afterEnsureInitialized('await {{app_name_pc}}Di.setUp();')],
          mustacheVariables: {'app_name': 'my_app'},
        );

        expect(
          functionStatements(await readMain(), 'main'),
          contains('await MyAppDi.setUp();'),
        );
      },
    );

    group('renders the inserted text of', () {
      const myApp = {'app_name': 'my_app'};

      test('InsertIntoFunction, keeping beforeStatement', () async {
        await applyAll(
          [
            const InsertIntoFunction(
              file: _mainFile,
              function: 'main',
              beforeStatement: 'runApp',
              insert: 'await {{app_name_pc}}Di.setUp();',
            ),
          ],
          mustacheVariables: myApp,
        );

        expect(functionStatements(await readMain(), 'main'), [
          _ensureInitialized,
          'await MyAppDi.setUp();',
          _runApp,
        ]);
      });

      test('InsertIntoMethodInClass', () async {
        await writeFile(_mainFile, homePageStateDart);

        await applyAll(
          [
            const InsertIntoMethodInClass(
              file: _mainFile,
              className: '_HomePageState',
              method: 'initState',
              afterStatement: 'super.initState()',
              insert: '{{app_name_pc}}Analytics.track();',
            ),
          ],
          mustacheVariables: myApp,
        );

        expect(
          methodStatements(await readMain(), '_HomePageState', 'initState'),
          ['super.initState();', 'MyAppAnalytics.track();'],
        );
      });

      test('InsertIntoListInFunction', () async {
        await writeFile(_mainFile, providerMainDart);

        await applyAll(
          [
            const InsertIntoListInFunction(
              file: _mainFile,
              function: 'main',
              listVariableMatch: 'providers',
              parentExpressionMatch: 'MultiProvider',
              insert: 'Provider(create: (_) => {{app_name_pc}}Api()),',
            ),
          ],
          mustacheVariables: myApp,
        );

        expect(namedListsOf(await readMain(), 'providers'), [
          [
            'Provider(create: (_) => MyAppApi())',
            'Provider(create: (_) => Logger())'
          ],
        ]);
      });

      test('InsertIntoListInMethodInClass', () async {
        await writeFile(_mainFile, '''
class MainApp {
  Widget build() {
    return MaterialApp(
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
      ],
    );
  }
}
''');

        await applyAll(
          [
            const InsertIntoListInMethodInClass(
              file: _mainFile,
              className: 'MainApp',
              method: 'build',
              listVariableMatch: 'localizationsDelegates',
              parentExpressionMatch: 'MaterialApp',
              insert: '{{app_name_pc}}Localizations.delegate,',
            ),
          ],
          mustacheVariables: myApp,
        );

        expect(namedListsOf(await readMain(), 'localizationsDelegates'), [
          [
            'GlobalMaterialLocalizations.delegate',
            'MyAppLocalizations.delegate',
          ],
        ]);
      });

      test('ReplaceWidget, keeping its scope', () async {
        await applyAll(
          [
            const ReplaceWidget(
              file: _mainFile,
              fromWidget: 'MaterialApp',
              toWidget: '{{app_name_pc}}App',
              className: 'MainApp',
              methodName: 'build',
            ),
            // Would rename the widget in main() if the class were lost.
            const ReplaceWidget(
              file: _mainFile,
              fromWidget: 'MainApp',
              toWidget: '{{app_name_pc}}',
              className: 'MainApp',
            ),
          ],
          mustacheVariables: myApp,
        );

        final result = await readMain();
        expect(
          methodStatements(result, 'MainApp', 'build').single,
          startsWith('return const MyAppApp('),
        );
        expect(functionStatements(result, 'main'), contains(_runApp));
      });

      test('ModifyWidgetArguments', () async {
        await applyAll(
          [
            const ModifyWidgetArguments(
              file: _mainFile,
              widgetName: 'MaterialApp',
              removeArgs: ['home'],
              addArgs: {'title': '{{app_name_pc}}Strings.title'},
            ),
          ],
          mustacheVariables: myApp,
        );

        expect(methodStatements(await readMain(), 'MainApp', 'build'), [
          'return MaterialApp(title: MyAppStrings.title);',
        ]);
      });

      test('a contribution of another type, but not the existing code',
          () async {
        final source = monolithMainDart.replaceFirst(
          "Text('Hello World!')",
          "Text('Hello {{name}}!')",
        );
        await writeFile(_mainFile, source);

        await applyAll(
          [const _AppendLine('// Made by {{app_name_pc}}.')],
          mustacheVariables: myApp,
        );

        expect(await readMain(), '$source// Made by MyApp.\n');
      });

      test('a subclass of a known type, keeping what the subclass adds',
          () async {
        await applyAll(
          [
            const _SignedImport(
              import: "import 'package:{{app_name_sc}}/core/di/core_di.dart';",
            ),
          ],
          mustacheVariables: myApp,
        );

        final result = await readMain();
        expect(
          directivesOf(result),
          contains("import 'package:my_app/core/di/core_di.dart';"),
        );
        expect(result, endsWith('// Signed.\n'));
      });
    });
  });
}
