@TestOn('vm')
library;

import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_core/src/preflight/commands.dart';
import 'package:smf_firebase_core/src/preflight/firebase_cli.dart';
import 'package:smf_firebase_core/src/preflight/firebase_login.dart';
import 'package:smf_firebase_core/src/preflight/flutterfire_cli.dart';
import 'package:smf_firebase_core/src/preflight/install_scripts.dart';
import 'package:smf_firebase_core/src/preflight/xcode_project_tools.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

import 'support/fake_machine.dart';

const _firebase = '/opt/npm/bin/firebase';
const _dart = '/sdk/bin/dart';
const _bash = '/bin/bash';
const _ruby = '/usr/bin/ruby';

SmfProcessResult _result(
  int exitCode, {
  String stdout = '',
  String stderr = '',
}) =>
    SmfProcessResult(exitCode: exitCode, stdout: stdout, stderr: stderr);

/// A check that found nothing of what it looks for, or [found] in its
/// place.
Matcher _missing({
  required Object instructions,
  required bool installable,
  Object? found,
}) =>
    isA<PreflightMissing>()
        .having((s) => s.instructions, 'instructions', instructions)
        .having((s) => s.installable, 'installable', installable)
        .having((s) => s.found, 'found', found);

Matcher _failed(Object message) =>
    isA<PreflightFailed>().having((s) => s.message, 'message', message);

Matcher _setupFailure(Object message) => throwsA(
      isA<PreflightSetupException>()
          .having((e) => e.message, 'message', message),
    );

/// The output of `firebase login:list --json` with the accounts of [emails],
/// which holds the tokens of each account.
String _accounts(List<String> emails) => '{\n'
    '  "status": "success",\n'
    '  "result": [${[
      for (final email in emails)
        '{"user": {"email": "$email"}, "tokens": {"refresh_token": "secret"}}',
    ].join(', ')}]\n'
    '}';

/// What `firebase projects:list --debug` of firebase-tools 15.14.0 printed
/// on its standard output for a login that Google rejects, a refresh token
/// that was revoked, of the account `me@example.com`, shortened.
///
/// Google answers 400 when the Firebase CLI refreshes the access token, so
/// the Firebase CLI tries the refresh token itself, which the API rejects
/// with 401.
const _revoked = '''
[2026-09-28T12:52:53.938Z] > command requires scopes: ["email","openid","https://www.googleapis.com/auth/cloudplatformprojects.readonly","https://www.googleapis.com/auth/firebase","https://www.googleapis.com/auth/cloud-platform"]
[2026-09-28T12:52:53.939Z] > authorizing via signed-in user (me@example.com)
[2026-09-28T12:52:53.940Z] Checked if tokens are valid: false, expires at: 1000
[2026-09-28T12:52:53.940Z] > refreshing access token with scopes: []
[2026-09-28T12:52:53.941Z] >>> [apiv2][query] POST https://www.googleapis.com/oauth2/v3/token [none]
[2026-09-28T12:52:53.941Z] >>> [apiv2][body] POST https://www.googleapis.com/oauth2/v3/token [omitted]
[2026-09-28T12:52:54.101Z] <<< [apiv2][status] POST https://www.googleapis.com/oauth2/v3/token 400
[2026-09-28T12:52:54.101Z] <<< [apiv2][body] POST https://www.googleapis.com/oauth2/v3/token [omitted]
[2026-09-28T12:52:54.102Z] >>> [apiv2][query] GET https://firebase.googleapis.com/v1beta1/projects pageSize=1000
[2026-09-28T12:52:54.315Z] <<< [apiv2][status] GET https://firebase-public.firebaseio.com/cli.json 200
[2026-09-28T12:52:54.340Z] <<< [apiv2][status] GET https://firebase.googleapis.com/v1beta1/projects 401
[2026-09-28T12:52:54.340Z] <<< [apiv2][body] GET https://firebase.googleapis.com/v1beta1/projects [omitted]
[2026-09-28T12:52:54.340Z] Got a 401 Unauthenticated error for a call that required authentication. Refreshing tokens.
[2026-09-28T12:52:54.341Z] > refreshing access token with scopes: []
[2026-09-28T12:52:54.341Z] >>> [apiv2][query] POST https://www.googleapis.com/oauth2/v3/token [none]
[2026-09-28T12:52:54.387Z] <<< [apiv2][status] POST https://www.googleapis.com/oauth2/v3/token 400
[2026-09-28T12:52:54.388Z] Request to https://firebase.googleapis.com/v1beta1/projects?pageSize=1000 had HTTP Error: 401, Request had invalid authentication credentials. Expected OAuth 2 access token, login cookie or other valid authentication credential. See https://developers.google.com/identity/sign-in/web/devconsole-project.

Error: Failed to list Firebase projects. See firebase-debug.log for more info.
''';

/// What `firebase projects:list --debug` of firebase-tools 15.14.0 printed
/// on its standard output for the login of [_revoked] when no request
/// reached Google, shortened, with the reasons of a machine without a
/// network in place of those of the run, whose proxy refused connections
/// (see [_refused]): the Firebase CLI says that the credentials are no
/// longer valid when it cannot refresh the access token for any reason.
const _offline = '''
[2026-09-28T12:52:54.917Z] > authorizing via signed-in user (me@example.com)
[2026-09-28T12:52:54.921Z] > refreshing access token with scopes: []
[2026-09-28T12:52:54.921Z] >>> [apiv2][query] POST https://www.googleapis.com/oauth2/v3/token [none]
[2026-09-28T12:52:54.926Z] *** [apiv2] error from fetch(https://firebase-public.firebaseio.com/cli.json, {"headers":{},"method":"GET"}): FetchError: request to https://firebase-public.firebaseio.com/cli.json failed, reason: getaddrinfo ENOTFOUND firebase-public.firebaseio.com
⚠  Unable to fetch the CLI MOTD and remote config. This is not a fatal error, but may indicate an issue with your network connection.
[2026-09-28T12:52:54.926Z] *** [apiv2] error from fetch(https://www.googleapis.com/oauth2/v3/token, {"headers":{},"method":"POST"}): FetchError: request to https://www.googleapis.com/oauth2/v3/token failed, reason: getaddrinfo ENOTFOUND www.googleapis.com
Authentication Error: Your credentials are no longer valid. Please run firebase login --reauth

For CI servers and headless environments, generate a new token with firebase login:ci
[2026-09-28T12:52:54.927Z] FirebaseError: Authentication Error: Your credentials are no longer valid. Please run firebase login --reauth

Error: Failed to list Firebase projects. See firebase-debug.log for more info.
''';

/// The standard output of `firebase projects:list --debug` for a login that
/// works, with one project, in the form of the sources of firebase-tools
/// 15.14.0, since no such login was at hand; the check reads only the exit
/// code of the command.
const _oneProject = '''
[2026-09-28T12:50:01.101Z] > authorizing via signed-in user (me@example.com)
[2026-09-28T12:50:01.402Z] <<< [apiv2][status] GET https://firebase.googleapis.com/v1beta1/projects 200
┌──────────────────────┬──────────────┬────────────────┬──────────────────────┐
│ Project Display Name │ Project ID   │ Project Number │ Resource Location ID │
├──────────────────────┼──────────────┼────────────────┼──────────────────────┤
│ My App               │ my-app-1a2b3 │ 123456789012   │ [Not specified]      │
└──────────────────────┴──────────────┴────────────────┴──────────────────────┘

1 project(s) total.
''';

/// The standard output of `firebase projects:list --debug` for a login that
/// works without a project, in the same form as [_oneProject].
const _noProject = '''
[2026-09-28T12:50:01.101Z] > authorizing via signed-in user (me@example.com)
No projects found.
''';

/// The API that lists the Firebase projects.
const _projectsUrl = 'https://firebase.googleapis.com/v1beta1/projects';

/// The line of a failed request as firebase-tools 15.14.0 printed it for a
/// proxy that refused connections, with the options of the request
/// shortened.
const _refused = '[2026-09-28T12:52:54.926Z] *** [apiv2] error from '
    'fetch($_tokenUrl, {"headers":{}, "method":"POST"}): FetchError: '
    'request to $_tokenUrl failed, reason: connect ECONNREFUSED 127.0.0.1:9';

/// The endpoint of Google that refreshes the access token of the Firebase
/// CLI.
const _tokenUrl = 'https://www.googleapis.com/oauth2/v3/token';

/// What `firebase projects:list` writes on its standard error when it
/// fails.
const _spinner = '- Preparing the list of your Firebase projects\n'
    '✖ Preparing the list of your Firebase projects\n';

void main() {
  test('the module checks the machine for flutterfire configure in order', () {
    final preflight = const FirebaseCoreModule()
        .contribute(ContractHarness.defaultContext)
        .whereType<Preflight>()
        .single;

    expect(preflight.when, isEmpty);
    expect(preflight.checks.map((check) => check.id), [
      'firebase_cli',
      'firebase_login',
      'flutterfire_cli',
      'xcode_project_tools',
      'xcode_project_on_mac',
    ]);
    // The app compiles without any of them, so none stops generation.
    expect(preflight.checks.where((check) => check.required), isEmpty);
  });

  group('FirebaseCliCheck', () {
    const check = FirebaseCliCheck();
    const install = 'Install it with "npm install -g firebase-tools", or see '
        'https://firebase.google.com/docs/cli.';

    test('passes when firebase runs, and shows nothing of it', () async {
      final machine = FakeMachine(
        executables: {'firebase': _firebase},
        reply: (_) => _result(0, stdout: '15.14.0\n'),
      );

      expect(await check.check(machine), isA<PreflightPassed>());
      final call = machine.calls.single;
      expect(call.line, '$_firebase --version');
      expect(call.interactive, isFalse);
      // A directory of its own for firebase-debug.log, and no check for
      // updates in the background.
      expect(call.workingDirectory, directoryOf(machine.tempFiles.keys.single));
      expect(call.environment, {'NO_UPDATE_NOTIFIER': '1'});
      expect(machine.reports, isEmpty);
    });

    test(
        'offers to install it again when firebase does not run, and says how '
        'it ended, on one line', () async {
      const wrapper = '/home/me/.local/bin/firebase';
      const node18 = '/home/me/.nvm/versions/node/v18.20.8/bin/firebase';
      const run = '"firebase --version"';
      for (final (result, why) in [
        // A firebase command that runs the Firebase CLI of the Node.js of
        // the terminal, which has none.
        (
          _result(
            127,
            stderr: '$wrapper: line 2: $node18: No such file or directory\n',
          ),
          '$run exited with code 127: $wrapper: line 2: $node18: No such '
              'file or directory.',
        ),
        // The Firebase CLI on a Node.js that is too old for it.
        (
          _result(
            1,
            stderr: 'Firebase CLI v15.14.0 is incompatible with Node.js '
                'v18.20.8 Please upgrade Node.js to version >=20.0.0 || '
                '>=22.0.0 || >=24.0.0\n',
          ),
          '$run exited with code 1: Firebase CLI v15.14.0 is incompatible '
              'with Node.js v18.20.8 Please upgrade Node.js to version '
              '>=20.0.0 || >=22.0.0 || >=24.0.0.',
        ),
        // Lines of errors that end with a period.
        (
          _result(
            1,
            stderr: 'Error: CLI is out of date (on 15.14.0, need at least '
                '15.20.0)\n\nRun npm install -g firebase-tools to upgrade.\n',
          ),
          '$run exited with code 1: Error: CLI is out of date (on 15.14.0, '
              'need at least 15.20.0) Run npm install -g firebase-tools to '
              'upgrade.',
        ),
        // The last lines of long errors.
        (
          _result(1, stderr: [for (var i = 1; i <= 8; i++) 'e$i'].join('\n')),
          '$run exited with code 1: … e4 e5 e6 e7 e8.',
        ),
        (_result(1), '$run exited with code 1.'),
        (_result(-9), '$run was stopped by signal 9.'),
      ]) {
        final machine = FakeMachine(
          operatingSystem: HostOperatingSystem.linux,
          executables: {'firebase': wrapper},
          reply: (_) => result,
        );

        expect(
          await check.check(machine),
          _missing(
            found: '$wrapper does not run',
            instructions: '$why $install',
            installable: true,
          ),
          reason: why,
        );
      }
      // Where SMF has no install script, it only tells.
      expect(
        await check.check(
          FakeMachine(
            operatingSystem: HostOperatingSystem.other,
            executables: {'firebase': wrapper},
            reply: (_) => _result(1),
          ),
        ),
        _missing(
          found: '$wrapper does not run',
          instructions: '$run exited with code 1. $install',
          installable: false,
        ),
      );
    });

    test(
        'offers to install it again when firebase cannot start, and says '
        'why on one line', () async {
      final machine = FakeMachine(
        operatingSystem: HostOperatingSystem.linux,
        executables: {'firebase': _firebase},
        reply: (call) => throw ProcessException(
          call.executable,
          call.arguments,
          'Permission denied',
          13,
        ),
      );

      expect(
        await check.check(machine),
        _missing(
          found: '$_firebase does not run',
          instructions: '"firebase --version" could not start: '
              'ProcessException: Permission denied Command: $_firebase '
              '--version. $install',
          installable: true,
        ),
      );
    });

    test('lets the cancellation of the run through', () async {
      final machine = FakeMachine(
        executables: {'firebase': _firebase},
        reply: (_) => throw const SmfCancelledException(),
      );

      await expectLater(
        check.check(machine),
        throwsA(isA<SmfCancelledException>()),
      );
    });

    test('can install it on macOS, Linux and Windows only', () async {
      for (final system in HostOperatingSystem.values) {
        expect(
          await check.check(FakeMachine(operatingSystem: system)),
          _missing(
            instructions: install,
            installable: system != HostOperatingSystem.other,
          ),
          reason: '$system',
        );
      }
    });

    test(
        'installs it with the script of the system, and returns the '
        'directories that the script prints', () async {
      late final FakeMachine machine;
      machine = FakeMachine(
        executables: {'bash': _bash},
        reply: (call) {
          machine.executables['firebase'] = _firebase;
          return _result(
            0,
            stdout: 'added 600 packages\n15.14.0\n'
                'smf-note=Added /opt/npm/bin to the PATH in ~/.zprofile.\n'
                'smf-bin-dir=/opt/npm/bin\n'
                'smf-bin-dir=/opt/node/bin\n'
                'smf-bin-dir=/opt/npm/bin\n',
          );
        },
      );

      final installed = await check.install(machine);

      expect(installed.binDirs, ['/opt/npm/bin', '/opt/node/bin']);
      final script = machine.tempFiles.keys.single;
      expect(script, endsWith('/install_firebase_macos.sh'));
      expect(
        machine.tempFiles[script],
        InstallScript.of(machine.operatingSystem)!.text,
      );
      expect(machine.calls.map((call) => call.line), ['$_bash $script']);
      // In a directory of its own, where the Firebase CLI leaves its log.
      expect(machine.calls.single.workingDirectory, directoryOf(script));
      expect(machine.calls.single.interactive, isFalse);
      expect(machine.questions, isEmpty);
      // What the script is doing, then what it changed.
      expect(machine.reports, [
        'progress: Installing the Firebase CLI',
        'update: Installing the Firebase CLI: added 600 packages',
        'update: Installing the Firebase CLI: 15.14.0',
        'complete: Installed the Firebase CLI',
        'info: Added /opt/npm/bin to the PATH in ~/.zprofile.',
        startsWith('detail: added 600 packages'),
      ]);
    });

    test('runs the PowerShell script on Windows', () async {
      final machine = FakeMachine(
        operatingSystem: HostOperatingSystem.windows,
        executables: {'powershell': r'C:\Windows\powershell.exe'},
        reply: (_) => _result(
          0,
          stdout: 'smf-bin-dir=C:\\Users\\me\\AppData\\Roaming\\npm\r\n',
        ),
      );

      final installed = await check.install(machine);

      final script = machine.tempFiles.keys.single;
      expect(script, endsWith('/install_firebase_windows.ps1'));
      expect(machine.calls.single.arguments, [
        '-ExecutionPolicy',
        'Bypass',
        '-NoLogo',
        '-NonInteractive',
        '-File',
        script,
      ]);
      expect(installed.binDirs, [r'C:\Users\me\AppData\Roaming\npm']);
    });

    test(
        'asks before the standalone binary when npm fails on Linux, and '
        'installs nothing more when the user declines', () async {
      final machine = FakeMachine(
        operatingSystem: HostOperatingSystem.linux,
        executables: {'bash': _bash},
        reply: (_) => _result(
          1,
          stdout: 'smf-note=Installed nvm in /home/me/.nvm.\n'
              'npm ERR! code EACCES',
          stderr: 'x',
        ),
        confirmations: [false],
      );

      await expectLater(
        check.install(machine),
        _setupFailure(
          '"install_firebase_linux.sh" exited with code 1:\nx\nnpm ERR! code '
          'EACCES',
        ),
      );
      // What it changed before it failed.
      expect(
        machine.reports,
        contains('info: Installed nvm in /home/me/.nvm.'),
      );
      expect(
        machine.questions.single,
        'Install the standalone binary of the Firebase CLI with "curl -sL '
        'https://firebase.tools | bash" instead? It asks for your password '
        'when it needs sudo to write to /usr/local/bin.',
      );
      expect(machine.calls, hasLength(1));
      expect(
        machine.reports,
        contains(
          'warn: Installing the Firebase CLI with npm failed: '
          '"install_firebase_linux.sh" exited with code 1:\nx\nnpm ERR! code '
          'EACCES',
        ),
      );
    });

    test('installs the standalone binary in a terminal when the user agrees',
        () async {
      var code = 0;
      final machine = FakeMachine(
        executables: {'bash': _bash},
        reply: (call) => call.interactive ? _result(code) : _result(1),
        confirmations: [true, true],
      );

      final installed = await check.install(machine);

      expect(installed.binDirs, ['/usr/local/bin']);
      final standalone = machine.calls.last;
      expect(standalone.interactive, isTrue);
      expect(
        standalone.line,
        '$_bash -lc curl -sL https://firebase.tools | bash',
      );

      code = 3;
      await expectLater(
        check.install(machine),
        _setupFailure(
          '"curl -sL https://firebase.tools | bash" exited with code 3.',
        ),
      );
    });

    test('offers no standalone binary on Windows', () async {
      final machine = FakeMachine(
        operatingSystem: HostOperatingSystem.windows,
        executables: {'powershell': 'powershell.exe'},
        reply: (_) => _result(2),
      );

      await expectLater(
        check.install(machine),
        _setupFailure('"install_firebase_windows.ps1" exited with code 2.'),
      );
      expect(machine.questions, isEmpty);
    });

    test('stops its progress when the user cancels the run', () async {
      final machine = FakeMachine(
        executables: {'bash': _bash},
        reply: (_) => throw const SmfCancelledException(),
      );

      await expectLater(
        check.install(machine),
        throwsA(isA<SmfCancelledException>()),
      );
      expect(machine.reports, [
        'progress: Installing the Firebase CLI',
        'fail: Installing the Firebase CLI',
      ]);
    });

    test('cannot install without a script or its shell', () async {
      await expectLater(
        check.install(FakeMachine(operatingSystem: HostOperatingSystem.other)),
        _setupFailure(
          'SMF cannot install the Firebase CLI on this operating system.',
        ),
      );
      await expectLater(
        check.install(FakeMachine()),
        _setupFailure('bash, which runs the installation, was not found.'),
      );
    });
  });

  group('FirebaseCliVersionCheck', () {
    const check = FirebaseCliVersionCheck(minimum: '15.6.0');
    const install = 'Install it with "npm install -g firebase-tools", or see '
        'https://firebase.google.com/docs/cli.';
    const update = 'Update it with "npm install -g firebase-tools" if npm '
        'installed it, or see https://firebase.google.com/docs/cli#update-cli.';

    /// A machine whose `firebase --version` prints [output].
    FakeMachine machineWith(
      String output, {
      HostOperatingSystem operatingSystem = HostOperatingSystem.macos,
    }) =>
        FakeMachine(
          operatingSystem: operatingSystem,
          executables: {'firebase': _firebase},
          reply: (_) => _result(0, stdout: output),
        );

    test(
        'is a check of its own, named after the lowest version, which stops '
        'no generation', () {
      expect(check.id, 'firebase_cli_version');
      // Next to the check of the Firebase CLI in one run, under another id.
      expect(check.id, isNot(const FirebaseCliCheck().id));
      expect(check.description, 'Firebase CLI 15.6.0 or later');
      expect(
        const FirebaseCliVersionCheck(minimum: '16.1.0').description,
        'Firebase CLI 16.1.0 or later',
      );
      expect(check.required, isFalse);
    });

    test(
        'passes with the lowest version or a later one, and asks as the '
        'check of the Firebase CLI does', () async {
      for (final output in [
        '15.6.0\n',
        '15.6.1\n',
        // By its numbers, not as a text.
        '15.14.0\n',
        '16.0.0\n',
        '100.0.0\n',
        // A pre-release and a build of a later version, and a build of the
        // lowest one.
        '15.7.0-rc.1\n',
        '15.6.0+build.5\n',
        '15.14.0\r\n',
        '15.14.0',
      ]) {
        final machine = machineWith(output);

        expect(
          await check.check(machine),
          isA<PreflightPassed>(),
          reason: output,
        );
        final call = machine.calls.single;
        expect(call.line, '$_firebase --version');
        expect(call.interactive, isFalse);
        // A directory of its own for firebase-debug.log, and no check for
        // updates in the background.
        expect(
          call.workingDirectory,
          directoryOf(machine.tempFiles.keys.single),
        );
        expect(call.environment, {'NO_UPDATE_NOTIFIER': '1'});
        expect(machine.reports, isEmpty);
        expect(machine.questions, isEmpty);
      }
    });

    test(
        'tells which Firebase CLI is older and how to update it, on every '
        'system, and offers no installation', () async {
      for (final version in [
        '15.5.1',
        '15.5.99',
        '14.27.0',
        // By its numbers: 9 comes before 15.
        '9.23.3',
        // A pre-release of the lowest version comes before it.
        '15.6.0-rc.1',
        '15.6.0-rc.1+build.5',
      ]) {
        for (final system in HostOperatingSystem.values) {
          expect(
            await check.check(
              machineWith('$version\n', operatingSystem: system),
            ),
            _missing(
              found: '$_firebase is $version',
              instructions: update,
              installable: false,
            ),
            reason: '$version on $system',
          );
        }
      }
    });

    test('compares with the lowest version that the module gave', () async {
      const later = FirebaseCliVersionCheck(minimum: '16.1.0');

      expect(
        await later.check(machineWith('15.14.0\n')),
        _missing(
          found: '$_firebase is 15.14.0',
          instructions: update,
          installable: false,
        ),
      );
      expect(
        await later.check(machineWith('16.0.9\n')),
        isA<PreflightMissing>(),
      );
      for (final version in ['16.1.0', '17.0.0']) {
        expect(
          await later.check(machineWith('$version\n')),
          isA<PreflightPassed>(),
          reason: version,
        );
      }
    });

    test(
        'reads the version from its line among the others of the output, '
        'the last one that is a version', () async {
      // A firebase command that picks its Node.js and says so first.
      expect(
        await check.check(
          machineWith('Now using node v22.11.0 (npm v10.9.0)\n\n15.5.1\n'),
        ),
        _missing(
          found: '$_firebase is 15.5.1',
          instructions: update,
          installable: false,
        ),
      );
      expect(
        await check.check(machineWith('1.0.0\n15.14.0\n')),
        isA<PreflightPassed>(),
      );
    });

    test('fails on an output without a version, and shows it on one line',
        () async {
      for (final (output, printed) in [
        ('main\n', 'main'),
        // Not three numbers.
        ('15.6\n', '15.6'),
        ('15\n', '15'),
        // A version inside a line is not the version that the command
        // prints.
        ('firebase-tools 15.14.0 is out\n', 'firebase-tools 15.14.0 is out'),
        ('v15.14.0\n', 'v15.14.0'),
        ('a\r\n\r\nb\r\n', 'a b'),
        ('', ''),
      ]) {
        expect(
          await check.check(machineWith(output)),
          _failed(
            '"firebase --version" printed "$printed", which is not a version.',
          ),
          reason: output,
        );
      }
      // The last lines of a long output.
      expect(
        await check.check(
          machineWith([for (var i = 1; i <= 8; i++) 'line $i'].join('\n')),
        ),
        _failed(
          '"firebase --version" printed "… line 4 line 5 line 6 line 7 line '
          '8", which is not a version.',
        ),
      );
    });

    test(
        'says only that the Firebase CLI does not run when it does not, '
        'which the check of the Firebase CLI tells about', () async {
      const doesNotRun = 'the Firebase CLI does not run';
      for (final system in HostOperatingSystem.values) {
        final failing = FakeMachine(
          operatingSystem: system,
          executables: {'firebase': _firebase},
          reply: (_) => _result(
            1,
            // A version in the output of a command that failed is none.
            stdout: '15.14.0\n',
            stderr: 'Firebase CLI v15.14.0 is incompatible with Node.js '
                'v18.20.8 Please upgrade Node.js to version >=20.0.0\n',
          ),
        );

        expect(
          await check.check(failing),
          _missing(
            found: doesNotRun,
            instructions: install,
            installable: false,
          ),
          reason: '$system',
        );
        expect(failing.calls.single.line, '$_firebase --version');
      }

      final cannotStart = FakeMachine(
        executables: {'firebase': _firebase},
        reply: (call) => throw ProcessException(
          call.executable,
          call.arguments,
          'Permission denied',
          13,
        ),
      );
      expect(
        await check.check(cannotStart),
        _missing(found: doesNotRun, instructions: install, installable: false),
      );
    });

    test(
        'reports it missing on a machine without the Firebase CLI, and runs '
        'nothing', () async {
      for (final system in HostOperatingSystem.values) {
        final machine = FakeMachine(operatingSystem: system);

        expect(
          await check.check(machine),
          // The check of the Firebase CLI offers the installation.
          _missing(instructions: install, installable: false),
          reason: '$system',
        );
        expect(machine.calls, isEmpty);
      }
    });

    test('lets the cancellation of the run through', () async {
      final machine = FakeMachine(
        executables: {'firebase': _firebase},
        reply: (_) => throw const SmfCancelledException(),
      );

      await expectLater(
        check.check(machine),
        throwsA(isA<SmfCancelledException>()),
      );
    });

    test('installs nothing', () async {
      final machine = machineWith('15.5.1\n');

      await expectLater(check.install(machine), throwsUnsupportedError);
      expect(machine.calls, isEmpty);
      expect(machine.questions, isEmpty);
    });

    test(
        'refuses a lowest version that is not three numbers, before it runs '
        'anything', () async {
      for (final minimum in [
        '15.6',
        '15',
        'latest',
        '',
        // A range, or a pre-release, which a module cannot ask for.
        '^15.6.0',
        '>=15.6.0',
        '15.6.0-rc.1',
        '15.6.0+build.5',
        ' 15.6.0',
      ]) {
        final machine = machineWith('15.14.0\n');

        await expectLater(
          FirebaseCliVersionCheck(minimum: minimum).check(machine),
          throwsA(
            isA<ArgumentError>()
                .having((error) => error.name, 'name', 'minimum')
                .having((error) => error.invalidValue, 'value', minimum)
                .having(
                  (error) => error.message,
                  'message',
                  'The lowest version of the Firebase CLI must be three '
                      'numbers, such as 15.6.0',
                ),
          ),
          reason: minimum,
        );
        expect(machine.calls, isEmpty, reason: minimum);
      }
    });
  });

  group('FirebaseLoginCheck', () {
    const check = FirebaseLoginCheck();

    /// A machine whose Firebase CLI runs, whose `login:list` gives [result],
    /// and whose `projects:list` gives [projects], a project by default.
    FakeMachine machineWith(
      SmfProcessResult result, {
      SmfProcessResult? projects,
    }) =>
        FakeMachine(
          executables: {'firebase': _firebase},
          reply: (call) => switch (call.arguments.first) {
            '--version' => _result(0, stdout: '15.14.0\n'),
            'projects:list' => projects ?? _result(0, stdout: _oneProject),
            _ => result,
          },
        );

    /// A machine whose Firebase CLI has the account `me@example.com`, and
    /// whose `projects:list` gives [projects].
    FakeMachine loggedIn(SmfProcessResult projects) => machineWith(
          _result(0, stdout: _accounts(['me@example.com'])),
          projects: projects,
        );

    const expired = 'the login has expired or is no longer valid';
    const logInAgain = 'Log in again with "firebase login --reauth", or on a '
        'remote machine, such as over SSH, with "firebase login --reauth '
        '--no-localhost".';

    test('needs the Firebase CLI first', () async {
      final machine = FakeMachine();

      expect(
        await check.check(machine),
        _missing(
          instructions: 'Install the Firebase CLI, then log in with '
              '"firebase login", or on a remote machine, such as over SSH, '
              'with "firebase login --no-localhost".',
          installable: false,
        ),
      );
      expect(machine.calls, isEmpty);
    });

    test(
        'passes with an account whose login lists the projects, however '
        'many, and shows nothing of the output', () async {
      for (final projects in [_oneProject, _noProject]) {
        final machine = loggedIn(_result(0, stdout: projects));

        expect(await check.check(machine), isA<PreflightPassed>());
        expect(machine.calls.map((call) => call.line), [
          '$_firebase login:list --json',
          // It asks Google, and only reads.
          '$_firebase projects:list --debug',
        ]);
        // As long as flutterfire configure waits for its list of projects.
        expect(
          machine.calls.map((call) => call.timeout),
          [null, const Duration(seconds: 40)],
        );
        final directories = machine.tempFiles.keys.map(directoryOf).toList();
        for (final (index, call) in machine.calls.indexed) {
          // A directory of its own for firebase-debug.log, and no check for
          // updates in the background.
          expect(call.workingDirectory, directories[index]);
          expect(call.environment, {'NO_UPDATE_NOTIFIER': '1'});
          expect(call.interactive, isFalse);
        }
        expect(machine.reports, isEmpty);
      }
    });

    test(
        'tells that the login has expired when Google rejects it, and offers '
        'to log in again', () async {
      for (final (name, output) in [
        ('a revoked refresh token', _revoked),
        ('the same on Windows', _revoked.replaceAll('\n', '\r\n')),
        // Google asks for a new login, as a policy of Google Workspace does,
        // when the Firebase CLI refreshes the access token.
        (
          'a login to renew',
          '[2026-09-28T12:52:54.101Z] <<< [apiv2][status] POST '
              'https://www.googleapis.com/oauth2/v3/token 400\n'
              'Authentication Error: Your credentials are no longer valid. '
              'Please run firebase login --reauth\n\n'
              'Error: Failed to list Firebase projects. See firebase-debug.log '
              'for more info.\n'
        ),
        // An access token that Google no longer accepts, before it expires.
        (
          'an access token that was revoked',
          '[2026-09-28T12:52:54.340Z] <<< [apiv2][status] GET '
              'https://firebase.googleapis.com/v1beta1/projects 401\n'
        ),
      ]) {
        final machine = loggedIn(_result(2, stdout: output, stderr: _spinner));

        expect(
          await check.check(machine),
          _missing(found: expired, instructions: logInAgain, installable: true),
          reason: name,
        );
        expect(machine.reports, isEmpty, reason: name);
      }
    });

    test(
        'says that the login could not be checked when no request reached '
        'Google, as without a network, and not that it has expired', () async {
      final offline = await check.check(
        loggedIn(_result(2, stdout: _offline, stderr: _spinner)),
      );

      expect(
        offline,
        _failed(
          '"firebase projects:list --debug" exited with code 2:\n'
          'Failed to list Firebase projects.\n'
          'request to https://firebase-public.firebaseio.com/cli.json failed, '
          'reason: getaddrinfo ENOTFOUND firebase-public.firebaseio.com\n'
          'request to https://www.googleapis.com/oauth2/v3/token failed, '
          'reason: getaddrinfo ENOTFOUND www.googleapis.com',
        ),
      );
      // The email in the output is never shown.
      expect((offline as PreflightFailed).message, isNot(contains('@')));

      // A proxy that refuses connections, as in the run of the fixtures.
      expect(
        await check.check(
          loggedIn(
            _result(
              2,
              stdout: '$_refused\n\nError: Failed to list Firebase projects. '
                  'See firebase-debug.log for more info.\n',
            ),
          ),
        ),
        _failed(
          '"firebase projects:list --debug" exited with code 2:\n'
          'Failed to list Firebase projects.\n'
          'request to https://www.googleapis.com/oauth2/v3/token failed, '
          'reason: connect ECONNREFUSED 127.0.0.1:9',
        ),
      );

      // A request that got no answer in time.
      expect(
        await check.check(
          loggedIn(
            _result(
              2,
              stdout: '[2026-09-28T12:53:25.012Z] Timeout reached making '
                  'request to $_projectsUrl?pageSize=1000\r\n'
                  'Error: Failed to list Firebase projects. See '
                  'firebase-debug.log for more info.\r\n',
            ),
          ),
        ),
        _failed(
          '"firebase projects:list --debug" exited with code 2:\n'
          'Failed to list Firebase projects.\n'
          'Timeout reached making request to $_projectsUrl?pageSize=1000',
        ),
      );
    });

    test(
        'says that the login could not be checked when the listing does not '
        'finish in 40 s, as on a network that drops the requests', () async {
      final machine = loggedIn(
        const SmfProcessResult(
          exitCode: -15,
          stdout: '[2026-09-28T13:59:21.071Z] >>> [apiv2][body] POST '
              'https://www.googleapis.com/oauth2/v3/token [omitted]\n',
          timedOut: true,
        ),
      );

      expect(
        await check.check(machine),
        _failed('"firebase projects:list --debug" did not finish in 40 s.'),
      );
      expect(machine.reports, isEmpty);
    });

    test(
        'says how the listing ended when it fails otherwise, with only its '
        'error', () async {
      // Google answered, but did not reject the login.
      for (final status in ['403', '500']) {
        expect(
          await check.check(
            loggedIn(
              _result(
                2,
                stdout: '[2026-09-28T12:52:54.101Z] <<< [apiv2][status] POST '
                    'https://www.googleapis.com/oauth2/v3/token 200\n'
                    '[2026-09-28T12:52:54.340Z] <<< [apiv2][status] GET '
                    'https://firebase.googleapis.com/v1beta1/projects '
                    '$status\n\n'
                    'Error: Failed to list Firebase projects. See '
                    'firebase-debug.log for more info.\n',
                stderr: _spinner,
              ),
            ),
          ),
          _failed(
            '"firebase projects:list --debug" exited with code 2:\n'
            'Failed to list Firebase projects.',
          ),
          reason: status,
        );
      }
      // The message of the day, which the Firebase CLI fetches without the
      // login, and a host that is not an API of Google.
      for (final url in [
        'https://firebase-public.firebaseio.com/cli.json',
        'https://example.com/v1beta1/projects',
        'https://notgoogleapis.com/oauth2/v3/token',
      ]) {
        expect(
          await check.check(
            loggedIn(
              _result(
                2,
                stdout: '<<< [apiv2][status] GET $url 401\n'
                    '<<< [apiv2][status] POST $url 400\n'
                    'Error: Failed to list Firebase projects.\n',
              ),
            ),
          ),
          _failed(
            '"firebase projects:list --debug" exited with code 2:\n'
            'Failed to list Firebase projects.',
          ),
          reason: url,
        );
      }
      // A bad request elsewhere than to refresh the access token.
      expect(
        await check.check(
          loggedIn(
            _result(
              1,
              stdout: '<<< [apiv2][status] GET $_projectsUrl 400\n'
                  'Error: Request to $_projectsUrl had HTTP Error: 400, Bad '
                  'request\n',
            ),
          ),
        ),
        _failed(
          '"firebase projects:list --debug" exited with code 1:\n'
          'Request to $_projectsUrl had HTTP Error: 400, Bad request',
        ),
      );
      // Nothing that tells why.
      expect(
        await check.check(loggedIn(_result(1, stderr: _spinner))),
        _failed('"firebase projects:list --debug" exited with code 1.'),
      );
    });

    test(
        'says only that the Firebase CLI does not run when firebase '
        '--version fails too', () async {
      for (final failure in [
        // The Firebase CLI stops before its JSON on an old Node.js.
        _result(
          1,
          stderr: 'Firebase CLI v15.14.0 is incompatible with Node.js '
              'v18.20.0 Please upgrade Node.js to version >=20.0.0',
        ),
        // A firebase command that runs the Firebase CLI of another
        // Node.js, which has none.
        _result(127, stderr: 'firebase: No such file or directory'),
      ]) {
        final machine = FakeMachine(
          executables: {'firebase': _firebase},
          reply: (_) => failure,
        );

        expect(
          await check.check(machine),
          _missing(
            found: 'the Firebase CLI does not run',
            instructions: 'Install the Firebase CLI, then log in with '
                '"firebase login", or on a remote machine, such as over SSH, '
                'with "firebase login --no-localhost".',
            installable: false,
          ),
          reason: failure.stderr,
        );
        expect(machine.calls.map((call) => call.line), [
          '$_firebase login:list --json',
          '$_firebase --version',
        ]);
        // As the check of the Firebase CLI runs it.
        expect(machine.calls.last.environment, {'NO_UPDATE_NOTIFIER': '1'});
        expect(machine.calls.last.workingDirectory, isNotNull);
      }
    });

    test('lets the cancellation of the run through, and runs nothing more',
        () async {
      final machine = FakeMachine(
        executables: {'firebase': _firebase},
        reply: (_) => throw const SmfCancelledException(),
      );

      await expectLater(
        check.check(machine),
        throwsA(isA<SmfCancelledException>()),
      );
      expect(machine.calls.map((call) => call.line), [
        '$_firebase login:list --json',
      ]);
    });

    test('says the same when the Firebase CLI cannot start', () async {
      final machine = FakeMachine(
        executables: {'firebase': _firebase},
        reply: (call) => throw ProcessException(
          call.executable,
          call.arguments,
          'Permission denied',
          13,
        ),
      );

      expect(
        await check.check(machine),
        _missing(
          found: 'the Firebase CLI does not run',
          instructions: startsWith('Install the Firebase CLI, then log in'),
          installable: false,
        ),
      );
      expect(machine.calls.map((call) => call.line), [
        '$_firebase login:list --json',
        '$_firebase --version',
      ]);
      // A command of a Firebase CLI that runs that cannot start is the
      // error of the check.
      final starts = FakeMachine(
        executables: {'firebase': _firebase},
        reply: (call) => call.arguments.first == '--version'
            ? _result(0, stdout: '15.14.0\n')
            : throw ProcessException(call.executable, call.arguments, 'x'),
      );
      await expectLater(
        check.check(starts),
        throwsA(isA<ProcessException>()),
      );
    });

    test('offers to log in when there is no account', () async {
      for (final output in [
        '{\n  "status": "success"\n}',
        '{"status": "success", "result": []}',
        // A warning before the JSON.
        '⚠  No authorized accounts\n{"status": "success"}',
      ]) {
        expect(
          await check.check(machineWith(_result(0, stdout: output))),
          _missing(
            instructions: 'Log in with "firebase login", or on a remote '
                'machine, such as over SSH, with "firebase login '
                '--no-localhost".',
            installable: true,
          ),
          reason: output,
        );
      }
    });

    test('fails when the command fails or tells nothing', () async {
      // The output of the accounts is never shown, even of a failed run.
      expect(
        await check.check(
          machineWith(_result(1, stdout: _accounts(['a@b.c']))),
        ),
        _failed('"firebase login:list --json" exited with code 1.'),
      );
      expect(
        await check.check(
          machineWith(
            _result(
              1,
              stdout: '{\n  "status": "error",\n  "error": "Failed to fetch '
                  'the accounts."\n}',
              stderr: 'Update available 15.14.0 → 15.15.0\n',
            ),
          ),
        ),
        _failed(
          '"firebase login:list --json" exited with code 1:\nFailed to fetch '
          'the accounts.\nUpdate available 15.14.0 → 15.15.0',
        ),
      );
      // An error of its own before its JSON, while the Firebase CLI runs.
      expect(
        await check.check(
          machineWith(_result(2, stderr: 'Error: Unexpected token in JSON')),
        ),
        _failed(
          '"firebase login:list --json" exited with code 2:\nError: '
          'Unexpected token in JSON',
        ),
      );
      for (final output in [
        '',
        'not json',
        '{"status": "error", "error": "x"}',
        '{"status": "success", "result": [}',
      ]) {
        expect(
          await check.check(machineWith(_result(0, stdout: output))),
          _failed(
            '"firebase login:list --json" did not report the accounts it '
            'knows.',
          ),
          reason: output,
        );
      }
    });

    test('logs in with firebase login in the terminal', () async {
      var code = 0;
      final machine = FakeMachine(
        executables: {'firebase': _firebase},
        // No account: login:list prints no JSON of one, or fails.
        reply: (_) => _result(code),
      );

      final installed = await check.install(machine);

      expect(installed.binDirs, isEmpty);
      expect(machine.calls.map((call) => call.line), [
        '$_firebase login:list --json',
        '$_firebase login',
      ]);
      expect(machine.calls.first.interactive, isFalse);
      expect(machine.calls.last.interactive, isTrue);
      expect(machine.calls.last.workingDirectory, isNotNull);

      code = 1;
      await expectLater(
        check.install(machine),
        _setupFailure('"firebase login" exited with code 1.'),
      );
      // Ctrl-C in the terminal stops only the login.
      code = -2;
      await expectLater(
        check.install(machine),
        _setupFailure('"firebase login" was stopped by signal 2.'),
      );
      await expectLater(
        check.install(FakeMachine()),
        _setupFailure('The Firebase CLI was not found.'),
      );
    });

    test(
        'logs in again with --reauth when the Firebase CLI has an account, '
        'whose login firebase login would keep', () async {
      var code = 0;
      final machine = FakeMachine(
        executables: {'firebase': _firebase},
        reply: (call) => call.arguments.first == 'login:list'
            ? _result(0, stdout: _accounts(['me@example.com']))
            : _result(code),
      );

      await check.install(machine);

      expect(machine.calls.map((call) => call.line), [
        '$_firebase login:list --json',
        '$_firebase login --reauth',
      ]);
      expect(machine.calls.last.interactive, isTrue);
      expect(machine.reports, isEmpty);

      code = 1;
      await expectLater(
        check.install(machine),
        _setupFailure('"firebase login --reauth" exited with code 1.'),
      );
    });

    test(
        'logs in with --no-localhost over SSH, where the browser is on '
        'another machine', () async {
      for (final (name, value) in [
        ('SSH_CONNECTION', '10.0.0.2 51234 10.0.0.1 22'),
        ('SSH_CLIENT', '10.0.0.2 51234 22'),
        ('SSH_TTY', '/dev/pts/0'),
      ]) {
        for (final (accounts, login) in [
          ('', 'login --no-localhost'),
          (_accounts(['me@example.com']), 'login --reauth --no-localhost'),
        ]) {
          var code = 0;
          final machine = FakeMachine(
            operatingSystem: HostOperatingSystem.linux,
            executables: {'firebase': _firebase},
            variables: {name: value},
            reply: (call) => call.arguments.first == 'login:list'
                ? _result(0, stdout: accounts)
                : _result(code),
          );

          await check.install(machine);

          expect(
            machine.calls.last.line,
            '$_firebase $login',
            reason: name,
          );
          expect(machine.calls.last.interactive, isTrue);

          code = 1;
          await expectLater(
            check.install(machine),
            _setupFailure('"firebase $login" exited with code 1.'),
            reason: name,
          );
        }
      }
    });

    test('logs in on the machine itself when a variable of SSH is empty',
        () async {
      final machine = FakeMachine(
        executables: {'firebase': _firebase},
        variables: {'SSH_CONNECTION': '', 'SSH_TTY': ''},
      );

      await check.install(machine);

      expect(machine.calls.last.line, '$_firebase login');
    });

    test('tells a session over SSH by its variables', () {
      expect(isOverSsh(FakeMachine()), isFalse);
      expect(
        isOverSsh(FakeMachine(variables: {'SSH_AUTH_SOCK': '/tmp/agent'})),
        isFalse,
        reason: 'an SSH agent runs on the machine of the user too',
      );
      expect(
        isOverSsh(
          FakeMachine(
            operatingSystem: HostOperatingSystem.windows,
            variables: {'SSH_CONNECTION': '10.0.0.2 51234 10.0.0.1 22'},
          ),
        ),
        isTrue,
        reason: 'the OpenSSH server of Windows sets it too',
      );
    });
  });

  group('FlutterfireCliCheck', () {
    const check = FlutterfireCliCheck();

    FakeMachine machineWith(SmfProcessResult result) => FakeMachine(
          executables: {'dart': _dart},
          reply: (_) => result,
        );

    test('names the versions that it accepts', () {
      expect(check.description, 'FlutterFire CLI 1.4.1 or a later 1.x');
    });

    test('passes with flutterfire_cli 1.4.1 or a later 1.x active', () async {
      for (final version in ['1.4.1', '1.5.0', '1.9.12', '1.4.2-dev.1']) {
        final machine = machineWith(
          _result(
            0,
            stdout: 'coverage 1.15.1\nflutterfire_cli $version\nmelos 7.5.1\n',
          ),
        );

        expect(await check.check(machine), isA<PreflightPassed>());
        expect(machine.calls.single.line, '$_dart pub global list');
      }
    });

    test('offers to activate it when it is not active', () async {
      expect(
        await check.check(machineWith(_result(0, stdout: 'melos 7.5.1\n'))),
        _missing(
          instructions: 'Activate it with "dart pub global activate '
              'flutterfire_cli 1.4.1".',
          installable: true,
        ),
      );
    });

    test('offers to activate it in place of an older version', () async {
      for (final version in ['1.4.0', '1.4.1-dev.1', '1.3.2', '0.3.0-dev.1']) {
        expect(
          await check.check(
            machineWith(
              _result(0, stdout: 'flutterfire_cli $version at path "/x"\n'),
            ),
          ),
          _missing(
            found: 'flutterfire_cli $version is active',
            instructions: 'Activate 1.4.1 in its place with "dart pub global '
                'activate flutterfire_cli 1.4.1".',
            installable: true,
          ),
          reason: version,
        );
      }
    });

    test(
        'activates 1.4.1 in place of 1.4.0, whose build phases fail with '
        'Swift Package Manager, and passes then', () async {
      var active = '1.4.0';
      final machine = FakeMachine(
        executables: {'dart': _dart},
        reply: (call) {
          if (call.arguments.contains('activate')) active = '1.4.1';
          return _result(0, stdout: 'flutterfire_cli $active\n');
        },
      );

      expect(
        await check.check(machine),
        _missing(
          found: 'flutterfire_cli 1.4.0 is active',
          instructions: startsWith('Activate 1.4.1 in its place'),
          installable: true,
        ),
      );
      await check.install(machine);
      expect(await check.check(machine), isA<PreflightPassed>());
      expect(machine.calls.map((call) => call.line), [
        '$_dart pub global list',
        '$_dart pub global activate flutterfire_cli 1.4.1',
        '$_dart pub global list',
      ]);
    });

    test('never replaces a newer major version, but tells how', () async {
      for (final active in ['2.0.0', '2.1.0-dev.3 at path "/x"', '10.0.1']) {
        final version = active.split(' ').first;
        expect(
          await check.check(
            machineWith(_result(0, stdout: 'flutterfire_cli $active\n')),
          ),
          _missing(
            found: 'flutterfire_cli $version is active',
            instructions: 'SMF does not replace a newer major version, which '
                'other apps may need. To use 1.4.1, activate it with "dart pub '
                'global activate flutterfire_cli 1.4.1".',
            installable: false,
          ),
          reason: active,
        );
      }
    });

    test('fails on a version it cannot read', () async {
      expect(
        await check.check(
          machineWith(_result(0, stdout: 'flutterfire_cli main\n')),
        ),
        _failed(
          '"dart pub global list" reported flutterfire_cli "main", which is '
          'not a version.',
        ),
      );
    });

    test('fails without dart or when dart fails', () async {
      expect(
        await check.check(FakeMachine()),
        _failed('dart of the Flutter SDK was not found.'),
      );
      expect(
        await check.check(machineWith(_result(65))),
        _failed('"dart pub global list" exited with code 65.'),
      );
    });

    test('cannot activate it without dart', () async {
      await expectLater(
        check.install(FakeMachine()),
        _setupFailure('dart of the Flutter SDK was not found.'),
      );
    });

    test('activates the version whose Gradle edits the tests repeat', () async {
      var code = 0;
      final machine = FakeMachine(
        executables: {'dart': _dart},
        reply: (_) => _result(code, stderr: 'Could not resolve'),
      );

      final installed = await check.install(machine);

      expect(
        machine.calls.single.line,
        '$_dart pub global activate flutterfire_cli 1.4.1',
      );
      expect(installed.tool, same(flutterfireTool));
      expect(machine.reports, [
        'progress: Activating the FlutterFire CLI',
        'complete: Activated the FlutterFire CLI 1.4.1',
      ]);

      code = 69;
      await expectLater(
        check.install(machine),
        _setupFailure(
          '"dart pub global activate flutterfire_cli 1.4.1" exited with code '
          '69:\nCould not resolve',
        ),
      );
    });

    test('stops its progress when the user cancels the run', () async {
      final machine = FakeMachine(
        executables: {'dart': _dart},
        reply: (_) => throw const SmfCancelledException(),
      );

      await expectLater(
        check.install(machine),
        throwsA(isA<SmfCancelledException>()),
      );
      expect(machine.reports, [
        'progress: Activating the FlutterFire CLI',
        'fail: Activating the FlutterFire CLI',
      ]);
    });

    test('passes no character to dart.bat that cmd.exe reads itself', () {
      // On Windows, dart is a batch file, which cmd.exe runs.
      for (final argument in [
        flutterfireVersion,
        ...flutterfireTool.prefixArgs,
      ]) {
        expect(argument, isNot(contains(RegExp('[%^&|<>"]'))));
      }
    });

    test('accepts 1.4.1 and every later 1.x version', () {
      expect(minimumFlutterfireVersion, '1.4.1');
      for (final version in [
        '1.4.1',
        '1.4.1+2',
        '1.4.2',
        '1.4.2-dev.1',
        '1.5.0',
        '1.10.3',
      ]) {
        expect(isSupportedFlutterfireVersion(version), isTrue, reason: version);
      }
      for (final version in [
        '1.4.0',
        '1.4.0+2',
        '1.4.1-dev.1',
        '1.4.1-dev.1+2',
        '1.3.9',
        '0.9.0',
        '2.0.0',
        '1',
        'x',
      ]) {
        expect(
          isSupportedFlutterfireVersion(version),
          isFalse,
          reason: version,
        );
      }
    });
  });

  group('XcodeProjectToolsCheck', () {
    const check = XcodeProjectToolsCheck();

    FakeMachine macWith(SmfProcessResult result) => FakeMachine(
          executables: {'ruby': _ruby},
          reply: (_) => result,
        );

    test('needs nothing elsewhere than on macOS', () async {
      for (final system in [
        HostOperatingSystem.linux,
        HostOperatingSystem.windows,
        HostOperatingSystem.other,
      ]) {
        final machine = FakeMachine(operatingSystem: system);

        expect(await check.check(machine), isA<PreflightPassed>());
        expect(machine.calls, isEmpty);
      }
    });

    test('passes on macOS with xcodeproj 1.23.0 or newer', () async {
      for (final version in ['1.23.0', '1.27.0', '1.28.1\n']) {
        final machine = macWith(_result(0, stdout: version));

        expect(await check.check(machine), isA<PreflightPassed>());
        expect(machine.calls.single.arguments, [
          '-e',
          "require 'xcodeproj'; print Xcodeproj::VERSION",
        ]);
      }
    });

    test('tells how to install Ruby, the gem or a newer gem', () async {
      expect(
        await check.check(FakeMachine()),
        _missing(
          instructions: 'flutterfire configure changes the Xcode project with '
              'Ruby and its gem xcodeproj 1.23.0 or newer: install Ruby, then '
              'the gem with "gem install xcodeproj".',
          installable: false,
        ),
      );
      expect(
        await check.check(macWith(_result(1, stderr: 'cannot load such file'))),
        _missing(
          instructions: 'flutterfire configure changes the Xcode project with '
              'the Ruby gem xcodeproj 1.23.0 or newer: install it with "gem '
              'install xcodeproj", with a Ruby version manager or, for the '
              'Ruby of macOS, with sudo.',
          installable: false,
        ),
      );
      expect(
        await check.check(macWith(_result(0, stdout: '1.22.0'))),
        _missing(
          found: 'the Ruby gem xcodeproj is 1.22.0',
          instructions: 'flutterfire configure needs 1.23.0 or newer to open '
              'the Xcode project of the app, which has a Swift package: '
              'install it with "gem install xcodeproj", with a Ruby version '
              'manager or, for the Ruby of macOS, with sudo.',
          installable: false,
        ),
      );
    });

    test('fails on a version it cannot read', () async {
      expect(
        await check.check(macWith(_result(0, stdout: 'unknown'))),
        _failed('Ruby printed "unknown" for the version of the gem xcodeproj.'),
      );
    });
  });

  group('XcodeProjectOnMacCheck', () {
    const check = XcodeProjectOnMacCheck();

    test(
        'warns elsewhere than on macOS that the Xcode project stays as it is, '
        'without the build phases of some Firebase packages', () async {
      for (final system in [
        HostOperatingSystem.linux,
        HostOperatingSystem.windows,
        HostOperatingSystem.other,
      ]) {
        final machine = FakeMachine(operatingSystem: system);

        expect(
          await check.check(machine),
          _missing(
            found: 'this machine is not a Mac',
            instructions: 'flutterfire configure changes the Xcode project '
                'only on macOS. Elsewhere it registers the iOS app and writes '
                'its options into lib/firebase_options.dart, but writes no '
                'GoogleService-Info.plist and leaves the Xcode project as it '
                'is, without the build phases that it adds for some Firebase '
                'packages: run flutterfire configure again on a Mac.',
            installable: false,
          ),
          reason: '$system',
        );
        expect(machine.calls, isEmpty);
      }
    });

    test('passes on macOS', () async {
      final machine = FakeMachine();

      expect(await check.check(machine), isA<PreflightPassed>());
      expect(machine.calls, isEmpty);
    });
  });

  group('the helpers', () {
    test('find the directory of a file with either separator', () {
      expect(directoryOf('/tmp/smf/a/file.sh'), '/tmp/smf/a');
      expect(directoryOf(r'C:\Temp\smf\a\file.ps1'), r'C:\Temp\smf\a');
      expect(directoryOf('/file'), '/');
      expect(directoryOf('file'), '');
    });

    test('tell a signal from an exit code outside Windows only', () {
      expect(
        endOf('x', -2, HostOperatingSystem.macos),
        '"x" was stopped by signal 2',
      );
      expect(
        endOf('x', -15, HostOperatingSystem.linux),
        '"x" was stopped by signal 15',
      );
      // STATUS_CONTROL_C_EXIT, 0xC000013A, as a signed 32-bit exit code.
      expect(
        endOf('x', -1073741510, HostOperatingSystem.windows),
        '"x" exited with code -1073741510',
      );
      expect(
        endOf('x', 3, HostOperatingSystem.windows),
        '"x" exited with code 3',
      );
    });

    test('keep the last lines of each stream, the errors first', () {
      final result = _result(
        1,
        stdout: [for (var i = 1; i <= 25; i++) 'out $i\r'].join('\n'),
        stderr: 'error 1\n\nerror 2\n',
      );

      // A long output keeps the errors.
      expect(
        outputTail(result),
        [
          'error 1',
          'error 2',
          '…',
          for (var i = 6; i <= 25; i++) 'out $i',
        ].join('\n'),
      );
      expect(outputTail(result, lines: 30).split('\n').take(3), [
        'error 1',
        'error 2',
        'out 1',
      ]);
      expect(
        outputTail(_result(1, stderr: 'e1\ne2\ne3'), lines: 2),
        '…\ne2\ne3',
      );
      expect(outputTail(_result(1, stdout: ' \n')), isEmpty);
    });

    test('read each directory that an install script printed once', () {
      expect(
        binDirsIn('x\n smf-bin-dir=/a \nsmf-bin-dir=\nsmf-bin-dir=/b\r\n'
            'smf-bin-dir=/a\n'),
        ['/a', '/b'],
      );
    });
  });
}
