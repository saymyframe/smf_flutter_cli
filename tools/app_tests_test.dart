// Checks the tests that packages keep for the apps of the matrix in
// `app_tests/`, and the matrix tools that register them. Each tool runs
// once, with `--app-tests --json`, which reports its MatrixAppTests, for
// all the checks.
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
// The app tests that a package of modules keeps apply only to the apps
// that have one of its modules. They test those modules, and the apps of
// the matrix of today may all have them, as every app has the app entry of
// flutter_core: a check of the start of every app that flutter_core kept
// and that applied to every app would reach no app with another provider
// of the app entry, and one that imports what only flutter_core generates
// would not even compile there. So each tool reports, for each of its
// tests that a package of modules keeps, the modules of that package in
// its matrix and the apps of the matrix that the test applies to once they
// are taken out of their modules; there must be such modules, and no such
// app. The app tests of a package of no module, such as the start check of
// the CLI, may apply to every app. The tool knows the modules of each
// package exactly, by their classes, and the check takes them from it: a
// package of modules that `declaresModule` of workspace.dart takes for a
// package of no module, whose app tests the other checks would then read
// as those of a package of no module, is a problem too.
//
// A tool selects the apps of a test, fills the values of its files and
// generates files for it only by the roles of the app (`MatrixApp.hook`)
// and by the ids of the modules that the test knows: the modules of the
// package that keeps it and of the packages of modules it depends on, or,
// for the fixture registry, those of the fixture modules it depends on,
// whose files the test may import (`knownModules`). What a test needs of
// the other modules of an app comes from its roles: the tool of the CLI
// once filled the start screen of the screen views test with `home.home`
// when the app had the module home, which a second feature with a start
// screen, or `--start`, would make wrong, while the router role knows the
// screen that the app starts on. Each tool reports the modules whose ids
// it uses for each test: those that, with another id in their place in an
// app of the matrix, change whether the test applies to the app, the
// values of its files there or the files it generates there. So a use of
// an id counts however the tool writes it: as a string, a `ModuleId`, the
// id of the class of a module or a lookup of the modules by their ids. A
// test of what only one provider of a role does, such as the refresh of
// go_router, selects the apps of that provider by its id: those tests are
// the only exceptions, which _ofOneProvider lists. And the code
// that registers the app tests of a tool, the tool and the library of its
// package that `matrixTools` names, imports, of the packages of the
// workspace, only the packages of the modules whose app tests it registers,
// for their ids and the directories of their app tests, and the packages
// that it needs besides, which declare no module (_needed).
//
// An app test of a module runs in every app with its module, whatever else
// the app has. A role that an app can have several providers of, such as
// crash reporting, generates functions that reach all of them, such as
// createCrashReporter(), whose reporter reports to every provider, and
// what the other providers do is known only to their own tests. So an app
// test calls no such function: a test of a provider uses the
// implementation of its own module instead, such as
// createCrashlyticsCrashReporter(). Only a test of the contract of such a
// role calls them, since what the role does with every provider is its
// contract: it names the role in its MatrixAppTest.roles, a package of no
// module keeps it, such as the fixture registry, and it looks only at what
// reaches the providers that its package knows, such as the fixture
// providers of the role. Each tool reports the calls of such functions in
// each of its app tests, with their roles and the functions of the roles
// of the modules of its matrix, so the app tests of every registry are
// checked with the providers that their apps can have.
import 'dart:io';

import 'package:test/test.dart';

import 'workspace.dart';

/// The problems of the tests of the apps in the repository at [root], whose
/// packages are at the paths [packages] from it: a directory of app tests
/// that no tool of [listed] lists, a file right in `app_tests`, which is in
/// no directory of app tests, and a directory that a tool lists but that
/// does not exist or is not a directory of app tests. [listed] holds the
/// directories of the MatrixAppTests of each matrix tool, by the path of
/// the tool, whose library that registers them [matrixTools] names.
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
  // Where a directory of app tests gets its MatrixAppTest: the library
  // that registers the app tests of a tool.
  final registrations = [
    for (final tool in listed.keys) matrixTools[tool] ?? tool,
  ].join(' or ');
  return [
    ...unlisted.map(
      (path) => '${directories[path]}: no matrix tool lists this directory '
          'of app tests, so its tests never run. Add a MatrixAppTest for it '
          'to $registrations.',
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
  // The matrix (runMatrix, MatrixAppTest and the directories of app tests),
  // the modules that `smf create` offers, which the tool of the CLI
  // generates its apps from, and the app tests that it registers
  // (smfAppTests), with the start check.
  'smf_flutter_cli',
  // The modules of the fixtures, which the tool of the fixtures generates
  // its apps from, and the app tests that it registers (fixtureAppTests).
  'fixture_registry',
};

/// The problems of the file at [tool] of the repository, a matrix tool or
/// the library that registers its app tests, whose code imports the
/// packages [imported] and which registers the app tests of the packages
/// [registered], among the [packages] of the workspace: one line for each
/// package of modules that it imports and whose app tests it does not
/// register, and for each other package of the workspace that it imports
/// and that is not among [needed].
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
) =>
    {
      for (final directory in directories)
        if (_keeperOf(root, packages, directory) case final package?)
          package.name,
    };

/// The package among the [packages] of the workspace at [root] whose
/// `app_tests` holds [directory], or `null` if none does or [directory]
/// does not exist, which [problemsOf] finds.
WorkspacePackage? _keeperOf(
  String root,
  List<WorkspacePackage> packages,
  String directory,
) {
  String real(String path) =>
      Directory(path).resolveSymbolicLinksSync().replaceAll(r'\', '/');
  if (!Directory(directory).existsSync()) return null;
  final path = real(directory);
  for (final package in packages) {
    final appTests = Directory('$root/${package.path}/app_tests');
    if (appTests.existsSync() && path.startsWith('${real(appTests.path)}/')) {
      return package;
    }
  }
  return null;
}

/// The problems of the MatrixAppTests of the matrix tools, [listed] by the
/// path of each tool, that a package of modules among the [packages] of the
/// workspace at [root] keeps: one line for each such test that applies to
/// apps of the matrix without the modules of its package, and for each
/// such test whose tool has none of the modules of its package.
///
/// The tool knows the modules of the package that keeps each test
/// (ListedAppTest.modules), so a test with modules is a test of a package
/// of modules, whatever WorkspacePackage.declaresModules says; a package
/// that declares modules by the tool but not by it is a problem too.
List<String> moduleProblemsOf(
  String root,
  List<WorkspacePackage> packages,
  Map<String, List<ListedAppTest>> listed,
) {
  final problems = <String>[];
  for (final MapEntry(key: tool, value: tests) in listed.entries) {
    for (final test in tests) {
      final package = _keeperOf(root, packages, test.directory);
      if (package == null) continue;
      final name = test.directory.replaceAll(r'\', '/').split('/').last;
      final directory = '${package.path}/app_tests/$name';
      if (test.modules.isNotEmpty && !package.declaresModules) {
        problems.add(
          '$tool finds the modules ${test.modules.join(', ')} of '
          '${package.name}, which keeps $directory, but tools/workspace.dart '
          'sees no class in its lib/ that extends SmfModule (declaresModule), '
          'so the checks that read the packages of the workspace take '
          '${package.name} for a package of no module. Make declaresModule '
          'see how ${package.name} declares its modules.',
        );
      }
      if (test.modules.isEmpty && package.declaresModules) {
        problems.add(
          '$tool registers $directory, which ${package.name} keeps, but the '
          'matrix of the tool has no module of ${package.name}, so its tests '
          'run in apps without the modules they test. Register it in the '
          'matrix tool of a registry of those modules.',
        );
      } else if (test.appliesWithout.isNotEmpty) {
        problems.add(
          '$tool registers $directory, which ${package.name} keeps, for apps '
          'without the modules of ${package.name} '
          '(${test.modules.join(', ')}): with other modules in their place, '
          'it would apply to these apps of the matrix: '
          '${test.appliesWithout.join(', ')}. Its tests test those modules, '
          'so they apply only to the apps that have one of them: make its '
          'appliesTo require them, or keep tests for every app in a package '
          'of no module, as the CLI keeps its start check.',
        );
      }
    }
  }
  return problems;
}

/// The problems of the MatrixAppTests of the matrix tools, [listed] by the
/// path of each tool, among the [packages] of the workspace at [root]: one
/// line for each use, in the files of a test, of a function of a role that
/// an app can have several providers of, which the tool reports, but for
/// the uses in a test of the contract of that role that a package of no
/// module keeps; and one for each test whose uses the tool does not
/// report.
///
/// A test of the role names it in its roles (ListedAppTest.roles). A test
/// that a package of modules keeps, which the tool knows by the modules of
/// that package (ListedAppTest.modules) whatever
/// WorkspacePackage.declaresModules says, tests those modules, even when it
/// names the role.
List<String> roleFunctionProblemsOf(
  String root,
  List<WorkspacePackage> packages,
  Map<String, List<ListedAppTest>> listed,
) {
  final problems = <String>[];
  for (final MapEntry(key: tool, value: tests) in listed.entries) {
    for (final test in tests) {
      final uses = test.roleFunctionUses;
      if (uses == null) {
        problems.add(
          '$tool reports no uses of the functions of roles in the app tests '
          'of ${test.directory}, so nothing checks that they call none of a '
          'role that an app can have several providers of.',
        );
        continue;
      }
      final keeper = _keeperOf(root, packages, test.directory);
      final ofNoModule =
          keeper != null && !keeper.declaresModules && test.modules.isEmpty;
      for (final use in uses) {
        if (ofNoModule && test.roles.contains(use.role)) continue;
        problems.add(
          '${test.directory}/${use.use}: the function reaches every provider '
          'of its role, ${use.role}, and only the tests of each provider know '
          'what it does. Only a test of the contract of the role calls it: '
          'its MatrixAppTest names the role in its roles, a package of no '
          'module keeps it, such as the fixture registry, and it looks only '
          'at what reaches the providers that its package knows. A test of a '
          'provider uses the implementation of its own module instead, such '
          'as createCrashlyticsCrashReporter().',
        );
      }
    }
  }
  return problems;
}

/// The app tests of what only one provider of a role does, which select
/// the apps of that provider by its id, by their directories from the root
/// of the repository, each with the ids of the modules that its tool may
/// use for it besides those that it knows. Every other test selects its
/// apps by their roles and by the modules it knows.
const _ofOneProvider = {
  // The notifications of the delegate of go_router that leave the page on
  // top as it is, which the listeners of the screen do not hear of, and
  // push() after a refresh of its routes.
  'packages/smf_pipeline/fixture_registry/app_tests/go_router_screens': {
    'go_router',
  },
  // The new route that the router of go_router gives it for the main
  // navigation each time the main navigation leaves its pages, since
  // go_router keeps the pages of the branches with the route.
  'packages/smf_pipeline/fixture_registry/app_tests/go_router_branches': {
    'go_router',
  },
  // A refresh of the routes of go_router while the flow of a condition is
  // open, and a request before go_router has a page.
  'packages/smf_pipeline/fixture_registry/app_tests/go_router_conditions': {
    'go_router',
  },
  // A tap on a tab of the bar of bottom_tabs, which selects its
  // destination.
  'packages/smf_pipeline/fixture_registry/app_tests/bottom_tabs_screens': {
    'bottom_tabs',
  },
};

/// The problems of the ids of modules that the matrix tools, [listed] by
/// the path of each tool, use for their MatrixAppTests among the
/// [packages] of the workspace at [root]: one line for each module whose id
/// a tool uses for a test that does not know the module (knownModules) and
/// that [ofOneProvider] does not let it use, and one for each id of
/// [ofOneProvider] that no tool uses for its test.
List<String> usesProblemsOf(
  String root,
  List<WorkspacePackage> packages,
  Map<String, List<ListedAppTest>> listed, {
  Map<String, Set<String>> ofOneProvider = _ofOneProvider,
}) {
  final byName = {for (final package in packages) package.name: package};
  final unused = {
    for (final MapEntry(key: directory, value: ids) in ofOneProvider.entries)
      for (final id in ids) (directory, id),
  };
  final problems = <String>[];
  for (final MapEntry(key: tool, value: tests) in listed.entries) {
    for (final test in tests) {
      final package = _keeperOf(root, packages, test.directory);
      if (package == null) continue;
      final name = test.directory.replaceAll(r'\', '/').split('/').last;
      final directory = '${package.path}/app_tests/$name';
      final known = [
        for (final module in knownModules(package, byName)) module.name,
      ];
      final allowed = ofOneProvider[directory] ?? const {};
      for (final use in test.uses) {
        if (allowed.contains(use.module)) {
          unused.remove((directory, use.module));
        } else if (!test.modules.contains(use.module) &&
            !known.contains(use.package)) {
          problems.add(
            '$tool selects the apps of $directory, fills the values of its '
            'files or generates files by the id of ${use.module}, a module of '
            '${use.package} that its tests do not know: with another module in '
            'its place, they would apply otherwise, or get other values or '
            'files, in these apps of the matrix: ${use.apps.join(', ')}. What '
            'they need of the '
            'other modules of an app comes from the roles of the app '
            '(MatrixApp.hook), such as whether it has a router (presentRoles) '
            'or the screen it starts on. The tests of ${package.name} know '
            'the modules of ${known.isEmpty ? 'no package' : known.join(', ')}'
            '; a test of what only one provider of a role does names the '
            'provider in _ofOneProvider of tools/app_tests_test.dart.',
          );
        }
      }
    }
  }
  return [
    ...problems,
    for (final (directory, id) in unused) _unusedException(directory, id),
  ];
}

/// The problem that [_ofOneProvider] lets the tool of the app tests in
/// [directory] use the id [id], which no tool uses for them.
String _unusedException(String directory, String id) =>
    'tools/app_tests_test.dart lets the tool of $directory use the id of $id '
    '(_ofOneProvider), but no tool uses it for that test: remove it from '
    '_ofOneProvider.';

/// The MatrixAppTests of each matrix tool of the repository, by the path of
/// the tool. Each tool runs once for all the tests of this file.
final Future<Map<String, List<ListedAppTest>>> _listed = () async {
  final root = repositoryRoot();
  final tools = matrixTools.keys.toList();
  final listed = await Future.wait(
    [for (final tool in tools) appTestsListedBy(root, tool)],
  );
  return {for (final (index, tool) in tools.indexed) tool: listed[index]};
}();

/// The directories of the MatrixAppTests of each tool of [listed].
Map<String, List<String>> _directoriesOf(
  Map<String, List<ListedAppTest>> listed,
) =>
    {
      for (final MapEntry(key: tool, value: tests) in listed.entries)
        tool: [for (final test in tests) test.directory],
    };

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
      'finds the app tests of packages of modules that apply to apps without '
      'their modules, or whose tool has none of them, and the packages of '
      'modules that declaresModule misses', () {
    final temp = Directory.systemTemp.createTempSync('smf_app_test_modules_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final root = temp.path;
    for (final path in [
      'modules/app_tests/with_them',
      'modules/app_tests/everywhere',
      'modules/app_tests/elsewhere',
      'registry/app_tests/start',
      'aliased/app_tests/everywhere',
    ]) {
      Directory('$root/$path').createSync(recursive: true);
    }
    const packages = [
      WorkspacePackage(
        'modules',
        name: 'modules',
        dependencies: {},
        published: true,
        declaresModules: true,
      ),
      WorkspacePackage(
        'registry',
        name: 'registry',
        dependencies: {'modules'},
        published: true,
        declaresModules: false,
      ),
      // A package whose module class extends SmfModule through another
      // class, or is a class alias, which declaresModule does not see.
      WorkspacePackage(
        'aliased',
        name: 'aliased',
        dependencies: {},
        published: true,
        declaresModules: false,
      ),
    ];
    final listed = {
      'tool/matrix.dart': [
        ListedAppTest('$root/modules/app_tests/with_them', modules: ['a']),
        ListedAppTest(
          '$root/modules/app_tests/everywhere',
          modules: ['a', 'b'],
          appliesWithout: ['every module', 'a without b'],
        ),
        ListedAppTest('$root/modules/app_tests/elsewhere'),
        ListedAppTest('$root/registry/app_tests/start'),
        ListedAppTest(
          '$root/aliased/app_tests/everywhere',
          modules: ['c'],
          appliesWithout: ['every module'],
        ),
      ],
    };
    const everywhere = 'tool/matrix.dart registers '
        'modules/app_tests/everywhere, which modules keeps, for apps without '
        'the modules of modules (a, b): with other modules in their place, it '
        'would apply to these apps of the matrix: every module, a without b. '
        'Its tests test those modules, so they apply only to the apps that '
        'have one of them: make its appliesTo require them, or keep tests for '
        'every app in a package of no module, as the CLI keeps its start '
        'check.';
    const elsewhere = 'tool/matrix.dart registers '
        'modules/app_tests/elsewhere, which modules keeps, but the matrix of '
        'the tool has no module of modules, so its tests run in apps without '
        'the modules they test. Register it in the matrix tool of a registry '
        'of those modules.';
    const missed = 'tool/matrix.dart finds the modules c of aliased, which '
        'keeps aliased/app_tests/everywhere, but tools/workspace.dart sees no '
        'class in its lib/ that extends SmfModule (declaresModule), so the '
        'checks that read the packages of the workspace take aliased for a '
        'package of no module. Make declaresModule see how aliased declares '
        'its modules.';
    const aliasedEverywhere = 'tool/matrix.dart registers '
        'aliased/app_tests/everywhere, which aliased keeps, for apps without '
        'the modules of aliased (c): with other modules in their place, it '
        'would apply to these apps of the matrix: every module. Its tests '
        'test those modules, so they apply only to the apps that have one of '
        'them: make its appliesTo require them, or keep tests for every app '
        'in a package of no module, as the CLI keeps its start check.';

    expect(moduleProblemsOf(root, packages, listed), [
      everywhere,
      elsewhere,
      missed,
      aliasedEverywhere,
    ]);
  });

  test(
      'finds the ids of modules that a tool uses for an app test that does '
      'not know them, but for the tests of one provider, and the ids that '
      'those may use and do not', () {
    final temp = Directory.systemTemp.createTempSync('smf_app_test_uses_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final root = temp.path;
    for (final path in [
      'analytics/app_tests/screens',
      'cli/app_tests/start',
      'registry/app_tests/screens',
      'registry/app_tests/of_router',
    ]) {
      Directory('$root/$path').createSync(recursive: true);
    }
    WorkspacePackage package(
      String name, {
      Set<String> dependencies = const {},
      bool published = true,
      bool declaresModules = true,
    }) =>
        WorkspacePackage(
          name,
          name: name,
          dependencies: dependencies,
          published: published,
          declaresModules: declaresModules,
        );
    final packages = [
      package('core'),
      package('analytics', dependencies: {'core'}),
      package('home'),
      package('router'),
      // A package of no module that depends on published modules, as the
      // CLI does, and a registry of fixture modules.
      package(
        'cli',
        dependencies: {'core', 'analytics', 'home'},
        declaresModules: false,
      ),
      package('fixture', published: false),
      package(
        'registry',
        dependencies: {'fixture', 'router'},
        published: false,
        declaresModules: false,
      ),
    ];
    UsedModule use(String module, String package) =>
        UsedModule(module, package: package, apps: ['every module']);
    final listed = {
      'tool/matrix.dart': [
        // Its own module, a module that it depends on, and home.
        ListedAppTest(
          '$root/analytics/app_tests/screens',
          modules: ['analytics'],
          uses: [
            use('analytics', 'analytics'),
            use('core', 'core'),
            use('home', 'home'),
          ],
        ),
        // A module of a package of the dependencies of a package of no
        // module, which is published.
        ListedAppTest(
          '$root/cli/app_tests/start',
          uses: [use('core', 'core')],
        ),
        // A fixture module, and a provider of a role.
        ListedAppTest(
          '$root/registry/app_tests/screens',
          uses: [use('fake', 'fixture'), use('router', 'router')],
        ),
        // A test of what only the router does.
        ListedAppTest(
          '$root/registry/app_tests/of_router',
          uses: [use('fake', 'fixture'), use('router', 'router')],
        ),
      ],
    };
    // The problem of a use of the id of the module of the package of the
    // same name.
    String problem(String directory, String module, String known) =>
        'tool/matrix.dart selects the apps of $directory, fills the values of '
        'its files or generates files by the id of $module, a module of '
        '$module that its tests do not know: with another module in its '
        'place, they would apply otherwise, or get other values or files, in '
        'these apps of the matrix: every module. What they need of the other '
        'modules of an app comes '
        'from the roles of the app (MatrixApp.hook), such as whether it has a '
        'router (presentRoles) or the screen it starts on. $known; a test of '
        'what only one provider of a role does names the provider in '
        '_ofOneProvider of tools/app_tests_test.dart.';

    const unused = 'tools/app_tests_test.dart lets the tool of '
        'registry/app_tests/screens use the id of home (_ofOneProvider), but '
        'no tool uses it for that test: remove it from _ofOneProvider.';

    expect(
      usesProblemsOf(
        root,
        packages,
        listed,
        ofOneProvider: {
          'registry/app_tests/of_router': {'router'},
          'registry/app_tests/screens': {'home'},
        },
      ),
      [
        problem(
          'analytics/app_tests/screens',
          'home',
          'The tests of analytics know the modules of analytics, core',
        ),
        problem(
          'cli/app_tests/start',
          'core',
          'The tests of cli know the modules of no package',
        ),
        problem(
          'registry/app_tests/screens',
          'router',
          'The tests of registry know the modules of fixture',
        ),
        unused,
      ],
    );
  });

  test(
      'finds the uses of the functions of roles that a tool reports in its '
      'app tests, but those of a test of the role that a package of no module '
      'keeps, and the app tests whose uses it does not report', () {
    final temp = Directory.systemTemp.createTempSync('smf_role_functions_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final root = temp.path;
    for (final path in [
      'crashlytics/app_tests/crashlytics',
      'crashlytics/app_tests/of_role',
      'aliased/app_tests/of_role',
      'registry/app_tests/clean',
      'registry/app_tests/of_role',
      'registry/app_tests/of_other_role',
      'registry/app_tests/unknown',
    ]) {
      Directory('$root/$path').createSync(recursive: true);
    }
    WorkspacePackage package(String name, {required bool declaresModules}) =>
        WorkspacePackage(
          name,
          name: name,
          dependencies: const {},
          published: declaresModules,
          declaresModules: declaresModules,
        );
    final packages = [
      package('crashlytics', declaresModules: true),
      // A package whose modules declaresModule does not see, which the tool
      // knows.
      package('aliased', declaresModules: false),
      package('registry', declaresModules: false),
    ];
    const use = RoleFunctionUse(
      'test/a_test.dart: createCrashReporter() of '
      'lib/core/crash_reporting/crash_reporter.dart',
      role: 'crash_reporting',
    );
    final listed = {
      'tool/matrix.dart': [
        // A test of a provider, and one of the role, that a package of
        // modules keeps.
        ListedAppTest(
          '$root/crashlytics/app_tests/crashlytics',
          modules: ['crashlytics'],
          roleFunctionUses: [use],
        ),
        ListedAppTest(
          '$root/crashlytics/app_tests/of_role',
          modules: ['crashlytics'],
          roles: ['crash_reporting'],
          roleFunctionUses: [use],
        ),
        ListedAppTest(
          '$root/aliased/app_tests/of_role',
          modules: ['aliased'],
          roles: ['crash_reporting'],
          roleFunctionUses: [use],
        ),
        // Tests that a package of no module keeps: without uses, of the
        // role, of another role, and one whose uses the tool does not
        // report.
        ListedAppTest('$root/registry/app_tests/clean', roleFunctionUses: []),
        ListedAppTest(
          '$root/registry/app_tests/of_role',
          roles: ['analytics', 'crash_reporting'],
          roleFunctionUses: [use],
        ),
        ListedAppTest(
          '$root/registry/app_tests/of_other_role',
          roles: ['analytics'],
          roleFunctionUses: [use],
        ),
        ListedAppTest('$root/registry/app_tests/unknown'),
      ],
    };
    String problem(String directory) =>
        '$root/$directory/${use.use}: the function reaches every provider '
        'of its role, crash_reporting, and only the tests of each provider '
        'know what it does. Only a test of the contract of the role calls '
        'it: its MatrixAppTest names the role in its roles, a package of no '
        'module keeps it, such as the fixture registry, and it looks only at '
        'what reaches the providers that its package knows. A test of a '
        'provider uses the implementation of its own module instead, such as '
        'createCrashlyticsCrashReporter().';
    final unknown = 'tool/matrix.dart reports no uses of the functions of '
        'roles in the app tests of $root/registry/app_tests/unknown, so '
        'nothing checks that they call none of a role that an app can have '
        'several providers of.';

    expect(roleFunctionProblemsOf(root, packages, listed), [
      problem('crashlytics/app_tests/crashlytics'),
      problem('crashlytics/app_tests/of_role'),
      problem('aliased/app_tests/of_role'),
      problem('registry/app_tests/of_other_role'),
      unknown,
    ]);
  });

  test(
    'every directory of app tests in the packages of the workspace is the '
    'directory of a MatrixAppTest of a matrix tool, and every directory '
    'that a tool lists is one',
    () async {
      final root = repositoryRoot();

      expect(
        problemsOf(
          root,
          [for (final package in workspacePackages(root)) package.path],
          _directoriesOf(await _listed),
        ),
        isEmpty,
      );
    },
    // Each tool loads the modules of its matrix first, which takes a while
    // on the runners of CI.
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'the matrix tools, and the libraries that register their app tests, '
    'import, of the packages of modules, only those whose app tests they '
    'register',
    () async {
      final root = repositoryRoot();
      final packages = workspacePackages(root);
      final listed = _directoriesOf(await _listed);

      expect(
        [
          for (final MapEntry(key: tool, value: directories) in listed.entries)
            for (final file in [tool, matrixTools[tool]!])
              if (!File('$root/$file').existsSync())
                '$file, which matrixTools names for $tool, does not exist.'
              else
                ...importProblemsOf(
                  file,
                  packagesUsedBy('$root/$file'),
                  _packagesOf(root, packages, directories),
                  packages,
                ),
        ],
        isEmpty,
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'the matrix tools select the apps of their tests, fill the values of '
    'their files and generate files for them by the roles of the apps and by '
    'the modules that the tests know',
    () async {
      final root = repositoryRoot();

      expect(
        usesProblemsOf(root, workspacePackages(root), await _listed),
        isEmpty,
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'the app tests that packages of modules keep apply only to the apps '
    'with their modules',
    () async {
      final root = repositoryRoot();

      expect(
        moduleProblemsOf(root, workspacePackages(root), await _listed),
        isEmpty,
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'the app tests of every matrix tool call no function of a role that an '
    'app can have several providers of, but the tests of the role that a '
    'package of no module keeps',
    () async {
      final root = repositoryRoot();

      expect(
        roleFunctionProblemsOf(root, workspacePackages(root), await _listed),
        isEmpty,
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
