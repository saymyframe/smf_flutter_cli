import 'package:smf_contribution_engine/smf_contribution_engine.dart';
import 'package:test/test.dart';

import '../../ast_helpers.dart';

const _localizedApp = '''
import 'package:flutter/material.dart';

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      supportedLocales: [
        Locale('en'),
      ],
      home: Scaffold(
        body: Column(
          children: [
            Text('Hello World!'),
          ],
        ),
      ),
    );
  }
}
''';

void main() {
  group('InsertIntoListInMethodInClass', () {
    InsertIntoListInMethodInClass contribution({
      String className = 'MainApp',
      String method = 'build',
      String listVariableMatch = 'supportedLocales',
      String parentExpressionMatch = 'MaterialApp',
      String insert = "Locale('uk'),",
      int index = 0,
    }) =>
        InsertIntoListInMethodInClass(
          file: 'lib/main.dart',
          className: className,
          method: method,
          listVariableMatch: listVariableMatch,
          parentExpressionMatch: parentExpressionMatch,
          insert: insert,
          index: index,
        );

    test('appends the insert to the matching list', () async {
      final result = await contribution().apply(_localizedApp);

      expect(namedListsOf(result, 'supportedLocales'), [
        ["Locale('en')", "Locale('uk')"],
      ]);
    });

    test('produces the expected file', () async {
      final result = await contribution().apply(_localizedApp);

      expect(
        result,
        _localizedApp.replaceFirst(
          "        Locale('en'),\n",
          "        Locale('en'),\n        Locale('uk'),\n",
        ),
      );
    });

    test('finds lists nested inside other widget arguments', () async {
      final result = await contribution(
        listVariableMatch: 'children',
        parentExpressionMatch: 'Column',
        insert: "Text('Bye!'),",
      ).apply(_localizedApp);

      expect(namedListsOf(result, 'children'), [
        ["Text('Hello World!')", "Text('Bye!')"],
      ]);
    });

    test('keeps existing comments', () async {
      final source = _localizedApp.replaceFirst(
        '      supportedLocales: [\n',
        '      // Keep in sync with l10n.yaml.\n      supportedLocales: [\n',
      );

      final result = await contribution().apply(source);

      expect(result, contains('// Keep in sync with l10n.yaml.'));
    });

    test('appends to an empty list', () async {
      final source = _localizedApp.replaceFirst(
        "supportedLocales: [\n        Locale('en'),\n      ],",
        'supportedLocales: [],',
      );

      final result = await contribution().apply(source);

      expect(namedListsOf(result, 'supportedLocales'), [
        ["Locale('uk')"],
      ]);
    });

    test('uses index to pick among several matching lists', () async {
      const source = '''
class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(children: [Text('body'),]),
      bottomNavigationBar: Row(children: [Text('bottom'),]),
    );
  }
}
''';

      final result = await contribution(
        className: 'HomePage',
        listVariableMatch: 'children',
        parentExpressionMatch: 'Row',
        insert: "Text('new'),",
        index: 1,
      ).apply(source);

      expect(namedListsOf(result, 'children'), [
        ["Text('body')"],
        ["Text('bottom')", "Text('new')"],
      ]);
    });

    group('throws', () {
      Matcher throwsWithMessage(String message) => throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains(message),
            ),
          );

      test('when the class does not exist', () {
        expect(
          contribution(className: 'App').apply(_localizedApp),
          throwsWithMessage('Class App not found'),
        );
      });

      test('when the method does not exist in the class', () {
        expect(
          contribution(method: 'createState').apply(_localizedApp),
          throwsWithMessage('Method createState not found in class MainApp'),
        );
      });

      test('when the method has an expression body', () {
        expect(
          contribution().apply('''
class MainApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const MaterialApp(supportedLocales: [Locale('en')]);
}
'''),
          throwsWithMessage('Method body is not a block'),
        );
      });

      test('when no list has that name', () {
        expect(
          contribution(listVariableMatch: 'localizationsDelegates')
              .apply(_localizedApp),
          throwsWithMessage('No matching list found at index 0'),
        );
      });

      test('when the parent expression is not in the file', () {
        expect(
          contribution(parentExpressionMatch: 'CupertinoApp')
              .apply(_localizedApp),
          throwsWithMessage('No matching list found at index 0'),
        );
      });

      test('when index is past the last match', () {
        expect(
          contribution(index: 1).apply(_localizedApp),
          throwsWithMessage('No matching list found at index 1'),
        );
      });
    });

    test(
      'appends to a list that has no trailing comma',
      () async {
        final source = _localizedApp.replaceFirst(
          "supportedLocales: [\n        Locale('en'),\n      ],",
          "supportedLocales: [Locale('en')],",
        );

        final result = await contribution().apply(source);

        expect(namedListsOf(result, 'supportedLocales'), [
          ["Locale('en')", "Locale('uk')"],
        ]);
      },
      skip: 'Bug: the insert is placed before `]` without adding a separator, '
          'so a list without a trailing comma becomes invalid Dart',
    );

    test(
      'only matches lists whose parent expression matches',
      () async {
        const source = '''
class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(children: [Text('a'),]),
      ],
    );
  }
}
''';

        final result = await contribution(
          className: 'HomePage',
          listVariableMatch: 'children',
          parentExpressionMatch: 'Row',
          insert: "Text('b'),",
        ).apply(source);

        final lists = namedListsOf(result, 'children');
        expect(lists[1], ["Text('a')", "Text('b')"]);
        expect(lists[0], hasLength(1));
      },
      skip: 'Bug: the parent check walks up to the compilation unit, so any '
          'occurrence of parentExpressionMatch in the file matches',
    );

    test(
      'is idempotent',
      () async {
        final once = await contribution().apply(_localizedApp);

        expect(await contribution().apply(once), once);
      },
      skip: 'Bug: nothing checks whether the element is already in the list, '
          'so every run adds it again',
    );
  });
}
