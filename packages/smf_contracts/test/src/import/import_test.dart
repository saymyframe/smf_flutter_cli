import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

const _package = 'package:{{app_name_sc}}';

void main() {
  group('ImportAnchor', () {
    test('every anchor is a lib/ directory ending with a slash', () {
      // Import.resolve concatenates the anchor and the relative path directly.
      for (final anchor in ImportAnchor.values) {
        expect(anchor.path, startsWith('lib/'), reason: anchor.name);
        expect(anchor.path, endsWith('/'), reason: anchor.name);
      }
    });

    test('anchors point to distinct directories', () {
      final paths = ImportAnchor.values.map((a) => a.path).toList();
      expect(paths.toSet(), hasLength(paths.length));
    });
  });

  group('Import.core', () {
    test('resolves a path relative to its anchor inside the app package', () {
      const import = Import.core(
        ImportAnchor.coreService,
        'analytics/i_analytics_service.dart',
      );

      expect(
        import.resolve(),
        "import '$_package/core/services/analytics/i_analytics_service.dart';",
      );
    });

    test('drops the lib/ segment of every anchor', () {
      const expected = {
        ImportAnchor.coreService: 'core/services/',
        ImportAnchor.coreModel: 'core/models/',
        ImportAnchor.coreUtil: 'core/utils/',
        ImportAnchor.coreRepo: 'core/repositories/',
        ImportAnchor.coreWidgets: 'core/widgets/',
        ImportAnchor.features: 'features/',
      };
      expect(expected.keys, unorderedEquals(ImportAnchor.values));

      for (final entry in expected.entries) {
        expect(
          Import.core(entry.key, 'file.dart').resolve(),
          "import '$_package/${entry.value}file.dart';",
          reason: entry.key.name,
        );
      }
    });

    test('strips a leading lib/ from the relative path', () {
      expect(
        const Import.core(ImportAnchor.coreWidgets, 'lib/shell.dart').resolve(),
        "import '$_package/core/widgets/shell.dart';",
      );
    });

    test(
      'keeps lib/ segments that are part of a directory name',
      () {
        expect(
          const Import.core(ImportAnchor.coreUtil, 'zlib/codec.dart').resolve(),
          "import '$_package/core/utils/zlib/codec.dart';",
        );
      },
      skip: 'Bug: Import.resolve removes the first "lib/" anywhere in the '
          'path (zlib/codec.dart becomes zcodec.dart), not only a leading one',
    );

    test('requires an anchor', () {
      ImportAnchor? noAnchor;
      expect(
        () => Import.core(noAnchor, 'file.dart'),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('Import.features', () {
    test('is anchored at lib/features/', () {
      const import = Import.features('home/home_screen.dart');

      expect(import.anchor, ImportAnchor.features);
      expect(
        import.resolve(),
        "import '$_package/features/home/home_screen.dart';",
      );
    });
  });

  group('Import.direct', () {
    test('has no anchor', () {
      expect(const Import.direct("import 'dart:io';").anchor, isNull);
    });

    test('keeps a complete statement as is', () {
      const statement = "import 'package:event_bus/event_bus.dart';";

      expect(const Import.direct(statement).resolve(), statement);
    });

    test('adds a missing semicolon', () {
      expect(
        const Import.direct("import 'package:event_bus/event_bus.dart'")
            .resolve(),
        "import 'package:event_bus/event_bus.dart';",
      );
    });

    test('trims surrounding whitespace before checking the semicolon', () {
      expect(
        const Import.direct("  import 'dart:io'  \n").resolve(),
        "import 'dart:io';",
      );
      expect(
        const Import.direct("import 'dart:io';\n").resolve(),
        "import 'dart:io';",
      );
    });

    test('leaves mustache placeholders for the DSL generators to render', () {
      const statement = "import '$_package/core/di/core_di.dart';";

      expect(const Import.direct(statement).resolve(), statement);
    });
  });
}
