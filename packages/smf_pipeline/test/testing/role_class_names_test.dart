import 'dart:convert';

import 'package:file/memory.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

/// The roles whose classes the tests look for: `AppShell` and `Destination`
/// of the layout role, and `FallbackStartScreen` of the app entry role,
/// which requires functions too, as the DI role does.
const List<Role> _roles = [layoutRole, appEntryRole, diRole];

/// The pubspecs of the packages of the tests: `acme_app` depends on the
/// module packages `acme_router`, in the workspace `/work`, and
/// `smf_contracts`, in the pub cache `/pub`, and on `yaml`, a package of no
/// module; `acme_theme` is a module package that it does not depend on.
const _pubspecs = {
  '/work/packages/acme_app/pubspec.yaml': 'name: acme_app\n'
      'dependencies:\n'
      '  yaml: any\n'
      '  smf_contracts: any\n'
      '  acme_router: any\n',
  '/work/packages/acme_router/pubspec.yaml': 'name: acme_router\n'
      'dependencies:\n'
      '  smf_contracts: any\n',
  '/work/packages/acme_theme/pubspec.yaml': 'name: acme_theme\n'
      'dependencies:\n'
      '  smf_contracts: any\n',
  '/pub/smf_contracts/pubspec.yaml': 'name: smf_contracts\n',
  '/pub/yaml/pubspec.yaml': 'name: yaml\n',
};

/// A file system with the packages of [_pubspecs] and [files] by their
/// paths, resolved at the root of the workspace as `dart pub get` does. The
/// current directory is the one of `acme_app`, as when `dart test` runs its
/// tests.
MemoryFileSystem _workspace(Map<String, String> files) {
  final fileSystem = MemoryFileSystem();
  for (final MapEntry(key: path, value: text)
      in {..._pubspecs, ...files}.entries) {
    fileSystem.file(path)
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
  }
  fileSystem.file('/work/.dart_tool/package_config.json')
    ..createSync(recursive: true)
    ..writeAsStringSync(
      jsonEncode({
        'configVersion': 2,
        'packages': [
          for (final (name, root) in [
            ('acme_app', '../packages/acme_app'),
            ('acme_router', '../packages/acme_router'),
            ('acme_theme', '../packages/acme_theme'),
            ('smf_contracts', 'file:///pub/smf_contracts'),
            ('yaml', 'file:///pub/yaml'),
          ])
            {'name': name, 'rootUri': root, 'packageUri': 'lib/'},
        ],
      }),
    );
  fileSystem.currentDirectory = '/work/packages/acme_app';
  return fileSystem;
}

/// The problems of `acme_app` in [fileSystem], in the current directory.
List<String> _problemsOf(MemoryFileSystem fileSystem) =>
    roleClassNameProblems(_roles, fileSystem: fileSystem);

void main() {
  test(
      'finds the strings that spell out the name of a class of a role, but '
      'not the interpolations of its name, comments or code', () {
    const source = r'''
/// Writes `AppShell(...)`, which a comment may name.
String shell() => '  builder: (context, state, shell) => AppShell(';

String fallback() => """
  return const FallbackStartScreen();""";

String destination(String label) =>
    '${LayoutRole.destination.name}(label: $label), NavigationDestination(';

String destinations(String icon) => '[Destination(icon: $icon)]';

final home = Route('/', destination: Destination(label: 'Home'));
''';

    expect(
      _problemsOf(
        _workspace({'/work/packages/acme_app/lib/a.dart': source}),
      ),
      [
        'acme_app/lib/a.dart:2 spells out AppShell( of the layout role.',
        equals(
          'acme_app/lib/a.dart:5 spells out FallbackStartScreen( of the app '
          'entry role.',
        ),
        'acme_app/lib/a.dart:10 spells out Destination( of the layout role.',
      ],
    );
  });

  test(
      'a name that an escape spells counts on the line where its string '
      'starts', () {
    const source = "const shell = '''\n"
        r"  App\u0053hell(''';"
        '\n';

    expect(
      _problemsOf(
        _workspace({'/work/packages/acme_app/lib/a.dart': source}),
      ),
      ['acme_app/lib/a.dart:1 spells out AppShell( of the layout role.'],
    );
  });

  test(
      'checks the code of the package and of the module packages it depends '
      'on, but not other packages, tests, bundles of bricks or other files',
      () {
    const shell = "const shell = 'AppShell(';\n";

    expect(
      _problemsOf(
        _workspace({
          for (final path in [
            '/work/packages/acme_app/lib/acme_app.dart',
            '/work/packages/acme_app/lib/bundles/app_bundle.dart',
            '/work/packages/acme_app/lib/notes.txt',
            '/work/packages/acme_app/test/app_test.dart',
            '/work/packages/acme_router/lib/src/router.dart',
            '/work/packages/acme_theme/lib/acme_theme.dart',
            '/pub/smf_contracts/lib/src/layout.dart',
            '/pub/yaml/lib/yaml.dart',
          ])
            path: shell,
        }),
      ),
      [
        for (final path in [
          'acme_app/lib/acme_app.dart',
          'acme_router/lib/src/router.dart',
          'smf_contracts/lib/src/layout.dart',
        ])
          '$path:1 spells out AppShell( of the layout role.',
      ],
    );
  });

  test('a package without dependencies has only its own code checked', () {
    expect(
      _problemsOf(
        _workspace({
          '/work/packages/acme_app/pubspec.yaml': 'name: acme_app\n',
          '/work/packages/acme_app/lib/acme_app.dart':
              "const shell = 'AppShell(';\n",
          '/work/packages/acme_router/lib/router.dart':
              "const shell = 'AppShell(';\n",
        }),
      ),
      ['acme_app/lib/acme_app.dart:1 spells out AppShell( of the layout role.'],
    );
  });

  test('without its pubspec the package is not there', () {
    expect(
      roleClassNameProblems(
        _roles,
        root: '/work/packages/acme_app',
        fileSystem: MemoryFileSystem(),
      ),
      ['The directory /work/packages/acme_app has no pubspec.yaml.'],
    );
  });

  test('without a package config the packages are not resolved', () {
    final fileSystem = _workspace(const {})
      ..file('/work/.dart_tool/package_config.json').deleteSync();

    expect(_problemsOf(fileSystem), [
      equals(
        'Neither the directory . nor one above it has '
        '.dart_tool/package_config.json: run dart pub get.',
      ),
    ]);
  });

  test(
      'a package that the package config leads to no pubspec of is '
      'unresolved', () {
    final fileSystem = _workspace({
      '/work/packages/acme_app/pubspec.yaml': 'name: acme_app\n'
          'dependencies:\n'
          '  smf_contracts: any\n'
          '  acme_icons: any\n',
    })
      ..directory('/pub/smf_contracts').deleteSync(recursive: true);

    expect(_problemsOf(fileSystem), [
      for (final package in ['acme_icons', 'smf_contracts'])
        equals(
          'The package config /work/.dart_tool/package_config.json has no '
          'package $package with a pubspec.yaml: run dart pub get.',
        ),
    ]);
  });
}
