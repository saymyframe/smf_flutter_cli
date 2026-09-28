// The install scripts run with bash here, on a PATH of fake tools that
// install nothing and reach no network: npm, Node.js, Homebrew and nvm write
// fake executables into a temporary directory, and curl and wget fail.
@TestOn('vm && !windows')
// The fake tools start with their shebang line.
// ignore_for_file: leading_newlines_in_multiline_strings
library;

import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/src/preflight/install_scripts.dart';
import 'package:test/test.dart';

/// npm, which reports as its global directory the parent of its own
/// directory, like an npm installed with Node.js, or the one that
/// `npm config set prefix` stored. As npm does, `npm install -g
/// firebase-tools` puts the Firebase CLI into its `lib/node_modules`, and a
/// link to it, the firebase command, into its `bin`.
const _npm = r'''#!/bin/sh
echo "npm $*" >> "$HOME/calls.log"
prefix="$(cd "$(dirname "$0")/.." && pwd)"
if [ -f "$HOME/npm_prefix" ]; then prefix="$(cat "$HOME/npm_prefix")"; fi
case "$1 $2" in
  "prefix -g") echo "$prefix" ;;
  "config get") echo "$prefix" ;;
  "config set") echo "$4" > "$HOME/npm_prefix" ;;
  "install -g")
    cli="$prefix/lib/node_modules/firebase-tools/lib/bin"
    mkdir -p "$prefix/bin" "$cli"
    cp "$TEMPLATES/firebase.js" "$cli/firebase.js"
    chmod +x "$cli/firebase.js"
    ln -sf ../lib/node_modules/firebase-tools/lib/bin/firebase.js \
      "$prefix/bin/firebase"
    echo "added 600 packages in 9s" ;;
  *) echo "unexpected: npm $*" >&2; exit 64 ;;
esac
''';

/// The Firebase CLI, whose shebang runs it with the node on the PATH, and
/// which stops on a Node.js older than 20, as the real one does.
const _firebase = r'''#!/usr/bin/env node
case "$FAKE_NODE" in
  v1[0-9].*)
    echo "Firebase CLI v15.14.0 is incompatible with Node.js $FAKE_NODE" >&2
    exit 1 ;;
esac
echo 15.14.0
''';

/// Node.js [version], which runs a script, such as the Firebase CLI, with
/// sh, telling it the version in `FAKE_NODE`, and prints its own path for
/// `-p process.execPath`.
String _node(String version) => '#!/bin/sh\n'
    'echo "node \$*" >> "\$HOME/calls.log"\n'
    'if [ "\$1" = -p ]; then echo "\$0"; exit 0; fi\n'
    'if [ -f "\$1" ]; then export FAKE_NODE=$version; exec /bin/sh "\$@"; fi\n'
    'echo $version\n';

/// Homebrew, which installs Node.js 22 with npm into its own directory and
/// lists the version of Node.js it has in `$HOME/brew_node`.
const _brew = r'''#!/bin/sh
echo "brew $*" >> "$HOME/calls.log"
case "$*" in
  "list --versions node") cat "$HOME/brew_node" 2>/dev/null ;;
  "install node")
    cp "$TEMPLATES/node" "$TEMPLATES/npm" "$(dirname "$0")/"
    echo "node 22.11.0" > "$HOME/brew_node" ;;
  *) exit 64 ;;
esac
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

/// The firebase command of `~/.local/bin` that runs the Firebase CLI [cli]
/// with [node].
String _firebaseCommand(String node, String cli) => '#!/usr/bin/env bash\n'
    '# Added by SMF: runs the Firebase CLI with the Node.js that installed '
    'it.\n'
    'exec $node $cli "\$@"\n';

/// The note of the firebase command of `~/.local/bin` in [home], which runs
/// the Firebase CLI with [node].
String _firebaseCommandNote(String home, String node) =>
    'Added a firebase command to $home/.local/bin, which runs the Firebase '
    'CLI with $node.';

/// The note that the firebase command [path], which did not run, still
/// does not.
String _staleNote(String path) => '$path does not run, and a new terminal '
    'may run it in place of the Firebase CLI that SMF installed: remove it.';

/// The script of the Firebase CLI in the global npm directory [prefix].
String _cliIn(String prefix) =>
    '$prefix/lib/node_modules/firebase-tools/lib/bin/firebase.js';

/// A command that would reach the network.
const _network = '#!/bin/sh\necho "network: \$0 \$*" >&2\nexit 97\n';

/// The tools that the scripts and the fakes use besides the fakes.
const _coreutils = [
  'cat',
  'chmod',
  'cp',
  'dirname',
  'grep',
  'ln',
  'mkdir',
  'readlink',
  'rm',
  'touch',
];

/// A machine for one run of a script, in a temporary directory.
final class _Machine {
  _Machine() : root = Directory.systemTemp.createTempSync('smf_scripts_') {
    home.createSync();
    templates.createSync();
    File('${templates.path}/npm').writeAsStringSync(_npm);
    File('${templates.path}/node').writeAsStringSync(_node('v22.11.0'));
    File('${templates.path}/firebase.js').writeAsStringSync(_firebase);
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
  void installNode(String name, {String version = 'v22.11.0'}) =>
      _installNodeIn(bin(name), version);

  /// Puts Node.js [version] of nvm and its npm into their directory in the
  /// nvm of the home directory, and on the PATH, as nvm does with its
  /// default Node.js in a terminal; returns the directory.
  String installNodeOfNvm(String version) => _installNodeIn(
        Directory('${home.path}/.nvm/versions/node/$version/bin')
          ..createSync(recursive: true),
        version,
      );

  String _installNodeIn(Directory directory, String version) {
    _write(directory, 'node', _node(version));
    File('${templates.path}/npm').copySync('${directory.path}/npm');
    _executable(File('${directory.path}/npm'));
    path.add(directory.path);
    return directory.path;
  }

  /// The directory with bash, for commands whose shebang looks for it on
  /// the PATH.
  String get shell {
    final directory = bin('shell');
    final bash = Link('${directory.path}/bash');
    if (!bash.existsSync()) bash.createSync('/bin/bash');
    return directory.path;
  }

  /// Puts Homebrew into the directory of executables `brew` and on the
  /// PATH, with Node.js [node] if it has one already, and returns its
  /// directory.
  String installBrew({String? node}) {
    final directory = bin('brew');
    _write(directory, 'brew', _brew);
    if (node != null) {
      File('${home.path}/brew_node').writeAsStringSync('node $node\n');
    }
    if (!path.contains(directory.path)) path.add(directory.path);
    return directory.path;
  }

  /// Puts a firebase command that does not run first on the PATH, such as
  /// one that runs the Firebase CLI of a Node.js that has none.
  void staleFirebase() {
    final directory = bin('stale');
    _write(
      directory,
      'firebase',
      '#!/bin/sh\necho "firebase of another Node.js: not found" >&2\n'
          'exit 127\n',
    );
    path.add(directory.path);
  }

  void _write(Directory directory, String name, String text) =>
      _executable(File('${directory.path}/$name')..writeAsStringSync(text));

  void _executable(File file) =>
      Process.runSync('chmod', ['+x', file.path]).exitCode == 0
          ? null
          : throw StateError('chmod failed');

  /// Runs the install script for [system] with the shell [shell], and the
  /// environment variables [variables] besides those of the machine.
  ProcessResult run(
    HostOperatingSystem system, {
    String shell = '/bin/zsh',
    Map<String, String> variables = const {},
  }) {
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
        ...variables,
      },
    );
  }

  /// Runs [command] as a new terminal of the user would, with the
  /// directories [path] first on its PATH.
  ProcessResult runInTerminal(String command, {required List<String> path}) =>
      Process.runSync(
        '/bin/bash',
        ['-c', command],
        workingDirectory: root.path,
        includeParentEnvironment: false,
        environment: {
          'PATH': [...path, shell, bin('system').path].join(':'),
          'HOME': home.path,
          'TEMPLATES': templates.path,
        },
      );

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
        'node -v',
        'npm install -g firebase-tools',
        'npm prefix -g',
        // The Firebase CLI that it installed runs.
        'node $nodeBin/firebase --version',
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
        final file = '${machine.home.path}/$profile';
        expect(notesIn('${result.stdout}'), [
          'Added $prefix/bin to the PATH in $file, for new terminals.',
        ]);
      }
    });

    test(
        'adds to the ~/.profile that bash reads, rather than a new '
        '~/.bash_profile that would hide it', () {
      machine.installNode('node');
      final prefix = '${machine.home.path}/.npm-custom';
      File('${machine.home.path}/npm_prefix').writeAsStringSync(prefix);
      File('${machine.home.path}/.profile').writeAsStringSync('umask 022\n');

      final result = machine.run(HostOperatingSystem.macos, shell: '/bin/bash');

      expect(result, succeeded(), reason: '${result.stderr}');
      expect(
        machine.homeFile('.profile'),
        'umask 022\nexport PATH="\$PATH:$prefix/bin"\n',
      );
      expect(machine.homeFile('.bash_profile'), isNull);
    });

    test('installs Node.js with Homebrew when it is missing', () {
      final brew = machine.installBrew();

      final result = machine.run(HostOperatingSystem.macos);

      expect(result, succeeded(), reason: '${result.stderr}');
      expect(machine.calls.take(3), [
        'brew list --versions node',
        'brew install node',
        'brew list --versions node',
      ]);
      expect(binDirsIn('${result.stdout}'), [brew]);
      expect(notesIn('${result.stdout}'), ['Installed Node.js with Homebrew.']);
      // New terminals have the Node.js of Homebrew.
      expect(machine.homeFile('.local/bin/firebase'), isNull);
    });

    test('installs Node.js 20 or newer when the one it finds is older', () {
      // An older Node.js of Homebrew, which it upgrades.
      machine.installNode('brew', version: 'v18.20.0');
      final brew = machine.installBrew(node: '18.20.0');

      final result = machine.run(HostOperatingSystem.macos);

      expect(result, succeeded(), reason: '${result.stderr}');
      expect(machine.calls, [
        'node -v',
        'brew list --versions node',
        'brew install node',
        'brew list --versions node',
        'node -v',
        'npm install -g firebase-tools',
        'npm prefix -g',
        'node $brew/firebase --version',
      ]);
      expect(binDirsIn('${result.stdout}'), [brew]);
      expect(notesIn('${result.stdout}'), ['Installed Node.js with Homebrew.']);
    });

    test(
        'does not say that it installed the Node.js that Homebrew had '
        'already', () {
      // An older Node.js comes before the one of Homebrew.
      machine
        ..installNode('old', version: 'v18.20.0')
        ..installBrew(node: '22.11.0');

      final result = machine.run(HostOperatingSystem.macos);

      expect(result.exitCode, isNot(0));
      expect(machine.calls, contains('brew install node'));
      expect(notesIn('${result.stdout}'), isEmpty);
    });

    test('stops when an older Node.js comes first on the PATH', () {
      machine.installNode('old', version: 'v18.20.0');
      final brew = machine.bin('brew');
      File('${brew.path}/brew').writeAsStringSync(_brew);
      Process.runSync('chmod', ['+x', '${brew.path}/brew']);
      machine.path.add(brew.path);

      final result = machine.run(HostOperatingSystem.macos);

      expect(result.exitCode, isNot(0));
      expect(
        '${result.stderr}',
        contains(
          'The Firebase CLI needs Node.js 20 or newer, but node is v18.20.0.',
        ),
      );
      expect(machine.calls, isNot(contains(startsWith('npm'))));
    });

    test('installs Node.js with nvm when there is no Homebrew', () {
      final nvm = Directory('${machine.home.path}/.nvm')..createSync();
      File('${nvm.path}/nvm.sh').writeAsStringSync(_nvm);

      final result = machine.run(HostOperatingSystem.macos);

      expect(result, succeeded(), reason: '${result.stderr}');
      final nodeBin = '${nvm.path}/versions/node/v22.11.0/bin';
      expect(machine.calls, [
        'nvm install --lts',
        'node -v',
        'node -v',
        'npm install -g firebase-tools',
        'npm prefix -g',
        // For the firebase command of ~/.local/bin.
        'node -p process.execPath',
        'node $nodeBin/firebase --version',
      ]);
      expect(binDirsIn('${result.stdout}'), [nodeBin]);
      // nvm puts the directory of its Node.js on the PATH of new terminals
      // only while it is its default one.
      final home = machine.home.path;
      final profile = '$home/.zprofile';
      expect(notesIn('${result.stdout}'), [
        'Installed the Firebase CLI with Node.js v22.11.0 of nvm.',
        _firebaseCommandNote(home, '$nodeBin/node'),
        'Added \$HOME/.local/bin to the PATH in $profile, for new terminals.',
      ]);
      expect(
        machine.homeFile('.local/bin/firebase'),
        _firebaseCommand(
          '$nodeBin/node',
          _cliIn('${nvm.path}/versions/node/v22.11.0'),
        ),
      );
      expect(
        machine.homeFile('.zprofile'),
        r'export PATH="$PATH:$HOME/.local/bin"'
        '\n',
      );
    });

    test('knows the directory of nvm when its NVM_DIR ends with a slash', () {
      final home = machine.home.path;
      final nvm = Directory('$home/.nvm')..createSync();
      File('${nvm.path}/nvm.sh').writeAsStringSync(_nvm);

      final result = machine.run(
        HostOperatingSystem.macos,
        variables: {'NVM_DIR': '$home/.nvm/'},
      );

      expect(result, succeeded(), reason: '${result.stderr}');
      expect(machine.homeFile('.local/bin/firebase'), isNotNull);
    });

    test(
        'installs Node.js with nvm, not Homebrew, and writes a firebase '
        'command that a new terminal runs with an older default Node.js of '
        'nvm', () {
      final home = machine.home.path;
      final nvm = Directory('$home/.nvm')..createSync();
      File('${nvm.path}/nvm.sh').writeAsStringSync(_nvm);
      // The default Node.js of nvm, older than 20 and without the Firebase
      // CLI, first on the PATH of the terminal, which has Homebrew too: nvm
      // puts its directory before that of Homebrew.
      final node18 = machine.installNodeOfNvm('v18.20.8');
      machine.installBrew();

      final result = machine.run(HostOperatingSystem.macos);

      expect(result, succeeded(), reason: '${result.stderr}');
      expect(machine.calls, contains('nvm install --lts'));
      expect(machine.calls, isNot(contains(startsWith('brew'))));
      final node22 = '${nvm.path}/versions/node/v22.11.0';
      expect(binDirsIn('${result.stdout}'), ['$node22/bin']);
      expect(
        machine.homeFile('.local/bin/firebase'),
        _firebaseCommand('$node22/bin/node', _cliIn(node22)),
      );
      final before = machine.runInTerminal(
        'firebase --version',
        path: [node18],
      );
      expect(before.exitCode, 127, reason: 'no firebase on the PATH');

      // A new terminal, whose profile adds ~/.local/bin to the PATH.
      final after = machine.runInTerminal(
        'firebase --version',
        path: [node18, '$home/.local/bin'],
      );

      expect(after.exitCode, 0, reason: '${after.stderr}');
      expect('${after.stdout}', '15.14.0\n');
      expect(machine.calls.last, 'node ${_cliIn(node22)} --version');
    });

    test(
        'tells about the Firebase CLI of Homebrew that the older default '
        'Node.js of nvm cannot run, which new terminals find first', () {
      final home = machine.home.path;
      final nvm = Directory('$home/.nvm')..createSync();
      File('${nvm.path}/nvm.sh').writeAsStringSync(_nvm);
      machine.installNodeOfNvm('v18.20.8');
      // The Firebase CLI of the npm of Homebrew, whose shebang runs the
      // first node on the PATH.
      final brew = machine.installBrew(node: '22.11.0');
      final cli = Directory(
        '${Directory(brew).parent.path}/lib/node_modules/firebase-tools/lib/'
        'bin',
      )..createSync(recursive: true);
      File('${cli.path}/firebase.js').writeAsStringSync(_firebase);
      Process.runSync('chmod', ['+x', '${cli.path}/firebase.js']);
      Link('$brew/firebase').createSync(
        '../lib/node_modules/firebase-tools/lib/bin/firebase.js',
      );

      final result = machine.run(HostOperatingSystem.macos);

      expect(result, succeeded(), reason: '${result.stderr}');
      expect(machine.calls, isNot(contains('brew install node')));
      expect(notesIn('${result.stdout}').last, _staleNote('$brew/firebase'));
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

    test('installs the Firebase CLI when the firebase command does not run',
        () {
      machine
        ..staleFirebase()
        ..installNode('node');

      final result = machine.run(HostOperatingSystem.macos);

      expect(result, succeeded(), reason: '${result.stderr}');
      final nodeBin = machine.bin('node').path;
      expect(machine.calls, [
        'node -v',
        'npm install -g firebase-tools',
        'npm prefix -g',
        // The one it installed comes first on the PATH.
        'node $nodeBin/firebase --version',
      ]);
      expect(binDirsIn('${result.stdout}'), [nodeBin]);
      // It stays first on the PATH of new terminals.
      expect(
        notesIn('${result.stdout}'),
        [_staleNote('${machine.bin('stale').path}/firebase')],
      );
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
        'node -p process.execPath',
        'node $home/.npm-global/bin/firebase --version',
      ]);
      expect(
        machine.homeFile('.bashrc'),
        'export PATH="\$PATH:$home/.npm-global/bin"\n'
        r'export PATH="$PATH:$HOME/.local/bin"'
        '\n',
      );
      // It runs the Firebase CLI with the Node.js that installed it.
      final node = '${machine.bin('usr').path}/node';
      expect(
        machine.homeFile('.local/bin/firebase'),
        _firebaseCommand(node, _cliIn('$home/.npm-global')),
      );
      final rc = '$home/.bashrc';
      final moved = 'Moved the global directory of npm to $home/.npm-global, '
          'in ~/.npmrc, so that it needs no sudo.';
      expect(notesIn('${result.stdout}'), [
        moved,
        'Added $home/.npm-global/bin to the PATH in $rc, for new terminals.',
        _firebaseCommandNote(home, node),
        'Added \$HOME/.local/bin to the PATH in $rc, for new terminals.',
      ]);
    });

    test(
        'runs the Firebase CLI with the Node.js behind a shim, which picks a '
        'version by the directory', () {
      // A shim of a version manager first on the PATH, which runs the
      // Node.js it picks, as asdf does.
      machine.installNode('real');
      final real = machine.path.removeLast();
      final shims = machine.bin('shims');
      for (final tool in ['node', 'npm']) {
        File('${shims.path}/$tool')
            .writeAsStringSync('#!/bin/sh\nexec "$real/$tool" "\$@"\n');
        Process.runSync('chmod', ['+x', '${shims.path}/$tool']);
      }
      machine.path.add(shims.path);

      final result = machine.run(HostOperatingSystem.linux, shell: '/bin/bash');

      expect(result, succeeded(), reason: '${result.stderr}');
      expect(
        machine.homeFile('.local/bin/firebase'),
        _firebaseCommand(
          '$real/node',
          _cliIn('${machine.home.path}/.npm-global'),
        ),
      );
    });

    test(
        'writes its firebase command in place of a link, not into the file '
        'that the link points to', () {
      machine.installNode('usr');
      final other = File('${machine.root.path}/other/firebase.js')
        ..createSync(recursive: true)
        ..writeAsStringSync('the Firebase CLI of another Node.js\n');
      final local = Directory('${machine.home.path}/.local/bin')
        ..createSync(recursive: true);
      Link('${local.path}/firebase').createSync(other.path);

      final result = machine.run(HostOperatingSystem.linux, shell: '/bin/bash');

      expect(result, succeeded(), reason: '${result.stderr}');
      expect(other.readAsStringSync(), 'the Firebase CLI of another Node.js\n');
      expect(
        FileSystemEntity.isLinkSync('${local.path}/firebase'),
        isFalse,
      );
      expect(
        machine.homeFile('.local/bin/firebase'),
        startsWith('#!/usr/bin/env bash\n'),
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
      // nvm puts the directory of its Node.js on the PATH itself.
      expect(
        machine.homeFile('.bashrc'),
        r'export PATH="$PATH:$HOME/.local/bin"'
        '\n',
      );
      expect(
        notesIn('${result.stdout}'),
        contains('Installed the Firebase CLI with Node.js v22.11.0 of nvm.'),
      );
    });

    test('needs curl or wget to install nvm, and reaches nothing here', () {
      final result = machine.run(HostOperatingSystem.linux);

      expect(result.exitCode, isNot(0));
      expect('${result.stderr}', contains('network: '));
    });

    test(
        'writes a firebase command that runs the Firebase CLI with the '
        'Node.js of nvm that installed it, which a new terminal runs with an '
        'older default Node.js of nvm', () {
      final home = machine.home.path;
      final nvm = Directory('$home/.nvm')..createSync();
      File('${nvm.path}/nvm.sh').writeAsStringSync(_nvm);
      // The default Node.js of nvm, older than 20 and without the Firebase
      // CLI, first on the PATH of the terminal.
      final node18 = machine.installNodeOfNvm('v18.20.8');
      // The firebase command of an earlier installation, which runs the
      // Firebase CLI of the Node.js of the terminal, and so fails.
      final local = Directory('$home/.local/bin')..createSync(recursive: true);
      final earlier = File('${local.path}/firebase')
        ..writeAsStringSync(
          '#!/usr/bin/env bash\nexec "\$(npm prefix -g)/bin/firebase" "\$@"\n',
        );
      Process.runSync('chmod', ['+x', earlier.path]);
      machine.path.addAll([local.path, machine.shell]);
      final before = machine.runInTerminal(
        'firebase --version',
        path: [node18, local.path],
      );
      expect(before.exitCode, isNot(0), reason: 'the earlier one fails');
      expect('${before.stderr}', contains('No such file or directory'));

      final result = machine.run(HostOperatingSystem.linux, shell: '/bin/bash');

      expect(result, succeeded(), reason: '${result.stderr}');
      final node22 = '${nvm.path}/versions/node/v22.11.0';
      final cli = _cliIn(node22);
      // Written again.
      expect(
        machine.homeFile('.local/bin/firebase'),
        _firebaseCommand('$node22/bin/node', cli),
      );
      expect(notesIn('${result.stdout}'), [
        'Installed the Firebase CLI with Node.js v22.11.0 of nvm.',
        _firebaseCommandNote(home, '$node22/bin/node'),
      ]);
      // nvm has its directory on the PATH, and ~/.local/bin was there.
      expect(machine.homeFile('.bashrc'), isNull);
      expect(binDirsIn('${result.stdout}'), ['$node22/bin']);

      // A new terminal, whose default Node.js of nvm is the older one.
      final after = machine.runInTerminal(
        'firebase --version',
        path: [node18, local.path],
      );

      expect(after.exitCode, 0, reason: '${after.stderr}');
      expect('${after.stdout}', '15.14.0\n');
      expect(machine.calls.last, 'node $cli --version');
    });

    test('installs the Firebase CLI when the firebase command does not run',
        () {
      machine
        ..staleFirebase()
        ..installNode('usr');

      final result = machine.run(HostOperatingSystem.linux, shell: '/bin/bash');

      expect(result, succeeded(), reason: '${result.stderr}');
      final home = machine.home.path;
      expect(machine.calls, [
        'node -v',
        'npm config get prefix',
        'npm config set prefix $home/.npm-global',
        'npm install -g firebase-tools',
        'npm prefix -g',
        'node -p process.execPath',
        // The one it installed comes first on the PATH.
        'node $home/.npm-global/bin/firebase --version',
      ]);
      expect(binDirsIn('${result.stdout}').first, '$home/.npm-global/bin');
      expect(
        notesIn('${result.stdout}').last,
        _staleNote('${machine.bin('stale').path}/firebase'),
      );
    });

    test(
        'tells about a Firebase CLI of the default Node.js of nvm that does '
        'not run, which new terminals find first', () {
      final home = machine.home.path;
      final nvm = Directory('$home/.nvm')..createSync();
      File('${nvm.path}/nvm.sh').writeAsStringSync(_nvm);
      // The default Node.js of nvm, older than 20, with a Firebase CLI that
      // stops on it, as npm installs one.
      final node18 = machine.installNodeOfNvm('v18.20.8');
      final prefix = Directory(node18).parent.path;
      final cli = Directory(
        '$prefix/lib/node_modules/firebase-tools/lib/bin',
      )..createSync(recursive: true);
      File('${cli.path}/firebase.js').writeAsStringSync(_firebase);
      Process.runSync('chmod', ['+x', '${cli.path}/firebase.js']);
      Link('$node18/firebase').createSync(
        '../lib/node_modules/firebase-tools/lib/bin/firebase.js',
      );

      final result = machine.run(HostOperatingSystem.linux, shell: '/bin/bash');

      expect(result, succeeded(), reason: '${result.stderr}');
      final node22 = '${nvm.path}/versions/node/v22.11.0';
      expect(binDirsIn('${result.stdout}'), ['$node22/bin']);
      const added = r'Added $HOME/.local/bin to the PATH in';
      expect(notesIn('${result.stdout}'), [
        'Installed the Firebase CLI with Node.js v22.11.0 of nvm.',
        _firebaseCommandNote(home, '$node22/bin/node'),
        '$added $home/.bashrc, for new terminals.',
        _staleNote('$node18/firebase'),
      ]);
    });
  });

  test('the Windows script prints the directories as the others do', () {
    final script = InstallScript.of(HostOperatingSystem.windows)!.text;

    expect(script, contains('npm install -g firebase-tools'));
    expect(script, contains(r'Write-Output "smf-bin-dir=$(Split-Path'));
    expect(binDirPrefix, 'smf-bin-dir=');
    expect(script, contains(r'Write-Output "smf-note=Added $pathEntry'));
    expect(notePrefix, 'smf-note=');
  });

  test('the Windows script installs Node.js 20 or newer', () {
    final script = InstallScript.of(HostOperatingSystem.windows)!.text;

    // Within the installation, after the firebase command of before is
    // noted.
    expect(
      script,
      contains(
        r'  $stalePath = $env:Path'
        '\n'
        '  if ((Get-NodeMajorVersion) -lt 20) {\n',
      ),
    );
    expect(
      script,
      contains('if ((Get-NodeMajorVersion) -lt 20) { Install-PortableNode }'),
    );
  });

  test(
      'the Windows script installs the Firebase CLI unless a firebase '
      'command runs', () {
    final script = InstallScript.of(HostOperatingSystem.windows)!.text;

    // As the other scripts do with firebase --version; a stale exit code
    // does not count, nor do errors that the command writes.
    expect(
      script,
      contains(
        'function Firebase-Runs {\n'
        '  \$firebase = Get-Command firebase -ErrorAction SilentlyContinue\n'
        '  if (-not \$firebase) { return \$false }\n',
      ),
    );
    const run = r'  try { & $firebase.Source --version *> $null } '
        r'catch { return $false }';
    expect(
      script,
      contains(
        [
          r'  $ErrorActionPreference = "Continue"',
          r'  $global:LASTEXITCODE = 1',
          run,
          r'  return ($LASTEXITCODE -eq 0)',
        ].join('\n'),
      ),
    );
    expect(script, isNot(contains("if (-not (Command-Exists 'firebase'))")));
  });

  test(
      'the Windows script tells about a firebase command that still does not '
      'run after the installation, which new terminals may find first', () {
    final script = InstallScript.of(HostOperatingSystem.windows)!.text;

    // As the other scripts do: the one found before the installation, run
    // with the PATH of before, unless the installation replaced it.
    expect(
      script,
      contains(
        'if (-not (Firebase-Runs)) {\n'
        r'  $staleCommand = Get-Command firebase -ErrorAction SilentlyContinue'
        '\n'
        r'  $stale = if ($staleCommand) { $staleCommand.Source } '
        r'else { $null }'
        '\n'
        r'  $stalePath = $env:Path'
        '\n',
      ),
    );
    expect(
      script,
      contains(
        r'  $env:Path = "$npmBin;$env:Path"'
        '\n'
        r'  Write-StaleFirebaseNote $stale $stalePath'
        '\n}\n',
      ),
    );
    expect(
      script,
      contains(
        r'  if ($installed -and $installed.Source -eq $stale) { return }',
      ),
    );
    expect(
      script,
      contains('Write-Output "smf-note=${_staleNote(r'$stale')}"'),
    );
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
