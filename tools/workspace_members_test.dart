import 'package:test/test.dart';

import 'workspace_members.dart';

void main() {
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
}
