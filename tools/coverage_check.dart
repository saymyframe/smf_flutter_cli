// Checks that the tests of every package cover each line and each branch of
// its lib/, as AGENTS.md asks.
//
// Run it anywhere in the repository after `melos run test:coverage`, which
// writes coverage/lcov.info in every package with a test/ directory:
// `dart tools/coverage_check.dart`. It reads the lcov.info of the packages
// that melos runs the tests of, the members of the workspace in the root
// pubspec.yaml with a test/ directory, and fails when one of them has none,
// so that it cannot pass on tests that did not run.
//
// test_with_coverage leaves out of lcov.info, with their branches, the lines
// from `// coverage:ignore-start` to `// coverage:ignore-end` and a line
// that ends with `// coverage:ignore-line`, so the check does not see them.
// A file of lib/ that no test loads is not in lcov.info either.
import 'dart:convert';
import 'dart:io';

/// The members of the workspace that the root pubspec [text] lists, by
/// their paths from the root of the repository.
List<String> workspaceMembers(String text) {
  final members = <String>[];
  var inWorkspace = false;
  for (final line in const LineSplitter().convert(text)) {
    if (RegExp(r'^\S').hasMatch(line)) {
      inWorkspace = line.trimRight() == 'workspace:';
    } else if (inWorkspace) {
      if (RegExp(r'^\s+-\s+(\S+)').firstMatch(line) case final match?) {
        members.add(match[1]!);
      }
    }
  }
  return members;
}

/// The lcov.info of each member of the workspace at [root] with a test/
/// directory, by the path of the member from [root], or `null` when the
/// member has none.
Map<String, String?> lcovsOf(String root) {
  final pubspec = File('$root/pubspec.yaml').readAsStringSync();
  return {
    for (final member in workspaceMembers(pubspec))
      if (Directory('$root/$member/test').existsSync())
        member: switch (File('$root/$member/coverage/lcov.info')) {
          final lcov when lcov.existsSync() => lcov.readAsStringSync(),
          _ => null,
        },
  };
}

/// How often the tests ran the lines and took the branches of a file.
final class _Hits {
  /// The runs of each line.
  final lines = <int, int>{};

  /// The line of each branch and how often the tests took it, by
  /// `line,block,branch`.
  final branches = <String, (int, int)>{};
}

/// The hits of each file that the lcov.info [lcov] names, by the path it
/// gives; the records of one file add up.
Map<String, _Hits> _hitsOf(String lcov) {
  final files = <String, _Hits>{};
  _Hits? file;
  for (final line in const LineSplitter().convert(lcov)) {
    final record = line.trim();
    if (record.startsWith('SF:')) {
      file = files.putIfAbsent(record.substring(3), _Hits.new);
    } else if (record == 'end_of_record') {
      file = null;
    } else if (file != null && record.startsWith('DA:')) {
      // DA:<line>,<runs>[,<checksum>]
      final [number, runs, ...] = record.substring(3).split(',');
      file.lines.update(
        int.parse(number),
        (sum) => sum + int.parse(runs),
        ifAbsent: () => int.parse(runs),
      );
    } else if (file != null && record.startsWith('BRDA:')) {
      // BRDA:<line>,<block>,<branch>,<taken>; `-` for a branch whose block
      // never ran.
      final fields = record.substring(5).split(',');
      final taken = fields.last == '-' ? 0 : int.parse(fields.last);
      final key = fields.take(3).join(',');
      final (_, sum) = file.branches[key] ?? (0, 0);
      file.branches[key] = (int.parse(fields.first), sum + taken);
    }
  }
  return files;
}

/// [path] with `/` between its parts.
String _slashed(String path) => path.replaceAll(r'\', '/');

/// The problems of the coverage of [lcovs], the lcov.info of each package by
/// the path of the package from [root], or `null` when a package has none:
/// the packages without lcov.info or without a file of lib/ in it, and for
/// each file of lib/ its lines that no test runs and the lines of its
/// branches that no test takes, as `path:line` from [root].
List<String> problemsOf(Map<String, String?> lcovs, {required String root}) {
  if (lcovs.isEmpty) {
    return ['No member of the workspace has a test/ directory.'];
  }
  final top = _slashed(root);
  final problems = <String>[];
  for (final MapEntry(key: package, value: lcov) in lcovs.entries) {
    if (lcov == null) {
      problems.add(
        'No $package/coverage/lcov.info: run melos run test:coverage first.',
      );
      continue;
    }
    final lib = '$top/$package/lib/';
    final files = <String, _Hits>{};
    for (final MapEntry(key: source, value: hits) in _hitsOf(lcov).entries) {
      final path = _slashed(source);
      final absolute = path.startsWith(RegExp('/|[A-Za-z]:/'))
          ? path
          : '$top/$package/$path';
      if (absolute.startsWith(lib)) {
        files[absolute.substring(top.length + 1)] = hits;
      }
    }
    if (files.isEmpty) {
      problems.add('$package/coverage/lcov.info names no file of lib/.');
    }
    for (final path in files.keys.toList()..sort()) {
      final hits = files[path]!;
      final lines = {
        for (final MapEntry(key: line, value: runs) in hits.lines.entries)
          if (runs == 0) line,
      };
      final branches = {
        for (final (line, taken) in hits.branches.values)
          if (taken == 0) line,
      };
      if (lines.isEmpty && branches.isEmpty) continue;
      problems.add(
        [
          path,
          for (final line in {...lines, ...branches}.toList()..sort())
            '  $path:$line${lines.contains(line) ? '' : ' (a branch)'}',
        ].join('\n'),
      );
    }
  }
  return problems;
}

void main() {
  final top = Process.runSync('git', ['rev-parse', '--show-toplevel']);
  if (top.exitCode != 0) {
    stderr.writeln('Run the check in the repository: ${top.stderr}');
    exit(2);
  }
  final root = '${top.stdout}'.trim();
  final lcovs = lcovsOf(root);
  final problems = problemsOf(lcovs, root: root);
  if (problems.isEmpty) {
    stdout.writeln(
      'The tests cover every line and branch of lib/ in '
      '${lcovs.length} packages.',
    );
    return;
  }
  stderr
    ..writeln('The coverage of lib/ is not complete:')
    ..writeln(
      problems
          .expand((problem) => problem.split('\n'))
          .map((line) => '  $line')
          .join('\n'),
    )
    ..writeln(
      'The tests must run every line and take every branch of lib/. Code '
      'that no test can run goes between // coverage:ignore-start and '
      '// coverage:ignore-end, with the reason in a comment; see AGENTS.md.',
    );
  exitCode = 1;
}
