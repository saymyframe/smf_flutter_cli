import 'dart:convert';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:yaml/yaml.dart';

/// The libraries of `smf_contracts` that a module may use: the module
/// model.
const _model = {
  'package:smf_contracts/smf_contracts.dart',
  'package:smf_contracts/core.dart',
};

/// The module packages by name: `smf_contracts`, which does not depend on
/// itself, and `smf_pipeline`, whose contract harness the tests of a module
/// use.
const _modelPackages = {'smf_contracts', 'smf_pipeline'};

/// The libraries of Dart that reach the machine, which the code of a module
/// does not use: it runs tools and reads the machine only through the
/// environment that the pipeline gives its checks and steps.
const _machineLibraries = {
  'dart:ffi',
  'dart:io',
  'dart:isolate',
  'dart:mirrors',
};

/// The package of a module and the rules it follows, which the package
/// checks in its own tests with [problems]:
/// - the Dart files in `lib/` import, export and include as parts only
///   `dart:` libraries but those that reach the machine, such as `dart:io`,
///   the module model of `smf_contracts` (`smf_contracts.dart` and
///   `core.dart`), the files of the package and the public libraries,
///   outside `src/`, of the packages among its [dependencies], and a
///   relative URI does not leave `lib/`, conditional ones included;
/// - of the module packages, the Dart files in `test/` use only the module
///   model of `smf_contracts` and the public libraries of the package
///   itself, the packages among its [dependencies], such as a module it
///   depends on, `smf_pipeline` and [testModules], and a relative URI does
///   not leave `test/`, so a test uses no file of another package;
/// - the package depends on `smf_contracts` and [dependencies], on no other
///   package, and on none that no file in `lib/` uses;
/// - of the module packages, its dev dependencies are `smf_pipeline`, for
///   the contract harness, and [testModules].
///
/// So the code of a module knows only the module model and the modules it
/// depends on.
///
/// The module packages are `smf_contracts`, `smf_pipeline` and every
/// package that depends on `smf_contracts`, as the package of a module
/// does, whatever its name.
///
/// ```dart
/// test('follows the rules of the package of a module', () {
///   expect(
///     const ModulePackage(
///       'smf_riverpod',
///       testModules: {'smf_flutter_core'},
///     ).problems(),
///     isEmpty,
///   );
/// });
/// ```
final class ModulePackage {
  /// Describes the package [name] of a module.
  const ModulePackage(
    this.name, {
    this.dependencies = const {},
    this.testModules = const {},
  });

  /// The name of the package, such as `smf_riverpod`.
  final String name;

  /// The packages besides `smf_contracts` that the code of the module uses,
  /// such as `mason` for the bundles of its bricks, or the package of a
  /// module it depends on, which the tests use too.
  final Set<String> dependencies;

  /// The packages of other modules that the tests use, besides
  /// `smf_pipeline`, such as `smf_flutter_core` for the app entry of the
  /// apps they render.
  ///
  /// pub.dev resolves the dev dependencies of a package when it analyzes
  /// it, so they must not form a cycle: the tests of a package that another
  /// module tests with do not use that module in turn.
  final Set<String> testModules;

  /// The problems of the package in the directory [root], the current
  /// directory by default, which is the package's own when `dart test` runs
  /// its tests: one line for every package and every URI of a file that
  /// breaks a rule.
  ///
  /// It tells the module packages by their pubspecs, which it finds through
  /// the package config that `dart pub get` writes to
  /// `.dart_tool/package_config.json` in the directory of the package or,
  /// in a pub workspace, in the root of the workspace above it. Without the
  /// package config, or without the pubspec of a package it has to tell,
  /// the problems ask to run `dart pub get`.
  List<String> problems({
    String root = '.',
    FileSystem fileSystem = const LocalFileSystem(),
  }) {
    final directory = fileSystem.directory(root);
    final pubspecFile = directory.childFile('pubspec.yaml');
    final pubspec = pubspecFile.existsSync()
        ? loadYaml(pubspecFile.readAsStringSync())
        : null;
    if (pubspec is! YamlMap || pubspec['name'] != name) {
      return ['The directory $root has no pubspec.yaml of $name.'];
    }
    Set<String> packagesOf(String section) => switch (pubspec[section]) {
          final YamlMap packages => {...packages.keys.cast<String>()},
          _ => const {},
        };
    final config = _packageConfigOf(
      fileSystem.directory(fileSystem.path.normalize(directory.absolute.path)),
    );
    if (config == null) {
      final problem = 'Neither the directory $root nor one above it has '
          '.dart_tool/package_config.json: run dart pub get.';
      return [problem];
    }

    final roots = _packageRootsIn(config);
    // A package that the package config leads to no pubspec of is
    // unresolved, and the rules take it for a package of no module.
    final unresolved = <String>{};
    bool isModule(String package) {
      if (_modelPackages.contains(package)) return true;
      final file = roots[package]?.childFile('pubspec.yaml');
      if (file == null || !file.existsSync()) {
        unresolved.add(package);
        return false;
      }
      return switch (loadYaml(file.readAsStringSync())) {
        {'dependencies': final YamlMap dependencies} =>
          dependencies.containsKey('smf_contracts'),
        _ => false,
      };
    }

    final code = {'smf_contracts', ...dependencies};
    final tests = {'smf_pipeline', ...testModules};
    final problems = [
      ..._dependencyProblems(code, packagesOf('dependencies')),
      ..._devDependencyProblems(
        tests,
        packagesOf('dev_dependencies'),
        isModule,
      ),
      ..._libProblems(directory, code),
      ..._testProblems(directory, tests, isModule),
    ];
    return [
      ..._sorted(unresolved).map(
        (package) => 'The package config ${config.path} has no package '
            '$package with a pubspec.yaml: run dart pub get.',
      ),
      ...problems,
    ];
  }

  /// The problems of [dependsOn], the dependencies of the package, which
  /// must be [code], the packages its code uses.
  List<String> _dependencyProblems(Set<String> code, Set<String> dependsOn) {
    final problems = <String>[];
    for (final package in _sorted(dependsOn.difference(code))) {
      problems.add(
        '$name depends on $package, which is not among the dependencies of '
        'the module: ${_list(code)}.',
      );
    }
    for (final package in _sorted(code.difference(dependsOn))) {
      problems.add('$name does not depend on $package.');
    }
    return problems;
  }

  /// The problems of [devDependencies], the dev dependencies of the
  /// package, which must have [tests] among the module packages that
  /// [isModule] tells.
  List<String> _devDependencyProblems(
    Set<String> tests,
    Set<String> devDependencies,
    bool Function(String package) isModule,
  ) {
    final modules = {
      for (final package in devDependencies.difference(tests))
        if (isModule(package)) package,
    };
    final problems = <String>[];
    for (final package in _sorted(modules)) {
      problems.add(
        '$name has a dev dependency on $package, but of the module packages '
        'the tests of a module use only ${_list(tests)}.',
      );
    }
    for (final package in _sorted(tests.difference(devDependencies))) {
      problems.add('$name has no dev dependency on $package.');
    }
    return problems;
  }

  /// The problems of the files in `lib/` of the package in [directory]:
  /// the URIs they use, and the packages among [code] that none uses.
  List<String> _libProblems(Directory directory, Set<String> code) {
    final problems = <String>[];
    final used = <String>{};
    for (final (path, uri) in _directives(directory, 'lib')) {
      final package = _packageOf(uri);
      if (package != null) used.add(package);
      if (!_isAllowed(uri, path, 'lib', {name, ...dependencies})) {
        problems.add(
          '$path uses $uri, but the code of a module uses only the dart: '
          'libraries that do not reach the machine, the module model of '
          'smf_contracts, its own files in lib/ and the public libraries of '
          'the packages it depends on.',
        );
      }
    }
    for (final package in _sorted(code.difference(used))) {
      problems.add(
        '$name depends on $package, but no file in lib/ uses it.',
      );
    }
    return problems;
  }

  /// The problems of the URIs that the files in `test/` of the package in
  /// [directory] use, with [tests] among the module packages that
  /// [isModule] tells.
  List<String> _testProblems(
    Directory directory,
    Set<String> tests,
    bool Function(String package) isModule,
  ) {
    // The tests may use the modules that the code depends on, as the code
    // does: the registry of their apps needs them.
    final testable = {
      name,
      ...tests,
      for (final package in dependencies)
        if (isModule(package)) package,
    };
    final problems = <String>[];
    for (final (path, uri) in _directives(directory, 'test')) {
      if (!_isAllowed(uri, path, 'test', testable, isModule: isModule)) {
        problems.add(
          '$path uses $uri, but of the module packages the tests of a module '
          'use only the module model of smf_contracts and the public '
          'libraries of ${_list(testable)}, and no file outside test/ by a '
          'relative path.',
        );
      }
    }
    return problems;
  }

  /// Whether the file at [path] in the directory [directory] may use [uri]:
  /// a `dart:` library, but for those that reach the machine in `lib/`, a
  /// relative URI that stays in [directory], the module model of
  /// `smf_contracts`, a library of [packages] that is not in `src/` unless
  /// it is of this package, or, if [isModule] tells the module packages, a
  /// library of a package that is not one.
  bool _isAllowed(
    String uri,
    String path,
    String directory,
    Set<String> packages, {
    bool Function(String package)? isModule,
  }) =>
      switch (_packageOf(uri)) {
        null when uri.startsWith('dart:') =>
          directory != 'lib' || !_machineLibraries.contains(uri),
        null => _staysIn(directory, path, uri),
        'smf_contracts' => _model.contains(uri),
        final package when packages.contains(package) =>
          package == name || !uri.startsWith('package:$package/src/'),
        final package => isModule != null && !isModule(package),
      };

  /// The package config that `dart pub get` wrote for the package in
  /// [directory], by its normalized absolute path:
  /// `.dart_tool/package_config.json` in [directory] or in the nearest
  /// directory above it that has one, or `null` when none has.
  static File? _packageConfigOf(Directory directory) {
    final config =
        directory.childDirectory('.dart_tool').childFile('package_config.json');
    if (config.existsSync()) return config;
    final parent = directory.parent;
    return parent.path == directory.path ? null : _packageConfigOf(parent);
  }

  /// The root directory of each package in the package [config], by name.
  /// `dart pub get` writes a root as a URI relative to [config], as for the
  /// packages of a workspace, or as an absolute `file:` URI, as for those
  /// in the pub cache.
  static Map<String, Directory> _packageRootsIn(File config) {
    final fileSystem = config.fileSystem;
    final context = fileSystem.path;
    final uri = context.toUri(config.path);
    final json = jsonDecode(config.readAsStringSync()) as Map<String, Object?>;
    return {
      for (final package in json['packages']! as List<Object?>)
        if (package
            case {'name': final String name, 'rootUri': final String root})
          name: fileSystem.directory(context.fromUri(uri.resolve(root))),
    };
  }

  /// The URIs of the imports, exports and parts of the Dart files in the
  /// directory [name] of [package], each with the path of its file relative
  /// to the package, as the parser of the analyzer reads them, so that text
  /// in strings does not count.
  static List<(String, String)> _directives(Directory package, String name) {
    final directory = package.childDirectory(name);
    if (!directory.existsSync()) return const [];
    final context = package.fileSystem.path;
    final files = [
      for (final entity in directory.listSync(recursive: true))
        if (entity is File && entity.path.endsWith('.dart')) entity,
    ]..sort((a, b) => a.path.compareTo(b.path));
    return [
      for (final file in files)
        for (final uri in _urisOf(file.readAsStringSync()))
          (
            context
                .relative(file.path, from: package.path)
                .replaceAll(context.separator, '/'),
            uri,
          ),
    ];
  }

  /// The URIs of the imports, exports and parts of the Dart file with
  /// [text], and of the libraries that a conditional import or export may
  /// use instead.
  static List<String> _urisOf(String text) => [
        for (final directive
            in parseString(content: text, throwIfDiagnostics: false)
                .unit
                .directives) ...[
          if (directive case UriBasedDirective(:final uri))
            uri.stringValue ?? '',
          // The libraries a conditional import or export may use instead.
          if (directive case NamespaceDirective(:final configurations))
            for (final configuration in configurations)
              configuration.uri.stringValue ?? '',
        ],
      ];

  /// The package of [uri], a `package:` URI, or `null` for another URI.
  static String? _packageOf(String uri) => uri.startsWith('package:')
      ? uri.substring('package:'.length).split('/').first
      : null;

  /// Whether [uri] is relative and, from the file at [path], stays in the
  /// directory [directory].
  static bool _staysIn(String directory, String path, String uri) =>
      !uri.contains(':') &&
      Uri.parse(path).resolve(uri).path.startsWith('$directory/');

  static List<String> _sorted(Set<String> packages) =>
      packages.toList()..sort();

  static String _list(Set<String> packages) {
    final sorted = _sorted(packages);
    if (sorted.length == 1) return sorted.single;
    return '${sorted.sublist(0, sorted.length - 1).join(', ')} and '
        '${sorted.last}';
  }
}
