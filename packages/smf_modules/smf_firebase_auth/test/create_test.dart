// What a user of `smf create` sees of the step that enables the sign-in
// methods: the check of the machine before generation, the question before
// the step, and the command for later when the step does not run. The
// machine is in memory, so no command runs for real; the script of the step
// runs in `enable_sign_in_script_test.dart`.
@TestOn('vm')
library;

import 'package:file/memory.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_auth/smf_firebase_auth.dart';
import 'package:smf_firebase_auth/src/enable_sign_in.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:test/test.dart';

import 'support/fake_terminal.dart';

const _dart = '/sdk/bin/dart';
const _firebase = '/opt/npm/bin/firebase';

/// The options of `flutterfire configure`, with the ids of the app.
const _options = '--platforms=android,ios --overwrite-firebase-options '
    '--ios-bundle-id=com.example.my-app '
    '--android-package-name=com.example.my_app';

/// `flutterfire configure` as the steps of the Flutter SDK run it, and as
/// the user types it later.
const _configure =
    '$_dart pub global run flutterfire_cli:flutterfire configure $_options';
const _configureLater =
    'dart pub global run flutterfire_cli:flutterfire configure $_options';

/// The step of the module as the pipeline runs it, and as the user types it
/// later.
const _enable = '$_dart tool/enable_firebase_sign_in.dart';
const _enableLater = 'dart tool/enable_firebase_sign_in.dart';

/// What the step of the module does.
const _enabling = 'Enabling the sign-in methods of the app in its Firebase '
    'project';

/// What the user has to know before the step runs.
const _notice = 'The Firebase CLI adds a web app named "Default Web App" to '
    'a project that has no web app, because it enables the methods through '
    'one (firebase/firebase-tools#11250). The Firebase console enables them '
    'without it: '
    'https://console.firebase.google.com/project/_/authentication/providers.';

/// The question whether to configure Firebase now.
const _configureNow = 'Configuring Firebase with flutterfire '
    '($_configureLater), for firebase_core. Run it now?';

/// The question whether to enable the sign-in methods now.
const _enableNow = '$_enabling ($_enableLater), for firebase_auth. $_notice '
    'Run it now?';

/// The question whether to install the Firebase CLI, which the check of
/// firebase_core asks.
const _installFirebase = 'Firebase CLI is missing (needed by firebase_core). '
    'Install it with "npm install -g firebase-tools", or see '
    'https://firebase.google.com/docs/cli. Set it up now?';

/// How to update the Firebase CLI.
const _update = 'Update it with "npm install -g firebase-tools" if npm '
    'installed it, or see https://firebase.google.com/docs/cli#update-cli.';

/// The warning that Firebase is not configured, because of [reason].
String _notConfigured(String reason) =>
    'Configuring Firebase with flutterfire is not done, because $reason. Run '
    'it in the app: $_configureLater';

/// The warning that the sign-in methods are not enabled, because of
/// [reason], with the command for later and the notice of the step.
String _notEnabled(String reason) =>
    '$_enabling is not done, because $reason. Run it in the app: '
    '$_enableLater\n$_notice';

/// Why the step is left for later with `flutterfire configure`.
const _afterConfigure = 'it runs after "Configuring Firebase with '
    'flutterfire", which is not done';

/// The path of the install script of the Firebase CLI in a command.
final _script = RegExp(r'/[^ ]*/install_firebase_\w+\.sh$');

/// A Mac with a Flutter SDK, flutterfire_cli 1.4.1 and Ruby with the gem
/// xcodeproj, on which `smf create` runs, in a terminal unless
/// [hasTerminal] is false; the app goes to `/work/my_app`.
///
/// Its Firebase CLI, with a login that Google accepts, is in the version
/// given as `firebase`. Without one, the machine has no Firebase CLI until
/// the install script puts `firebase` 15.14.0 into `/opt/npm/bin`. The
/// script of the step exits with [enableCode].
final class _Machine {
  _Machine({
    String? firebase = '15.14.0',
    List<bool> confirmations = const [],
    this.hasTerminal = true,
    this.enableCode = 0,
  }) : _version = firebase {
    files.directory('/sdk/bin/cache/dart-sdk').createSync(recursive: true);
    files.file('/sdk/bin/cache/flutter.version.json').writeAsStringSync(
          '{"flutterVersion": "3.44.2", "dartSdkVersion": "3.12.2"}',
        );
    for (final tool in [
      '/sdk/bin/flutter',
      _dart,
      '/bin/bash',
      '/bin/ruby',
      if (firebase != null) _firebase,
    ]) {
      files.file(tool).createSync(recursive: true);
    }
    files.directory('/work').createSync();
    files.currentDirectory = '/work';
    terminal = FakeTerminal(reply: _reply, confirmations: confirmations);
  }

  final bool hasTerminal;
  final int enableCode;
  final files = MemoryFileSystem.test();
  late final FakeTerminal terminal;
  String? _version;

  SmfProcessResult _reply(Call call) {
    final line = call.line;
    if (_script.hasMatch(line)) {
      files.file(_firebase).createSync(recursive: true);
      _version = '15.14.0';
      return const SmfProcessResult(
        exitCode: 0,
        stdout: 'smf-bin-dir=/opt/npm/bin\n',
      );
    }
    return switch (line) {
      '$_firebase --version' =>
        SmfProcessResult(exitCode: 0, stdout: '$_version\n'),
      '$_firebase login:list --json' => const SmfProcessResult(
          exitCode: 0,
          stdout: '{"status": "success", "result": [{"user": {}}]}',
        ),
      '$_dart pub global list' => const SmfProcessResult(
          exitCode: 0,
          stdout: 'flutterfire_cli 1.4.1\n',
        ),
      _enable => SmfProcessResult(
          exitCode: enableCode,
          stderr: enableCode == 0 ? '' : 'The Firebase CLI failed.\n',
        ),
      _ when line.startsWith("/bin/ruby -e require 'xcodeproj'") =>
        const SmfProcessResult(exitCode: 0, stdout: '1.27.0'),
      _ => const SmfProcessResult(exitCode: 0),
    };
  }

  /// Runs `smf create my_app -m firebase_auth` with [options]: the user
  /// names only the module, and the pipeline adds firebase_core for it.
  Future<int> create([List<String> options = const []]) => runSmf(
        [
          'create',
          'my_app',
          '-m',
          '${FirebaseAuthModule.id}',
          '--org',
          'com.example',
          ...options,
        ],
        modules: const [
          FlutterCoreModule(),
          FirebaseCoreModule(),
          FirebaseAuthModule(),
        ],
        hostFor: ({required verbose}) => SmfHost(
          prompter: terminal.prompter,
          processRunner: terminal.processRunner,
          logger: terminal.logger,
          fileSystem: files,
          environmentVariables: const {'PATH': '/sdk/bin:/bin:/opt/npm/bin'},
          operatingSystem: HostOperatingSystem.macos,
          hasTerminal: hasTerminal,
        ),
      );

  /// The commands of the Firebase CLI and of flutterfire that ran, the
  /// install script of the Firebase CLI and the step of the module.
  List<String> get commands => [
        for (final call in terminal.calls)
          if (call.line.startsWith(_firebase) ||
              call.line == _configure ||
              call.line == _enable ||
              _script.hasMatch(call.line))
            call.line.replaceFirst(_script, '<script>'),
      ];

  /// The warnings that the run printed.
  List<String> get warnings => _reports('warn: ');

  /// What the run printed as information, such as the lines of `--explain`.
  List<String> get infos => _reports('info: ');

  List<String> _reports(String kind) => [
        for (final report in terminal.reports)
          if (report.startsWith(kind)) report.substring(kind.length),
      ];

  /// Whether the run generated the script of the step in the app.
  bool get hasScript =>
      files.file('/work/my_app/$enableSignInScript').existsSync();
}

void main() {
  group('smf create -m firebase_auth, in a terminal,', () {
    test(
        'asks before it enables the sign-in methods, once flutterfire '
        'configured the app, with what the Firebase CLI does to the project '
        'and the other way in the question', () async {
      final machine = _Machine(confirmations: [true, true]);

      final code = await machine.create();

      expect(
        code,
        SmfExitCodes.success,
        reason: machine.terminal.reports.join('\n'),
      );
      expect(machine.terminal.questions, [_configureNow, _enableNow]);
      // The question is one line, and tells neither answer.
      expect(_enableNow, isNot(contains('\n')));
      expect(
        machine.commands,
        containsAllInOrder([_configure, _enable]),
      );
      expect(
        machine.terminal.calls.singleWhere((call) => call.line == _enable),
        isA<Call>().having((call) => call.interactive, 'interactive', isFalse),
        reason: 'The Firebase CLI asks nothing, so the step needs no '
            'terminal.',
      );
      expect(machine.warnings, isEmpty);
      expect(machine.hasScript, isTrue);
    });

    test(
        'leaves the methods for later when the user says so, with the '
        'command and the notice', () async {
      final machine = _Machine(confirmations: [true, false]);

      final code = await machine.create();

      expect(
        code,
        SmfExitCodes.success,
        reason: machine.terminal.reports.join('\n'),
      );
      expect(machine.terminal.questions, [_configureNow, _enableNow]);
      expect(machine.commands, contains(_configure));
      expect(machine.commands, isNot(contains(_enable)));
      expect(machine.warnings, [_notEnabled('you chose to run it later')]);
      expect(machine.hasScript, isTrue);
    });

    test(
        'does not ask about the methods when the user leaves flutterfire '
        'configure for later, and leaves them for later with it', () async {
      final machine = _Machine(confirmations: [false]);

      final code = await machine.create();

      expect(
        code,
        SmfExitCodes.success,
        reason: machine.terminal.reports.join('\n'),
      );
      expect(machine.terminal.questions, [_configureNow]);
      expect(machine.commands, isNot(contains(_configure)));
      expect(machine.commands, isNot(contains(_enable)));
      expect(machine.warnings, [
        _notConfigured('you chose to run it later'),
        _notEnabled(_afterConfigure),
      ]);
    });

    test(
        'leaves the methods for later when the script fails, with what it '
        'printed', () async {
      final machine = _Machine(confirmations: [true, true], enableCode: 2);

      final code = await machine.create();

      expect(
        code,
        SmfExitCodes.success,
        reason: machine.terminal.reports.join('\n'),
      );
      expect(machine.commands, containsAllInOrder([_configure, _enable]));
      expect(machine.warnings, [
        allOf(
          startsWith('The step "$_enabling" failed: '),
          contains('The Firebase CLI failed.'),
        ),
        _notEnabled('it exited with code 2'),
      ]);
    });

    test(
        'holds back only the methods with a Firebase CLI that is older than '
        'the command, and does not ask about them', () async {
      const older = 'Firebase CLI 15.6.0 or later is needed, but $_firebase '
          'is 15.5.1';
      final machine = _Machine(firebase: '15.5.1', confirmations: [true]);

      final code = await machine.create();

      expect(
        code,
        SmfExitCodes.success,
        reason: machine.terminal.reports.join('\n'),
      );
      // flutterfire configure runs with the older Firebase CLI.
      expect(machine.terminal.questions, [_configureNow]);
      expect(machine.commands, contains(_configure));
      expect(machine.commands, isNot(contains(_enable)));
      expect(machine.warnings, [
        endsWith('$older. $_update'),
        _notEnabled(older),
      ]);
    });

    test(
        'enables the methods with the Firebase CLI that the run installed '
        'for firebase_core, which has the command', () async {
      final machine = _Machine(
        firebase: null,
        confirmations: [true, true, true],
      );

      final code = await machine.create();

      expect(
        code,
        SmfExitCodes.success,
        reason: machine.terminal.reports.join('\n'),
      );
      expect(
        machine.terminal.questions,
        [_installFirebase, _configureNow, _enableNow],
      );
      expect(
        machine.commands,
        containsAllInOrder(['/bin/bash <script>', _configure, _enable]),
      );
      expect(machine.warnings, isEmpty);
    });

    test(
        'with --skip-external-setup, leaves flutterfire configure and the '
        'methods for later without a question', () async {
      final machine = _Machine();

      final code = await machine.create(['--skip-external-setup']);

      expect(
        code,
        SmfExitCodes.success,
        reason: machine.terminal.reports.join('\n'),
      );
      expect(machine.terminal.questions, isEmpty);
      expect(machine.commands, isNot(contains(_configure)));
      expect(machine.commands, isNot(contains(_enable)));
      expect(machine.warnings, [
        _notConfigured('the run skips external setup'),
        _notEnabled(_afterConfigure),
      ]);
      expect(machine.hasScript, isTrue);
    });

    test(
        '--explain shows the check of the version of the Firebase CLI, and '
        'the step under flutterfire configure, with its notice', () async {
      final machine = _Machine();

      final code = await machine.create(['--explain']);

      expect(
        code,
        SmfExitCodes.success,
        reason: machine.terminal.reports.join('\n'),
      );
      final lines = machine.infos.expand((info) => info.split('\n')).toList();
      expect(
        lines,
        contains('  ✓ Firebase CLI 15.6.0 or later (for firebase_auth)'),
        reason: lines.join('\n'),
      );
      final configure = lines.indexOf('  $_configureLater (firebase_core)');
      expect(configure, isNonNegative, reason: lines.join('\n'));
      const asks = '      A run asks before it runs this step, and leaves it '
          'for later when it cannot ask.';
      expect(lines.skip(configure + 1).take(3), [
        '    then $_enableLater (firebase_auth)',
        '      $_notice',
        asks,
      ]);
      expect(machine.terminal.questions, isEmpty);
      expect(machine.commands, isNot(contains(_enable)));
      expect(machine.hasScript, isFalse);
    });

    test('--explain shows a Firebase CLI that is older than the command',
        () async {
      final machine = _Machine(firebase: '15.5.1');

      final code = await machine.create(['--explain']);

      expect(
        code,
        SmfExitCodes.success,
        reason: machine.terminal.reports.join('\n'),
      );
      final lines = machine.infos.expand((info) => info.split('\n')).toList();
      final check = lines.indexOf(
        '  ✗ Firebase CLI 15.6.0 or later (for firebase_auth): $_firebase '
        'is 15.5.1',
      );
      expect(check, isNonNegative, reason: lines.join('\n'));
      expect(lines[check + 1], '    $_update');
    });
  });

  group('smf create -m firebase_auth, without a terminal,', () {
    test(
        'leaves flutterfire configure and the methods for later, each with '
        'its command', () async {
      final machine = _Machine(hasTerminal: false);

      final code = await machine.create(['--no-input']);

      expect(
        code,
        SmfExitCodes.success,
        reason: machine.terminal.reports.join('\n'),
      );
      expect(machine.terminal.questions, isEmpty);
      expect(machine.terminal.selections, isEmpty);
      expect(machine.commands, isNot(contains(_configure)));
      expect(machine.commands, isNot(contains(_enable)));
      expect(machine.warnings, [
        _notConfigured('the run cannot ask the user'),
        _notEnabled(_afterConfigure),
      ]);
      expect(machine.hasScript, isTrue);
    });
  });

  test('the step of the module is the one that the tests of a run name', () {
    expect(enableSignIn.description, _enabling);
    expect(enableSignIn.notice, _notice);
    expect(enableSignInCommand, _enableLater);
  });
}
