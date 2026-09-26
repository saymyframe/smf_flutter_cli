import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:smf_pipeline/src/testing/file_indexer.dart';
import 'package:yaml/yaml.dart';

/// The libraries of `smf_contracts` that a module may use: the module
/// model.
const _model = {
  'package:smf_contracts/lego.dart',
  'package:smf_contracts/lego_core.dart',
};

/// The package of a module and the rules it follows, which the package
/// checks in its own tests with [problems]:
/// - the Dart files in `lib/` import and export only `dart:` libraries, the
///   module model of `smf_contracts` (`lego.dart` and `lego_core.dart`), the
///   files of the package and the packages among its [dependencies], and a
///   relative URI does not leave `lib/`;
/// - of the SMF packages, the Dart files in `test/` use only the module
///   model of `smf_contracts`, the package itself, `smf_pipeline` and
///   [testModules], and a relative URI does not leave `test/`, so a test
///   uses no file of another package;
/// - the package depends on `smf_contracts` and [dependencies], and on no
///   other package;
/// - of the SMF packages, its dev dependencies are `smf_pipeline`, for the
///   contract harness, and [testModules].
///
/// So the code of a module knows only the module model and the modules it
/// depends on.
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
  /// module it depends on.
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

    final problems = <String>[];
    final code = {'smf_contracts', ...dependencies};
    final dependsOn = packagesOf('dependencies');
    for (final package in _sorted(dependsOn.difference(code))) {
      problems.add(
        '$name depends on $package, but a module depends only on '
        '${_list(code)}.',
      );
    }
    for (final package in _sorted(code.difference(dependsOn))) {
      problems.add('$name does not depend on $package.');
    }

    final tests = {'smf_pipeline', ...testModules};
    final testsWith = {
      for (final package in packagesOf('dev_dependencies'))
        if (package.startsWith('smf_')) package,
    };
    for (final package in _sorted(testsWith.difference(tests))) {
      problems.add(
        '$name has a dev dependency on $package, but of the SMF packages the '
        'tests of a module use only ${_list(tests)}.',
      );
    }
    for (final package in _sorted(tests.difference(testsWith))) {
      problems.add('$name has no dev dependency on $package.');
    }

    final reachable = {name, ...dependencies};
    for (final (path, uri) in _directives(directory, 'lib')) {
      final package = _packageOf(uri);
      final allowed = package == null
          ? uri.startsWith('dart:') || _staysIn('lib', path, uri)
          : package == 'smf_contracts'
              ? _model.contains(uri)
              : reachable.contains(package);
      if (!allowed) {
        problems.add(
          '$path uses $uri, but the code of a module uses only dart:, the '
          'module model of smf_contracts, its own files in lib/ and the '
          'packages it depends on.',
        );
      }
    }
    final testable = {name, ...tests};
    for (final (path, uri) in _directives(directory, 'test')) {
      final package = _packageOf(uri);
      final allowed = package == null
          ? uri.startsWith('dart:') || _staysIn('test', path, uri)
          : package == 'smf_contracts'
              ? _model.contains(uri)
              : !package.startsWith('smf_') || testable.contains(package);
      if (!allowed) {
        problems.add(
          '$path uses $uri, but of the SMF packages the tests of a module use '
          'only the module model of smf_contracts, ${_list(testable)}, and '
          'no file outside test/ by a relative path.',
        );
      }
    }
    return problems;
  }

  /// The URIs of the imports and exports of the Dart files in the directory
  /// [name] of [package], each with the path of its file relative to the
  /// package, as the parser of the analyzer reads them, so that text in
  /// strings does not count.
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
        if (DartFileIndexer.index(file.path, file.readAsStringSync())
            case final index)
          for (final directive in [...index.imports, ...index.exports])
            (
              context
                  .relative(file.path, from: package.path)
                  .replaceAll(context.separator, '/'),
              directive.uri,
            ),
    ];
  }

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
    return sorted.length == 1
        ? sorted.single
        : '${sorted.sublist(0, sorted.length - 1).join(', ')} and '
            '${sorted.last}';
  }
}
