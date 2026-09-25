import 'package:smf_contracts/lego_core.dart';
import 'package:test/test.dart';

void main() {
  group('Fragment', () {
    test('holds code and imports', () {
      const fragment = Fragment(
        'await Firebase.initializeApp();',
        imports: [ImportRef('package:firebase_core/firebase_core.dart')],
      );

      expect(fragment.code, 'await Firebase.initializeApp();');
      expect(fragment.closing, isNull);
      expect(fragment.isWrapper, isFalse);
      expect(fragment.imports, hasLength(1));
    });

    test('wrap holds an opening and a closing part', () {
      const fragment = Fragment.wrap('ProviderScope(child: ', ')');

      expect(fragment.code, 'ProviderScope(child: ');
      expect(fragment.closing, ')');
      expect(fragment.isWrapper, isTrue);
      expect(fragment.imports, isEmpty);
    });

    test('has no problems when mason would render it unchanged', () {
      expect(const Fragment(r"final path = r'C:\temp';").problems(), isEmpty);
      expect(const Fragment('// Привіт').problems(), isEmpty);
    });

    test('reports a backslash that mason would strip', () {
      // mason drops a backslash before a line break or a non-ASCII
      // character anywhere in its output.
      for (final code in ['a \\\nb', 'a \\\r\nb', r"'\é'"]) {
        final problems = Fragment(code).problems();
        expect(problems, hasLength(1), reason: code);
        expect(problems.single, contains('backslash'));
      }
    });

    test('reports a backslash in the closing part of a wrapper', () {
      expect(const Fragment.wrap('Wrap(', '\\\n)').problems(), hasLength(1));
    });

    test('shortens the excerpt of long code', () {
      final code = '${'x' * 40}\\\ny';
      expect(
        Fragment(code).problems().single,
        contains('"${'x' * 20}\\\\n"'),
      );
    });

    test('reports the problems of its imports', () {
      const fragment =
          Fragment('x', imports: [ImportRef('dart:io', prefix: '1')]);
      expect(fragment.problems().single, contains('prefix "1"'));
    });
  });

  group('ImportRef', () {
    test('renders a directive with prefix and shown names', () {
      expect(
        const ImportRef('package:go_router/go_router.dart').toDirective('app'),
        "import 'package:go_router/go_router.dart';",
      );
      expect(
        const ImportRef('package:a/a.dart', prefix: 'a', show: ['A', 'B'])
            .toDirective('app'),
        "import 'package:a/a.dart' as a show A, B;",
      );
    });

    test('app imports use the package name of the app', () {
      const import = ImportRef.app('core/app/app.dart');

      expect(import.isAppFile, isTrue);
      expect(import.resolveUri('my_app'), 'package:my_app/core/app/app.dart');
      expect(
        import.toDirective('my_app'),
        "import 'package:my_app/core/app/app.dart';",
      );
    });

    test('accepts dart:, package: and app imports', () {
      expect(const ImportRef('dart:async').problems(), isEmpty);
      expect(const ImportRef('package:a/a.dart').problems(), isEmpty);
      expect(const ImportRef.app('core/app.dart').problems(), isEmpty);
    });

    test('rejects relative and malformed URIs', () {
      expect(const ImportRef('src/a.dart').problems().single, contains('URI'));
      for (final path in [
        '',
        '/core/a.dart',
        'lib/core/a.dart',
        '../a.dart',
        'core/../../a.dart',
        'core/a.txt',
      ]) {
        expect(
          ImportRef.app(path).problems().single,
          contains('below lib/'),
          reason: path,
        );
      }
    });

    test('rejects prefixes and shown names that are not identifiers', () {
      final problems = const ImportRef(
        'package:a/a.dart',
        prefix: 'my-prefix',
        show: ['Good', 'bad name'],
      ).problems();

      expect(problems, hasLength(2));
      expect(problems.first, contains('prefix "my-prefix"'));
      expect(problems.last, contains('"bad name"'));
    });

    test('compares by uri, kind, prefix and shown names', () {
      expect(
        const ImportRef('package:a/a.dart', show: ['A']),
        const ImportRef('package:a/a.dart', show: ['A']),
      );
      expect(
        const ImportRef('package:a/a.dart', show: ['A']).hashCode,
        const ImportRef('package:a/a.dart', show: ['A']).hashCode,
      );
      expect(
        const ImportRef('package:a/a.dart'),
        isNot(const ImportRef('package:a/a.dart', prefix: 'a')),
      );
      expect(
        const ImportRef('package:a/a.dart', show: ['A']),
        isNot(const ImportRef('package:a/a.dart', show: ['B'])),
      );
      expect(
        const ImportRef('package:a/a.dart', show: ['A']),
        isNot(const ImportRef('package:a/a.dart', show: ['A', 'B'])),
      );
      expect(
        const ImportRef('a.dart'),
        isNot(const ImportRef.app('a.dart')),
      );
    });

    test('describes itself', () {
      expect('${const ImportRef('dart:io')}', 'ImportRef(dart:io)');
      expect('${const ImportRef.app('a.dart')}', 'ImportRef.app(a.dart)');
    });
  });

  group('ImportRef.merge', () {
    test('merges imports with the same URI and prefix', () {
      final merged = ImportRef.merge(
        const [
          ImportRef('package:a/a.dart', show: ['B']),
          ImportRef('package:a/a.dart', show: ['A', 'B']),
        ],
        appName: 'app',
      );

      expect(merged, [
        const ImportRef('package:a/a.dart', show: ['A', 'B']),
      ]);
    });

    test('an import of all names wins over shown names', () {
      for (final imports in [
        const [
          ImportRef('package:a/a.dart', show: ['A']),
          ImportRef('package:a/a.dart'),
        ],
        const [
          ImportRef('package:a/a.dart'),
          ImportRef('package:a/a.dart', show: ['A']),
        ],
      ]) {
        expect(ImportRef.merge(imports, appName: 'app'), [
          const ImportRef('package:a/a.dart'),
        ]);
      }
    });

    test('keeps different prefixes of one URI apart', () {
      final merged = ImportRef.merge(
        const [
          ImportRef('package:a/a.dart', prefix: 'b'),
          ImportRef('package:a/a.dart'),
          ImportRef('package:a/a.dart', prefix: 'a'),
        ],
        appName: 'app',
      );

      expect(merged.map((import) => import.prefix), [null, 'a', 'b']);
    });

    test('resolves app imports and merges them with package imports', () {
      final merged = ImportRef.merge(
        const [
          ImportRef.app('core/a.dart'),
          ImportRef('package:my_app/core/a.dart'),
        ],
        appName: 'my_app',
      );

      expect(merged, [const ImportRef('package:my_app/core/a.dart')]);
    });

    test('sorts dart: imports first, then package: imports by URI', () {
      final merged = ImportRef.merge(
        const [
          ImportRef('package:b/b.dart'),
          ImportRef('dart:io'),
          ImportRef('package:a/a.dart'),
          ImportRef('dart:async'),
        ],
        appName: 'app',
      );

      expect(merged.map((import) => import.uri), [
        'dart:async',
        'dart:io',
        'package:a/a.dart',
        'package:b/b.dart',
      ]);
    });
  });
}
