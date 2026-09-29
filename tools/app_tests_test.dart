// Checks the tests that packages keep for the apps of the matrix in
// `app_tests/`, and the matrix tools that register them. Each tool runs
// once, with `--app-tests`, which prints the directories of its
// MatrixAppTests, for all the checks.
//
// The tests of each directory of app tests run in CI. The matrix tools
// copy the files of a directory of app tests into the apps they generate
// only when the directory is the directory of one of their MatrixAppTests,
// so the tests of a directory that no tool lists would never run, and no
// other check would say so. A directory of app tests is a directory right
// in the `app_tests` of a package of the workspace; each is the directory
// of one MatrixAppTest. Hidden files and directories, whose names start
// with `.`, stay out, as they stay out of the apps.
//
// A matrix tool knows only the modules whose app tests it registers. A
// value or a selection of the app tests of a module, such as the screen
// that an app with Firebase Analytics starts on, depends on the other
// modules of the app only through its roles, so the tool takes it from the
// roles of the app (`MatrixApp.hook`), not from whether the app has some
// module: the tool of the CLI once filled the start screen of the screen
// views test with `home.home` when the app had the module home, which a
// second feature with a start screen, or `--start`, would make wrong. So a
// matrix tool imports, of the packages of the workspace, only the packages
// of the modules whose app tests it registers, for their ids and the
// directories of their app tests, and the packages that it needs besides,
// which declare no module (_needed). It may use the modules of the matrix
// only through the roles they declare, as the tool of the CLI finds the
// apps with a router among the modules of `smf create`.
import 'dart:io';

import 'package:test/test.dart';

import 'workspace.dart';

/// The problems of the tests of the apps in the repository at [root], whose
/// packages are at the paths [packages] from it: a directory of app tests
/// that no tool of [listed] lists, a file right in `app_tests`, which is in
/// no directory of app tests, and a directory that a tool lists but that
/// does not exist or is not a directory of app tests. [listed] holds the
/// directories of the MatrixAppTests of each matrix tool, by the path of
/// the tool.
List<String> problemsOf(
  String root,
  List<String> packages,
  Map<String, List<String>> listed,
) {
  // The directories of app tests by their real path, which the paths that
  // the tools print resolve to, whatever their separators, and their paths
  // from the root.
  final directories = <String, String>{};
  final files = <String>[];
  for (final package in packages) {
    final appTests = Directory('$root/$package/app_tests');
    if (!appTests.existsSync()) continue;
    final entities = appTests.listSync()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final entity in entities) {
      final name = entity.path.split(RegExp(r'[/\\]')).last;
      if (name.startsWith('.')) continue;
      if (entity is Directory) {
        directories[entity.resolveSymbolicLinksSync()] =
            '$package/app_tests/$name';
      } else {
        files.add(
          '$package/app_tests/$name: this file is in no directory of app '
          'tests, so no matrix tool copies it into an app.',
        );
      }
    }
  }
  final unlisted = {...directories.keys};
  final wrong = <String>[];
  for (final MapEntry(key: tool, value: paths) in listed.entries) {
    for (final path in paths) {
      final directory = Directory(path);
      if (!directory.existsSync()) {
        wrong.add('$tool lists $path, which does not exist.');
        continue;
      }
      final real = directory.resolveSymbolicLinksSync();
      if (directories.containsKey(real)) {
        unlisted.remove(real);
      } else {
        wrong.add(
          '$tool lists $path, which is not a directory right in the '
          'app_tests of a package of the workspace.',
        );
      }
    }
  }
  return [
    ...unlisted.map(
      (path) => '${directories[path]}: no matrix tool lists this directory '
          'of app tests, so its tests never run. Add a MatrixAppTest for it '
          'to ${listed.keys.join(' or ')}.',
    ),
    ...files,
    ...wrong,
  ];
}

/// The packages of the workspace that declare no module and that the
/// matrix tools need.
const _needed = {
  // The module model: the roles, whose data and choices in an app give the
  // values and the selections of the app tests, and the ids of modules.
  'smf_contracts',
  // The pipeline, for the app that --add-app-tests adds app tests to.
  'smf_pipeline',
  // The matrix (runMatrix and MatrixAppTest), and the modules that
  // `smf create` offers, which the tool of the CLI generates its apps from,
  // and the directory of the start check.
  'smf_flutter_cli',
  // The modules of the fixtures, which the tool of the fixtures generates
  // its apps from, and the directory of its app tests.
  'fixture_registry',
};

/// The problems of the matrix tool at [tool] of the repository, whose code
/// imports the packages [imported] and which registers the app tests of the
/// packages [registered], among the [packages] of the workspace: one line
/// for each package of modules that it imports and whose app tests it does
/// not register, and for each other package of the workspace that it
/// imports and that is not among [needed].
List<String> importProblemsOf(
  String tool,
  Set<String> imported,
  Set<String> registered,
  List<WorkspacePackage> packages, {
  Set<String> needed = _needed,
}) {
  final modules = {
    for (final package in packages)
      if (package.declaresModules) package.name,
  };
  final workspace = {for (final package in packages) package.name};
  final allowed = registered.intersection(modules).toList()..sort();
  final problems = <String>[];
  for (final package in imported.toList()..sort()) {
    if (modules.contains(package)) {
      if (registered.contains(package)) continue;
      problems.add(
        '$tool imports $package, a package of modules whose app tests it '
        'does not register. A value or a selection of the app tests it '
        'registers comes from the roles of the app (MatrixApp.hook), not '
        'from whether the app has a module of $package. It may import, of '
        'the packages of modules, only those whose app tests it registers: '
        '${allowed.isEmpty ? 'none' : allowed.join(', ')}.',
      );
    } else if (workspace.contains(package) && !needed.contains(package)) {
      problems.add(
        '$tool imports $package, a package of the workspace that the matrix '
        'tools do not need. If the tool needs it, add it to _needed in '
        'tools/app_tests_test.dart, with what for.',
      );
    }
  }
  return problems;
}

/// The packages that the Dart file at [path] imports, exports or includes,
/// and that the files it uses by a relative path do in turn.
Set<String> packagesUsedBy(String path) {
  final packages = <String>{};
  final visited = <Uri>{};
  void visit(Uri file) {
    if (!visited.add(file)) return;
    for (final uri in urisOf(File.fromUri(file).readAsStringSync())) {
      if (uri.startsWith('package:')) {
        packages.add(uri.substring('package:'.length).split('/').first);
      } else if (!uri.contains(':')) {
        visit(file.resolve(uri));
      }
    }
  }

  visit(Uri.file(path));
  return packages;
}

/// The names of the [packages] of the workspace at [root] with the
/// [directories] of app tests in their `app_tests`.
Set<String> _packagesOf(
  String root,
  List<WorkspacePackage> packages,
  List<String> directories,
) {
  String real(String path) =>
      Directory(path).resolveSymbolicLinksSync().replaceAll(r'\', '/');
  final appTests = {
    for (final package in packages)
      if (Directory('$root/${package.path}/app_tests').existsSync())
        '${real('$root/${package.path}/app_tests')}/': package.name,
  };
  return {
    for (final directory in directories)
      // A directory that does not exist is a problem of
      // tools/app_tests_test.dart.
      if (Directory(directory).existsSync())
        for (final MapEntry(key: path, value: name) in appTests.entries)
          if (real(directory).startsWith(path)) name,
  };
}

/// The paths of the packages of the workspace at [root] from it.
List<String> _workspacePackages(String root) {
  final packages = <String>[];
  var inWorkspace = false;
  for (final line in File('$root/pubspec.yaml').readAsLinesSync()) {
    if (RegExp(r'^\S').hasMatch(line)) inWorkspace = line == 'workspace:';
    if (!inWorkspace) continue;
    if (RegExp(r'^  - (\S+)').firstMatch(line) case final match?) {
      packages.add(match[1]!);
    }
  }
  return packages;
}

/// The directories of the MatrixAppTests of each matrix tool of the
/// repository, by the path of the tool. Each tool runs once for all the
/// tests of this file.
final Future<Map<String, List<String>>> _listed = () async {
  final root = repositoryRoot();
  final listed = await Future.wait(
    [for (final tool in matrixTools) appTestsListedBy(root, tool)],
  );
  return {
    for (final (index, tool) in matrixTools.indexed) tool: listed[index],
  };
}();

void main() {
  test(
      'finds the directories of app tests that no tool lists, the files in '
      'no such directory, and the directories that a tool lists that are '
      'none', () {
    final temp = Directory.systemTemp.createTempSync('smf_app_tests_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final root = temp.path;
    for (final path in [
      'a/app_tests/listed/test/listed_test.dart',
      'a/app_tests/twice/test/twice_test.dart',
      'a/app_tests/unlisted/test/unlisted_test.dart',
      'a/app_tests/stray_test.dart',
      'a/app_tests/.hidden/test/hidden_test.dart',
      'a/app_tests/.DS_Store',
      'a/lib/a.dart',
      'b/lib/b.dart',
      'other/app_tests/other/test/other_test.dart',
    ]) {
      File('$root/$path').createSync(recursive: true);
    }

    // Absolute paths, with names joined with `/` as the tools join them,
    // which on Windows follow a path with `\`.
    final listed = {
      'one.dart': ['$root/a/app_tests/listed', '$root/a/app_tests/twice'],
      'two.dart': [
        '$root/a/app_tests/twice',
        '$root/a/app_tests/gone',
        '$root/a/lib',
        '$root/other/app_tests/other',
      ],
    };
    const unlisted = 'a/app_tests/unlisted: no matrix tool lists this '
        'directory of app tests, so its tests never run. Add a MatrixAppTest '
        'for it to one.dart or two.dart.';
    const stray = 'a/app_tests/stray_test.dart: this file is in no '
        'directory of app tests, so no matrix tool copies it into an app.';
    const notOne = 'which is not a directory right in the app_tests of a '
        'package of the workspace.';

    expect(problemsOf(root, ['a', 'b'], listed), [
      unlisted,
      stray,
      'two.dart lists $root/a/app_tests/gone, which does not exist.',
      'two.dart lists $root/a/lib, $notOne',
      'two.dart lists $root/other/app_tests/other, $notOne',
    ]);
  });

  const packages = [
    WorkspacePackage(
      'contracts',
      name: 'contracts',
      dependencies: {},
      published: true,
      declaresModules: false,
    ),
    WorkspacePackage(
      'analytics',
      name: 'analytics',
      dependencies: {'contracts'},
      published: true,
      declaresModules: true,
    ),
    WorkspacePackage(
      'home',
      name: 'home',
      dependencies: {'contracts'},
      published: true,
      declaresModules: true,
    ),
    WorkspacePackage(
      'engine',
      name: 'engine',
      dependencies: {},
      published: true,
      declaresModules: false,
    ),
  ];

  test(
      'finds the packages of modules whose app tests a tool does not '
      'register, and the other packages of the workspace it does not need', () {
    const engine = 'tool/matrix.dart imports engine, a package of the '
        'workspace that the matrix tools do not need. If the tool needs it, '
        'add it to _needed in tools/app_tests_test.dart, with what for.';
    const home = 'tool/matrix.dart imports home, a package of modules whose '
        'app tests it does not register. A value or a selection of the app '
        'tests it registers comes from the roles of the app (MatrixApp.hook), '
        'not from whether the app has a module of home. It may import, of the '
        'packages of modules, only those whose app tests it registers:';

    expect(
      importProblemsOf(
        'tool/matrix.dart',
        {'contracts', 'analytics', 'home', 'engine', 'path'},
        {'analytics'},
        packages,
        needed: {'contracts'},
      ),
      [engine, '$home analytics.'],
    );
    // A package of modules among those that the tools need counts as one.
    expect(
      importProblemsOf(
        'tool/matrix.dart',
        {'home'},
        {},
        packages,
        needed: {'home'},
      ),
      ['$home none.'],
    );
  });

  test(
      'finds the packages that a file uses, through its relative imports '
      'too', () {
    final temp = Directory.systemTemp.createTempSync('smf_matrix_tool_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final files = {
      'tool/matrix.dart': "import 'dart:io';\n"
          "import 'package:a/a.dart';\n"
          "import 'src/values.dart';\n"
          "part 'matrix_part.dart';\n"
          "// import 'package:in_a_comment/x.dart';\n",
      'tool/matrix_part.dart': "part of 'matrix.dart';\n",
      'tool/src/values.dart': "export 'package:b/b.dart';\n"
          "import '../matrix.dart';\n"
          "import 'c.dart' if (dart.library.io) 'package:c/c.dart';\n",
      'tool/src/c.dart': '',
    };
    for (final MapEntry(key: path, value: text) in files.entries) {
      File('${temp.path}/$path')
        ..createSync(recursive: true)
        ..writeAsStringSync(text);
    }

    expect(
      packagesUsedBy('${temp.path}/tool/matrix.dart'),
      {'a', 'b', 'c'},
    );
  });

  test(
    'every directory of app tests in the packages of the workspace is the '
    'directory of a MatrixAppTest of a matrix tool, and every directory '
    'that a tool lists is one',
    () async {
      final root = repositoryRoot();

      expect(
        problemsOf(root, _workspacePackages(root), await _listed),
        isEmpty,
      );
    },
    // Each tool loads the modules of its matrix first, which takes a while
    // on the runners of CI.
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'the matrix tools import, of the packages of modules, only those whose '
    'app tests they register',
    () async {
      final root = repositoryRoot();
      final packages = workspacePackages(root);
      final listed = await _listed;

      expect(
        [
          for (final MapEntry(key: tool, value: directories) in listed.entries)
            ...importProblemsOf(
              tool,
              packagesUsedBy('$root/$tool'),
              _packagesOf(root, packages, directories),
              packages,
            ),
        ],
        isEmpty,
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
