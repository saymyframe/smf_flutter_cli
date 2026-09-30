// Checks that the workflows of GitHub Actions, and the scripts of
// .github/scripts, take the version of the FlutterFire CLI from
// smf_firebase_core rather than writing it themselves.
//
// firebase_core activates one version of flutterfire_cli on the machine of
// a user, and its check of the machine accepts that version or a later one
// of the same major version, as the name of the check says, such as
// `FlutterFire CLI 1.4.1 or a later 1.x`. CI activates the version of the
// module for the apps that it configures with Firebase, and finds the check
// in what `smf create --explain` says. A workflow that wrote the version,
// or the name of the check with it, would go on testing that version once
// the module moves to another, and one that activated no version would test
// the latest. So the steps take both from the module, with
// packages/smf_modules/smf_firebase_core/tool/flutterfire_version.dart, and
// the check fails when a workflow or a script activates flutterfire_cli
// with a version that it writes or with none, or writes the name of the
// check with a version, also in a regular expression, such as
// `FlutterFire CLI 1\.4\.1`.
import 'dart:io';

import 'package:test/test.dart';

/// The problems of [text], a workflow of GitHub Actions or a script of
/// .github/scripts, at [file]: each line that activates flutterfire_cli
/// with `pub global activate` of dart or flutter with a version that it
/// writes, rather than one of a variable or an expression, which starts
/// with `$`, or with none; and each line that writes the name of the check
/// of the FlutterFire CLI with a version, as text or in a regular
/// expression. A line that ends with the escape character of bash, `\`, or
/// of PowerShell, a backtick, goes on in the next, as the shell reads it.
List<String> problemsOf(String text, {required String file}) {
  final problems = <String>[];
  final lines = text.split('\n');
  for (var index = 0; index < lines.length; index++) {
    final where = '$file:${index + 1}';
    var line = lines[index];
    while (_continued.hasMatch(line) && index + 1 < lines.length) {
      line = '${line.replaceFirst(_continued, ' ')}${lines[++index]}';
    }
    for (final match in _activation.allMatches(line)) {
      switch (_versionIn(match[1]!)) {
        case null:
          problems.add(_withoutVersion(where));
        case final version when !version.startsWith(r'$'):
          problems.add(_writtenVersion(where, version));
      }
    }
    if (_checkWithVersion.firstMatch(line) case final match?) {
      problems.add(_writtenCheck(where, match[0]!));
    }
  }
  return problems;
}

/// The end of a line that goes on in the next: the escape character of
/// bash or of PowerShell.
final _continued = RegExp(r'[\\`]\r?$');

/// A command that activates flutterfire_cli, with what follows the name of
/// the package on its line.
final _activation = RegExp(
  r'''\bpub\s+global\s+activate\s+(?:[^\s;|&]+\s+)*?["']?flutterfire_cli["']?(?![\w:])(.*)''',
);

/// The version that [rest], what follows the name of the package in a
/// command that activates it, gives it: its first word that is no option,
/// without its quotes, before the command ends; `null` for none.
String? _versionIn(String rest) {
  for (final match in RegExp(r'''"([^"]*)"|'([^']*)'|([^\s;|&)#]+)|[;|&)#]''')
      .allMatches(rest)) {
    final word = match[1] ?? match[2] ?? match[3];
    // A character that ends the command, or starts a comment.
    if (word == null) return null;
    if (!word.startsWith('-')) return word;
  }
  return null;
}

/// The name of the check of the FlutterFire CLI with a version after it,
/// as `FlutterFire CLI 1.4.1`, or in a regular expression, such as
/// `FlutterFire\ CLI\ 1\.4\.1` or `FlutterFire CLI\s+1\.4\.1`.
final _checkWithVersion = RegExp(
  r'''FlutterFire(?:\s|\\s[+*]?|\\ )+CLI(?:\s|\\s[+*]?|\\ )+\d[^\s'"]*''',
);

/// Where the steps take the version of the FlutterFire CLI and the name of
/// its check from.
const _take = 'Take the version and the name of the check from '
    'packages/smf_modules/smf_firebase_core/tool/flutterfire_version.dart, '
    'which prints those of the module.';

/// The problem that [where] activates flutterfire_cli without a version.
String _withoutVersion(String where) =>
    '$where activates flutterfire_cli without a version, so CI would test '
    'the latest one rather than the one that firebase_core activates. $_take';

/// The problem that [where] activates flutterfire_cli in [version], which
/// it writes.
String _writtenVersion(String where, String version) =>
    '$where activates flutterfire_cli $version, a version that it writes, '
    'so CI would go on testing it once firebase_core activates another. '
    '$_take';

/// The problem that [where] writes the name of the check of the FlutterFire
/// CLI with a version, in [text].
String _writtenCheck(String where, String text) =>
    '$where writes the name of the check of the FlutterFire CLI with a '
    'version: $text. The name changes with the versions that firebase_core '
    'activates and accepts. $_take';

void main() {
  test(
      'finds a line that activates flutterfire_cli with a version that it '
      'writes, or with none, in bash and in PowerShell', () {
    expect(
      problemsOf(
        r'''
jobs:
  linux:
    steps:
      - run: |
          dart pub global activate flutterfire_cli 1.4.1
          flutter pub global activate flutterfire_cli '^1.4.1' --overwrite
          dart pub global activate --overwrite flutterfire_cli \
            1.5.0
          dart pub global activate flutterfire_cli && flutterfire --version
          dart pub global activate flutterfire_cli # the latest
  windows:
    steps:
      - shell: pwsh
        run: |
          dart pub global activate flutterfire_cli "1.4.1"; flutterfire --version
          dart pub global activate `
            flutterfire_cli
''',
        file: 'apps.yml',
      ),
      [
        equals(
          'apps.yml:5 activates flutterfire_cli 1.4.1, a version that it '
          'writes, so CI would go on testing it once firebase_core activates '
          'another. Take the version and the name of the check from '
          'packages/smf_modules/smf_firebase_core/tool/flutterfire_version.dart, '
          'which prints those of the module.',
        ),
        startsWith(
          'apps.yml:6 activates flutterfire_cli ^1.4.1, a version that it '
          'writes,',
        ),
        startsWith(
          'apps.yml:7 activates flutterfire_cli 1.5.0, a version that it '
          'writes,',
        ),
        equals(
          'apps.yml:9 activates flutterfire_cli without a version, so CI '
          'would test the latest one rather than the one that firebase_core '
          'activates. Take the version and the name of the check from '
          'packages/smf_modules/smf_firebase_core/tool/flutterfire_version.dart, '
          'which prints those of the module.',
        ),
        startsWith('apps.yml:10 activates flutterfire_cli without a version,'),
        startsWith(
          'apps.yml:15 activates flutterfire_cli 1.4.1, a version that it '
          'writes,',
        ),
        startsWith('apps.yml:16 activates flutterfire_cli without a version,'),
      ],
    );
  });

  test(
      'passes a line that activates flutterfire_cli with a version of a '
      'variable or an expression, and one that runs it', () {
    expect(
      problemsOf(
        r'''
          version="$(dart run packages/smf_modules/smf_firebase_core/tool/flutterfire_version.dart | jq -er .version)"
          dart pub global activate flutterfire_cli "$version"
          dart pub global activate flutterfire_cli ${VERSION} --overwrite
          dart pub global activate flutterfire_cli ${{ steps.flutterfire.outputs.version }}
          dart pub global activate flutterfire_cli $version
          dart pub global activate flutterfire_cli "$($flutterfire.version)"
          dart pub global run flutterfire_cli:flutterfire --version
          dart pub global activate flutterfire_cli_other 1.0.0
          dart pub global activate coverage; echo flutterfire_cli 1.4.1
''',
        file: 'apps.yml',
      ),
      isEmpty,
    );
  });

  test(
      'finds a line that writes the name of the check of the FlutterFire CLI '
      'with a version, also in a regular expression', () {
    expect(
      problemsOf(
        r'''
            if ($explain -match '(?m)FlutterFire CLI 1\.4\.1 or a later 1\.x \(for \w+\)\r?$') {
          grep -q 'FlutterFire CLI 1.4.1 or a later 1.x (for firebase_core)' explain.txt
          $passed = 'FlutterFire\ CLI\ 1\.5\.0'
          $explain -match 'FlutterFire\s+CLI\s+2'
''',
        file: 'apps.yml',
      ),
      [
        equals(
          'apps.yml:1 writes the name of the check of the FlutterFire CLI '
          r'with a version: FlutterFire CLI 1\.4\.1. The name changes with '
          'the versions that firebase_core activates and accepts. Take the '
          'version and the name of the check from '
          'packages/smf_modules/smf_firebase_core/tool/flutterfire_version.dart, '
          'which prints those of the module.',
        ),
        startsWith(
          'apps.yml:2 writes the name of the check of the FlutterFire CLI '
          'with a version: FlutterFire CLI 1.4.1.',
        ),
        startsWith(
          'apps.yml:3 writes the name of the check of the FlutterFire CLI '
          r'with a version: FlutterFire\ CLI\ 1\.5\.0.',
        ),
        startsWith(
          'apps.yml:4 writes the name of the check of the FlutterFire CLI '
          r'with a version: FlutterFire\s+CLI\s+2.',
        ),
      ],
    );
  });

  test('passes the FlutterFire CLI named without a version', () {
    expect(
      problemsOf(
        r'''
      - name: Install the Firebase CLI and the FlutterFire CLI
          $passed = "(?m)$([regex]::Escape($flutterfire.check)) \(for \w+\)\r?$"
          throw "SMF does not find the FlutterFire CLI for $app."
''',
        file: 'apps.yml',
      ),
      isEmpty,
    );
  });

  test(
      'the workflows and the scripts of the repository take the version of '
      'the FlutterFire CLI from firebase_core', () {
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

    // CI activates the FlutterFire CLI, so the check has something to find.
    expect(
      [
        for (final MapEntry(:key, :value) in files.entries)
          if (_activation.hasMatch(value)) key,
      ],
      isNotEmpty,
    );
    expect(
      [
        for (final MapEntry(:key, :value) in files.entries)
          ...problemsOf(value, file: key),
      ],
      isEmpty,
    );
  });
}
