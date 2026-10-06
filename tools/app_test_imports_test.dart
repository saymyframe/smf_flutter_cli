// Checks that the tests that packages keep for the apps of the matrix in
// `app_tests/` import from the app only files that every app they apply to
// has, whichever modules provide its roles. An app test imports a file of
// the app as `package:{{app_name}}/<path>`, or by a relative path from a
// file that goes into the app: the files of a directory of app tests go
// into the app at their paths in the directory, so `import 'app.dart';` in
// its `lib/` and `import '../lib/app.dart';` in its `test/` both import
// `lib/app.dart` of the app. It runs in the apps that have the modules it
// tests, whatever their other modules. A file that only one provider of a
// role generates, such as `lib/app.dart` of the brick of flutter_core, is
// missing from an app with another provider, even when every app of the
// matrix has it today.
//
// So an app test imports only:
// - the files that the roles of smf_contracts guarantee to the apps that
//   have them: the files of the templates of the roles and those of the
//   symbols that every provider of a role generates (`RoleInterface`);
// - the files that the bricks of the modules of its package generate, and
//   those of the modules they depend on: the packages of modules among the
//   dependencies of its package, and theirs in turn;
// - the files that its own directory puts into `lib/`.
//
// The app tests of a package of no module, such as the CLI, belong to no
// module, so they import the files of no published module: the start
// check of the CLI applies to every app, whichever module provides its app
// entry. The app tests of the fixture registry test the fixture modules,
// fake modules that exist only for its tests and are never published
// (`publish_to: none`), so they may import the files of the fixture
// modules among the packages it depends on too. A fixture module depends on
// no published package of modules: the app tests of the fixture registry
// would know that module with it, and could import the files of a provider
// that another app does not have.
import 'dart:io';
import 'dart:mirrors';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'workspace.dart';

/// How an app test imports a file of the app, before its path in `lib/`.
const _app = 'package:{{app_name}}/';

/// The path in the app of the file that [uri] names in the file at [file]
/// of a directory of app tests, which goes into the app at the same path,
/// if it is a file of `lib/` of the app: `lib/<path>` for
/// `package:{{app_name}}/<path>`, and for a relative URI the path it
/// resolves to from [file]; otherwise `null`.
String? appFileOf(String file, String uri) {
  if (uri.startsWith(_app)) return 'lib/${uri.substring(_app.length)}';
  if (Uri.parse(uri).hasScheme) return null;
  // The root of the app, whose name no relative URI can reach.
  const root = '/app/';
  final path = Uri.parse('file://$root$file').resolve(uri).path;
  return path.startsWith('${root}lib/') ? path.substring(root.length) : null;
}

/// The problems of the imports of files of the app in the app tests of the
/// [packages] of the repository at [root]: one line for each import of a
/// file that no role guarantees, that the modules its package knows do not
/// generate and that its directory does not put into `lib/`.
///
/// [roleFiles] holds the path in the app of each file that a role
/// guarantees, such as `lib/main.dart`, with the name of the role, such as
/// `app entry role`.
List<String> problemsOf(
  String root,
  List<WorkspacePackage> packages,
  Map<String, String> roleFiles,
) {
  final byName = {for (final package in packages) package.name: package};
  final problems = <String>[];
  for (final package in packages) {
    final appTests = Directory('$root/${package.path}/app_tests');
    if (!appTests.existsSync()) continue;
    final known = knownModules(package, byName);
    final generated = {
      for (final module in known) module.name: _brickFiles(root, module),
    };
    final patterns = [
      for (final files in generated.values) ...files.map(brickFilePattern),
    ];
    final directories = [
      for (final entity in appTests.listSync())
        if (entity is Directory)
          entity.path.replaceAll(r'\', '/').split('/').last,
    ]..sort();
    for (final directory in directories) {
      if (directory.startsWith('.')) continue;
      final path = '${package.path}/app_tests/$directory';
      final own = {
        for (final file in filesIn(Directory('$root/$path')))
          if (file.startsWith('lib/')) file,
      };
      for (final file in dartFilesIn('$root/$path')) {
        final text = File('$root/$path/$file').readAsStringSync();
        for (final uri in urisOf(text)) {
          final inApp = appFileOf(file, uri);
          if (inApp == null ||
              roleFiles.containsKey(inApp) ||
              own.contains(inApp) ||
              patterns.any((pattern) => pattern.hasMatch(inApp))) {
            continue;
          }
          problems.add(
            _problem('$path/$file', uri, inApp, package, generated, roleFiles),
          );
        }
      }
    }
  }
  return problems;
}

/// The paths of the files in `lib/` of the bricks of [package] of the
/// repository at [root], each from the `__brick__` of its brick, as mason
/// writes them, such as `lib/core/router/app_router_factory.dart`.
List<String> _brickFiles(String root, WorkspacePackage package) {
  final bricks = Directory('$root/${package.path}/bricks');
  if (!bricks.existsSync()) return const [];
  return [
    for (final brick
        in bricks.listSync()..sort((a, b) => a.path.compareTo(b.path)))
      if (Directory('${brick.path}/__brick__') case final files
          when files.existsSync())
        for (final file in filesIn(files))
          if (file.startsWith('lib/')) file,
  ];
}

/// The paths in an app of the file of a brick at [path] from its
/// `__brick__`, as a pattern: a section of mason, such as
/// `{{#has_router}}…{{/has_router}}`, keeps what it holds, and a variable,
/// such as `{{name.snakeCase()}}`, stands for any name.
RegExp brickFilePattern(String path) {
  final pattern = StringBuffer('^');
  var at = 0;
  for (final tag
      in RegExp(r'\{\{\{?\s*([#^/]?)[^{}]*\}\}\}?').allMatches(path)) {
    pattern.write(RegExp.escape(path.substring(at, tag.start)));
    if (tag[1]!.isEmpty) pattern.write('[^/]+');
    at = tag.end;
  }
  pattern
    ..write(RegExp.escape(path.substring(at)))
    ..write(r'$');
  return RegExp('$pattern');
}

/// The problem of the import of [uri], the file [inApp] of the app, in the
/// app test at [file] of [package], whose app tests may import the files
/// that the modules of [generated] generate, by the names of their
/// packages, and those of [roleFiles].
String _problem(
  String file,
  String uri,
  String inApp,
  WorkspacePackage package,
  Map<String, List<String>> generated,
  Map<String, String> roleFiles,
) {
  final byRole = <String, List<String>>{};
  for (final MapEntry(key: path, value: role) in roleFiles.entries) {
    if (path.startsWith('lib/')) {
      (byRole[role] ??= []).add(path.substring('lib/'.length));
    }
  }
  final roles = byRole.keys.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  final guaranteed = [
    for (final role in roles) '${_list(byRole[role]!)} of the $role',
  ].join('; ');
  final modules = generated.keys.toList();
  final files = [
    for (final paths in generated.values)
      for (final path in paths) path.substring('lib/'.length),
  ];
  final problem = StringBuffer('$file imports $uri');
  if (!uri.startsWith(_app)) problem.write(', $inApp of the app');
  problem.write(', a file that no role guarantees');
  if (modules.isNotEmpty) {
    problem.write(' and no module of ${_list(modules, 'or')} generates');
  }
  problem
    ..write(', so an app whose roles other modules provide need not have ')
    ..write('it. The app tests of ${package.name}');
  if (!package.declaresModules) problem.write(', a package of no module,');
  problem.write(
    ' may import the files that roles guarantee to the apps that have '
    'them: $guaranteed',
  );
  if (files.isNotEmpty) {
    problem.write(
      '; and the files that the bricks of ${_list(modules)} generate: '
      '${_list(files)}',
    );
  }
  problem.write(', and those that their directory puts into lib/.');
  return '$problem';
}

String _list(List<String> items, [String conjunction = 'and']) =>
    items.length < 2
        ? items.join()
        : '${items.sublist(0, items.length - 1).join(', ')} $conjunction '
            '${items.last}';

/// The files that the roles of smf_contracts guarantee to the apps that
/// have them, by path in the app, such as `lib/main.dart`, each with the
/// name of its role: the files of the template of each role and those of
/// the symbols that every provider of a role generates (`RoleInterface`).
///
/// The roles are the public top-level constants of the libraries of
/// smf_contracts that are a `Role`, which mirrors find, so that a new role
/// counts without a change here.
Map<String, String> _roleFiles() {
  final guaranteed = <String, String>{};
  for (final library in currentMirrorSystem().libraries.values) {
    if (!'${library.uri}'.startsWith('package:smf_contracts/')) continue;
    for (final declaration in library.declarations.values) {
      if (declaration is! VariableMirror || declaration.isPrivate) continue;
      if (library.getField(declaration.simpleName).reflectee
          case final Role role) {
        final RoleInterface(:files, :symbols) = role.interface;
        final paths = [...files, for (final symbol in symbols) symbol.path];
        for (final path in paths) {
          guaranteed.putIfAbsent(path, () => '$role');
        }
      }
    }
  }
  return guaranteed;
}

void main() {
  test(
      'finds the imports of files of the app that neither the roles nor '
      'the modules that the package of an app test knows guarantee', () {
    final temp = Directory.systemTemp.createTempSync('smf_app_test_imports_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final root = temp.path;
    const module = 'final class AModule extends SmfModule {}';
    final files = {
      // A package of modules that depends on the package of another, and
      // does not know the other modules of the workspace.
      'a/pubspec.yaml': 'name: a\n'
          'dependencies:\n'
          '  b: ^1.0.0\n'
          '  smf_contracts: ^1.0.0\n',
      'a/lib/a.dart': module,
      'a/bricks/a/__brick__/lib/core/a/a.dart': '',
      'a/app_tests/a/lib/own.dart': '',
      // A file that goes into lib/ of the app, whose relative imports name
      // the files of lib/ of the app.
      'a/app_tests/a/lib/own_root.dart': '''
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'own.dart';
import 'core/a/a.dart';
import 'main.dart' as app;
import 'app.dart';
''',
      'a/app_tests/a/test/a_test.dart': '''
import 'package:{{app_name}}/main.dart' as app;
import 'package:{{app_name}}/core/a/a.dart';
import 'package:{{app_name}}/core/b/b.dart';
import 'package:{{app_name}}/features/home/screen.dart';
import 'package:{{app_name}}/own.dart';
import 'package:{{app_name}}/app.dart';
import '../lib/own.dart';
import '../lib/app.dart';
import '../../../outside.dart';
import 'helper.dart'
    if (dart.library.io) 'package:{{app_name}}/core/c/c.dart';
// import 'package:{{app_name}}/in_a_comment.dart';
const text = 'package:{{app_name}}/in_a_string.dart';
''',
      'a/app_tests/a/test/helper.dart': '',
      'a/app_tests/a/.hidden/hidden.dart':
          "import 'package:{{app_name}}/app.dart';",
      'b/pubspec.yaml': 'name: b\n',
      'b/lib/src/b.dart': module,
      'b/bricks/b/__brick__/lib/core/b/b.dart': '',
      'b/bricks/b/__brick__/lib/features/{{name}}/screen.dart': '',
      'c/pubspec.yaml': 'name: c\n',
      'c/lib/c.dart': module,
      'c/bricks/c/__brick__/lib/core/c/c.dart': '',
      // The provider of the app entry of the apps.
      'entry/pubspec.yaml': 'name: entry\n',
      'entry/lib/entry.dart': module,
      'entry/bricks/entry/__brick__/lib/app.dart': '',
      'entry/bricks/entry/__brick__/lib/main.dart': '',
      // A registry of a published module and of a fixture module.
      'registry/pubspec.yaml': 'name: registry\n'
          'dependencies:\n'
          '  entry: ^1.0.0\n'
          '  fixture: any\n',
      'registry/lib/registry.dart': '/// Not a class that extends SmfModule.',
      'registry/app_tests/r/test/r_test.dart': '''
import 'package:{{app_name}}/main.dart' as app;
import 'package:{{app_name}}/core/fixture/fixture.dart';
import 'package:{{app_name}}/app.dart';
''',
      'fixture/pubspec.yaml': 'name: fixture\npublish_to: none\n',
      'fixture/lib/fixture.dart': module,
      'fixture/bricks/fixture/__brick__/lib/core/fixture/fixture.dart': '',
    };
    for (final MapEntry(key: path, value: text) in files.entries) {
      File('$root/$path')
        ..createSync(recursive: true)
        ..writeAsStringSync(text);
    }
    final packages = [
      for (final path in ['a', 'b', 'c', 'entry', 'registry', 'fixture'])
        WorkspacePackage.read(root, path),
    ];

    const need = 'so an app whose roles other modules provide need not have '
        'it.';
    const roles = 'the files that roles guarantee to the apps that have '
        'them: main.dart of the app entry role';
    const ofA = 'a file that no role guarantees and no module of a or b '
        'generates, $need The app tests of a may import $roles; and the files '
        'that the bricks of a and b generate: core/a/a.dart, core/b/b.dart and '
        'features/{{name}}/screen.dart, and those that their directory puts '
        'into lib/.';
    const ownRoot = 'a/app_tests/a/lib/own_root.dart imports app.dart, '
        'lib/app.dart of the app, $ofA';
    const app = 'a/app_tests/a/test/a_test.dart imports '
        'package:{{app_name}}/app.dart, $ofA';
    const relative = 'a/app_tests/a/test/a_test.dart imports '
        '../lib/app.dart, lib/app.dart of the app, $ofA';
    const c = 'a/app_tests/a/test/a_test.dart imports '
        'package:{{app_name}}/core/c/c.dart, $ofA';
    const registry = 'registry/app_tests/r/test/r_test.dart imports '
        'package:{{app_name}}/app.dart, a file that no role guarantees and no '
        'module of fixture generates, $need The app tests of registry, a '
        'package of no module, may import $roles; and the files that the '
        'bricks of fixture generate: core/fixture/fixture.dart, and those that '
        'their directory puts into lib/.';

    expect(
      problemsOf(root, packages, {'lib/main.dart': 'app entry role'}),
      [ownRoot, app, relative, c, registry],
    );
  });

  test(
      'finds the file of lib/ of the app that an import names, also by a '
      'relative path from a file of app tests, which goes into the app at '
      'its path in their directory', () {
    expect(
      appFileOf('test/a_test.dart', 'package:{{app_name}}/a.dart'),
      'lib/a.dart',
    );
    expect(appFileOf('lib/own.dart', 'app.dart'), 'lib/app.dart');
    expect(appFileOf('lib/src/own.dart', '../app.dart'), 'lib/app.dart');
    expect(appFileOf('test/a_test.dart', '../lib/app.dart'), 'lib/app.dart');
    // Files of the app outside lib/, and the files of other packages.
    for (final (file, uri) in [
      ('test/a_test.dart', 'helper.dart'),
      ('lib/own.dart', '../test/helper.dart'),
      ('test/a_test.dart', '../../../lib/app.dart'),
      ('lib/own.dart', 'package:flutter/widgets.dart'),
      ('lib/own.dart', 'dart:io'),
    ]) {
      expect(appFileOf(file, uri), isNull, reason: '$uri in $file');
    }
  });

  test('maps the paths of the files of bricks to the paths in the app', () {
    final plain = brickFilePattern('lib/core/a.dart');
    expect(plain.hasMatch('lib/core/a.dart'), isTrue);
    expect(plain.hasMatch('lib/core/a_dart'), isFalse);
    final variable =
        brickFilePattern('lib/features/{{name.snakeCase()}}/x.dart');
    expect(variable.hasMatch('lib/features/home/x.dart'), isTrue);
    expect(variable.hasMatch('lib/features/a/b/x.dart'), isFalse);
    final section =
        brickFilePattern('lib/{{#has_router}}routed.dart{{/has_router}}');
    expect(section.hasMatch('lib/routed.dart'), isTrue);
    expect(
      brickFilePattern('lib/{{^has_router}}{{{name}}}.dart{{/has_router}}')
          .hasMatch('lib/home.dart'),
      isTrue,
    );
  });

  test('finds the files that the roles of smf_contracts guarantee', () {
    final guaranteed = _roleFiles();

    expect(guaranteed, containsPair(AppEntryRole.mainFile, '$appEntryRole'));
    expect(
      guaranteed,
      containsPair(RouterRole.navigationFile, '$routerRole'),
    );
    expect(
      guaranteed,
      containsPair(DiRole.serviceLocatorFile, '$diRole'),
    );
  });

  test(
      'the app tests of the packages of the workspace import only the files '
      'of the app that roles guarantee or that the modules their package '
      'knows generate', () {
    final root = repositoryRoot();

    expect(problemsOf(root, workspacePackages(root), _roleFiles()), isEmpty);
  });

  test(
      'no package of fixture modules depends on a published package of '
      'modules, so the app tests of a package of no module know only '
      'fixture modules', () {
    final packages = workspacePackages(repositoryRoot());
    final byName = {for (final package in packages) package.name: package};
    List<String> published(WorkspacePackage package) => [
          for (final module in knownModules(package, byName))
            if (module.published) module.name,
        ];
    final fixtures = [
      for (final package in packages)
        if (package.declaresModules && !package.published) package,
    ];

    expect(fixtures, isNotEmpty);
    for (final fixture in fixtures) {
      expect(
        published(fixture),
        isEmpty,
        reason: '${fixture.name}, a package of fixture modules, depends on '
            'a published package of modules, itself or through another '
            'fixture. The app tests of a package that depends on it, such '
            'as the fixture registry, may then import the files of that '
            'module, and its matrix tool may select apps by the id of the '
            'module, though an app can have another provider of its role.',
      );
    }
    // So the app tests of a package that declares no module know none.
    for (final package in packages) {
      if (package.declaresModules) continue;
      expect(published(package), isEmpty, reason: package.name);
    }
  });
}
