// Checks that sonar-project.properties gives SonarCloud the coverage of every
// package whose code it analyzes. `melos run test:coverage` writes
// coverage/lcov.info in each package with a test/ directory, but SonarCloud
// reads only the reports that sonar.dart.lcov.reportPaths lists, and the
// list is kept by hand: a new package with tests that it lacks would have
// the code of its lib/ counted as uncovered, and no other check would say
// so. A report in the list that no such package writes is left over from a
// package that moved, or is of code that SonarCloud does not analyze.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'workspace_members.dart';

/// The problems of the coverage reports that [properties], the text of
/// sonar-project.properties, gives SonarCloud for [packages], the packages
/// of the workspace by their paths from the root of the repository, each
/// with whether it has a test/ directory:
/// - a package with a test/ directory whose lib/ SonarCloud analyzes, but
///   whose coverage/lcov.info is not in sonar.dart.lcov.reportPaths;
/// - a report in the list that is not the coverage/lcov.info of such a
///   package.
List<String> problemsOf(String properties, Map<String, bool> packages) {
  final values = _propertiesOf(properties);
  List<String> listed(String key) => [
        for (final item in (values[key] ?? '').split(','))
          if (item.trim().isNotEmpty) item.trim(),
      ];
  final sources = listed('sonar.sources');
  final exclusions = listed('sonar.exclusions');
  final reports = listed('sonar.dart.lcov.reportPaths');
  final analyzed = [
    for (final MapEntry(key: package, value: tested) in packages.entries)
      if (tested && _analyzes('$package/lib', sources, exclusions)) package,
  ];
  final expected = [
    for (final package in analyzed) '$package/coverage/lcov.info',
  ];
  return [
    for (final package in analyzed)
      if (!reports.contains('$package/coverage/lcov.info')) _missing(package),
    for (final report in reports)
      if (!expected.contains(report)) _leftOver(report),
  ];
}

String _missing(String package) => 'sonar.dart.lcov.reportPaths does not list '
    '$package/coverage/lcov.info, so SonarCloud counts the code of '
    '$package/lib as uncovered.';

String _leftOver(String report) =>
    'sonar.dart.lcov.reportPaths lists $report, which is not the report of '
    'a package of the workspace with a test/ directory and a lib/ that '
    'SonarCloud analyzes.';

/// The properties of [text], the text of a .properties file, by key, as far
/// as sonar-project.properties uses the format: a line `key=value`, whose
/// value goes on in the next line when it ends with `\`, and comments,
/// lines that start with `#` or `!`.
Map<String, String> _propertiesOf(String text) {
  final properties = <String, String>{};
  final lines = const LineSplitter().convert(text);
  for (var index = 0; index < lines.length; index++) {
    var line = lines[index].trimLeft();
    if (line.startsWith('#') || line.startsWith('!')) continue;
    while (line.endsWith(r'\') && index + 1 < lines.length) {
      line = line.substring(0, line.length - 1) + lines[++index].trimLeft();
    }
    final separator = line.indexOf('=');
    if (separator < 0) continue;
    properties[line.substring(0, separator).trim()] =
        line.substring(separator + 1).trim();
  }
  return properties;
}

/// Whether SonarCloud analyzes the code in the directory [path], from the
/// root of the repository: a path of [sources] holds it, and no pattern of
/// [exclusions] excludes all of it, as one that ends with `/**`, such as
/// `**/test/**`, does when it matches the files in it; a pattern such as
/// `**/*.g.dart` excludes only some files.
bool _analyzes(String path, List<String> sources, List<String> exclusions) =>
    sources.any((source) => _holds(source, path)) &&
    !exclusions.any(
      (pattern) => pattern.endsWith('/**') && _glob(pattern).hasMatch('$path/'),
    );

/// Whether [source], a path of sonar.sources, such as `packages` or `.` for
/// the whole repository, holds the directory [path].
bool _holds(String source, String path) {
  final directory =
      source.replaceFirst(RegExp(r'^\./'), '').replaceFirst(RegExp(r'/$'), '');
  return directory.isEmpty ||
      directory == '.' ||
      path == directory ||
      path.startsWith('$directory/');
}

/// The regular expression of a path that the pattern [glob] of Sonar
/// matches, in which `**/` stands for any directories, or none, `**` for
/// any text, and `*` for any text without a `/`.
RegExp _glob(String glob) {
  final pattern = glob.replaceAllMapped(
    RegExp(r'\*\*/|\*\*|\*|[^*]+'),
    (match) => switch (match[0]!) {
      '**/' => '(?:.*/)?',
      '**' => '.*',
      '*' => '[^/]*',
      final text => RegExp.escape(text),
    },
  );
  return RegExp('^$pattern\$');
}

/// The packages of the workspace at [root], the members that its root
/// pubspec lists as workspace_members.dart reads them, by their paths from
/// [root], each with whether it has a test/ directory.
Map<String, bool> _workspacePackages(String root) => {
      for (final package in workspaceMembers(
        File('$root/pubspec.yaml').readAsStringSync(),
      ))
        package: Directory('$root/$package/test').existsSync(),
    };

void main() {
  // The packages of a workspace, each with whether it has a test/ directory.
  const packages = {
    'packages/a': true,
    // In a directory of tests, as the fixtures of the pipeline are.
    'packages/a/test/fixtures/fake': true,
    // Excluded by packages/*/registry/**, unlike packages/b/x/registry: `*`
    // stands for one directory.
    'packages/a/registry': true,
    'packages/b': true,
    'packages/b/x/registry': true,
    // Without tests.
    'packages/c': false,
    // Outside the sources.
    'tool/d': true,
  };
  String properties(List<String> reports) => '''
sonar.projectKey=example
sonar.sources=packages
sonar.exclusions=**/bundles/**,**/test/**,packages/*/registry/**,**/*.g.dart

# Written by `melos run test:coverage`.
sonar.dart.lcov.reportPaths=\\
  ${reports.join(',\\\n  ')}
''';

  test(
      'finds the packages with tests whose lib/ SonarCloud analyzes but '
      'whose reports the list lacks', () {
    expect(
      problemsOf(
        properties(['packages/a/coverage/lcov.info']),
        packages,
      ),
      [_missing('packages/b'), _missing('packages/b/x/registry')],
    );
    expect(
      problemsOf(
        properties([
          'packages/a/coverage/lcov.info',
          'packages/b/coverage/lcov.info',
          'packages/b/x/registry/coverage/lcov.info',
        ]),
        packages,
      ),
      isEmpty,
    );
  });

  test(
      'finds the reports in the list that are not of a package with tests '
      'whose lib/ SonarCloud analyzes', () {
    expect(
      problemsOf(
        properties([
          'packages/a/coverage/lcov.info',
          'packages/a/test/fixtures/fake/coverage/lcov.info',
          'packages/a/registry/coverage/lcov.info',
          'packages/b/coverage/lcov.info',
          'packages/b/x/registry/coverage/lcov.info',
          'packages/c/coverage/lcov.info',
          'packages/gone/coverage/lcov.info',
          'tool/d/coverage/lcov.info',
        ]),
        packages,
      ),
      [
        _leftOver('packages/a/test/fixtures/fake/coverage/lcov.info'),
        _leftOver('packages/a/registry/coverage/lcov.info'),
        _leftOver('packages/c/coverage/lcov.info'),
        _leftOver('packages/gone/coverage/lcov.info'),
        _leftOver('tool/d/coverage/lcov.info'),
      ],
    );
  });

  /// A workspace in a temporary directory, deleted after the test, whose
  /// root pubspec is [pubspec], with a test/ directory in each package of
  /// [tested].
  String workspace(String pubspec, List<String> tested) {
    final root = Directory.systemTemp.createTempSync('sonar_lcov_');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/pubspec.yaml').writeAsStringSync(pubspec);
    for (final package in tested) {
      Directory('${root.path}/$package/test').createSync(recursive: true);
    }
    return root.path;
  }

  test(
      'reads a member of the workspace in quotes, so that the list cannot '
      'lack the report of its package unseen', () {
    final root = workspace(
      'name: root\n'
      'workspace:\n'
      '  - packages/a\n'
      '  - "packages/b"\n',
      ['packages/a', 'packages/b'],
    );

    expect(
      problemsOf(
        properties(['packages/a/coverage/lcov.info']),
        _workspacePackages(root),
      ),
      [_missing('packages/b')],
    );
  });

  test(
      'reads the members of the workspace after a comment on its line, so '
      'that the reports of their packages are not taken for left over', () {
    final root = workspace(
      'name: root\n'
      'workspace: # The packages of the repository.\n'
      '  - packages/a\n',
      ['packages/a'],
    );

    expect(
      problemsOf(
        properties(['packages/a/coverage/lcov.info']),
        _workspacePackages(root),
      ),
      isEmpty,
    );
  });

  test(
      'sonar-project.properties lists the report of every package of the '
      'workspace with tests whose lib/ SonarCloud analyzes, and no other', () {
    final top = Process.runSync('git', ['rev-parse', '--show-toplevel']);
    expect(top.exitCode, 0, reason: '${top.stderr}');
    final root = '${top.stdout}'.trim();
    final properties = File('$root/sonar-project.properties');

    expect(
      problemsOf(properties.readAsStringSync(), _workspacePackages(root)),
      isEmpty,
    );
  });
}
