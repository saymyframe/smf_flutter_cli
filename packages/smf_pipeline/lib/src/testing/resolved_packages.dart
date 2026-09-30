import 'dart:convert';

import 'package:file/file.dart';
import 'package:yaml/yaml.dart';

/// The module packages by name: `smf_contracts`, which does not depend on
/// itself, and `smf_pipeline`, whose contract harness the tests of a module
/// use.
const _modelPackages = {'smf_contracts', 'smf_pipeline'};

/// The packages that `dart pub get` resolved for a package, by the package
/// config it wrote, which tell the module packages from the others: the
/// module packages are `smf_contracts`, `smf_pipeline` and every package
/// that depends on `smf_contracts`, as the package of a module does,
/// whatever its name.
///
/// A package that the package config leads to no pubspec of is unresolved,
/// and [problems] asks to run `dart pub get`.
final class ResolvedPackages {
  ResolvedPackages._(this._config, this._roots);

  /// The packages resolved for the package in [directory], by the package
  /// config that `dart pub get` writes to `.dart_tool/package_config.json`
  /// in the directory of the package or, in a pub workspace, in the root of
  /// the workspace above it; `null` when neither [directory] nor one above
  /// it has one, and the problem is [missingConfig].
  static ResolvedPackages? of(Directory directory) {
    final fileSystem = directory.fileSystem;
    final config = _configOf(
      fileSystem.directory(fileSystem.path.normalize(directory.absolute.path)),
    );
    return config == null ? null : ResolvedPackages._(config, _rootsIn(config));
  }

  /// The problem of the package in the directory [root] when [of] finds no
  /// package config for it.
  static String missingConfig(String root) =>
      'Neither the directory $root nor one above it has '
      '.dart_tool/package_config.json: run dart pub get.';

  final File _config;
  final Map<String, Directory> _roots;
  final Set<String> _unresolved = {};

  /// The root directory of [package], or `null` when the package config
  /// leads to no pubspec of it: the package is unresolved.
  Directory? rootOf(String package) {
    final root = _roots[package];
    if (root != null && root.childFile('pubspec.yaml').existsSync()) {
      return root;
    }
    _unresolved.add(package);
    return null;
  }

  /// Whether [package] is a module package, by its name or by the pubspec
  /// at its [rootOf]; an unresolved package is taken for a package of no
  /// module.
  bool isModule(String package) {
    if (_modelPackages.contains(package)) return true;
    final root = rootOf(package);
    if (root == null) return false;
    return switch (
        loadYaml(root.childFile('pubspec.yaml').readAsStringSync())) {
      {'dependencies': final YamlMap dependencies} =>
        dependencies.containsKey('smf_contracts'),
      _ => false,
    };
  }

  /// A problem for each package that [rootOf] found unresolved so far, in
  /// the order of their names, which asks to run `dart pub get`.
  List<String> get problems => [
        for (final package in _unresolved.toList()..sort())
          _unresolvedProblem(package),
      ];

  String _unresolvedProblem(String package) =>
      'The package config ${_config.path} has no package $package with a '
      'pubspec.yaml: run dart pub get.';

  /// The package config that `dart pub get` wrote for the package in
  /// [directory], by its normalized absolute path:
  /// `.dart_tool/package_config.json` in [directory] or in the nearest
  /// directory above it that has one, or `null` when none has.
  static File? _configOf(Directory directory) {
    final config =
        directory.childDirectory('.dart_tool').childFile('package_config.json');
    if (config.existsSync()) return config;
    final parent = directory.parent;
    return parent.path == directory.path ? null : _configOf(parent);
  }

  /// The root directory of each package in the package [config], by name.
  /// `dart pub get` writes a root as a URI relative to [config], as for the
  /// packages of a workspace, or as an absolute `file:` URI, as for those
  /// in the pub cache.
  static Map<String, Directory> _rootsIn(File config) {
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
}

/// The Dart files in the directory [name] of the package in [package], such
/// as `lib`, each with its path relative to the package with `/` between
/// its parts, in the order of their paths; none when the package has no
/// such directory.
List<(String, File)> dartFilesIn(Directory package, String name) {
  final directory = package.childDirectory(name);
  if (!directory.existsSync()) return const [];
  final context = package.fileSystem.path;
  final files = [
    for (final entity in directory.listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.dart')) entity,
  ]..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final file in files)
      (
        context
            .relative(file.path, from: package.path)
            .replaceAll(context.separator, '/'),
        file,
      ),
  ];
}
