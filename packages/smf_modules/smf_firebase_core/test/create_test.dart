@TestOn('vm')
library;

import 'package:file/memory.dart';
import 'package:smf_contracts/lego.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:test/test.dart';

import 'support/fake_machine.dart';

const _dart = '/sdk/bin/dart';
const _firebase = '/opt/npm/bin/firebase';

/// `flutterfire configure` as the steps of the Flutter SDK run it.
const _configure = '$_dart pub global run flutterfire_cli:flutterfire '
    'configure --platforms=android,ios --overwrite-firebase-options';

/// `flutterfire configure` as the user types it later.
const _later = 'dart pub global run flutterfire_cli:flutterfire configure '
    '--platforms=android,ios --overwrite-firebase-options';

/// The question whether to configure Firebase now.
const _configureNow = 'Configuring Firebase with flutterfire ($_later), for '
    'firebase_core. Run it now?';

/// The warning that Firebase is not configured, because of [reason].
String _notConfigured(String reason) =>
    'Configuring Firebase with flutterfire is not done, because $reason. Run '
    'it in the app: $_later';

/// A macOS machine with a Flutter SDK, bash and Ruby with xcodeproj
/// 1.27.0, on which `smf create` runs in a terminal; the app goes to
/// `/work/my_app`.
///
/// The Firebase CLI and the FlutterFire CLI are missing until a command
/// installs them: the install script puts `firebase` into `/opt/npm/bin`,
/// `firebase login` logs in, and `dart pub global activate` activates
/// flutterfire_cli. Every other command succeeds.
final class _Machine {
  _Machine({
    List<bool> confirmations = const [],
    this.hasTerminal = true,
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
    fake = FakeMachine(reply: _reply, confirmations: confirmations);
  }

  final files = MemoryFileSystem.test();
  final bool hasTerminal;
  late final FakeMachine fake;
  var _loggedIn = false;
  var _activated = false;

  SmfProcessResult _reply(Call call) {
    final line = call.line;
    if (line.endsWith('/install_firebase_macos.sh')) {
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
    if (line == '$_firebase login') _loggedIn = true;
    if (line == '$_dart pub global list') {
      return SmfProcessResult(
        exitCode: 0,
        stdout: _activated ? 'flutterfire_cli 1.4.1\n' : 'melos 7.5.1\n',
      );
    }
    if (line == '$_dart pub global activate flutterfire_cli 1.4.1') {
      _activated = true;
    }
    if (line.startsWith('/bin/ruby ')) {
      return const SmfProcessResult(exitCode: 0, stdout: '1.27.0');
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
          operatingSystem: HostOperatingSystem.macos,
          hasTerminal: hasTerminal,
        ),
      );

  /// The commands that ran but those of the Flutter SDK after generation.
  List<String> get checks => [
        for (final call in fake.calls)
          if (!call.line.startsWith('/sdk/bin/flutter') &&
              !call.line.startsWith('$_dart fix') &&
              !call.line.startsWith('$_dart format'))
            call.line.replaceFirst(
              RegExp('/[^ ]*/install_firebase_macos.sh'),
              '<script>',
            ),
      ];

  /// The warnings that the run printed.
  List<String> get warnings => [
        for (final report in fake.reports)
          if (report.startsWith('warn: ')) report.substring('warn: '.length),
      ];
}

void main() {
  test(
      'a user who declines to install the CLIs gets no installation, but '
      'instructions, and the app', () async {
    final machine = _Machine(confirmations: [false, false, false]);

    final code = await machine.create();

    expect(code, SmfExitCodes.success, reason: machine.fake.reports.join('\n'));
    // Each is asked once: no is no.
    expect(machine.fake.questions, [
      'Firebase CLI is missing (needed by firebase_core). Install it now?',
      'FlutterFire CLI is missing (needed by firebase_core). Install it now?',
      _configureNow,
    ]);
    expect(machine.checks, [
      '$_dart pub global list',
      "/bin/ruby -e require 'xcodeproj'; print Xcodeproj::VERSION",
    ]);
    expect(machine.warnings, [
      contains('Firebase CLI is missing. Install it with "npm install -g '
          'firebase-tools"'),
      contains('Firebase login is missing. Install the Firebase CLI, then log '
          'in with "firebase login".'),
      contains('FlutterFire CLI is missing. Activate it with "dart pub global '
          'activate flutterfire_cli 1.4.1".'),
      _notConfigured('you chose to run it later'),
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
      'FlutterFire CLI is missing (needed by firebase_core). Install it now?',
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
      '$_dart pub global activate flutterfire_cli 1.4.1',
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
}
