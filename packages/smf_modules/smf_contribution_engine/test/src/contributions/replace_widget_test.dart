import 'package:smf_contribution_engine/smf_contribution_engine.dart';
import 'package:test/test.dart';

import '../../ast_helpers.dart';
import '../../fixtures.dart';

const _twoPages = '''
class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Text('home');
  }

  Widget buildTitle() {
    return const Text('title');
  }
}

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Text('settings');
  }
}
''';

void main() {
  group('ReplaceWidget', () {
    // How SmfGoRouterModule switches the generated app to go_router.
    const toRouter = ReplaceWidget(
      file: 'lib/main.dart',
      fromWidget: 'MaterialApp',
      toWidget: 'MaterialApp.router',
      className: 'MainApp',
      methodName: 'build',
    );

    ReplaceWidget textToSelectable({String? className, String? methodName}) =>
        ReplaceWidget(
          file: 'lib/pages.dart',
          fromWidget: 'Text',
          toWidget: 'SelectableText',
          className: className,
          methodName: methodName,
        );

    List<String> texts(String source) => [
          ...methodStatements(source, 'HomePage', 'build'),
          ...methodStatements(source, 'HomePage', 'buildTitle'),
          ...methodStatements(source, 'SettingsPage', 'build'),
        ];

    test('turns MaterialApp into MaterialApp.router in MainApp.build',
        () async {
      final result = await toRouter.apply(monolithMainDart);

      expect(methodStatements(result, 'MainApp', 'build'), [
        'return const MaterialApp.router('
            "home: Scaffold(body: Center(child: Text('Hello World!'))));",
      ]);
      expect(
        functionStatements(result, 'main'),
        functionStatements(monolithMainDart, 'main'),
      );
    });

    test('replaces the widget in every class when no scope is given', () async {
      final result = await textToSelectable().apply(_twoPages);

      expect(texts(result), [
        "return const SelectableText('home');",
        "return const SelectableText('title');",
        "return const SelectableText('settings');",
      ]);
    });

    test('only replaces inside the named class', () async {
      final result =
          await textToSelectable(className: 'SettingsPage').apply(_twoPages);

      expect(texts(result), [
        "return const Text('home');",
        "return const Text('title');",
        "return const SelectableText('settings');",
      ]);
    });

    test('only replaces inside the named method', () async {
      final result =
          await textToSelectable(methodName: 'buildTitle').apply(_twoPages);

      expect(texts(result), [
        "return const Text('home');",
        "return const SelectableText('title');",
        "return const Text('settings');",
      ]);
    });

    test('only replaces inside the named method of the named class', () async {
      final result = await textToSelectable(
        className: 'HomePage',
        methodName: 'build',
      ).apply(_twoPages);

      expect(texts(result), [
        "return const SelectableText('home');",
        "return const Text('title');",
        "return const Text('settings');",
      ]);
    });

    test('keeps new, the import prefix and arguments naming the widget',
        () async {
      const source = '''
class HomePage {
  Widget build() {
    return new m.Text('Text');
  }
}
''';

      final result = await textToSelectable().apply(source);

      expect(methodStatements(result, 'HomePage', 'build'), [
        "return new m.SelectableText('Text');",
      ]);
    });

    test('leaves the file untouched when the widget is not found', () async {
      final result = await const ReplaceWidget(
        file: 'lib/main.dart',
        fromWidget: 'CupertinoApp',
        toWidget: 'CupertinoApp.router',
      ).apply(monolithMainDart);

      expect(result, monolithMainDart);
    });

    test('is idempotent', () async {
      final once = await toRouter.apply(monolithMainDart);

      expect(await toRouter.apply(once), once);
    });

    test(
      'replaces widgets created without const or new',
      () async {
        final source = monolithMainDart.replaceFirst(
          'return const MaterialApp(',
          'return MaterialApp(',
        );

        final result = await toRouter.apply(source);

        expect(
          methodStatements(result, 'MainApp', 'build').single,
          startsWith('return MaterialApp.router('),
        );
      },
      skip: 'Bug: without resolution `MaterialApp(...)` parses as a '
          'MethodInvocation, which MatchWidgetVisitor never visits',
    );

    test(
      'replaces widgets outside classes when no class is given',
      () async {
        final result = await const ReplaceWidget(
          file: 'lib/main.dart',
          fromWidget: 'MainApp',
          toWidget: 'App',
        ).apply(monolithMainDart);

        expect(functionStatements(result, 'main'),
            contains('runApp(const App());'));
      },
      skip: 'Bug: ScopedWidgetVisitor only visits class declarations, so '
          'top-level functions such as main() are skipped',
    );

    test(
      'replaces nested widgets of the same type',
      () async {
        const source = '''
class HomePage {
  Widget build() {
    return const Padding(
      padding: EdgeInsets.all(8),
      child: const Padding(padding: EdgeInsets.all(4), child: Text('x')),
    );
  }
}
''';

        final result = await const ReplaceWidget(
          file: 'lib/home_page.dart',
          fromWidget: 'Padding',
          toWidget: 'SliverPadding',
        ).apply(source);

        expect(methodStatements(result, 'HomePage', 'build'), [
          'return const SliverPadding(padding: EdgeInsets.all(8), '
              'child: const SliverPadding(padding: EdgeInsets.all(4), '
              "child: Text('x')));",
        ]);
      },
      skip: 'Bug: the outer widget is rewritten from its original source '
          'using offsets that the inner replacement already shifted',
    );

    test(
      'preserves comments inside the replaced widget',
      () async {
        final source = monolithMainDart.replaceFirst(
          '      home: Scaffold(',
          '      // The first screen.\n      home: Scaffold(',
        );

        final result = await toRouter.apply(source);

        expect(result, contains('// The first screen.'));
      },
      skip: 'Bug: the widget is regenerated with toSource(), which drops '
          'comments',
    );
  });
}
