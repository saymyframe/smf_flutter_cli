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
      onMatch: (creation) => matches.add(creation.expression.toSource()),
    ),
  );
  return matches;
}

void main() {
  group('MatchWidgetVisitor', () {
    test('reports instances of the widget with or without const or new', () {
      const source = '''
final a = const Center(child: Text('a'));
final b = const Text('b');
final c = new Text('c');
''';

      expect(
        matchesOf(source, 'Text'),
        ["Text('a')", "const Text('b')", "new Text('c')"],
      );
    });

    test('reports outer widgets before the ones nested in them', () {
      const source = '''
final w = const Padding(
  padding: EdgeInsets.zero,
  child: const Padding(padding: EdgeInsets.zero),
);
''';

      const outer = 'const Padding(padding: EdgeInsets.zero, '
          'child: const Padding(padding: EdgeInsets.zero))';
      expect(matchesOf(source, 'Padding'), [
        outer,
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

    test('matches widgets created without const or new', () {
      expect(matchesOf("final w = Text('a');", 'Text'), ["Text('a')"]);
    });

    test('matches import-prefixed widgets created without const or new', () {
      expect(matchesOf("final w = m.Text('a');", 'Text'), ["m.Text('a')"]);
    });

    test('matches a named constructor called without const or new', () {
      const source = '''
final a = MaterialApp.router();
final b = m.MaterialApp.router();
''';

      expect(
        matchesOf(source, 'router'),
        ['MaterialApp.router()', 'm.MaterialApp.router()'],
      );
    });

    test('matches private widgets created without const or new', () {
      expect(matchesOf("final w = _Title('a');", '_Title'), ["_Title('a')"]);
    });

    test('ignores calls that create no widget', () {
      const source = '''
final a = text?.Text('a');
final b = text..Text('b');
final c = buildText().Text('c');
''';

      expect(matchesOf(source, 'Text'), isEmpty);
    });

    test('ignores functions and methods named like the widget', () {
      const source = '''
final a = builder();
final b = delegate.builder();
final c = m.delegate.builder();
''';

      expect(matchesOf(source, 'builder'), isEmpty);
    });

    test('reports what the replacements and argument edits need', () {
      final creations = <WidgetCreation>[];
      parseValid("final w = const Center(child: m.Text('a', maxLines: 1));")
          .visitChildren(
        MatchWidgetVisitor(targetWidget: 'Text', onMatch: creations.add),
      );

      final creation = creations.single;
      expect(creation.name.lexeme, 'Text');
      expect(creation.keyword, isNull);
      expect(creation.argumentList.toSource(), "('a', maxLines: 1)");
    });
  });
}
