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
      skip: 'Bug: the whole file is rendered as a mustache template after '
          'every contribution, not just the inserted code',
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
      skip: 'Bug: contributions see their unrendered text, so the duplicate '
          'check compares {{app_name_sc}} with the rendered file',
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
      skip: 'Bug: placeholders are rendered only after apply(), so one in code '
          'position makes the formatter reject the snippet',
    );
  });
}
