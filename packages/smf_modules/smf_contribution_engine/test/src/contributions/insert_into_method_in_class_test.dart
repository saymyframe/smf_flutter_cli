import 'package:smf_contribution_engine/smf_contribution_engine.dart';
import 'package:test/test.dart';

import '../../ast_helpers.dart';
import '../../fixtures.dart';

void main() {
  group('InsertIntoMethodInClass', () {
    const state = '_HomePageState';
    const createController = '_controller = AnimationController(vsync: this);';

    InsertIntoMethodInClass intoInitState({
      String className = state,
      String method = 'initState',
      String afterStatement = 'super.initState()',
    }) =>
        InsertIntoMethodInClass(
          file: 'lib/home_page.dart',
          className: className,
          method: method,
          afterStatement: afterStatement,
          insert: createController,
        );

    test('inserts after the statement that contains afterStatement', () async {
      final result = await intoInitState().apply(homePageStateDart);

      expect(
        methodStatements(result, state, 'initState'),
        ['super.initState();', createController],
      );
    });

    test('leaves the other methods untouched', () async {
      final result = await intoInitState().apply(homePageStateDart);

      expect(
        result,
        homePageStateDart.replaceFirst(
          '    super.initState();\n',
          '    super.initState();\n    $createController\n',
        ),
      );
    });

    test('only patches the method of the named class', () async {
      const source = '''
class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
  }
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
  }
}
''';

      final result =
          await intoInitState(className: '_SettingsPageState').apply(source);

      expect(methodStatements(result, state, 'initState'), [
        'super.initState();',
      ]);
      expect(methodStatements(result, '_SettingsPageState', 'initState'), [
        'super.initState();',
        createController,
      ]);
    });

    test('does not insert anything when no statement matches the anchor',
        () async {
      final result = await intoInitState(afterStatement: 'super.dispose()')
          .apply(homePageStateDart);

      expect(
        methodStatements(result, state, 'initState'),
        ['super.initState();'],
      );
    });

    test('throws when the class does not exist', () {
      expect(
        intoInitState(className: '_MissingState').apply(homePageStateDart),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Class _MissingState not found'),
          ),
        ),
      );
    });

    test('throws when the method does not exist in the class', () {
      expect(
        intoInitState(method: 'didChangeDependencies').apply(homePageStateDart),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains(
              'Method didChangeDependencies not found in class $state',
            ),
          ),
        ),
      );
    });

    test('throws when the method has an expression body', () {
      expect(
        intoInitState(method: 'build').apply(homePageStateDart),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Method body is not a block'),
          ),
        ),
      );
    });

    test(
      'is idempotent',
      () async {
        final once = await intoInitState().apply(homePageStateDart);

        expect(await intoInitState().apply(once), once);
      },
      skip: 'Bug: nothing checks whether the insert is already there, so every '
          'run adds it again',
    );

    test(
      'preserves comments in the method body',
      () async {
        final source = homePageStateDart.replaceFirst(
          '    super.initState();\n',
          '    super.initState();\n    // Controllers are created below.\n',
        );

        final result = await intoInitState().apply(source);

        expect(result, contains('    // Controllers are created below.\n'));
      },
      skip: 'Bug: the body is rebuilt from Statement.toSource(), which drops '
          'comments and blank lines',
    );
  });
}
