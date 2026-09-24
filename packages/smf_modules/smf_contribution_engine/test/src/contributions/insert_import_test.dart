import 'package:smf_contribution_engine/smf_contribution_engine.dart';
import 'package:test/test.dart';

import '../../ast_helpers.dart';
import '../../fixtures.dart';

void main() {
  group('InsertImport', () {
    const firebaseImport = "import 'package:firebase_core/firebase_core.dart';";

    Future<String> insert(String source, {String import = firebaseImport}) =>
        InsertImport(file: 'lib/main.dart', import: import).apply(source);

    test('adds the import on its own line after the existing import', () async {
      final result = await insert(monolithMainDart);

      expect(
        result,
        monolithMainDart.replaceFirst(
          "import 'package:flutter/material.dart';\n",
          "import 'package:flutter/material.dart';\n$firebaseImport\n",
        ),
      );
    });

    test('adds the import after the last of several imports', () async {
      final result = await insert(riverpodMainDart);

      expect(directivesOf(result), [
        "import 'package:flutter/material.dart';",
        "import 'package:flutter_riverpod/flutter_riverpod.dart';",
        firebaseImport,
      ]);
    });

    test('leaves the file untouched when the import is already there',
        () async {
      final source = monolithMainDart.replaceFirst(
        "import 'package:flutter/material.dart';\n",
        "import 'package:flutter/material.dart';\n$firebaseImport\n",
      );

      expect(await insert(source), source);
    });

    test('is idempotent', () async {
      final once = await insert(monolithMainDart);

      expect(await insert(once), once);
    });

    test('adds the import when the same URI is only imported with a prefix',
        () async {
      const source =
          "import 'package:firebase_core/firebase_core.dart' as fb;\n";

      expect(directivesOf(await insert(source)), [
        "import 'package:firebase_core/firebase_core.dart' as fb;",
        firebaseImport,
      ]);
    });

    test('ignores commented-out imports', () async {
      const source = '// $firebaseImport\n$monolithMainDart';

      expect(directivesOf(await insert(source)), [
        "import 'package:flutter/material.dart';",
        firebaseImport,
      ]);
    });

    test('passes mustache placeholders through untouched', () async {
      const templated =
          "import 'package:{{app_name_sc}}/core/di/core_di.dart';";

      final result = await insert(monolithMainDart, import: templated);

      expect(result, contains('\n$templated\n'));
    });

    test(
      'keeps a trailing comment on the import it belongs to',
      () async {
        const source = "import 'package:flutter/material.dart'; "
            '// ignore: unused_import\n'
            '\n'
            'void main() {}\n';

        expect(
          await insert(source),
          "import 'package:flutter/material.dart'; // ignore: unused_import\n"
          '$firebaseImport\n'
          '\n'
          'void main() {}\n',
        );
      },
    );

    test(
      'does not duplicate an import that the formatter wrapped over two lines',
      () async {
        const singleLine = "import 'package:flutter/foundation.dart' "
            'show PlatformDispatcher, kDebugMode, kReleaseMode;';
        // How dart format lays out [singleLine], which exceeds 80 columns.
        const source = "import 'package:flutter/foundation.dart'\n"
            '    show PlatformDispatcher, kDebugMode, kReleaseMode;\n'
            "import 'package:flutter/material.dart';\n"
            '\n'
            'void main() {}\n';

        expect(await insert(source, import: singleLine), source);
      },
    );

    test('does not duplicate an import written with double quotes', () async {
      const source = 'import "package:firebase_core/firebase_core.dart";\n';

      expect(await insert(source), source);
    });

    test('adds the import when the same URI is only imported with show',
        () async {
      const source =
          "import 'package:firebase_core/firebase_core.dart' show Firebase;\n";

      expect(directivesOf(await insert(source)), [
        "import 'package:firebase_core/firebase_core.dart' show Firebase;",
        firebaseImport,
      ]);
    });

    test('keeps code that follows the last import on its line valid', () async {
      const source = "import 'package:flutter/material.dart'; void main() {}\n";

      final result = await insert(source);

      expect(directivesOf(result), [
        "import 'package:flutter/material.dart';",
        firebaseImport,
      ]);
      expect(functionStatements(result, 'main'), isEmpty);
    });

    test('rejects text that is not a single import directive', () {
      expect(
        insert(monolithMainDart, import: "export 'a.dart';"),
        throwsArgumentError,
      );
    });

    group('when the file has no imports', () {
      test(
        'puts the import at the top, on its own line',
        () async {
          final result = await insert('void main() {}\n');

          expect(result, startsWith('$firebaseImport\n'));
          expect(result, contains('\nvoid main() {}\n'));
        },
      );

      test(
        'keeps the library directive first',
        () async {
          final result = await insert('library;\n\nvoid main() {}\n');

          // Not checked with directivesOf(): toSource() prints `library ;`.
          expect(result, 'library;\n$firebaseImport\n\nvoid main() {}\n');
        },
      );

      test('puts the import below a leading license comment', () async {
        final result = await insert('// Copyright 2025 SayMyFrame.\n\n'
            'void main() {}\n');

        expect(
          result,
          '// Copyright 2025 SayMyFrame.\n\n'
          '$firebaseImport\n\n'
          'void main() {}\n',
        );
      });

      test('adds the import after a file that holds only a comment', () async {
        expect(
          await insert('// Nothing here yet.'),
          '// Nothing here yet.\n$firebaseImport\n',
        );
      });

      test('keeps a doc comment on the declaration it documents', () async {
        final result = await insert('/// Starts the app.\nvoid main() {}\n');

        expect(
          result,
          '$firebaseImport\n\n/// Starts the app.\nvoid main() {}\n',
        );
      });
    });
  });
}
