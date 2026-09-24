import 'package:smf_contribution_engine/smf_contribution_engine.dart';
import 'package:test/test.dart';

import '../../ast_helpers.dart';
import '../../fixtures.dart';

const _nestedPaddings = '''
class HomePage {
  Widget build() {
    return const Padding(
      padding: EdgeInsets.all(8),
      child: const Padding(padding: EdgeInsets.all(4), child: Text('x')),
    );
  }
}
''';

void main() {
  group('ModifyWidgetArguments', () {
    // What ReplaceWidget leaves behind for SmfGoRouterModule.
    final routerMainDart = monolithMainDart.replaceFirst(
      'return const MaterialApp(',
      'return const MaterialApp.router(',
    );

    // How SmfGoRouterModule wires the router in. `const MaterialApp.router()`
    // parses as the type `router` with the import prefix `MaterialApp`, hence
    // the widget name.
    const useRouterConfig = ModifyWidgetArguments(
      file: 'lib/main.dart',
      widgetName: 'router',
      removeArgs: ['home'],
      addArgs: {'routerConfig': 'router'},
    );

    ModifyWidgetArguments modifyText({
      List<String> removeArgs = const [],
      Map<String, String> addArgs = const {},
    }) =>
        ModifyWidgetArguments(
          file: 'lib/home_page.dart',
          widgetName: 'Text',
          removeArgs: removeArgs,
          addArgs: addArgs,
        );

    String classWithBuild(String returned) => '''
class HomePage {
  Widget build() {
    return $returned;
  }
}
''';

    test('replaces home with routerConfig on MaterialApp.router', () async {
      final result = await useRouterConfig.apply(routerMainDart);

      // Dropping const is required here: `router` is not a constant.
      expect(methodStatements(result, 'MainApp', 'build'), [
        'return MaterialApp.router(routerConfig: router);',
      ]);
      expect(
        functionStatements(result, 'main'),
        functionStatements(monolithMainDart, 'main'),
      );
    });

    test('keeps positional and other named arguments, then appends new ones',
        () async {
      final source = classWithBuild(
        "const Text('Hi', maxLines: 1, overflow: TextOverflow.ellipsis)",
      );

      final result = await modifyText(
        removeArgs: ['maxLines'],
        addArgs: {
          'style': 'const TextStyle(fontSize: 12)',
          'softWrap': 'false',
        },
      ).apply(source);

      const expected = "return Text('Hi', overflow: TextOverflow.ellipsis, "
          'style: const TextStyle(fontSize: 12), softWrap: false);';
      expect(methodStatements(result, 'HomePage', 'build'), [expected]);
    });

    test('modifies every matching widget in the file', () async {
      const source = '''
final title = const Text('title');

class HomePage {
  Widget build() {
    return const Text('body');
  }
}
''';

      final result = await modifyText(addArgs: {'maxLines': '1'}).apply(source);

      expect(result, contains("Text('title', maxLines: 1)"));
      expect(result, contains("Text('body', maxLines: 1)"));
    });

    test('leaves the file untouched when the widget is not found', () async {
      expect(await useRouterConfig.apply(monolithMainDart), monolithMainDart);
    });

    test('is idempotent', () async {
      final once = await useRouterConfig.apply(routerMainDart);

      expect(await useRouterConfig.apply(once), once);
    });

    test(
      'overrides an argument that is already there instead of repeating it',
      () async {
        final source = classWithBuild("const Text('Hi', maxLines: 1)");

        final result =
            await modifyText(addArgs: {'maxLines': '2'}).apply(source);

        expect(
          methodStatements(result, 'HomePage', 'build').single,
          allOf(contains('maxLines: 2'), isNot(contains('maxLines: 1'))),
        );
      },
    );

    test(
      'preserves comments inside the argument list',
      () async {
        final source = classWithBuild('''
const Text(
      'Hi',
      // Titles must fit on one line.
      maxLines: 1,
    )''');

        final result =
            await modifyText(addArgs: {'softWrap': 'false'}).apply(source);

        expect(result, contains('// Titles must fit on one line.'));
      },
    );

    test(
      'modifies nested widgets of the same type',
      () async {
        final result = await const ModifyWidgetArguments(
          file: 'lib/home_page.dart',
          widgetName: 'Padding',
          addArgs: {'key': 'key'},
        ).apply(_nestedPaddings);

        expect(
          'key: key'.allMatches(parseValid(result).toSource()),
          hasLength(2),
        );
      },
    );

    test('removes the last argument together with the comma before it',
        () async {
      final source = classWithBuild("const Text('Hi', maxLines: 1)");

      final result = await modifyText(removeArgs: ['maxLines']).apply(source);

      expect(result, contains("return Text('Hi');"));
    });

    test('keeps a trailing comma after the appended arguments', () async {
      final source = classWithBuild('''
const Text(
      'Hi',
      maxLines: 1,
    )''');

      final result =
          await modifyText(addArgs: {'softWrap': 'false'}).apply(source);

      expect(result, contains('      softWrap: false,\n    );'));
    });

    test('drops the edits inside a nested widget that the outer one removes',
        () async {
      final result = await const ModifyWidgetArguments(
        file: 'lib/home_page.dart',
        widgetName: 'Padding',
        removeArgs: ['child'],
      ).apply(_nestedPaddings);

      expect(methodStatements(result, 'HomePage', 'build'), [
        'return Padding(padding: EdgeInsets.all(8));',
      ]);
    });

    test('drops the edits inside a nested widget that the outer one replaces',
        () async {
      final result = await const ModifyWidgetArguments(
        file: 'lib/home_page.dart',
        widgetName: 'Padding',
        addArgs: {'child': 'const SizedBox()'},
      ).apply(_nestedPaddings);

      expect(methodStatements(result, 'HomePage', 'build'), [
        'return Padding(padding: EdgeInsets.all(8), child: const SizedBox());',
      ]);
    });
  });
}
