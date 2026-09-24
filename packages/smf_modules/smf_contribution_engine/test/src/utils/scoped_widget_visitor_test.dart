import 'package:smf_contribution_engine/src/utils/scoped_widget_visitor.dart';
import 'package:test/test.dart';

import '../../ast_helpers.dart';

const _source = '''
class HomePage {
  Widget build() => const Text('home.build');

  Widget buildTitle() => const Text('home.buildTitle');
}

class SettingsPage {
  Widget build() => const Text('settings.build');
}
''';

/// The string arguments of the `Text` widgets that [ScopedWidgetVisitor]
/// reports, in visiting order.
List<String> textsIn({String? className, String? methodName}) {
  final matches = <String>[];
  parseValid(_source).visitChildren(
    ScopedWidgetVisitor(
      fromWidget: 'Text',
      className: className,
      methodName: methodName,
      onMatch: (node) => matches.add(
        node.argumentList.arguments.single.toSource().replaceAll("'", ''),
      ),
    ),
  );
  return matches;
}

void main() {
  group('ScopedWidgetVisitor', () {
    test('visits every class when no scope is given', () {
      expect(
        textsIn(),
        ['home.build', 'home.buildTitle', 'settings.build'],
      );
    });

    test('limits matches to the named class', () {
      expect(
        textsIn(className: 'HomePage'),
        ['home.build', 'home.buildTitle'],
      );
    });

    test('limits matches to the named method in every class', () {
      expect(textsIn(methodName: 'build'), ['home.build', 'settings.build']);
    });

    test('limits matches to the named method of the named class', () {
      expect(
        textsIn(className: 'SettingsPage', methodName: 'build'),
        ['settings.build'],
      );
    });

    test('reports nothing when the class does not exist', () {
      expect(textsIn(className: 'ProfilePage'), isEmpty);
    });
  });
}
