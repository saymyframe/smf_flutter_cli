// Checks that the published packages of the workspace depend on each other
// without a cycle, dev dependencies included: pub.dev resolves the dev
// dependencies of a package when it analyzes it, so a cycle would keep the
// first of its packages to be published from being analyzed. The modules
// test with the modules they need, such as smf_flutter_core for the app
// entry of their apps, so their dev dependencies could close one.
import 'dart:io';

import 'package:test/test.dart';

/// A package of the workspace, as its pubspec describes it.
final class _Package {
  const _Package(this.name, {required this.published, required this.uses});

  /// Reads the pubspec [text]; a pubspec of the workspace puts its sections
  /// at the start of a line and its packages two spaces in.
  factory _Package.parse(String text) {
    String? name;
    var published = true;
    String? section;
    final uses = <String>{};
    for (final line in text.split('\n')) {
      if (RegExp(r'^name:\s*(\S+)').firstMatch(line) case final match?) {
        name = match[1];
      } else if (RegExp(r'^publish_to:\s*none\b').hasMatch(line)) {
        published = false;
      } else if (RegExp(r'^(\w+):').firstMatch(line) case final match?) {
        section = match[1];
      } else if (const {'dependencies', 'dev_dependencies'}.contains(section)) {
        if (RegExp('^  ([a-z0-9_]+):').firstMatch(line) case final match?) {
          uses.add(match[1]!);
        }
      }
    }
    return _Package(name ?? '', published: published, uses: uses);
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
  final members = <String>[];
  var inWorkspace = false;
  for (final line in File('$root/pubspec.yaml').readAsLinesSync()) {
    if (RegExp(r'^\S').hasMatch(line)) inWorkspace = line == 'workspace:';
    if (!inWorkspace) continue;
    if (RegExp(r'^  - (\S+)').firstMatch(line) case final match?) {
      members.add(match[1]!);
    }
  }
  final packages = [
    for (final member in members)
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
