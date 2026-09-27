@TestOn('vm')
library;

import 'package:file/memory.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:test/test.dart';

import 'support/fake_machine.dart';

const _dart = '/sdk/bin/dart';
const _firebase = '/opt/npm/bin/firebase';

/// The options of `flutterfire configure`, with the ids of the app.
const _options = '--platforms=android,ios --overwrite-firebase-options '
    '--ios-bundle-id=com.example.my-app '
    '--android-package-name=com.example.my_app';

/// `flutterfire configure` as the steps of the Flutter SDK run it.
const _configure =
    '$_dart pub global run flutterfire_cli:flutterfire configure $_options';

/// `flutterfire configure` as the user types it later.
const _later =
    'dart pub global run flutterfire_cli:flutterfire configure $_options';

/// The question whether to configure Firebase now.
const _configureNow = 'Configuring Firebase with flutterfire ($_later), for '
    'firebase_core. Run it now?';

/// The question whether to activate flutterfire_cli.
const _flutterfireMissing = 'FlutterFire CLI 1.4.1 or a later 1.x is missing '
    '(needed by firebase_core). Install it now?';

/// The activation of flutterfire_cli.
const _activate = '$_dart pub global activate flutterfire_cli 1.4.1';

/// What the check says about flutterfire_cli 1.4.0.
const _tooOld = 'flutterfire_cli 1.4.0 is active, but SMF works with 1.4.1 or '
    'a later 1.x version: activate one with "dart pub global activate '
    'flutterfire_cli 1.4.1".';

/// The warning that Firebase is not configured, because of [reason].
String _notConfigured(String reason) =>
    'Configuring Firebase with flutterfire is not done, because $reason. Run '
    'it in the app: $_later';

/// The path of an install script of the Firebase CLI in a command.
final _script = RegExp(r'/[^ ]*/install_firebase_\w+\.sh$');

/// A machine with a Flutter SDK, bash and Ruby with xcodeproj 1.27.0, or
/// without the gem unless [xcodeproj], on which `smf create` runs in a
/// terminal; the app goes to `/work/my_app`. It runs macOS unless
/// [operatingSystem] says otherwise.
///
/// The Firebase CLI is missing until the install script puts `firebase`
/// into `/opt/npm/bin`, and `firebase login` logs in unless it exits with
/// [loginCode]. flutterfire_cli is not active, or in version [flutterfire],
/// until `dart pub global activate` activates flutterfire_cli 1.4.1. Every
/// other command succeeds.
final class _Machine {
  _Machine({
    List<bool> confirmations = const [],
    this.hasTerminal = true,
    this.loginCode = 0,
    this.xcodeproj = true,
    this.flutterfire,
    this.operatingSystem = HostOperatingSystem.macos,
  }) {
    files.directory('/sdk/bin/cache/dart-sdk').createSync(recursive: true);
    files.file('/sdk/bin/cache/flutter.version.json').writeAsStringSync(
          '{"flutterVersion": "3.44.2", "dartSdkVersion": "3.12.2"}',
        );
    for (final tool in ['/sdk/bin/flutter', _dart, '/bin/bash', '/bin/ruby']) {
      files.file(tool).createSync(recursive: true);
    }
    files.directory('/work').createSync();
    files.currentDirectory = '/work';
    fake = FakeMachine(
      operatingSystem: operatingSystem,
      reply: _reply,
      confirmations: confirmations,
    );
  }

  final files = MemoryFileSystem.test();
  final bool hasTerminal;
  final int loginCode;
  final bool xcodeproj;
  final String? flutterfire;
  final HostOperatingSystem operatingSystem;
  late final FakeMachine fake;
  var _loggedIn = false;
  var _activated = false;

  SmfProcessResult _reply(Call call) {
    final line = call.line;
    if (_script.hasMatch(line)) {
      files.file(_firebase).createSync(recursive: true);
      return const SmfProcessResult(
        exitCode: 0,
        stdout: 'smf-bin-dir=/opt/npm/bin\nsmf-bin-dir=/opt/node/bin\n',
      );
    }
    if (line == '$_firebase login:list --json') {
      return SmfProcessResult(
        exitCode: 0,
        stdout: _loggedIn
            ? '{"status": "success", "result": [{"user": {}}]}'
            : '{"status": "success"}',
      );
    }
    if (line == '$_firebase login') {
      _loggedIn = loginCode == 0;
      return SmfProcessResult(exitCode: loginCode);
    }
    if (line == '$_dart pub global list') {
      final active = _activated ? '1.4.1' : flutterfire;
      return SmfProcessResult(
        exitCode: 0,
        stdout: 'melos 7.5.1\n'
            '${active == null ? '' : 'flutterfire_cli $active\n'}',
      );
    }
    if (line == _activate) {
      _activated = true;
    }
    if (line.startsWith('/bin/ruby ')) {
      return xcodeproj
          ? const SmfProcessResult(exitCode: 0, stdout: '1.27.0')
          : const SmfProcessResult(
              exitCode: 1,
              stderr: 'cannot load such file -- xcodeproj (LoadError)',
            );
    }
    return const SmfProcessResult(exitCode: 0);
  }

  /// Runs `smf create my_app -m firebase_core` with [options].
  Future<int> create([List<String> options = const []]) => runSmf(
        [
          'create',
          'my_app',
          '-m',
          'firebase_core',
          '--org',
          'com.example',
          ...options,
        ],
        modules: const [FlutterCoreModule(), FirebaseCoreModule()],
        hostFor: ({required verbose}) => SmfHost(
          prompter: fake.prompter,
          processRunner: fake.processRunner,
          logger: fake.logger,
          fileSystem: files,
          environmentVariables: const {'PATH': '/sdk/bin:/bin'},
          operatingSystem: operatingSystem,
          hasTerminal: hasTerminal,
        ),
      );

  /// The commands that ran but those of the Flutter SDK after generation.
  List<String> get checks => [
        for (final call in fake.calls)
          if (!call.line.startsWith('/sdk/bin/flutter') &&
              !call.line.startsWith('$_dart fix') &&
              !call.line.startsWith('$_dart format'))
            call.line.replaceFirst(_script, '<script>'),
      ];

  /// The warnings that the run printed.
  List<String> get warnings => _reports('warn: ');

  /// What the run printed as information, such as the lines of `--explain`.
  List<String> get infos => _reports('info: ');

  List<String> _reports(String kind) => [
        for (final report in fake.reports)
          if (report.startsWith(kind)) report.substring(kind.length),
      ];
}

void main() {
  test(
      'a user who declines to install the CLIs gets no installation, but '
      'instructions, and the app', () async {
    final machine = _Machine(confirmations: [false, false]);

    final code = await machine.create();

    expect(code, SmfExitCodes.success, reason: machine.fake.reports.join('\n'));
    // Each is asked once: no is no. flutterfire configure would fail without
    // them, so it is not asked about.
    expect(machine.fake.questions, [
      'Firebase CLI is missing (needed by firebase_core). Install it now?',
      _flutterfireMissing,
    ]);
    expect(machine.checks, [
      '$_dart pub global list',
      "/bin/ruby -e require 'xcodeproj'; print Xcodeproj::VERSION",
    ]);
    expect(machine.warnings, [
      contains('Firebase CLI is missing. Install it with "npm install -g '
          'firebase-tools"'),
      contains('Firebase login is missing. Install the Firebase CLI, then log '
          'in with "firebase login", or on a remote machine, such as over SSH, '
          'with "firebase login --no-localhost".'),
      contains('FlutterFire CLI 1.4.1 or a later 1.x is missing. Activate it '
          'with "dart pub global activate flutterfire_cli 1.4.1".'),
      _notConfigured(
        'Firebase CLI, Firebase login and FlutterFire CLI 1.4.1 or a later '
        '1.x are missing',
      ),
    ]);
    expect(
      machine.files.file('/work/my_app/lib/firebase_options.dart').existsSync(),
      isTrue,
    );
  });

  test(
      'a user who agrees gets the Firebase CLI, a login and the FlutterFire '
      'CLI, each checked again after the one before', () async {
    final machine = _Machine(confirmations: [true, true, true, true]);

    final code = await machine.create();

    expect(code, SmfExitCodes.success, reason: machine.fake.reports.join('\n'));
    expect(machine.fake.questions, [
      'Firebase CLI is missing (needed by firebase_core). Install it now?',
      'Firebase login is missing (needed by firebase_core). Install it now?',
      _flutterfireMissing,
      _configureNow,
    ]);
    expect(machine.checks, [
      '$_dart pub global list',
      "/bin/ruby -e require 'xcodeproj'; print Xcodeproj::VERSION",
      '/bin/bash <script>',
      // The login is checked once the Firebase CLI is there.
      '$_firebase login:list --json',
      '$_firebase login',
      '$_firebase login:list --json',
      '$_dart pub global list',
      _activate,
      '$_dart pub global list',
      _configure,
    ]);
    final login = machine.fake.calls.firstWhere(
      (call) => call.line == '$_firebase login',
    );
    expect(login.interactive, isTrue);
    // The Firebase CLI runs on the Node.js that the script found.
    expect(
      login.environment['PATH'],
      startsWith('/sdk/bin:/opt/npm/bin:/opt/node/bin:'),
    );
    expect(machine.warnings, isEmpty);

    // After flutter pub get, in the temporary directory of the app, with the
    // terminal, and with the Firebase CLI on the PATH.
    final calls = machine.fake.calls;
    final configure = calls.singleWhere((call) => call.line == _configure);
    final pubGet = calls.indexWhere(
      (call) => call.line == '/sdk/bin/flutter pub get',
    );
    expect(calls.indexOf(configure), greaterThan(pubGet));
    expect(configure.interactive, isTrue);
    expect(configure.workingDirectory, endsWith('/my_app'));
    expect(configure.workingDirectory, isNot('/work/my_app'));
    expect(configure.environment['PATH'], contains('/opt/npm/bin'));
  });

  test('a login that fails leaves a warning that says how it ended', () async {
    final machine = _Machine(confirmations: [true, true, false], loginCode: 1);

    final code = await machine.create();

    expect(code, SmfExitCodes.success, reason: machine.fake.reports.join('\n'));
    expect(machine.checks, [
      '$_dart pub global list',
      "/bin/ruby -e require 'xcodeproj'; print Xcodeproj::VERSION",
      '/bin/bash <script>',
      '$_firebase login:list --json',
      '$_firebase login',
      '$_dart pub global list',
    ]);
    expect(machine.warnings, [
      contains('Firebase login could not be checked: The installation '
          'failed: "firebase login" exited with code 1.'),
      contains('FlutterFire CLI 1.4.1 or a later 1.x is missing.'),
      _notConfigured(
        'FlutterFire CLI 1.4.1 or a later 1.x is missing, and Firebase login '
        'could not be checked',
      ),
    ]);
  });

  test(
      'a Mac without the gem xcodeproj leaves the configuration for later '
      'without asking', () async {
    final machine =
        _Machine(confirmations: [true, true, true], xcodeproj: false);

    final code = await machine.create();

    expect(code, SmfExitCodes.success, reason: machine.fake.reports.join('\n'));
    expect(machine.fake.questions, hasLength(3));
    expect(machine.checks, isNot(contains(_configure)));
    expect(machine.warnings, [
      contains('Xcode project tools of flutterfire is missing. flutterfire '
          'configure changes the Xcode project with the Ruby gem xcodeproj'),
      _notConfigured('Xcode project tools of flutterfire is missing'),
    ]);
  });

  test(
      'elsewhere than on macOS, flutterfire configure runs without the tools '
      'of Xcode, and the Xcode project is left for a Mac', () async {
    final machine = _Machine(
      confirmations: [true, true, true, true],
      operatingSystem: HostOperatingSystem.linux,
    );

    final code = await machine.create();

    expect(code, SmfExitCodes.success, reason: machine.fake.reports.join('\n'));
    expect(machine.fake.questions.last, _configureNow);
    expect(machine.checks, [
      '$_dart pub global list',
      '/bin/bash <script>',
      '$_firebase login:list --json',
      '$_firebase login',
      '$_firebase login:list --json',
      '$_dart pub global list',
      _activate,
      '$_dart pub global list',
      _configure,
    ]);
    expect(machine.warnings, [
      contains('Setup of the Xcode project on a Mac is missing. flutterfire '
          'configure changes the Xcode project only on macOS.'),
    ]);
  });

  test('a run that skips external setup installs nothing and asks nothing',
      () async {
    final machine = _Machine();

    final code = await machine.create(['--skip-external-setup']);

    expect(code, SmfExitCodes.success, reason: machine.fake.reports.join('\n'));
    expect(machine.fake.questions, isEmpty);
    expect(machine.checks, [
      '$_dart pub global list',
      "/bin/ruby -e require 'xcodeproj'; print Xcodeproj::VERSION",
    ]);
    expect(machine.warnings, [
      ...List.filled(3, contains('is missing.')),
      _notConfigured('the run skips external setup'),
    ]);
  });

  test('a run without a terminal prints the command to configure Firebase',
      () async {
    final machine = _Machine(hasTerminal: false);

    final code = await machine.create();

    expect(code, SmfExitCodes.success, reason: machine.fake.reports.join('\n'));
    expect(machine.fake.questions, isEmpty);
    expect(
      machine.warnings.last,
      _notConfigured('the run cannot ask the user'),
    );
    expect(machine.checks, isNot(contains(_configure)));
  });

  group('with flutterfire_cli 1.4.0 active', () {
    test(
        'a user who agrees gets 1.4.1 in its place, and Firebase configured '
        'with it', () async {
      final machine = _Machine(
        confirmations: [true, true, true, true],
        flutterfire: '1.4.0',
      );

      final code = await machine.create();

      expect(
        code,
        SmfExitCodes.success,
        reason: machine.fake.reports.join('\n'),
      );
      expect(machine.fake.questions, [
        'Firebase CLI is missing (needed by firebase_core). Install it now?',
        'Firebase login is missing (needed by firebase_core). Install it now?',
        _flutterfireMissing,
        _configureNow,
      ]);
      expect(
        machine.checks,
        containsAllInOrder([
          '$_dart pub global list',
          _activate,
          '$_dart pub global list',
          _configure,
        ]),
      );
      expect(machine.warnings, isEmpty);
    });

    test(
        'a user who keeps it gets the configuration for later, with the '
        'reason', () async {
      final machine = _Machine(
        confirmations: [true, true, false],
        flutterfire: '1.4.0',
      );

      final code = await machine.create();

      expect(
        code,
        SmfExitCodes.success,
        reason: machine.fake.reports.join('\n'),
      );
      expect(machine.fake.questions.last, _flutterfireMissing);
      expect(machine.checks, isNot(contains(_activate)));
      expect(machine.checks, isNot(contains(_configure)));
      expect(machine.warnings, [
        contains('FlutterFire CLI 1.4.1 or a later 1.x is missing. $_tooOld'),
        _notConfigured('FlutterFire CLI 1.4.1 or a later 1.x is missing'),
      ]);
    });
  });

  test(
      'with flutterfire_cli 2.0.0 active, a run asks nothing about it, keeps '
      'it and leaves the configuration for later', () async {
    final machine = _Machine(
      confirmations: [true, true],
      flutterfire: '2.0.0',
    );

    final code = await machine.create();

    expect(code, SmfExitCodes.success, reason: machine.fake.reports.join('\n'));
    expect(machine.fake.questions, [
      'Firebase CLI is missing (needed by firebase_core). Install it now?',
      'Firebase login is missing (needed by firebase_core). Install it now?',
    ]);
    expect(machine.checks, isNot(contains(_activate)));
    expect(machine.checks, isNot(contains(_configure)));
    expect(machine.warnings, [
      contains('FlutterFire CLI 1.4.1 or a later 1.x is missing. '
          'flutterfire_cli 2.0.0 is active, but SMF works with 1.4.1 or a '
          'later 1.x version, and does not replace a newer one'),
      _notConfigured('FlutterFire CLI 1.4.1 or a later 1.x is missing'),
    ]);
  });

  test(
      '--explain shows flutterfire_cli 1.4.0 as missing and 1.4.1 as there, '
      'and changes nothing', () async {
    const check = 'FlutterFire CLI 1.4.1 or a later 1.x (for firebase_core)';
    for (final (active, lines) in [
      (
        '1.4.0',
        [
          '  ✗ $check: missing',
          '    $_tooOld',
          '    An interactive run offers to install it.',
        ]
      ),
      ('1.4.1', ['  ✓ $check']),
    ]) {
      final machine = _Machine(flutterfire: active);

      final code = await machine.create(['--explain']);

      expect(
        code,
        SmfExitCodes.success,
        reason: machine.fake.reports.join('\n'),
      );
      expect(machine.infos, containsAllInOrder(lines), reason: active);
      expect(machine.fake.questions, isEmpty);
      expect(machine.checks, isNot(contains(_activate)));
      expect(machine.files.directory('/work/my_app').existsSync(), isFalse);
    }
  });
}
