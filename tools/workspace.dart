// The packages of the workspace as the tests of the repository read them:
// their pubspecs, whether they declare modules, the modules that their app
// tests know, and the URIs that their Dart files use; and the matrix tools,
// with the libraries that register their app tests and what they report of
// them. Paths join their names with `/`, on Windows too.
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:yaml/yaml.dart';

import 'workspace_members.dart';

/// The matrix tools, by path from the root of the repository, each with the
/// library of its package that registers its MatrixAppTests, whose code
/// selects the apps of each test and fills the values of its files. Each
/// tool reports its MatrixAppTests with `--app-tests --json`.
const matrixTools = {
  'packages/smf_flutter_cli/tool/matrix.dart':
      'packages/smf_flutter_cli/lib/matrix_app_tests.dart',
  'packages/smf_pipeline/fixture_registry/tool/matrix.dart':
      'packages/smf_pipeline/fixture_registry/lib/matrix_app_tests.dart',
  'packages/smf_pipeline/fixture_registry/tool/several_providers_matrix.dart':
      'packages/smf_pipeline/fixture_registry/lib/matrix_app_tests.dart',
};

/// A MatrixAppTest of a matrix tool, as the tool reports it with
/// `--app-tests --json` (`appTestsReport` of smf_flutter_cli).
final class ListedAppTest {
  /// Describes the MatrixAppTest of the files in [directory].
  const ListedAppTest(
    this.directory, {
    this.modules = const [],
    this.appliesWithout = const [],
    this.uses = const [],
    this.roleFunctionUses,
  });

  /// Reads the report of a MatrixAppTest.
  factory ListedAppTest.fromJson(Map<String, Object?> json) => ListedAppTest(
        json['directory']! as String,
        modules: [...(json['modules']! as List<Object?>).cast<String>()],
        appliesWithout: [
          ...(json['appliesWithout']! as List<Object?>).cast<String>(),
        ],
        uses: [
          for (final use in json['uses']! as List<Object?>)
            UsedModule.fromJson(use! as Map<String, Object?>),
        ],
        roleFunctionUses: switch (json['roleFunctionUses']) {
          final List<Object?> uses => [...uses.cast<String>()],
          _ => null,
        },
      );

  /// The directory of its files, as the tool prints it.
  final String directory;

  /// The ids of the modules of the matrix of the tool that the package
  /// whose `app_tests` holds [directory] declares.
  final List<String> modules;

  /// The names of the apps of the matrix that it applies to once [modules]
  /// are taken out of their modules.
  final List<String> appliesWithout;

  /// The modules of the matrix whose ids the tool uses to select the apps
  /// of the test or to fill the values of its files.
  final List<UsedModule> uses;

  /// The uses, in its files, of the functions of the roles of the modules
  /// of the matrix that an app can have several providers of, such as
  /// `test/a_test.dart: createCrashReporter() of
  /// lib/core/crash_reporting/crash_reporter.dart`, or `null` if the tool
  /// does not report them.
  final List<String>? roleFunctionUses;
}

/// A module whose id a matrix tool uses for a MatrixAppTest: with another
/// id in its place in some apps of the matrix, the test applies to them
/// otherwise, or gets other values of its files there.
final class UsedModule {
  /// Describes the module [module] of the package [package], whose id the
  /// tool uses in the apps [apps].
  const UsedModule(this.module, {required this.package, required this.apps});

  /// Reads the report of a module that a MatrixAppTest uses.
  factory UsedModule.fromJson(Map<String, Object?> json) => UsedModule(
        json['module']! as String,
        package: json['package']! as String,
        apps: [...(json['apps']! as List<Object?>).cast<String>()],
      );

  /// The id of the module.
  final String module;

  /// The package that declares the module.
  final String package;

  /// The names of the apps of the matrix where the tool uses the id.
  final List<String> apps;
}

/// The MatrixAppTests of the matrix [tool] of the repository at [root],
/// which it reports with `--app-tests --json`.
Future<List<ListedAppTest>> appTestsListedBy(String root, String tool) async {
  final packageConfig = await Isolate.packageConfig;
  final result = await Process.run(
    Platform.resolvedExecutable,
    [
      '--packages=${packageConfig!.toFilePath()}',
      tool,
      '--app-tests',
      '--json',
    ],
    workingDirectory: root,
    // The tools write UTF-8, on Windows too.
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (result.exitCode != 0) {
    throw StateError(
      '$tool --app-tests --json: ${result.stdout}${result.stderr}',
    );
  }
  return [
    for (final test in jsonDecode('${result.stdout}') as List<Object?>)
      ListedAppTest.fromJson(test! as Map<String, Object?>),
  ];
}

/// A package of the workspace.
final class WorkspacePackage {
  /// Describes the package [name] at [path] from the root of the
  /// repository.
  const WorkspacePackage(
    this.path, {
    required this.name,
    required this.dependencies,
    required this.published,
    required this.declaresModules,
  });

  /// Reads the package at [path] from the root of the repository at
  /// [root].
  factory WorkspacePackage.read(String root, String path) {
    final pubspec = loadYaml(
      File('$root/$path/pubspec.yaml').readAsStringSync(),
    ) as YamlMap;
    return WorkspacePackage(
      path,
      name: pubspec['name'] as String,
      dependencies: switch (pubspec['dependencies']) {
        final YamlMap packages => {...packages.keys.cast<String>()},
        _ => const {},
      },
      published: pubspec['publish_to'] != 'none',
      declaresModules: dartFilesIn('$root/$path/lib').any(
        (file) =>
            declaresModule(File('$root/$path/lib/$file').readAsStringSync()),
      ),
    );
  }

  /// The path of the package from the root of the repository.
  final String path;

  /// The name of the package.
  final String name;

  /// The packages it depends on, without its dev dependencies.
  final Set<String> dependencies;

  /// Whether pub.dev gets the package: its pubspec has no
  /// `publish_to: none`, as the fixture modules have.
  final bool published;

  /// Whether its `lib/` declares a module, a class that extends
  /// `SmfModule`: it is a package of modules, whose code knows only the
  /// modules of the packages it depends on (see `ModulePackage` of
  /// `smf_pipeline`).
  ///
  /// It sees the classes that extend `SmfModule` itself, not a module class
  /// that extends it through another class or that is a class alias. The
  /// matrix tools know the packages of their modules exactly, and
  /// `tools/app_tests_test.dart` fails when a package whose app tests a tool
  /// registers declares modules by the tool but not by this.
  final bool declaresModules;
}

/// The packages of the modules that the app tests of [package] know, among
/// the [packages] of the workspace by name: the app tests may import the
/// files that those modules generate, beyond those that roles guarantee,
/// and a matrix tool may select them by the ids of those modules. If
/// [package] declares modules, [package] itself, and otherwise the fixture
/// modules among the packages it depends on, which exist only for its
/// tests and are never published; then the packages of modules among the
/// dependencies of each, which its modules depend on.
List<WorkspacePackage> knownModules(
  WorkspacePackage package,
  Map<String, WorkspacePackage> packages,
) {
  final known = <WorkspacePackage>[];
  void know(WorkspacePackage module) {
    if (known.contains(module)) return;
    known.add(module);
    for (final name in module.dependencies) {
      if (packages[name] case final other? when other.declaresModules) {
        know(other);
      }
    }
  }

  if (package.declaresModules) {
    know(package);
  } else {
    for (final name in package.dependencies) {
      if (packages[name] case final other?
          when other.declaresModules && !other.published) {
        know(other);
      }
    }
  }
  return known;
}

/// The root of the repository that the tests run in.
String repositoryRoot() {
  final top = Process.runSync('git', ['rev-parse', '--show-toplevel']);
  if (top.exitCode != 0) {
    throw StateError('git rev-parse --show-toplevel: ${top.stderr}');
  }
  return '${top.stdout}'.trim();
}

/// The packages of the workspace of the repository at [root], in the order
/// of its pubspec.
List<WorkspacePackage> workspacePackages(String root) {
  final pubspec = File('$root/pubspec.yaml').readAsStringSync();
  return [
    for (final path in workspaceMembers(pubspec))
      WorkspacePackage.read(root, path),
  ];
}

/// The paths of the Dart files in the directory [directory] and in its
/// directories, from it and sorted, but for those whose path from it has
/// a name that starts with `.`, such as `.dart_tool/`.
List<String> dartFilesIn(String directory) {
  final root = Directory(directory);
  if (!root.existsSync()) return const [];
  return filesIn(root)..retainWhere((path) => path.endsWith('.dart'));
}

/// The paths of the files in [directory] and in its directories, from it
/// and sorted, but for those whose path from it has a name that starts with
/// `.`, as the matrix leaves hidden files out of the apps.
List<String> filesIn(Directory directory) {
  final prefix = directory.path.replaceAll(r'\', '/').length + 1;
  return [
    for (final entity in directory.listSync(recursive: true))
      if (entity is File)
        if (entity.path.replaceAll(r'\', '/').substring(prefix) case final path
            when !path.split('/').any(_hidden))
          path,
  ]..sort();
}

bool _hidden(String name) => name.startsWith('.');

/// Whether the Dart file with [text] declares a module: a class that
/// extends `SmfModule`.
bool declaresModule(String text) =>
    parseString(content: text, throwIfDiagnostics: false).unit.declarations.any(
          (declaration) =>
              declaration is ClassDeclaration &&
              declaration.extendsClause?.superclass.name.lexeme == 'SmfModule',
        );

/// The URIs of the imports, exports and parts of the Dart file with
/// [text], and of the libraries that a conditional import or export may
/// use instead, as the parser of the analyzer reads them, so that text in
/// comments and strings does not count.
List<String> urisOf(String text) => [
      for (final directive
          in parseString(content: text, throwIfDiagnostics: false)
              .unit
              .directives) ...[
        if (directive case UriBasedDirective(:final uri)) uri.stringValue ?? '',
        if (directive case NamespaceDirective(:final configurations))
          for (final configuration in configurations)
            configuration.uri.stringValue ?? '',
      ],
    ];
