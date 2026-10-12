// Checks that the workflows of GitHub Actions, and the scripts of
// .github/scripts, install the Firebase CLI without a version that they
// write.
//
// A module may run a command that only newer versions of the Firebase CLI
// have, as firebase_auth does to enable the sign-in methods of an app. The
// module knows the first version with its command: its check of the
// machine holds its step back with an older Firebase CLI, and the script
// of the app stops there with what to do. CI installs the latest Firebase
// CLI, which has every such command. A workflow that wrote a version would
// go on installing it once a module needs a later one, and the jobs that
// run the command of the module would stop at the Firebase CLI. So the
// check fails when a workflow or a script installs or runs firebase-tools
// of npm in a version that it writes, such as `firebase-tools@15.5.0`.
import 'dart:io';

import 'package:test/test.dart';

/// The problems of [text], a workflow of GitHub Actions or a script of
/// .github/scripts, at [file]: each line that names the package
/// firebase-tools of npm with a version that it writes, as
/// `npm install --global firebase-tools@15.5.0` and `npx firebase-tools@15`
/// do. The latest one, `firebase-tools@latest`, and a version of a variable
/// or an expression, which starts with `$`, are none.
List<String> problemsOf(String text, {required String file}) => [
      for (final (index, line) in text.split('\n').indexed)
        for (final match in _withVersion.allMatches(line))
          if (match[1] case final version?
              when version != 'latest' && !version.startsWith(r'$'))
            _writtenVersion('$file:${index + 1}', version),
    ];

/// The problem that [where] installs the Firebase CLI in [version], which
/// it writes.
String _writtenVersion(String where, String version) =>
    '$where installs the Firebase CLI as firebase-tools@$version, a version '
    'that it writes, so CI would go on installing it once the command of a '
    'module needs a later one. Install the latest, as `npm install --global '
    'firebase-tools` does: a module that needs a version checks for it '
    'itself.';

/// The package firebase-tools with a version after `@`, up to where the
/// word ends in bash or PowerShell.
final _withVersion = RegExp(r'''\bfirebase-tools@([^\s"'`;|&)]+)''');

void main() {
  test(
      'finds a line that installs or runs firebase-tools in a version that '
      'it writes, in bash and in PowerShell', () {
    expect(
      problemsOf(
        '''
jobs:
  linux:
    steps:
      - run: |
          npm install --global firebase-tools@15.5.0
          npm i -g "firebase-tools@^15" && firebase --version
          npx firebase-tools@13.2.1 deploy --only auth
          yarn global add firebase-tools@15.6.0; firebase --version
  windows:
    steps:
      - shell: pwsh
        run: |
          npm install --global 'firebase-tools@15.14.0'
''',
        file: 'apps.yml',
      ),
      [
        equals(
          'apps.yml:5 installs the Firebase CLI as firebase-tools@15.5.0, a '
          'version that it writes, so CI would go on installing it once the '
          'command of a module needs a later one. Install the latest, as '
          '`npm install --global firebase-tools` does: a module that needs a '
          'version checks for it itself.',
        ),
        startsWith(
          'apps.yml:6 installs the Firebase CLI as firebase-tools@^15, a',
        ),
        startsWith(
          'apps.yml:7 installs the Firebase CLI as firebase-tools@13.2.1,',
        ),
        startsWith(
          'apps.yml:8 installs the Firebase CLI as firebase-tools@15.6.0,',
        ),
        startsWith(
          'apps.yml:13 installs the Firebase CLI as firebase-tools@15.14.0,',
        ),
      ],
    );
  });

  test(
      'passes a line that installs the latest Firebase CLI, or a version of '
      'a variable or an expression, and one that only runs it', () {
    expect(
      problemsOf(
        r'''
          npm install --global firebase-tools
          npm install --global firebase-tools@latest
          npm install --global "firebase-tools@$version"
          npm install --global firebase-tools@${{ steps.firebase.outputs.version }}
          curl -sL https://firebase.tools | bash
          firebase --version
          echo "firebase-tools is installed"
''',
        file: 'apps.yml',
      ),
      isEmpty,
    );
  });

  test(
      'the workflows and the scripts of the repository install the Firebase '
      'CLI without a version that they write', () {
    final top = Process.runSync('git', ['rev-parse', '--show-toplevel']);
    expect(top.exitCode, 0, reason: '${top.stderr}');
    final root = '${top.stdout}'.trim();
    final files = {
      for (final (directory, pattern) in [
        ('workflows', RegExp(r'\.ya?ml$')),
        ('scripts', RegExp(r'\.(sh|ps1)$')),
      ])
        for (final entity in Directory('$root/.github/$directory').listSync())
          if (entity is File && pattern.hasMatch(entity.path))
            '.github/$directory/${entity.uri.pathSegments.last}':
                entity.readAsStringSync(),
    };

    // A step installs it for the jobs that configure the apps with
    // Firebase, so the check reads what it checks.
    expect(
      [
        for (final text in files.values)
          if (text.contains('firebase-tools')) text,
      ],
      isNotEmpty,
    );
    expect(
      [
        for (final MapEntry(key: file, value: text) in files.entries)
          ...problemsOf(text, file: file),
      ],
      isEmpty,
    );
  });
}
