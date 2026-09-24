import 'package:smf_contribution_engine/smf_contribution_engine.dart';
import 'package:test/test.dart';

import '../../ast_helpers.dart';
import '../../fixtures.dart';

void main() {
  group('InsertIntoListInFunction', () {
    const logger = 'Provider(create: (_) => Logger())';
    const analytics = 'Provider(create: (_) => Analytics())';

    InsertIntoListInFunction intoProviders({
      String function = 'main',
      String listVariableMatch = 'providers',
      String parentExpressionMatch = 'MultiProvider',
      int index = 0,
    }) =>
        InsertIntoListInFunction(
          file: 'lib/main.dart',
          function: function,
          listVariableMatch: listVariableMatch,
          parentExpressionMatch: parentExpressionMatch,
          // The insert carries its own separator.
          insert: '$analytics,',
          index: index,
        );

    test('prepends the insert to the matching list', () async {
      final result = await intoProviders().apply(providerMainDart);

      expect(namedListsOf(result, 'providers'), [
        [analytics, logger],
      ]);
    });

    test('accepts the list name with a trailing colon', () async {
      final result = await intoProviders(listVariableMatch: 'providers:')
          .apply(providerMainDart);

      expect(namedListsOf(result, 'providers'), [
        [analytics, logger],
      ]);
    });

    test('keeps existing comments', () async {
      final source = providerMainDart.replaceFirst(
        '        Provider(create: (_) => Logger()),\n',
        '        // Logging comes first.\n'
            '        Provider(create: (_) => Logger()),\n',
      );

      final result = await intoProviders().apply(source);

      expect(result, contains('// Logging comes first.'));
    });

    test('inserts into an empty list', () async {
      final source = providerMainDart.replaceFirst(
        RegExp(r'providers: \[[^\]]*\]'),
        'providers: []',
      );

      final result = await intoProviders().apply(source);

      expect(namedListsOf(result, 'providers'), [
        [analytics],
      ]);
    });

    test('uses index to pick among several matching lists', () async {
      const source = '''
List<Widget> buildColumns() {
  return [
    Column(children: [Text('a')]),
    Column(children: [Text('b')]),
  ];
}
''';

      final result = await const InsertIntoListInFunction(
        file: 'lib/columns.dart',
        function: 'buildColumns',
        listVariableMatch: 'children',
        parentExpressionMatch: 'Column',
        insert: "Text('new'),",
        index: 1,
      ).apply(source);

      expect(namedListsOf(result, 'children'), [
        ["Text('a')"],
        ["Text('new')", "Text('b')"],
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

      test('when the function does not exist', () {
        expect(
          intoProviders(function: 'bootstrap').apply(providerMainDart),
          throwsWithMessage('Function bootstrap not found'),
        );
      });

      test('when the function has an expression body', () {
        expect(
          intoProviders().apply(
            'void main() => runApp(MultiProvider(providers: []));\n',
          ),
          throwsWithMessage('Function body is not a block'),
        );
      });

      test('when no list has that name', () {
        expect(
          intoProviders(listVariableMatch: 'overrides').apply(providerMainDart),
          throwsWithMessage('List match not found at index 0'),
        );
      });

      test('when the parent expression is not in the file', () {
        expect(
          intoProviders(parentExpressionMatch: 'MultiBlocProvider')
              .apply(providerMainDart),
          throwsWithMessage('List match not found at index 0'),
        );
      });

      test('when index is past the last match', () {
        expect(
          intoProviders(index: 1).apply(providerMainDart),
          throwsWithMessage('List match not found at index 1'),
        );
      });
    });

    test(
      'only looks for the list inside the named function',
      () async {
        const source = '''
void main() {
  runApp(MultiProvider(providers: [Provider(create: (_) => Logger())]));
}

Widget buildTestApp() {
  return MultiProvider(providers: [Provider(create: (_) => Logger())]);
}
''';

        final result =
            await intoProviders(function: 'buildTestApp').apply(source);

        expect(namedListsOf(result, 'providers'), [
          [logger],
          [analytics, logger],
        ]);
      },
      skip: 'Bug: the list is searched for in the whole file, not in the '
          'function body',
    );

    test(
      'finds lists nested under other named arguments',
      () async {
        const source = '''
void main() {
  runApp(
    MaterialApp(
      home: Scaffold(body: Column(children: [Text('a')])),
    ),
  );
}
''';

        final result = await const InsertIntoListInFunction(
          file: 'lib/main.dart',
          function: 'main',
          listVariableMatch: 'children',
          parentExpressionMatch: 'Column',
          insert: "Text('new'),",
        ).apply(source);

        expect(namedListsOf(result, 'children'), [
          ["Text('new')", "Text('a')"],
        ]);
      },
      skip: 'Bug: the visitor does not recurse into named arguments, so '
          'nested lists are never found',
    );

    test(
      'only matches lists whose parent expression matches',
      () async {
        const source = '''
List<Widget> buildRows() {
  return [
    Column(children: [Text('a')]),
    Row(children: [Text('b')]),
  ];
}
''';

        final result = await const InsertIntoListInFunction(
          file: 'lib/rows.dart',
          function: 'buildRows',
          listVariableMatch: 'children',
          parentExpressionMatch: 'Row',
          insert: "Text('new'),",
        ).apply(source);

        expect(namedListsOf(result, 'children'), [
          ["Text('a')"],
          ["Text('new')", "Text('b')"],
        ]);
      },
      skip: 'Bug: the parent check walks up to the compilation unit, so any '
          'occurrence of parentExpressionMatch in the file matches',
    );

    test(
      'is idempotent',
      () async {
        final once = await intoProviders().apply(providerMainDart);

        expect(await intoProviders().apply(once), once);
      },
      skip: 'Bug: nothing checks whether the element is already in the list, '
          'so every run adds it again',
    );
  });
}
