import 'dart:io';

import 'package:test/test.dart';

import 'coverage_check.dart';

/// An lcov.info record of the file [path] with the runs of its lines and
/// the branches taken, as test_with_coverage writes it.
String _record(
  String path, {
  Map<int, int> lines = const {},
  Map<int, String> branches = const {},
}) =>
    [
      'SF:$path',
      for (final MapEntry(key: line, value: runs) in lines.entries)
        'DA:$line,$runs',
      'LF:${lines.length}',
      'LH:${lines.values.where((runs) => runs > 0).length}',
      for (final MapEntry(key: line, value: taken) in branches.entries)
        'BRDA:$line,0,0,$taken',
      'end_of_record',
      '',
    ].join('\n');

/// The problem of the file [path] from the root of the repository: each of
/// its [lines] that no test runs, or with ` (a branch)` a branch there that
/// no test takes.
String _file(String path, List<String> lines) =>
    [path, for (final line in lines) '  $path:$line'].join('\n');

void main() {
  const a = 'packages/a';

  test('passes a package whose tests run every line and take every branch', () {
    expect(
      problemsOf(
        {
          a: _record(
            '/repo/$a/lib/a.dart',
            lines: {3: 1, 4: 2},
            branches: {3: '1', 4: '2'},
          ),
        },
        root: '/repo',
      ),
      isEmpty,
    );
  });

  test('reports the lines that no test runs and the branches no test takes',
      () {
    final lcov = _record(
          '/repo/$a/lib/b.dart',
          lines: {3: 1, 5: 0, 7: 1, 9: 0},
          branches: {3: '1', 5: '0', 7: '0', 8: '-'},
        ) +
        _record('/repo/$a/lib/a.dart', lines: {2: 0});

    expect(problemsOf({a: lcov}, root: '/repo'), [
      _file('$a/lib/a.dart', ['2']),
      _file('$a/lib/b.dart', ['5', '7 (a branch)', '8 (a branch)', '9']),
    ]);
  });

  test('reads the branches of one line apart, and the checksums of lines', () {
    const lcov = 'SF:/repo/$a/lib/a.dart\n'
        'DA:3,1,5d41402abc4b2a76\n'
        'DA:5,1\n'
        'DA:7,1\n'
        'BRDA:5,0,0,1\n'
        'BRDA:5,0,1,0\n'
        'BRDA:7,0,0,1\n'
        'BRDA:7,1,0,1\n'
        'end_of_record\n';

    expect(problemsOf({a: lcov}, root: '/repo'), [
      _file('$a/lib/a.dart', ['5 (a branch)']),
    ]);
  });

  test('adds up the records of one file', () {
    final lcov = _record(
          '/repo/$a/lib/a.dart',
          lines: {3: 0, 4: 0},
          branches: {3: '0', 4: '-'},
        ) +
        _record(
          '/repo/$a/lib/a.dart',
          lines: {3: 1, 4: 0},
          branches: {3: '1', 4: '-'},
        );

    expect(problemsOf({a: lcov}, root: '/repo'), [
      _file('$a/lib/a.dart', ['4']),
    ]);
  });

  test('reads only the files of lib/ of the package', () {
    final lcov = [
      _record('/repo/$a/lib/a.dart', lines: {1: 1}),
      _record('/repo/$a/test/a_test.dart', lines: {1: 0}),
      _record('/repo/$a/library/a.dart', lines: {1: 0}),
      _record('/repo/$a/bin/a.dart', lines: {1: 0}),
      _record('/repo/packages/b/lib/b.dart', lines: {1: 0}),
      _record('/elsewhere/$a/lib/a.dart', lines: {1: 0}),
      // A path from the package.
      _record('lib/src/c.dart', lines: {1: 0}),
    ].join();

    expect(problemsOf({a: lcov}, root: '/repo'), [
      _file('$a/lib/src/c.dart', ['1']),
    ]);
  });

  test('reads the paths of Windows', () {
    final lcov = _record(r'C:\repo\packages\a\lib\a.dart', lines: {1: 0});

    expect(problemsOf({a: lcov}, root: 'C:/repo'), [
      _file('$a/lib/a.dart', ['1']),
    ]);
  });

  test('reports a package without lcov.info or without a file of lib/ in it',
      () {
    expect(
      problemsOf(
        {
          a: null,
          'packages/b': _record('/repo/packages/b/test/b_test.dart'),
          'packages/c': '',
        },
        root: '/repo',
      ),
      [
        'No $a/coverage/lcov.info: run melos run test:coverage first.',
        'packages/b/coverage/lcov.info names no file of lib/.',
        'packages/c/coverage/lcov.info names no file of lib/.',
      ],
    );
    expect(
      problemsOf({}, root: '/repo'),
      ['No member of the workspace has a test/ directory.'],
    );
  });

  test('reads the members of the workspace', () {
    expect(
      workspaceMembers(
        'name: root\r\n'
        'workspace:\r\n'
        '  - packages/a\r\n'
        '  # A comment.\r\n'
        '  - packages/a/b\r\n'
        '\r\n'
        '  -   packages/c\r\n'
        'dev_dependencies:\r\n'
        '  - packages/d\r\n',
      ),
      ['packages/a', 'packages/a/b', 'packages/c'],
    );
  });

  test('reads the members of the workspace as YAML, with comments and quotes',
      () {
    expect(
      workspaceMembers(
        'name: root\n'
        'workspace: # The packages of the repository.\n'
        '  - packages/a\n'
        '  - "packages/b"\n'
        "  - 'packages/c' # A comment.\n"
        'dev_dependencies:\n'
        '  yaml: any\n',
      ),
      ['packages/a', 'packages/b', 'packages/c'],
    );
    expect(
      workspaceMembers('workspace: [packages/a, "packages/b"]\n'),
      ['packages/a', 'packages/b'],
    );
  });

  test(
      'fails on a member with the syntax of a glob, which pub expands from '
      'language version 3.11 on and the tools do not', () {
    for (final glob in [
      'packages/*',
      'packages/**',
      'packages/smf_?',
      'packages/[ab]',
      'packages/{a,b}',
      r'packages/a\b',
      'packages/a(b)',
      'packages/a]b',
    ]) {
      expect(
        () => workspaceMembers("workspace:\n  - packages/a\n  - '$glob'\n"),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            allOf(contains(glob), contains('glob')),
          ),
        ),
        reason: glob,
      );
    }
    // A glob reads these as themselves.
    expect(
      workspaceMembers('workspace:\n  - packages/smf-a\n  - packages/a,b\n'),
      ['packages/smf-a', 'packages/a,b'],
    );
  });

  test('fails on a pubspec without members, and on a member that is no path',
      () {
    for (final pubspec in [
      'name: root\n',
      'workspace:\n',
      'workspace: []\n',
      'workspace: packages/a\n',
      'workspace:\n  - packages/a\n  - 3\n',
      'workspace:\n  - packages/a\n  -\n',
      'workspace:\n  - path: packages/a\n',
    ]) {
      expect(
        () => workspaceMembers(pubspec),
        throwsFormatException,
        reason: pubspec,
      );
    }
  });

  test(
      'reads the lcov.info of every member that the root pubspec lists, with '
      'comments and quotes', () {
    final root = Directory.systemTemp.createTempSync('coverage_check_');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/pubspec.yaml').writeAsStringSync(
      'name: root\n'
      'workspace: # The packages of the repository.\n'
      '  - packages/a\n'
      '  - "packages/b"\n',
    );
    for (final package in ['a', 'b']) {
      Directory('${root.path}/packages/$package/test')
          .createSync(recursive: true);
      File('${root.path}/packages/$package/coverage/lcov.info')
        ..createSync(recursive: true)
        ..writeAsStringSync('SF:$package\n');
    }

    expect(
      lcovsOf(root.path),
      {'packages/a': 'SF:a\n', 'packages/b': 'SF:b\n'},
    );
  });

  test('reads the lcov.info of the members with a test/ directory', () {
    final root = Directory.systemTemp.createTempSync('coverage_check_');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/pubspec.yaml').writeAsStringSync(
      'workspace:\n'
      '  - packages/a\n'
      '  - packages/b\n'
      '  - packages/c\n',
    );
    Directory('${root.path}/packages/a/test').createSync(recursive: true);
    File('${root.path}/packages/a/coverage/lcov.info')
      ..createSync(recursive: true)
      ..writeAsStringSync('SF:a\n');
    // Tests that did not write lcov.info.
    Directory('${root.path}/packages/b/test').createSync(recursive: true);
    // No tests, but an lcov.info of old ones.
    File('${root.path}/packages/c/coverage/lcov.info')
      ..createSync(recursive: true)
      ..writeAsStringSync('SF:c\n');

    expect(lcovsOf(root.path), {'packages/a': 'SF:a\n', 'packages/b': null});
  });

  test('finds the packages of this repository that melos runs the tests of',
      () {
    final top = Process.runSync('git', ['rev-parse', '--show-toplevel']);
    expect(top.exitCode, 0, reason: '${top.stderr}');
    final packages = lcovsOf('${top.stdout}'.trim()).keys;

    expect(
      packages,
      containsAll([
        'packages/smf_contracts',
        'packages/smf_pipeline',
        'packages/smf_pipeline/fixture_registry',
        'packages/smf_flutter_cli',
        'packages/smf_modules/smf_go_router',
      ]),
    );
  });
}
