import 'package:smf_contracts/lego_core.dart';
import 'package:smf_pipeline/src/imports.dart';
import 'package:test/test.dart';

/// [text], the file at [path], with [imports] added.
String _add(
  String text,
  List<ImportRef> imports, {
  String path = 'lib/a/b.dart',
}) =>
    addImports(text, path: path, imports: imports, appName: 'app').text;

const _async = ImportRef('dart:async');
const _io = ImportRef('dart:io');
const _flutter = ImportRef('package:flutter/widgets.dart');
const _zeta = ImportRef('package:zeta/zeta.dart');

void main() {
  test('puts each import into its group, sorted', () {
    expect(
      _add(
        "import 'dart:convert';\n"
        '\n'
        "import 'package:flutter/material.dart';\n"
        "import 'package:yaml/yaml.dart';\n"
        '\n'
        "import 'c.dart';\n"
        '\n'
        'void f() {}\n',
        [_zeta, _async, _io, _flutter],
      ),
      "import 'dart:async';\n"
      "import 'dart:convert';\n"
      "import 'dart:io';\n"
      '\n'
      "import 'package:flutter/material.dart';\n"
      "import 'package:flutter/widgets.dart';\n"
      "import 'package:yaml/yaml.dart';\n"
      "import 'package:zeta/zeta.dart';\n"
      '\n'
      "import 'c.dart';\n"
      '\n'
      'void f() {}\n',
    );
  });

  test('starts a group before a later one, or after an earlier one', () {
    expect(
      _add("import 'c.dart';\n\nvoid f() {}\n", [_async, _zeta]),
      "import 'dart:async';\n"
      '\n'
      "import 'package:zeta/zeta.dart';\n"
      '\n'
      "import 'c.dart';\n"
      '\n'
      'void f() {}\n',
    );
    expect(
      _add("import 'dart:io';\n\nvoid f() {}\n", [_zeta]),
      "import 'dart:io';\n"
      '\n'
      "import 'package:zeta/zeta.dart';\n"
      '\n'
      'void f() {}\n',
    );
  });

  test('without imports, goes before the first directive or declaration', () {
    expect(
      _add('\n\n/// Docs.\n@immutable\nclass A {}\n', [_async, _zeta]),
      "import 'dart:async';\n"
      '\n'
      "import 'package:zeta/zeta.dart';\n"
      '\n'
      '\n'
      '\n'
      '/// Docs.\n'
      '@immutable\n'
      'class A {}\n',
    );
    expect(
      _add("// Header.\n\npart 'b.g.dart';\n", [_async]),
      "// Header.\n\nimport 'dart:async';\n\npart 'b.g.dart';\n",
    );
    expect(
      _add('/// The library.\nlibrary;\n\nvoid f() {}\n', [_async]),
      "/// The library.\nlibrary;\n\nimport 'dart:async';\n\nvoid f() {}\n",
    );
    expect(
      _add('library;\n', [_async]),
      "library;\n\nimport 'dart:async';\n",
    );
    expect(_add('', [_async]), "import 'dart:async';\n");
  });

  test('leaves out what the file imports already', () {
    const text = "import 'package:zeta/zeta.dart' show Z;\n"
        "import '../c.dart';\n"
        "import 'd.dart' as d;\n"
        "import 'package:flutter/widgets.dart';\n";

    final result = addImports(
      text,
      path: 'lib/a/b.dart',
      imports: const [
        ImportRef('package:zeta/zeta.dart', show: ['Z']),
        ImportRef.app('c.dart'),
        ImportRef.app('a/d.dart', prefix: 'd'),
        ImportRef('package:flutter/widgets.dart', show: ['Text']),
      ],
      appName: 'app',
    );
    expect(result.text, text);
    expect(result.added, isEmpty);

    // Other names, another prefix, or a file outside lib/ need their own.
    final more = addImports(
      text,
      path: 'test/b_test.dart',
      imports: const [
        ImportRef('package:zeta/zeta.dart', show: ['Y']),
        ImportRef.app('a/d.dart'),
        ImportRef('package:zeta/zeta.dart', prefix: 'z'),
      ],
      appName: 'app',
    );
    expect(
      [for (final import in more.added) import.toDirective('app')],
      [
        "import 'package:app/a/d.dart';",
        "import 'package:zeta/zeta.dart' show Y;",
        "import 'package:zeta/zeta.dart' as z;",
      ],
    );
  });

  test('several show combinators import the names they all show', () {
    const text = "import 'package:zeta/zeta.dart' show A, B show B, C;\n";

    expect(
      addImports(
        text,
        path: 'lib/b.dart',
        imports: const [
          ImportRef('package:zeta/zeta.dart', show: ['B']),
          ImportRef('package:zeta/zeta.dart', show: ['A']),
        ],
        appName: 'app',
      ).added.single.show,
      ['A', 'B'],
    );
  });

  test('a conditional import or one that hides names covers nothing', () {
    const text = "import 'package:zeta/zeta.dart' hide Z;\n"
        "import 'dart:io' if (dart.library.js_interop) 'web.dart';\n";

    expect(
      addImports(
        text,
        path: 'lib/b.dart',
        imports: const [_zeta, _io],
        appName: 'app',
      ).added,
      hasLength(2),
    );
  });

  test('merges the imports it adds', () {
    final result = addImports(
      'void f() {}\n',
      path: 'lib/b.dart',
      imports: const [
        ImportRef('package:zeta/zeta.dart', show: ['A']),
        ImportRef('package:zeta/zeta.dart', show: ['B']),
        ImportRef.app('x.dart'),
      ],
      appName: 'app',
    );

    expect(
      result.text,
      "import 'package:app/x.dart';\n"
      "import 'package:zeta/zeta.dart' show A, B;\n"
      '\n'
      'void f() {}\n',
    );
    expect(result.added, hasLength(2));
  });

  test('nothing to add leaves the text as it is', () {
    expect(_add('void f() {}\n', const []), 'void f() {}\n');
  });

  test('a part file cannot get imports', () {
    expect(
      () => _add("part of 'a.dart';\n", [_async]),
      throwsA(
        isA<ImportTargetException>().having(
          (e) => '$e',
          'message',
          'ImportTargetException: it is a part of another library',
        ),
      ),
    );
  });
}
