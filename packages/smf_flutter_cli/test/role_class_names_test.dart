@TestOn('vm')
library;

import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:test/test.dart';

/// The problems of [source], the Dart code of the file [path]: each string
/// that spells out the name of a class of [classes], the role of each class
/// by its name, followed by `(`, with the line of the name.
///
/// Generated code takes the names of the classes of roles from the
/// constants of the roles, as `'${LayoutRole.destination.name}('` does, so
/// only the text of a string between its interpolations counts. Comments
/// and code outside strings, such as a `Destination(...)` of the DSL of the
/// router, do not.
List<String> _problemsOf(
  String path,
  String source,
  Map<String, Role> classes,
) {
  final calls = {
    for (final MapEntry(key: name, value: role) in classes.entries)
      (name, role): RegExp('(?<![A-Za-z0-9_\$])${RegExp.escape(name)}\\('),
  };
  final result = parseString(content: source, path: path);
  final problems = <String>[];
  result.unit.accept(
    _Strings((node, text) {
      for (final MapEntry(key: (name, role), value: call) in calls.entries) {
        if (!call.hasMatch(text)) continue;
        // The line of the name in the code of the string, which may span
        // several lines.
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

/// The packages of the modules that the CLI offers: the packages that
/// `lib/src/modules.dart` imports, but the contracts.
Future<List<String>> _modulePackages() async {
  final modules = await Isolate.resolvePackageUri(
    Uri.parse('package:smf_flutter_cli/src/modules.dart'),
  );
  final unit = parseString(
    content: File.fromUri(modules!).readAsStringSync(),
  ).unit;
  return [
    for (final directive in unit.directives)
      if (directive
          case ImportDirective(uri: StringLiteral(stringValue: final uri?))
          when uri.startsWith('package:') &&
              !uri.startsWith('package:smf_contracts/'))
        uri.substring('package:'.length).split('/').first,
  ]..sort();
}

/// The Dart files of the `lib/` of [package] but its bundles, which bricks
/// generate, by their paths from the directory of the package.
Future<Map<String, File>> _libraryFilesOf(String package) async {
  final lib = await Isolate.resolvePackageUri(Uri.parse('package:$package/'));
  final directory = Directory.fromUri(lib!);
  final entities = directory.listSync(recursive: true)
    ..sort((a, b) => a.path.compareTo(b.path));
  final files = <String, File>{};
  for (final entity in entities) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = p.relative(entity.path, from: directory.path);
    final posix = p.split(path).join('/');
    if (posix.startsWith('bundles/')) continue;
    files['$package/lib/$posix'] = entity;
  }
  return files;
}

void main() {
  test(
      'finds the strings that spell out the name of a class of a role, but '
      'not the interpolations of its name, comments or code', () {
    final classes = {
      LayoutRole.appShell.name: layoutRole,
      LayoutRole.destination.name: layoutRole,
      AppEntryRole.fallbackStartScreen.name: appEntryRole,
    };
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

    expect(_problemsOf('lib/a.dart', source, classes), [
      'lib/a.dart:2 spells out AppShell( of the layout role.',
      'lib/a.dart:5 spells out FallbackStartScreen( of the app entry role.',
      'lib/a.dart:10 spells out Destination( of the layout role.',
    ]);
  });

  test(
      'the modules that the CLI offers take the names of the classes of '
      'roles from the roles', () async {
    final classes = {
      for (final role in ModuleRegistry(smfModules).roles)
        for (final symbol in role.interface.symbols)
          if (symbol is RequiredClass) symbol.name: role,
    };
    final packages = await _modulePackages();
    final problems = [
      for (final package in packages)
        for (final MapEntry(key: path, value: file)
            in (await _libraryFilesOf(package)).entries)
          ..._problemsOf(path, file.readAsStringSync(), classes),
    ];

    expect(classes, isNotEmpty);
    expect(packages, isNotEmpty);
    expect(
      problems,
      isEmpty,
      reason: 'Generated code takes the name of a class of a role from the '
          'role, such as LayoutRole.destination.name.',
    );
  });
}
