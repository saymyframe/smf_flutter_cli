@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

/// A file of the app at [path] with [text].
RenderedFile _file(String path, String text) => RenderedFile(
      path: path,
      bytes: utf8.encode(text),
      owner: const ModuleOrigin(ModuleId('shop')),
    );

/// An app of the package `shop_app` whose `lib/shop.dart` reads a constant
/// through a relative import, a file that it reaches through an import of the
/// package and an export, and a file of Flutter that nothing of it imports.
RenderedApp _app({Map<String, String> more = const {}}) => RenderedApp([
      _file('pubspec.yaml', 'name: shop_app\nenvironment:\n  sdk: ^3.6.0\n'),
      _file('lib/shop.dart', r'''
import 'dart:core';

import 'core/price.dart';
import 'package:shop_app/core/name.dart';

String describe() => '$name: $price';
'''),
      _file('lib/core/price.dart', '''
export '../sale.dart';

const _release = bool.fromEnvironment('dart.vm.product');

/// The price, which a release build must have.
const int price = bool.hasEnvironment('SHOP_PRICE') || !_release
    ? int.fromEnvironment('SHOP_PRICE')
    : ('The build has no price.' as int);
'''),
      _file('lib/core/name.dart', "const name = 'Shop';\n"),
      _file('lib/sale.dart', 'const sale = true;\n'),
      _file('lib/screen.dart', "import 'package:flutter/widgets.dart';\n"),
      for (final MapEntry(:key, :value) in more.entries) _file(key, value),
    ]);

const _script = '''
import 'package:shop_app/shop.dart';

void main() => print(describe());
''';

void main() {
  group('DartOnlyApp', () {
    test(
        'writes the files that it is given and those of the app that they '
        'import or export, directly or not, as the package of the app',
        () async {
      final app = DartOnlyApp.write(_app(), ['lib/shop.dart']);
      addTearDown(app.delete);

      expect(app.files, {
        'lib/shop.dart',
        'lib/core/price.dart',
        'lib/core/name.dart',
        'lib/sale.dart',
      });
      expect(
        File('${app.path}/lib/core/name.dart').readAsStringSync(),
        "const name = 'Shop';\n",
      );
      expect(File('${app.path}/lib/screen.dart').existsSync(), isFalse);
      expect(
        File('${app.path}/pubspec.yaml').readAsStringSync(),
        'name: shop_app\n',
      );
    });

    test(
        'runs a program with the Dart VM, which declares what it is given '
        'and evaluates no constant of a release build', () async {
      final app = DartOnlyApp.write(_app(), ['lib/shop.dart']);
      addTearDown(app.delete);

      expect(
        await app.run(_script, defines: {'SHOP_PRICE': '12'}),
        'Shop: 12\n',
      );
      expect(await app.run(_script), 'Shop: 0\n');
      await expectLater(
        app.run('''
void main() {
  print('Before');
  throw StateError('No shop');
}
'''),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(
              startsWith('The program failed with 255: Before\n'),
              contains('No shop'),
            ),
          ),
        ),
      );
    });

    test(
        'compiles a program as the compiler of a release build does, which '
        'stops at a constant that it cannot evaluate and quotes it', () async {
      final app = DartOnlyApp.write(_app(), ['lib/shop.dart']);
      addTearDown(app.delete);

      final without = await app.compile(_script);
      expect(without.compiled, isFalse);
      expect(without.output, contains('"The build has no price."'));

      final given = await app.compile(_script, defines: {'SHOP_PRICE': '12'});
      expect(given.compiled, isTrue, reason: given.output);
    });

    test(
        'refuses a file that the app lacks, an import of another package and '
        'an import of a file that the app lacks, naming the file', () {
      expect(
        () => DartOnlyApp.write(_app(), ['lib/gone.dart']),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'The app has no file lib/gone.dart.',
          ),
        ),
      );
      expect(
        () => DartOnlyApp.write(_app(), ['lib/screen.dart']),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'lib/screen.dart imports package:flutter/widgets.dart, a package '
                'other than the app, which needs more than the Dart SDK.',
          ),
        ),
      );
      expect(
        () => DartOnlyApp.write(
          _app(more: {'lib/broken.dart': "import 'missing.dart';\n"}),
          ['lib/broken.dart'],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'lib/broken.dart imports lib/missing.dart, which the app does not '
                'have.',
          ),
        ),
      );
    });

    test('needs the name of the package of the app in its pubspec.yaml', () {
      for (final app in [
        RenderedApp([_file('lib/a.dart', '')]),
        RenderedApp([
          _file('pubspec.yaml', 'description: x\n'),
          _file('lib/a.dart', ''),
        ]),
      ]) {
        expect(
          () => DartOnlyApp.write(app, ['lib/a.dart']),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'The app has no pubspec.yaml with the name of a package.',
            ),
          ),
        );
      }
    });
  });
}
