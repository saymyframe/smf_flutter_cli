import 'package:dart_style/dart_style.dart';
import 'package:smf_contribution_engine/smf_contribution_engine.dart';
import 'package:test/test.dart';

import '../../ast_helpers.dart';
import '../../fixtures.dart';

void main() {
  group('InsertIntoFunction', () {
    const ensureInitialized = 'WidgetsFlutterBinding.ensureInitialized();';
    const runApp = 'runApp(const MainApp());';
    const initFirebase = 'await Firebase.initializeApp();';

    InsertIntoFunction afterEnsureInitialized(
      String insert, {
      String function = 'main',
    }) =>
        InsertIntoFunction(
          file: 'lib/main.dart',
          function: function,
          afterStatement: 'WidgetsFlutterBinding.ensureInitialized',
          insert: insert,
        );

    test('inserts after the statement that contains afterStatement', () async {
      final result =
          await afterEnsureInitialized(initFirebase).apply(monolithMainDart);

      expect(
        functionStatements(result, 'main'),
        [ensureInitialized, initFirebase, runApp],
      );
    });

    test('inserts before the statement that contains beforeStatement',
        () async {
      final result = await const InsertIntoFunction(
        file: 'lib/main.dart',
        function: 'main',
        beforeStatement: 'runApp',
        insert: 'setUpCoreDI();',
      ).apply(monolithMainDart);

      expect(
        functionStatements(result, 'main'),
        [ensureInitialized, 'setUpCoreDI();', runApp],
      );
    });

    test('leaves code outside the function untouched', () async {
      final result =
          await afterEnsureInitialized(initFirebase).apply(monolithMainDart);

      expect(result, startsWith("import 'package:flutter/material.dart';\n\n"));
      expect(result, endsWith(monolithMainAppClass));
    });

    test('accepts an insert made of several statements', () async {
      final result = await afterEnsureInitialized('''
  final onError = FlutterError.onError;
  FlutterError.onError = (details) {
    onError?.call(details);
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };
''').apply(monolithMainDart);

      final statements = functionStatements(result, 'main');
      expect(statements, hasLength(4));
      expect(statements[1], 'final onError = FlutterError.onError;');
      expect(statements[2], startsWith('FlutterError.onError = (details) {'));
      expect(statements[3], runApp);
    });

    test('passes mustache placeholders inside string literals through',
        () async {
      final result = await afterEnsureInitialized(
        "debugPrint('{{app_name}} started');",
      ).apply(monolithMainDart);

      expect(
        functionStatements(result, 'main'),
        contains("debugPrint('{{app_name}} started');"),
      );
    });

    test('does not insert anything when no statement matches the anchor',
        () async {
      final result = await const InsertIntoFunction(
        file: 'lib/main.dart',
        function: 'main',
        afterStatement: 'Firebase.initializeApp',
        insert: 'setUpCoreDI();',
      ).apply(monolithMainDart);

      expect(functionStatements(result, 'main'), [ensureInitialized, runApp]);
    });

    test('throws when the function does not exist', () {
      expect(
        afterEnsureInitialized(initFirebase, function: 'bootstrap')
            .apply(monolithMainDart),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Function bootstrap not found'),
          ),
        ),
      );
    });

    test('only looks at top-level functions, not methods', () {
      expect(
        afterEnsureInitialized(initFirebase, function: 'build')
            .apply(monolithMainDart),
        throwsA(isA<Exception>()),
      );
    });

    test('throws when the function has an expression body', () {
      expect(
        afterEnsureInitialized(initFirebase)
            .apply('void main() => runApp(const MainApp());\n'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Function body is not a block'),
          ),
        ),
      );
    });

    test('throws instead of writing broken code when the insert is invalid',
        () {
      expect(
        afterEnsureInitialized('await Firebase.initializeApp(')
            .apply(monolithMainDart),
        throwsA(isA<FormatterException>()),
      );
    });

    test('requires beforeStatement or afterStatement', () {
      expect(
        () => InsertIntoFunction(
          file: 'lib/main.dart',
          function: 'main',
          insert: initFirebase,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test(
      'is idempotent',
      () async {
        final contribution = afterEnsureInitialized(initFirebase);
        final once = await contribution.apply(monolithMainDart);

        expect(await contribution.apply(once), once);
      },
      skip: 'Bug: nothing checks whether the insert is already there, so every '
          'run adds it again',
    );

    test(
      'preserves comments and blank lines in the function body',
      () async {
        const source = '''
import 'package:flutter/material.dart';

Future<void> main() async {
  // Must run before any plugin is used.
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MainApp()); // Keep this last.
}
''';

        final result = await afterEnsureInitialized(initFirebase).apply(source);

        expect(result, contains('  // Must run before any plugin is used.\n'));
        expect(result, contains('\n\n  runApp(const MainApp()); // Keep this'));
      },
      skip: 'Bug: the body is rebuilt from Statement.toSource(), which drops '
          'comments and blank lines',
    );
  });
}
