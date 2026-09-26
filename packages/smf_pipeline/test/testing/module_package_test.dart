import 'package:file/memory.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

/// The pubspec of the package `smf_router` with [dependencies] and
/// [devDependencies].
String _pubspec({
  List<String> dependencies = const ['mason', 'smf_contracts'],
  List<String> devDependencies = const [
    'smf_flutter_core',
    'smf_pipeline',
    'test',
  ],
}) =>
    [
      'name: smf_router',
      'dependencies:',
      for (final package in dependencies) '  $package: any',
      'dev_dependencies:',
      for (final package in devDependencies) '  $package: any',
    ].join('\n');

/// A file system with the package `smf_router` in `/router`: its pubspec
/// and [files] by path relative to the package, a module that follows the
/// rules unless they break them.
MemoryFileSystem _package(
  Map<String, String> files, {
  String? pubspec,
}) {
  final fileSystem = MemoryFileSystem();
  for (final MapEntry(key: path, value: text) in {
    'pubspec.yaml': pubspec ?? _pubspec(),
    'lib/smf_router.dart': "export 'src/router.dart';\n",
    'lib/src/router.dart': "import 'dart:convert';\n"
        "import 'package:mason/mason.dart';\n"
        "import 'package:smf_contracts/lego.dart';\n"
        "import 'package:smf_router/bundles/router_bundle.dart';\n"
        "import '../bundles/router_bundle.dart';\n",
    'lib/bundles/router_bundle.dart': "import 'package:mason/mason.dart';\n",
    'test/router_test.dart': "import 'package:smf_contracts/lego_core.dart';\n"
        "import 'package:smf_flutter_core/smf_flutter_core.dart';\n"
        "import 'package:smf_pipeline/testing.dart';\n"
        "import 'package:smf_router/smf_router.dart';\n"
        "import 'package:test/test.dart';\n"
        "import 'support/features.dart';\n",
    'test/support/features.dart': "import '../router_test.dart';\n",
    ...files,
  }.entries) {
    fileSystem.file('/router/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
  }
  return fileSystem;
}

const _router = ModulePackage(
  'smf_router',
  dependencies: {'mason'},
  testModules: {'smf_flutter_core'},
);

List<String> _problemsOf(
  MemoryFileSystem fileSystem, {
  ModulePackage package = _router,
}) =>
    package.problems(root: '/router', fileSystem: fileSystem);

void main() {
  test('a package that follows the rules has no problems', () {
    expect(_problemsOf(_package(const {})), isEmpty);
  });

  test('without its pubspec the package is not there', () {
    expect(_problemsOf(MemoryFileSystem()), [
      'The directory /router has no pubspec.yaml of smf_router.',
    ]);
    expect(
      _problemsOf(_package(const {}), package: const ModulePackage('other')),
      ['The directory /router has no pubspec.yaml of other.'],
    );
  });

  test('the package depends on smf_contracts and its dependencies only', () {
    expect(
      _problemsOf(
        _package(
          const {},
          pubspec: _pubspec(dependencies: ['mason', 'smf_other', 'path']),
        ),
      ),
      [
        equals(
          'smf_router depends on path, but a module depends only on mason and '
          'smf_contracts.',
        ),
        equals(
          'smf_router depends on smf_other, but a module depends only on mason '
          'and smf_contracts.',
        ),
        'smf_router does not depend on smf_contracts.',
      ],
    );
  });

  test('of the SMF packages, the tests use smf_pipeline and test modules', () {
    expect(
      _problemsOf(
        _package(
          const {},
          pubspec: _pubspec(
            devDependencies: ['smf_home', 'smf_flutter_core'],
          ),
        ),
      ),
      [
        equals(
          'smf_router has a dev dependency on smf_home, but of '
          'the SMF packages the tests of a module use only smf_flutter_core '
          'and smf_pipeline.',
        ),
        'smf_router has no dev dependency on smf_pipeline.',
      ],
    );
  });

  test('the code uses only the module model and what the package has', () {
    expect(
      _problemsOf(
        _package(const {
          'lib/src/old.dart':
              "import 'package:smf_contracts/smf_contracts.dart';\n"
                  "import 'package:smf_home/smf_home.dart';\n"
                  "export 'package:yaml/yaml.dart';\n"
                  "import '../../test/router_test.dart';\n"
                  "import 'package:smf_contracts/lego.dart';\n",
        }),
      ),
      [
        for (final uri in [
          'package:smf_contracts/smf_contracts.dart',
          'package:smf_home/smf_home.dart',
          '../../test/router_test.dart',
          'package:yaml/yaml.dart',
        ])
          equals(
            'lib/src/old.dart uses $uri, but the code of a module uses only '
            'dart:, the module model of smf_contracts, its own files in lib/ '
            'and the packages it depends on.',
          ),
      ],
    );
  });

  test('the tests use the module model and no file of another package', () {
    expect(
      _problemsOf(
        _package(const {
          'test/old_test.dart':
              "import 'package:smf_contracts/smf_contracts.dart';\n"
                  "import 'package:smf_home/smf_home.dart';\n"
                  "import '../../other/test/support.dart';\n"
                  "import 'package:yaml/yaml.dart';\n",
        }),
      ),
      [
        for (final uri in [
          'package:smf_contracts/smf_contracts.dart',
          'package:smf_home/smf_home.dart',
          '../../other/test/support.dart',
        ])
          equals(
            'test/old_test.dart uses $uri, but of the SMF packages the tests '
            'of a module use only the module model of smf_contracts, '
            'smf_flutter_core, smf_pipeline and smf_router, and no file '
            'outside test/ by a relative path.',
          ),
      ],
    );
  });

  test('a package without code or tests has only its pubspec to check', () {
    final fileSystem = MemoryFileSystem();
    fileSystem.file('/router/pubspec.yaml')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        _pubspec(
          dependencies: ['smf_contracts'],
          devDependencies: ['smf_pipeline'],
        ),
      );

    expect(
      _problemsOf(fileSystem, package: const ModulePackage('smf_router')),
      isEmpty,
    );
  });
}
