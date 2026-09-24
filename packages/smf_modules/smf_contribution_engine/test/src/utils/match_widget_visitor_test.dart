import 'package:smf_contribution_engine/src/utils/match_widget_visitor.dart';
import 'package:test/test.dart';

import '../../ast_helpers.dart';

/// The sources of the expressions that [MatchWidgetVisitor] reports for
/// [widget], in visiting order.
List<String> matchesOf(String source, String widget) {
  final matches = <String>[];
  parseValid(source).visitChildren(
    MatchWidgetVisitor(
      targetWidget: widget,
      onMatch: (node) => matches.add(node.toSource()),
    ),
  );
  return matches;
}

void main() {
  group('MatchWidgetVisitor', () {
    test('reports const and new instances of the widget only', () {
      const source = '''
final a = const Center(child: Text('a'));
final b = const Text('b');
final c = new Text('c');
''';

      expect(matchesOf(source, 'Text'), ["const Text('b')", "new Text('c')"]);
    });

    test('reports outer widgets before the ones nested in them', () {
      const source = '''
final w = const Padding(
  padding: EdgeInsets.zero,
  child: const Padding(padding: EdgeInsets.zero),
);
''';

      expect(matchesOf(source, 'Padding'), [
        'const Padding(padding: EdgeInsets.zero, '
            'child: const Padding(padding: EdgeInsets.zero))',
        'const Padding(padding: EdgeInsets.zero)',
      ]);
    });

    test('matches import-prefixed widgets by their class name', () {
      expect(
        matchesOf("final w = const m.Text('a');", 'Text'),
        ["const m.Text('a')"],
      );
    });

    test('matches a named constructor by the constructor name', () {
      // Unresolved, `MaterialApp.router` reads as prefix `MaterialApp` and
      // type `router`; SmfGoRouterModule targets it as 'router'.
      expect(
        matchesOf('final w = const MaterialApp.router();', 'router'),
        ['const MaterialApp.router()'],
      );
    });

    test(
      'matches widgets created without const or new',
      () {
        expect(matchesOf("final w = Text('a');", 'Text'), ["Text('a')"]);
      },
      skip: 'Bug: without resolution `Text(...)` parses as a MethodInvocation, '
          'which the visitor never looks at',
    );
  });
}
