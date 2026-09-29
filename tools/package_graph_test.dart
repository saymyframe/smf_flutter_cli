// Checks that the published packages of the workspace depend on each other
// without a cycle, dev dependencies included: pub.dev resolves the dev
// dependencies of a package when it analyzes it, so a cycle would keep the
// first of its packages to be published from being analyzed. The modules
// test with the modules they need, such as smf_flutter_core for the app
// entry of their apps, so their dev dependencies could close one.
import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'workspace_members.dart';

/// A package of the workspace, as its pubspec describes it.
final class _Package {
  const _Package(this.name, {required this.published, required this.uses});

  /// Reads the pubspec [text] as YAML, as pub reads it.
  factory _Package.parse(String text) {
    final pubspec = loadYaml(text) as YamlMap;
    return _Package(
      pubspec['name'] as String,
      published: pubspec['publish_to'] != 'none',
      uses: {
        for (final section in ['dependencies', 'dev_dependencies'])
          if (pubspec[section] case final YamlMap packages)
            ...packages.keys.cast<String>(),
      },
    );
  }

  final String name;

  /// Whether pub.dev gets the package.
  final bool published;

  /// The packages it depends on, dev dependencies included.
  final Set<String> uses;
}

/// The cycles of [graph], the packages each package uses by name: each is
/// the packages of a cycle in order, the first one again at the end.
List<List<String>> cyclesOf(Map<String, Set<String>> graph) {
  final cycles = <List<String>>[];
  final done = <String>{};
  final path = <String>[];
  void visit(String package) {
    if (done.contains(package)) return;
    final at = path.indexOf(package);
    if (at >= 0) {
      cycles.add([...path.sublist(at), package]);
      return;
    }
    path.add(package);
    ((graph[package]?.toList() ?? <String>[])..sort()).forEach(visit);
    path.removeLast();
    done.add(package);
  }

  (graph.keys.toList()..sort()).forEach(visit);
  return cycles;
}

/// The published packages of the workspace at [root] and the published
/// packages of the workspace each one uses.
Map<String, Set<String>> _workspaceGraph(String root) {
  final pubspec = File('$root/pubspec.yaml').readAsStringSync();
  final packages = [
    for (final member in workspaceMembers(pubspec))
      _Package.parse(File('$root/$member/pubspec.yaml').readAsStringSync()),
  ];
  final published = {
    for (final package in packages)
      if (package.published) package.name,
  };
  return {
    for (final package in packages)
      if (package.published) package.name: package.uses.intersection(published),
  };
}

void main() {
  test('finds the cycles of a graph', () {
    expect(
      cyclesOf({
        'a': {'b'},
        'b': {'c'},
        'c': {'a'},
        'd': {'a', 'd'},
        'e': {'a'},
      }),
      [
        ['a', 'b', 'c', 'a'],
        ['d', 'd'],
      ],
    );
    expect(
      cyclesOf({
        'cli': {'core', 'router'},
        'router': {'core'},
        'home': {'router', 'core'},
        'core': {},
      }),
      isEmpty,
    );
  });

  test('reads the packages a pubspec uses, and whether it is published', () {
    final package = _Package.parse(
      'name: smf_router\n'
      'publish_to: none\n'
      'environment:\n'
      '  sdk: ">=3.6.0 <4.0.0"\n'
      'dependencies:\n'
      '  smf_contracts: ^0.2.0\n'
      '  flutter:\n'
      '    sdk: flutter\n'
      'dev_dependencies:\n'
      '  # A comment.\n'
      '  smf_pipeline: ^0.2.0\n',
    );

    expect(package.name, 'smf_router');
    expect(package.published, isFalse);
    expect(package.uses, {'smf_contracts', 'flutter', 'smf_pipeline'});
  });

  test('reads a pubspec as YAML, with quotes, comments and flow maps', () {
    final package = _Package.parse(
      'name: "smf_router" # The router.\n'
      "publish_to: 'none'\n"
      'dependencies: {smf_contracts: ^0.2.0}\n'
      'dev_dependencies: # For its tests.\n'
      '  smf_pipeline: any\n',
    );

    expect(package.name, 'smf_router');
    expect(package.published, isFalse);
    expect(package.uses, {'smf_contracts', 'smf_pipeline'});
  });

  test(
      'reads the members that the root pubspec lists, with comments and '
      'quotes, into the graph of the published ones', () {
    final root = Directory.systemTemp.createTempSync('package_graph_');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/pubspec.yaml').writeAsStringSync(
      'name: root\n'
      'workspace: # The packages of the repository.\n'
      '  - packages/a\n'
      '  - "packages/b"\n'
      '  - packages/c\n',
    );
    void write(String path, String text) => File('${root.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
    write(
      'packages/a/pubspec.yaml',
      'name: a\ndependencies:\n  b: any\n  c: any\n',
    );
    write('packages/b/pubspec.yaml', 'name: b\ndev_dependencies:\n  a: any\n');
    write('packages/c/pubspec.yaml', 'name: c\npublish_to: none\n');

    final graph = _workspaceGraph(root.path);

    expect(graph, {
      'a': {'b'},
      'b': {'a'},
    });
    expect(cyclesOf(graph), [
      ['a', 'b', 'a'],
    ]);
  });

  test(
      'the published packages of the workspace depend on each other without '
      'a cycle, dev dependencies included', () {
    final top = Process.runSync('git', ['rev-parse', '--show-toplevel']);
    expect(top.exitCode, 0, reason: '${top.stderr}');
    final graph = _workspaceGraph('${top.stdout}'.trim());

    expect(graph.keys, containsAll(['smf_contracts', 'smf_pipeline']));
    expect(graph['smf_pipeline'], contains('smf_contracts'));
    expect(cyclesOf(graph), isEmpty);
  });
}
