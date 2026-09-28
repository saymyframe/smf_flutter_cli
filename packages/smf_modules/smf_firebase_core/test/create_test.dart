@TestOn('vm')
library;

import 'package:file/memory.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_core/src/crashlytics_phase.dart';
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

/// The question whether to install the Firebase CLI, with the instructions
/// for doing it by hand.
const _installFirebase = 'Firebase CLI is missing (needed by firebase_core). '
    'Install it with "npm install -g firebase-tools", or see '
    'https://firebase.google.com/docs/cli. Set it up now?';

/// The instructions for logging in to the Firebase CLI.
const _howToLogIn = 'Log in with "firebase login", or on a remote machine, '
    'such as over SSH, with "firebase login --no-localhost".';

/// The question whether to log in to the Firebase CLI.
const _logIn = 'Firebase login is missing (needed by firebase_core). '
    '$_howToLogIn Set it up now?';

/// The question whether to activate flutterfire_cli.
const _flutterfireMissing = 'FlutterFire CLI 1.4.1 or a later 1.x is missing '
    '(needed by firebase_core). Activate it with "dart pub global activate '
    'flutterfire_cli 1.4.1". Set it up now?';

/// The activation of flutterfire_cli.
const _activate = '$_dart pub global activate flutterfire_cli 1.4.1';

/// What the check found of flutterfire_cli with 1.4.0 active.
const _tooOld = 'flutterfire_cli 1.4.0 is active';

/// What the check tells to do with flutterfire_cli 1.4.0 active.
const _replace = 'Activate 1.4.1 in its place with "dart pub global activate '
    'flutterfire_cli 1.4.1".';

/// The question whether to activate flutterfire_cli 1.4.1 in place of 1.4.0,
/// which says so.
const _replaceFlutterfire = 'FlutterFire CLI 1.4.1 or a later 1.x is needed '
    'by firebase_core, but $_tooOld. $_replace Set it up now?';

/// The warning that Firebase is not configured, because of [reason].
String _notConfigured(String reason) =>
    'Configuring Firebase with flutterfire is not done, because $reason. Run '
    'it in the app: $_later';

/// The fix of the phase for Crashlytics, as the steps run it: Ruby with the
/// program and the Xcode project, which the line does not quote.
final String _fix = [
  '/bin/ruby',
  ...crashlyticsPhaseFix.arguments,
].join(' ');

/// The warning that the phase for Crashlytics is not fixed, since Firebase
/// is not configured, with the command of the README of the app.
const _fixAfterConfigure =
    'Fixing the Crashlytics phase of flutterfire, if any, for flutter build '
    'ipa is not done, because it runs after "Configuring Firebase with '
    'flutterfire", which is not done. Run it in the app: '
    '$crashlyticsPhaseFixCommand';

/// What a firebase command in `/bin` that runs the Firebase CLI of another
/// Node.js writes when it cannot find it.
const _noCli = '/bin/firebase: line 2: '
    '/home/me/.nvm/versions/node/v18.20.8/bin/firebase: No such file or '
    'directory';

/// The path of an install script of the Firebase CLI in a command.
final _script = RegExp(r'/[^ ]*/install_firebase_\w+\.sh$');

/// A machine with a Flutter SDK, bash and Ruby with xcodeproj 1.27.0, or
/// without the gem unless [xcodeproj], on which `smf create` runs in a
/// terminal; the app goes to `/work/my_app`. It runs macOS unless
/// [operatingSystem] says otherwise.
///
/// The Firebase CLI is missing until the install script puts `firebase`
/// into `/opt/npm/bin`, and `firebase login`, with `--no-localhost` or
/// not, logs in unless it exits with [loginCode]. flutterfire_cli is not
/// active, or in version [flutterfire], until `dart pub global activate`
/// activates flutterfire_cli 1.4.1. `flutterfire configure` exits with
/// [configureCode], and every other command succeeds. The environment
/// variables of the run are [variables] and the `PATH`.
///
/// With [brokenFirebase], a firebase command that does not run is in `/bin`
/// on the `PATH`, as a command that runs the Firebase CLI of another
/// Node.js does.
final class _Machine {
  _Machine({
    List<bool> confirmations = const [],
    this.hasTerminal = true,
    this.loginCode = 0,
    this.xcodeproj = true,
    this.flutterfire,
    this.operatingSystem = HostOperatingSystem.macos,
    this.configureCode = 0,
    this.variables = const {},
    this.brokenFirebase = false,
  }) {
    files.directory('/sdk/bin/cache/dart-sdk').createSync(recursive: true);
    files.file('/sdk/bin/cache/flutter.version.json').writeAsStringSync(
          '{"flutterVersion": "3.44.2", "dartSdkVersion": "3.12.2"}',
        );
    for (final tool in [
      '/sdk/bin/flutter',
      _dart,
      '/bin/bash',
      '/bin/ruby',
      if (brokenFirebase) '/bin/firebase',
    ]) {
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
  final int configureCode;
  final Map<String, String> variables;
  final bool brokenFirebase;
  late final FakeMachine fake;
  var _loggedIn = false;
  var _activated = false;

  SmfProcessResult _reply(Call call) {
    final line = call.line;
    if (line.startsWith('/bin/firebase ')) {
      return const SmfProcessResult(exitCode: 127, stderr: '$_noCli\n');
    }
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
    if (line == '$_firebase login' ||
        line == '$_firebase login --no-localhost') {
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
    if (line.startsWith("/bin/ruby -e require 'xcodeproj'")) {
      return xcodeproj
          ? const SmfProcessResult(exitCode: 0, stdout: '1.27.0')
          : const SmfProcessResult(
              exitCode: 1,
              stderr: 'cannot load such file -- xcodeproj (LoadError)',
            );
    }
    if (line == _configure) return SmfProcessResult(exitCode: configureCode);
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
          environmentVariables: {...variables, 'PATH': '/sdk/bin:/bin'},
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
      _installFirebase,
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
      _fixAfterConfigure,
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
      _installFirebase,
      _logIn,
      _flutterfireMissing,
      _configureNow,
    ]);
    expect(machine.checks, [
      '$_dart pub global list',
      "/bin/ruby -e require 'xcodeproj'; print Xcodeproj::VERSION",
      '/bin/bash <script>',
      // The Firebase CLI is checked again after its installation.
      '$_firebase --version',
      // The login is checked once the Firebase CLI is there.
      '$_firebase login:list --json',
      '$_firebase login',
      '$_firebase login:list --json',
      '$_dart pub global list',
      _activate,
      '$_dart pub global list',
      _configure,
      // Right after it, without a question.
      _fix,
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

    // The fix of the phase for Crashlytics, in the same place, with the
    // Xcode project of the app.
    final fix = calls.singleWhere((call) => call.line == _fix);
    expect(calls.indexOf(fix), calls.indexOf(configure) + 1);
    expect(fix.interactive, isFalse);
    expect(fix.workingDirectory, configure.workingDirectory);
    expect(fix.arguments.last, 'ios/Runner.xcodeproj/project.pbxproj');
  });

  test(
      'a user who leaves the configuration for later gets the fix of the '
      'phase for Crashlytics for later too, as the README of the app gives it',
      () async {
    final machine = _Machine(confirmations: [true, true, true, false]);

    final code = await machine.create();

    expect(code, SmfExitCodes.success, reason: machine.fake.reports.join('\n'));
    // Nothing is asked about the fix, which is part of the configuration.
    expect(machine.fake.questions.last, _configureNow);
    expect(machine.fake.questions, hasLength(4));
    expect(machine.checks, isNot(contains(_configure)));
    expect(machine.checks, isNot(contains(_fix)));
    expect(machine.warnings, [
      _notConfigured('you chose to run it later'),
      _fixAfterConfigure,
    ]);
    expect(
      machine.files.file('/work/my_app/README.md').readAsStringSync(),
      allOf(
        contains('```bash\n$crashlyticsPhaseFixCommand\n```\n'),
        contains(
          'flutterfire configure --platforms=android,ios '
          '--overwrite-firebase-options --ios-bundle-id=com.example.my-app '
          '--android-package-name=com.example.my_app\n',
        ),
      ),
    );
  });

  test('a configuration that fails leaves the fix for later', () async {
    final machine = _Machine(
      confirmations: [true, true, true, true],
      configureCode: 1,
    );

    final code = await machine.create();

    expect(code, SmfExitCodes.success, reason: machine.fake.reports.join('\n'));
    expect(machine.checks, contains(_configure));
    expect(machine.checks, isNot(contains(_fix)));
    expect(machine.warnings, [
      equals(
        'The step "Configuring Firebase with flutterfire" failed: it exited '
        'with code 1',
      ),
      _notConfigured('it exited with code 1'),
      _fixAfterConfigure,
    ]);
  });

  test(
      'a login that fails leaves the login missing, with how the login '
      'ended', () async {
    final machine = _Machine(confirmations: [true, true, false], loginCode: 1);

    final code = await machine.create();

    expect(code, SmfExitCodes.success, reason: machine.fake.reports.join('\n'));
    expect(machine.checks, [
      '$_dart pub global list',
      "/bin/ruby -e require 'xcodeproj'; print Xcodeproj::VERSION",
      '/bin/bash <script>',
      '$_firebase --version',
      '$_firebase login:list --json',
      '$_firebase login',
      '$_dart pub global list',
    ]);
    // The check found no login, and the login failed; the check itself
    // did not fail.
    expect(machine.warnings, [
      endsWith(
        'Firebase login is missing. $_howToLogIn Setting it up failed: '
        '"firebase login" exited with code 1.',
      ),
      contains('FlutterFire CLI 1.4.1 or a later 1.x is missing.'),
      _notConfigured(
        'Firebase login and FlutterFire CLI 1.4.1 or a later 1.x are missing',
      ),
      _fixAfterConfigure,
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
    expect(machine.checks, isNot(contains(_fix)));
    expect(machine.warnings, [
      contains('Xcode project tools of flutterfire is missing. flutterfire '
          'configure changes the Xcode project with the Ruby gem xcodeproj'),
      _notConfigured('Xcode project tools of flutterfire is missing'),
      _fixAfterConfigure,
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
      '$_firebase --version',
      '$_firebase login:list --json',
      '$_firebase login',
      '$_firebase login:list --json',
      '$_dart pub global list',
      _activate,
      '$_dart pub global list',
      _configure,
    ]);
    // flutterfire adds no phase there, so the fix neither runs nor is left
    // for later: the README of the app gives it for after a configuration
    // on a Mac.
    expect(machine.checks, isNot(contains(_fix)));
    expect(machine.warnings, [
      contains('Setup of the Xcode project on a Mac is needed, but this '
          'machine is not a Mac. flutterfire configure changes the Xcode '
          'project only on macOS.'),
    ]);
  });

  group('with a firebase command that does not run', () {
    // How the command ended, before the instructions for a missing one.
    const why = '"firebase --version" exited with code 127: $_noCli. Install '
        'it with "npm install -g firebase-tools", or see '
        'https://firebase.google.com/docs/cli.';
    const installAgain = 'Firebase CLI is needed by firebase_core, but '
        '/bin/firebase does not run. $why Set it up now?';

    test(
        'a user who agrees gets the Firebase CLI again, which runs, and is '
        'told why', () async {
      final machine = _Machine(
        confirmations: [true, true, true, true],
        brokenFirebase: true,
      );

      final code = await machine.create();

      expect(
        code,
        SmfExitCodes.success,
        reason: machine.fake.reports.join('\n'),
      );
      expect(machine.fake.questions, [
        installAgain,
        _logIn,
        _flutterfireMissing,
        _configureNow,
      ]);
      expect(
        machine.checks,
        containsAllInOrder([
          '/bin/firebase --version',
          '/bin/firebase login:list --json',
          '/bin/bash <script>',
          // The one it installed comes first on the PATH.
          '$_firebase --version',
          '$_firebase login:list --json',
          '$_firebase login',
          _configure,
        ]),
      );
      expect(machine.warnings, isEmpty);
    });

    test('a user who declines gets the reason in the warnings', () async {
      final machine = _Machine(
        confirmations: [false, false],
        brokenFirebase: true,
      );

      final code = await machine.create();

      expect(
        code,
        SmfExitCodes.success,
        reason: machine.fake.reports.join('\n'),
      );
      expect(machine.warnings, [
        endsWith(
          'Firebase CLI is needed, but /bin/firebase does not run. $why',
        ),
        endsWith(
          'Firebase login could not be checked: "firebase login:list '
          '--json" exited with code 127:\n$_noCli',
        ),
        contains('FlutterFire CLI 1.4.1 or a later 1.x is missing.'),
        _notConfigured(
          'FlutterFire CLI 1.4.1 or a later 1.x is missing, and Firebase CLI '
          'is needed, but /bin/firebase does not run, and Firebase login '
          'could not be checked',
        ),
        _fixAfterConfigure,
      ]);
    });
  });

  test(
      'over SSH, a user who agrees to log in logs in with --no-localhost, '
      'and is asked as anywhere else', () async {
    final machine = _Machine(
      confirmations: [true, true, true, true],
      operatingSystem: HostOperatingSystem.linux,
      variables: {'SSH_CONNECTION': '10.0.0.2 51234 10.0.0.1 22'},
    );

    final code = await machine.create();

    expect(code, SmfExitCodes.success, reason: machine.fake.reports.join('\n'));
    expect(machine.fake.questions.take(2), [_installFirebase, _logIn]);
    expect(
      machine.checks,
      containsAllInOrder([
        '$_firebase login:list --json',
        '$_firebase login --no-localhost',
        '$_firebase login:list --json',
        _configure,
      ]),
    );
    expect(machine.checks, isNot(contains('$_firebase login')));
    final login = machine.fake.calls.firstWhere(
      (call) => call.line == '$_firebase login --no-localhost',
    );
    expect(login.interactive, isTrue);
  });

  test(
      'over SSH, a login that the user stops at the authorization code '
      'leaves the login missing, and Firebase configured later', () async {
    // The Firebase CLI ends its login with code 2 on Ctrl-C at the prompt
    // for the code.
    final machine = _Machine(
      confirmations: [true, true, true],
      operatingSystem: HostOperatingSystem.linux,
      variables: {'SSH_CONNECTION': '10.0.0.2 51234 10.0.0.1 22'},
      loginCode: 2,
    );

    final code = await machine.create();

    expect(code, SmfExitCodes.success, reason: machine.fake.reports.join('\n'));
    expect(machine.warnings, [
      endsWith(
        'Firebase login is missing. $_howToLogIn Setting it up failed: '
        '"firebase login --no-localhost" exited with code 2.',
      ),
      contains('Setup of the Xcode project on a Mac is needed'),
      _notConfigured('Firebase login is missing'),
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
    // The reason names what configure needs too, for when the user runs it.
    expect(machine.warnings, [
      ...List.filled(3, contains('is missing.')),
      _notConfigured(
        'the run skips external setup, and Firebase CLI, Firebase login and '
        'FlutterFire CLI 1.4.1 or a later 1.x are missing',
      ),
      _fixAfterConfigure,
    ]);
  });

  test('a run without a terminal prints the command to configure Firebase',
      () async {
    final machine = _Machine(hasTerminal: false);

    final code = await machine.create();

    expect(code, SmfExitCodes.success, reason: machine.fake.reports.join('\n'));
    expect(machine.fake.questions, isEmpty);
    expect(machine.warnings.sublist(machine.warnings.length - 2), [
      _notConfigured(
        'the run cannot ask the user, and Firebase CLI, Firebase login and '
        'FlutterFire CLI 1.4.1 or a later 1.x are missing',
      ),
      _fixAfterConfigure,
    ]);
    expect(machine.checks, isNot(contains(_configure)));
    expect(machine.checks, isNot(contains(_fix)));
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
        _installFirebase,
        _logIn,
        _replaceFlutterfire,
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
      expect(machine.fake.questions.last, _replaceFlutterfire);
      expect(machine.checks, isNot(contains(_activate)));
      expect(machine.checks, isNot(contains(_configure)));
      expect(machine.warnings, [
        contains(
          'FlutterFire CLI 1.4.1 or a later 1.x is needed, but $_tooOld. '
          '$_replace',
        ),
        _notConfigured(
          'FlutterFire CLI 1.4.1 or a later 1.x is needed, but $_tooOld',
        ),
        _fixAfterConfigure,
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
      _installFirebase,
      _logIn,
    ]);
    expect(machine.checks, isNot(contains(_activate)));
    expect(machine.checks, isNot(contains(_configure)));
    expect(machine.warnings, [
      contains('FlutterFire CLI 1.4.1 or a later 1.x is needed, but '
          'flutterfire_cli 2.0.0 is active. SMF does not replace a newer '
          'major version, which other apps may need. To use 1.4.1, activate '
          'it with "dart pub global activate flutterfire_cli 1.4.1".'),
      _notConfigured(
        'FlutterFire CLI 1.4.1 or a later 1.x is needed, but flutterfire_cli '
        '2.0.0 is active',
      ),
      _fixAfterConfigure,
    ]);
  });

  test(
      '--explain shows that flutterfire_cli 1.4.0 is active in place of 1.4.1 '
      'or a later 1.x, and changes nothing', () async {
    const check = 'FlutterFire CLI 1.4.1 or a later 1.x (for firebase_core)';
    for (final (active, lines) in [
      (
        '1.4.0',
        [
          '  ✗ $check: $_tooOld',
          '    $_replace',
          '    An interactive run offers to set it up.',
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
