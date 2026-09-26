// The install scripts run with bash here, on a PATH of fake tools that
// install nothing and reach no network: npm, Node.js, Homebrew and nvm write
// fake executables into a temporary directory, and curl and wget fail.
@TestOn('vm && !windows')
// The fake tools start with their shebang line.
// ignore_for_file: leading_newlines_in_multiline_strings
library;

import 'dart:io';

import 'package:smf_contracts/lego.dart';
import 'package:smf_firebase_core/src/preflight/install_scripts.dart';
import 'package:test/test.dart';

/// npm, which reports as its global directory the parent of its own
/// directory, like an npm installed with Node.js, or the one that
/// `npm config set prefix` stored; `npm install -g firebase-tools` puts a
/// firebase command into its `bin`.
const _npm = r'''#!/bin/sh
echo "npm $*" >> "$HOME/calls.log"
prefix="$(cd "$(dirname "$0")/.." && pwd)"
if [ -f "$HOME/npm_prefix" ]; then prefix="$(cat "$HOME/npm_prefix")"; fi
case "$1 $2" in
  "prefix -g") echo "$prefix" ;;
  "config get") echo "$prefix" ;;
  "config set") echo "$4" > "$HOME/npm_prefix" ;;
  "install -g")
    mkdir -p "$prefix/bin"
    printf '#!/bin/sh\necho 15.14.0\n' > "$prefix/bin/firebase"
    chmod +x "$prefix/bin/firebase"
    echo "added 600 packages in 9s" ;;
  *) echo "unexpected: npm $*" >&2; exit 64 ;;
esac
''';

/// Node.js [version].
String _node(String version) => '#!/bin/sh\n'
    'echo "node \$*" >> "\$HOME/calls.log"\n'
    'echo $version\n';

/// Homebrew, which installs Node.js 22 with npm into its own directory.
const _brew = r'''#!/bin/sh
echo "brew $*" >> "$HOME/calls.log"
[ "$*" = "install node" ] || exit 64
cp "$TEMPLATES/node" "$TEMPLATES/npm" "$(dirname "$0")/"
''';

/// nvm, loaded from `$NVM_DIR/nvm.sh`, which installs Node.js 22 with npm.
const _nvm = r'''
nvm() {
  echo "nvm $*" >> "$HOME/calls.log"
  bin="$NVM_DIR/versions/node/v22.11.0/bin"
  case "$1" in
    install)
      mkdir -p "$bin"
      cp "$TEMPLATES/node" "$TEMPLATES/npm" "$bin/"
      PATH="$bin:$PATH"; export PATH ;;
    use) PATH="$bin:$PATH"; export PATH ;;
  esac
}
''';

/// A command that would reach the network.
const _network = '#!/bin/sh\necho "network: \$0 \$*" >&2\nexit 97\n';

/// The tools that the scripts and the fakes use besides the fakes.
const _coreutils = ['cat', 'chmod', 'cp', 'dirname', 'grep', 'mkdir', 'touch'];

/// A machine for one run of a script, in a temporary directory.
final class _Machine {
  _Machine() : root = Directory.systemTemp.createTempSync('smf_scripts_') {
    home.createSync();
    templates.createSync();
    File('${templates.path}/npm').writeAsStringSync(_npm);
    File('${templates.path}/node').writeAsStringSync(_node('v22.11.0'));
    templates.listSync().whereType<File>().forEach(_executable);
    for (final tool in _coreutils) {
      final path = Process.runSync('which', [tool]).stdout.toString().trim();
      Link('${bin('system').path}/$tool').createSync(path, recursive: true);
    }
    for (final tool in ['curl', 'wget']) {
      _write(bin('network'), tool, _network);
    }
  }

  final Directory root;

  Directory get home => Directory('${root.path}/home');

  Directory get templates => Directory('${root.path}/templates');

  /// The directory [name] of executables, which the PATH has.
  Directory bin(String name) =>
      Directory('${root.path}/$name/bin')..createSync(recursive: true);

  /// The directories on the PATH, the first first.
  final List<String> path = [];

  /// Puts Node.js [version] and npm into the directory of executables
  /// [name] and on the PATH.
  void installNode(String name, {String version = 'v22.11.0'}) {
    final directory = bin(name);
    _write(directory, 'node', _node(version));
    File('${templates.path}/npm').copySync('${directory.path}/npm');
    _executable(File('${directory.path}/npm'));
    path.add(directory.path);
  }

  void _write(Directory directory, String name, String text) =>
      _executable(File('${directory.path}/$name')..writeAsStringSync(text));

  void _executable(File file) =>
      Process.runSync('chmod', ['+x', file.path]).exitCode == 0
          ? null
          : throw StateError('chmod failed');

  /// Runs the install script for [system] with the shell [shell].
  ProcessResult run(HostOperatingSystem system, {String shell = '/bin/zsh'}) {
    final script = InstallScript.of(system)!;
    final file = File('${root.path}/${script.fileName}')
      ..writeAsStringSync(script.text);
    return Process.runSync(
      // The PATH of the script has no bash.
      '/bin/bash',
      [file.path],
      workingDirectory: root.path,
      includeParentEnvironment: false,
      environment: {
        'PATH': [
          ...path,
          bin('network').path,
          bin('system').path,
        ].join(':'),
        'HOME': home.path,
        'SHELL': shell,
        'TEMPLATES': templates.path,
      },
    );
  }

  /// The commands of the fakes that ran.
  List<String> get calls {
    final log = File('${home.path}/calls.log');
    return log.existsSync() ? log.readAsLinesSync() : const [];
  }

  /// The text of the file [name] in the home directory, or `null`.
  String? homeFile(String name) {
    final file = File('${home.path}/$name');
    return file.existsSync() ? file.readAsStringSync() : null;
  }

  void delete() => root.deleteSync(recursive: true);
}

void main() {
  late _Machine machine;

  setUp(() => machine = _Machine());
  tearDown(() => machine.delete());

  Matcher succeeded() => isA<ProcessResult>().having(
        (result) => result.exitCode,
        'exit code',
        0,
      );

  group('the macOS script', () {
    test('installs the Firebase CLI with the npm of the Node.js it finds', () {
      machine.installNode('node');

      final result = machine.run(HostOperatingSystem.macos);

      expect(result, succeeded(), reason: '${result.stderr}');
      final nodeBin = machine.bin('node').path;
      expect(
        binDirsIn('${result.stdout}'),
        [nodeBin],
        reason: 'npm puts firebase next to node',
      );
      expect('${result.stdout}', contains('15.14.0'));
      expect(machine.calls, [
        'npm install -g firebase-tools',
        'npm prefix -g',
      ]);
      // The directory is on the PATH already.
      expect(machine.homeFile('.zprofile'), isNull);
    });

    test(
        'adds a global npm directory that is not on the PATH to the profile '
        'of the shell of the user', () {
      machine.installNode('node');
      final prefix = '${machine.home.path}/.npm-custom';
      File('${machine.home.path}/npm_prefix').writeAsStringSync(prefix);

      for (final (shell, profile) in [
        ('/bin/zsh', '.zprofile'),
        ('/bin/bash', '.bash_profile'),
      ]) {
        final result = machine.run(HostOperatingSystem.macos, shell: shell);

        expect(result, succeeded(), reason: '${result.stderr}');
        expect(binDirsIn('${result.stdout}'), [
          '$prefix/bin',
          machine.bin('node').path,
        ]);
        expect(
          machine.homeFile(profile),
          'export PATH="\$PATH:$prefix/bin"\n',
          reason: shell,
        );
      }
    });

    test('installs Node.js with Homebrew when it is missing', () {
      final brew = machine.bin('brew');
      File('${brew.path}/brew').writeAsStringSync(_brew);
      Process.runSync('chmod', ['+x', '${brew.path}/brew']);
      machine.path.add(brew.path);

      final result = machine.run(HostOperatingSystem.macos);

      expect(result, succeeded(), reason: '${result.stderr}');
      expect(machine.calls.first, 'brew install node');
      expect(binDirsIn('${result.stdout}'), [brew.path]);
    });

    test('installs Node.js with nvm when there is no Homebrew', () {
      final nvm = Directory('${machine.home.path}/.nvm')..createSync();
      File('${nvm.path}/nvm.sh').writeAsStringSync(_nvm);

      final result = machine.run(HostOperatingSystem.macos);

      expect(result, succeeded(), reason: '${result.stderr}');
      expect(machine.calls, [
        'nvm install --lts',
        'npm install -g firebase-tools',
        'npm prefix -g',
      ]);
      expect(
        binDirsIn('${result.stdout}'),
        ['${nvm.path}/versions/node/v22.11.0/bin'],
      );
    });

    test('downloads nvm when there is no Node.js, Homebrew or nvm', () {
      final result = machine.run(HostOperatingSystem.macos);

      // The fake curl fails, so the script stops.
      expect(result.exitCode, isNot(0));
      expect('${result.stderr}', contains('network: '));
      expect(machine.calls, isEmpty);
    });

    test('changes nothing when the Firebase CLI is there already', () {
      machine.installNode('node');
      final firebase = File('${machine.bin('node').path}/firebase')
        ..writeAsStringSync('#!/bin/sh\necho 15.0.0\n');
      Process.runSync('chmod', ['+x', firebase.path]);

      final result = machine.run(HostOperatingSystem.macos);

      expect(result, succeeded(), reason: '${result.stderr}');
      expect(machine.calls, isEmpty);
      expect(binDirsIn('${result.stdout}'), [machine.bin('node').path]);
    });
  });

  group('the Linux script', () {
    test(
        'moves the global npm directory into the home directory, installs '
        'the Firebase CLI there and adds it to the PATH of new terminals', () {
      machine.installNode('usr');

      final result = machine.run(HostOperatingSystem.linux, shell: '/bin/bash');

      expect(result, succeeded(), reason: '${result.stderr}');
      final home = machine.home.path;
      expect(binDirsIn('${result.stdout}'), [
        '$home/.npm-global/bin',
        machine.bin('usr').path,
      ]);
      expect(machine.calls, [
        'node -v',
        'npm config get prefix',
        'npm config set prefix $home/.npm-global',
        'npm install -g firebase-tools',
        'npm prefix -g',
      ]);
      expect(
        machine.homeFile('.bashrc'),
        'export PATH="\$PATH:$home/.npm-global/bin"\n'
        r'export PATH="$PATH:$HOME/.local/bin"'
        '\n',
      );
      expect(
        machine.homeFile('.local/bin/firebase'),
        '#!/usr/bin/env bash\n'
        r'exec "$(npm prefix -g)/bin/firebase" "$@"'
        '\n',
      );
    });

    test('uses the rc file of zsh for zsh', () {
      machine.installNode('usr');

      final result = machine.run(HostOperatingSystem.linux);

      expect(result, succeeded(), reason: '${result.stderr}');
      expect(machine.homeFile('.zshrc'), contains('.npm-global/bin'));
      expect(machine.homeFile('.bashrc'), isNull);
    });

    test('installs Node.js with nvm when it is older than 20', () {
      machine.installNode('usr', version: 'v18.20.0');
      final nvm = Directory('${machine.home.path}/.nvm')..createSync();
      File('${nvm.path}/nvm.sh').writeAsStringSync(_nvm);

      final result = machine.run(HostOperatingSystem.linux, shell: '/bin/bash');

      expect(result, succeeded(), reason: '${result.stderr}');
      final nodeBin = '${nvm.path}/versions/node/v22.11.0/bin';
      expect(machine.calls.take(3), [
        'node -v',
        'nvm install --lts',
        'nvm use --lts',
      ]);
      // The global npm directory of nvm is in the home directory already.
      expect(machine.calls, isNot(contains(startsWith('npm config set'))));
      expect(binDirsIn('${result.stdout}'), [nodeBin]);
    });

    test('needs curl or wget to install nvm, and reaches nothing here', () {
      final result = machine.run(HostOperatingSystem.linux);

      expect(result.exitCode, isNot(0));
      expect('${result.stderr}', contains('network: '));
    });
  });

  test('the Windows script prints the directories as the others do', () {
    final script = InstallScript.of(HostOperatingSystem.windows)!.text;

    expect(script, contains('npm install -g firebase-tools'));
    expect(script, contains(r'Write-Output "smf-bin-dir=$(Split-Path'));
    expect(binDirPrefix, 'smf-bin-dir=');
  });

  test('the Windows script fails when the Firebase CLI does not run', () {
    final script = InstallScript.of(HostOperatingSystem.windows)!.text;

    // As bash does under set -e in the other scripts.
    expect(
      script,
      contains(
        '& \$firebase.Source --version\n'
        'if (\$LASTEXITCODE -ne 0) { exit \$LASTEXITCODE }\n'
        'Write-Output "smf-bin-dir=',
      ),
    );
  });
}
