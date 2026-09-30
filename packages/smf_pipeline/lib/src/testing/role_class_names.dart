import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:smf_contracts/core.dart';
import 'package:smf_pipeline/src/testing/resolved_packages.dart';
import 'package:yaml/yaml.dart';

/// The strings in the code of the package in the directory [root], the
/// current directory by default, and of the module packages it depends on,
/// that spell out the name of a class that one of [roles] requires: one line
/// for each, with the path of its file and the line of the name.
///
/// Generated code takes the name of such a class, such as the `AppShell` of
/// the layout role, from the role, as `'${LayoutRole.appShell.name}('`
/// does, so that it follows the role. The classes are the [RequiredClass]es
/// of the interfaces of [roles], and a string spells one out when its text
/// between its interpolations has the name followed by `(`. Comments and
/// code outside strings, such as a `Destination(...)` of the DSL of the
/// router, do not count, nor do the files in `lib/bundles/`, which bricks
/// generate.
///
/// It tells the module packages as `ModulePackage` does: they are
/// `smf_contracts`, `smf_pipeline` and every package that depends on
/// `smf_contracts`, which it finds through the package config that
/// `dart pub get` writes. Without the package config, or without the
/// pubspec of a package it has to tell, the problems ask to run
/// `dart pub get`.
///
/// ```dart
/// test('takes the names of the classes of roles from the roles', () {
///   expect(roleClassNameProblems(ModuleRegistry(modules).roles), isEmpty);
/// });
/// ```
List<String> roleClassNameProblems(
  Iterable<Role> roles, {
  String root = '.',
  FileSystem fileSystem = const LocalFileSystem(),
}) {
  final directory = fileSystem.directory(root);
  final pubspecFile = directory.childFile('pubspec.yaml');
  final pubspec = pubspecFile.existsSync()
      ? loadYaml(pubspecFile.readAsStringSync())
      : null;
  if (pubspec case final YamlMap map && {'name': final String name}) {
    final packages = ResolvedPackages.of(directory);
    if (packages == null) return [ResolvedPackages.missingConfig(root)];
    final dependencies = switch (map['dependencies']) {
      final YamlMap dependencies => [...dependencies.keys.cast<String>()]
        ..sort(),
      _ => const <String>[],
    };
    final checked = [
      (name, directory),
      for (final package in dependencies)
        if (packages.isModule(package))
          if (packages.rootOf(package) case final packageRoot?)
            (package, packageRoot),
    ];
    final classes = {
      for (final role in roles)
        for (final symbol in role.interface.symbols)
          if (symbol is RequiredClass) symbol.name: role,
    };
    final problems = [
      for (final (package, packageRoot) in checked)
        for (final (path, file) in dartFilesIn(packageRoot, 'lib'))
          if (!path.startsWith('lib/bundles/'))
            ..._problemsOf('$package/$path', file.readAsStringSync(), classes),
    ];
    return [...packages.problems, ...problems];
  }
  return ['The directory $root has no pubspec.yaml.'];
}

/// The problems of [source], the Dart code of the file [path]: each string
/// that spells out the name of a class of [classes], the role of each class
/// by its name, followed by `(`, with the line of the name.
List<String> _problemsOf(
  String path,
  String source,
  Map<String, Role> classes,
) {
  final calls = {
    for (final MapEntry(key: name, value: role) in classes.entries)
      (name, role): RegExp('(?<![A-Za-z0-9_\$])${RegExp.escape(name)}\\('),
  };
  final result = parseString(content: source, throwIfDiagnostics: false);
  final problems = <String>[];
  result.unit.accept(
    _Strings((node, text) {
      for (final MapEntry(key: (name, role), value: call) in calls.entries) {
        if (!call.hasMatch(text)) continue;
        // The line of the name in the code of the string, which may span
        // several lines, or of the string when an escape spells the name.
        final at = call.firstMatch(source.substring(node.offset, node.end));
        final line = result.lineInfo
            .getLocation(node.offset + (at?.start ?? 0))
            .lineNumber;
        problems.add('$path:$line spells out $name( of the $role.');
      }
    }),
  );
  return problems;
}

/// Visits the text of every string of a unit: of a string without
/// interpolations, and of each part of a string between its
/// interpolations.
final class _Strings extends RecursiveAstVisitor<void> {
  _Strings(this._visit);

  final void Function(AstNode node, String text) _visit;

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) =>
      _visit(node, node.value);

  @override
  void visitInterpolationString(InterpolationString node) =>
      _visit(node, node.value);
}
