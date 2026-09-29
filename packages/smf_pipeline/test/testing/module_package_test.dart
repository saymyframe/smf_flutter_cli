import 'dart:convert';

import 'package:file/memory.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

/// The packages in the pub cache `/pub` that the packages of the tests use,
/// each with the packages it depends on: a module package depends on
/// smf_contracts, whatever its name.
const _hosted = {
  'collection': <String>[],
  'mason': ['collection', 'yaml'],
  'smf_contracts': ['mason', 'meta'],
  'smf_core': ['smf_contracts'],
  'smf_flutter_core': ['mason', 'smf_contracts'],
  'smf_home': ['mason', 'smf_contracts'],
  'smf_pipeline': ['smf_contracts', 'yaml'],
  'smf_utils': ['collection'],
  'test': ['test_api'],
  'yaml': ['collection'],
};

/// Resolves the packages of [fileSystem] as `dart pub get` does: writes the
/// package config to `.dart_tool/package_config.json` in [workspace], with
/// the root of each of its [members] by its path relative to [workspace],
/// and the packages of [_hosted] in the pub cache with their pubspecs.
void _resolve(
  MemoryFileSystem fileSystem,
  String workspace,
  Map<String, String> members,
) {
  for (final MapEntry(key: package, value: dependencies) in _hosted.entries) {
    fileSystem.file('/pub/$package/pubspec.yaml')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        [
          'name: $package',
          if (dependencies.isNotEmpty) 'dependencies:',
          for (final dependency in dependencies) '  $dependency: any',
        ].join('\n'),
      );
  }
  fileSystem.file('$workspace/.dart_tool/package_config.json')
    ..createSync(recursive: true)
    ..writeAsStringSync(
      jsonEncode({
        'configVersion': 2,
        'packages': [
          for (final MapEntry(key: name, value: path) in members.entries)
            {'name': name, 'rootUri': '../$path', 'packageUri': 'lib/'},
          for (final name in _hosted.keys)
            {
              'name': name,
              'rootUri': 'file:///pub/$name',
              'packageUri': 'lib/',
            },
        ],
      }),
    );
}

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

/// A file system with the package `smf_router` in `/router`, resolved on
/// its own: its pubspec and [files] by path relative to the package, a
/// module that follows the rules unless they break them.
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
        "import 'package:smf_contracts/smf_contracts.dart';\n"
        "import 'package:smf_router/bundles/router_bundle.dart';\n"
        "import '../bundles/router_bundle.dart';\n",
    'lib/bundles/router_bundle.dart': "import 'package:mason/mason.dart';\n",
    'test/router_test.dart': "import 'package:smf_contracts/core.dart';\n"
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
  _resolve(fileSystem, '/router', {'smf_router': ''});
  return fileSystem;
}

/// A file system with the pub workspace `/work`, resolved at its root, with
/// two packages of modules in `packages/`: `acme_theme`, and `acme_feature`
/// with [files] by path relative to it and [devDependencies], a module that
/// follows the rules unless they break them. The current directory is the
/// one of `acme_feature`, as when `dart test` runs its tests.
MemoryFileSystem _acme(
  Map<String, String> files, {
  List<String> devDependencies = const ['smf_pipeline', 'test'],
}) {
  final fileSystem = MemoryFileSystem();
  for (final MapEntry(key: path, value: text) in {
    'acme_theme/pubspec.yaml': 'name: acme_theme\n'
        'dependencies:\n'
        '  smf_contracts: any\n',
    'acme_feature/pubspec.yaml': [
      'name: acme_feature',
      'dependencies:',
      '  smf_contracts: any',
      'dev_dependencies:',
      for (final package in devDependencies) '  $package: any',
    ].join('\n'),
    'acme_feature/lib/acme_feature.dart':
        "import 'package:smf_contracts/smf_contracts.dart';\n",
    'acme_feature/test/feature_test.dart':
        "import 'package:acme_feature/acme_feature.dart';\n"
            "import 'package:smf_pipeline/testing.dart';\n"
            "import 'package:test/test.dart';\n",
    for (final MapEntry(key: path, value: text) in files.entries)
      'acme_feature/$path': text,
  }.entries) {
    fileSystem.file('/work/packages/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
  }
  _resolve(fileSystem, '/work', {
    'acme_feature': 'packages/acme_feature',
    'acme_theme': 'packages/acme_theme',
  });
  fileSystem.currentDirectory = '/work/packages/acme_feature';
  return fileSystem;
}

/// The problems of `acme_feature` in [fileSystem] with [testModules], in
/// the current directory.
List<String> _acmeProblemsOf(
  MemoryFileSystem fileSystem, {
  Set<String> testModules = const {},
}) =>
    ModulePackage('acme_feature', testModules: testModules)
        .problems(fileSystem: fileSystem);

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

  test('without a package config the packages are not resolved', () {
    final fileSystem = _package(const {})
      ..file('/router/.dart_tool/package_config.json').deleteSync();

    expect(_problemsOf(fileSystem), [
      equals(
        'Neither the directory /router nor one above it has '
        '.dart_tool/package_config.json: run dart pub get.',
      ),
    ]);
  });

  test('without its pubspec in the package config a package is unresolved', () {
    final fileSystem = _acme(const {
      'test/theme_test.dart': "import 'package:acme_theme/acme_theme.dart';\n"
          "import 'package:acme_icons/acme_icons.dart';\n",
    })
      ..file('/work/packages/acme_theme/pubspec.yaml').deleteSync();

    expect(_acmeProblemsOf(fileSystem), [
      for (final package in ['acme_icons', 'acme_theme'])
        equals(
          'The package config /work/.dart_tool/package_config.json has no '
          'package $package with a pubspec.yaml: run dart pub get.',
        ),
    ]);
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
          'smf_router depends on path, which is not among the dependencies of '
          'the module: mason and smf_contracts.',
        ),
        equals(
          'smf_router depends on smf_other, which is not among the '
          'dependencies of the module: mason and smf_contracts.',
        ),
        'smf_router does not depend on smf_contracts.',
      ],
    );
  });

  test('of the module packages, tests use smf_pipeline and test modules', () {
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
          'the module packages the tests of a module use only '
          'smf_flutter_core and smf_pipeline.',
        ),
        'smf_router has no dev dependency on smf_pipeline.',
      ],
    );
  });

  test('smf_contracts counts as a module package by its name', () {
    expect(
      _problemsOf(
        _package(
          const {},
          pubspec: _pubspec(
            devDependencies: [
              'smf_contracts',
              'smf_flutter_core',
              'smf_pipeline',
              'test',
            ],
          ),
        ),
      ),
      [
        equals(
          'smf_router has a dev dependency on smf_contracts, but of the '
          'module packages the tests of a module use only smf_flutter_core '
          'and smf_pipeline.',
        ),
      ],
    );
  });

  test('a pubspec without dev dependencies lacks those of the tests', () {
    expect(
      _problemsOf(
        _package(
          const {},
          pubspec: 'name: smf_router\n'
              'dependencies:\n'
              '  mason: any\n'
              '  smf_contracts: any\n',
        ),
      ),
      [
        'smf_router has no dev dependency on smf_flutter_core.',
        'smf_router has no dev dependency on smf_pipeline.',
      ],
    );
  });

  test('the code uses only the module model and what the package has', () {
    expect(
      _problemsOf(
        _package(const {
          'lib/src/bad.dart':
              "import 'package:smf_contracts/bundles/router_role_bundle.dart';\n"
                  "import 'package:smf_home/smf_home.dart';\n"
                  "import 'package:mason/src/inner.dart';\n"
                  "export 'package:yaml/yaml.dart';\n"
                  "import '../../test/router_test.dart';\n"
                  "import 'package:smf_contracts/smf_contracts.dart';\n"
                  "import 'dart:io';\n"
                  "import 'dart:convert';\n"
                  "import 'stub.dart' if (dart.library.io) 'dart:isolate';\n"
                  "part '../../test/bad_part.dart';\n",
        }),
      ),
      [
        for (final uri in [
          'package:smf_contracts/bundles/router_role_bundle.dart',
          'package:smf_home/smf_home.dart',
          'package:mason/src/inner.dart',
          'package:yaml/yaml.dart',
          '../../test/router_test.dart',
          'dart:io',
          'dart:isolate',
          '../../test/bad_part.dart',
        ])
          equals(
            'lib/src/bad.dart uses $uri, but the code of a module uses only '
            'the dart: libraries that do not reach the machine, the module '
            'model of smf_contracts, its own files in lib/ and the public '
            'libraries of the packages it depends on.',
          ),
      ],
    );
  });

  test('the tests use the module model and no file of another package', () {
    expect(
      _problemsOf(
        _package(const {
          'test/bad_test.dart':
              "import 'package:smf_contracts/bundles/router_role_bundle.dart';\n"
                  "import 'package:smf_home/smf_home.dart';\n"
                  "import 'package:smf_pipeline/src/render.dart';\n"
                  "import '../../other/test/support.dart';\n"
                  "import 'package:yaml/yaml.dart';\n"
                  "import 'package:smf_router/src/router.dart';\n",
        }),
      ),
      [
        for (final uri in [
          'package:smf_contracts/bundles/router_role_bundle.dart',
          'package:smf_home/smf_home.dart',
          'package:smf_pipeline/src/render.dart',
          '../../other/test/support.dart',
        ])
          equals(
            'test/bad_test.dart uses $uri, but of the module packages the '
            'tests of a module use only the module model of smf_contracts and '
            'the public libraries of smf_flutter_core, smf_pipeline and '
            'smf_router, and no file outside test/ by a relative path.',
          ),
      ],
    );
  });

  test('the tests use the public libraries of the modules it depends on', () {
    const withCore = ModulePackage(
      'smf_router',
      dependencies: {'mason', 'smf_core'},
      testModules: {'smf_flutter_core'},
    );
    final fileSystem = _package(
      const {
        'lib/src/core.dart': "import 'package:smf_core/smf_core.dart';\n",
        'test/core_test.dart': "import 'package:smf_core/smf_core.dart';\n"
            "import 'package:smf_core/src/core.dart';\n",
      },
      pubspec: _pubspec(dependencies: ['mason', 'smf_contracts', 'smf_core']),
    );

    expect(_problemsOf(fileSystem, package: withCore), [
      equals(
        'test/core_test.dart uses package:smf_core/src/core.dart, but of the '
        'module packages the tests of a module use only the module model of '
        'smf_contracts and the public libraries of smf_core, '
        'smf_flutter_core, smf_pipeline and smf_router, and no file outside '
        'test/ by a relative path.',
      ),
    ]);
  });

  test('the package depends on nothing its code does not use', () {
    expect(
      _problemsOf(
        _package(const {
          'lib/src/router.dart':
              "import 'package:smf_contracts/smf_contracts.dart';\n",
          'lib/bundles/router_bundle.dart': '',
        }),
      ),
      ['smf_router depends on mason, but no file in lib/ uses it.'],
    );
  });

  test('a module without dependencies depends only on smf_contracts', () {
    expect(
      _problemsOf(
        _package(
          const {},
          pubspec: _pubspec(dependencies: ['mason', 'smf_contracts']),
        ),
        package: const ModulePackage(
          'smf_router',
          testModules: {'smf_flutter_core'},
        ),
      ),
      [
        equals(
          'smf_router depends on mason, which is not among the dependencies '
          'of the module: smf_contracts.',
        ),
        startsWith('lib/bundles/router_bundle.dart uses package:mason'),
        startsWith('lib/src/router.dart uses package:mason/mason.dart'),
      ],
    );
  });

  test('a package without tests has its code and pubspec to check', () {
    final fileSystem = MemoryFileSystem();
    fileSystem.file('/router/pubspec.yaml')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        _pubspec(
          dependencies: ['smf_contracts'],
          devDependencies: ['smf_pipeline'],
        ),
      );
    _resolve(fileSystem, '/router', {'smf_router': ''});

    expect(
      _problemsOf(fileSystem, package: const ModulePackage('smf_router')),
      ['smf_router depends on smf_contracts, but no file in lib/ uses it.'],
    );

    fileSystem.file('/router/lib/smf_router.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync("import 'package:smf_contracts/core.dart';\n");
    expect(
      _problemsOf(fileSystem, package: const ModulePackage('smf_router')),
      isEmpty,
    );
  });

  group('a module package of any name', () {
    test('is used by the tests only as a test module', () {
      const files = {
        'test/theme_test.dart':
            "import 'package:acme_theme/acme_theme.dart';\n",
      };

      expect(_acmeProblemsOf(_acme(files)), [
        equals(
          'test/theme_test.dart uses package:acme_theme/acme_theme.dart, but '
          'of the module packages the tests of a module use only the module '
          'model of smf_contracts and the public libraries of acme_feature '
          'and smf_pipeline, and no file outside test/ by a relative path.',
        ),
      ]);
      expect(
        _acmeProblemsOf(
          _acme(files, devDependencies: ['acme_theme', 'smf_pipeline', 'test']),
          testModules: {'acme_theme'},
        ),
        isEmpty,
      );
    });

    test('is a dev dependency only as a test module', () {
      expect(
        _acmeProblemsOf(
          _acme(
            const {},
            devDependencies: ['acme_theme', 'smf_pipeline', 'test'],
          ),
        ),
        [
          equals(
            'acme_feature has a dev dependency on acme_theme, but of the '
            'module packages the tests of a module use only smf_pipeline.',
          ),
        ],
      );
    });
  });

  test('the tests use a package that does not depend on smf_contracts', () {
    expect(
      _acmeProblemsOf(
        _acme(
          const {
            'test/collection_test.dart':
                "import 'package:collection/collection.dart';\n"
                    "import 'package:collection/src/utils.dart';\n",
          },
          devDependencies: ['collection', 'smf_pipeline', 'test'],
        ),
      ),
      isEmpty,
    );
  });

  test('the prefix smf_ does not make a package one of a module', () {
    expect(
      _acmeProblemsOf(
        _acme(
          const {
            'test/utils_test.dart':
                "import 'package:smf_utils/smf_utils.dart';\n",
          },
          devDependencies: ['smf_pipeline', 'smf_utils', 'test'],
        ),
      ),
      isEmpty,
    );
  });
}
