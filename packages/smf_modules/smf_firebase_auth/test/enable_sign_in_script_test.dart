// The script that enables the sign-in methods runs here for real, as the
// step of the module and a user run it: with the Dart VM, in the files of
// an app that the module rendered, in each mode of the auth role. A
// stand-in for the Firebase CLI is on its PATH, a Dart program that notes
// how it was called, so nothing reaches Firebase.
//
// A test starts the Dart VM for the script and for each call of the
// stand-in, some of them many times over, so it gets more time than a test
// has by default.
@TestOn('vm')
@Timeout(Duration(minutes: 3))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_auth/smf_firebase_auth.dart';
import 'package:smf_firebase_auth/src/enable_sign_in.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

import 'support/dart_app.dart';

/// The stand-in for the Firebase CLI. It appends to the file that
/// `STAND_IN_CALLS` names a line of JSON for each call: its arguments, the
/// directory it ran in, the files there, with their texts, and whether it
/// may check for a newer version, which the Firebase CLI does unless
/// `NO_UPDATE_NOTIFIER` is set.
///
/// As the Firebase CLI does on every call, it opens a log,
/// `firebase-debug.log`, in the directory it runs in, and removes it when
/// it ends, unless `DEBUG` is set or its exit code is 2 or more.
///
/// `--version` prints the lines of `STAND_IN_VERSION`, which `|` separates,
/// or 15.14.0, and what `STAND_IN_VERSION_ERRORS` has on the standard
/// error, and exits with `STAND_IN_VERSION_CODE`. Any other call prints a
/// line on each stream and exits with `STAND_IN_DEPLOY_CODE`. With
/// `STAND_IN_REMOVES_DIRECTORY`, it removes the directory it ran in first.
/// When `STAND_IN_WAITS` names the call, `version` or `deploy`, it waits
/// once it has noted the call, until a signal ends it.
const _standIn = r"""
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final environment = Platform.environment;
  final asksVersion = arguments.length == 1 && arguments.single == '--version';
  final directory = Directory.current;
  File(environment['STAND_IN_CALLS']!).writeAsStringSync(
    '${jsonEncode({
      'arguments': arguments,
      'directory': directory.resolveSymbolicLinksSync(),
      'files': {
        for (final file in directory.listSync().whereType<File>())
          file.uri.pathSegments.last: file.readAsStringSync(),
      },
      'checksForUpdates': !environment.containsKey('NO_UPDATE_NOTIFIER'),
    })}\n',
    mode: FileMode.append,
    flush: true,
  );
  final log = File('firebase-debug.log')..writeAsStringSync('$arguments\n');
  if (environment['STAND_IN_WAITS'] == (asksVersion ? 'version' : 'deploy')) {
    await Future<void>.delayed(const Duration(minutes: 2));
  }
  final int code;
  if (asksVersion) {
    final version = environment['STAND_IN_VERSION'] ?? '15.14.0';
    stdout.writeln(version.split('|').join('\n'));
    stderr.write(environment['STAND_IN_VERSION_ERRORS'] ?? '');
    code = int.parse(environment['STAND_IN_VERSION_CODE'] ?? '0');
  } else {
    stdout.writeln('stand-in: deploying');
    stderr.writeln('stand-in: on the standard error');
    code = int.parse(environment['STAND_IN_DEPLOY_CODE'] ?? '0');
  }
  if (environment.containsKey('STAND_IN_REMOVES_DIRECTORY') && !asksVersion) {
    directory.deleteSync(recursive: true);
  } else if (!environment.containsKey('DEBUG') && code < 2) {
    log.deleteSync();
  }
  exitCode = code;
}
""";

/// The command `firebase` of the tests on Windows, a batch file as npm
/// installs one: it runs [_standIn], next to it, with the Dart VM that
/// `SMF_TEST_DART` names and every argument it gets. It has no path of its
/// own, so it holds on a machine whose paths have other letters than those
/// of ASCII.
const _batch = '@echo off\r\n"%SMF_TEST_DART%" "%~dp0stand_in.dart" %*\r\n';

/// The command `firebase` of the tests elsewhere, a shell script that does
/// the same, with nothing but the shell: its `PATH` has no other command.
const _shell = '#!/bin/sh\n'
    'exec "\$SMF_TEST_DART" "\${0%/*}/stand_in.dart" "\$@"\n';

/// The ids of the Firebase apps of an app for Android and iOS.
const _androidApp = '1:1234567890:android:0a1b2c3d4e5f6789';
const _iosApp = '1:1234567890:ios:0a1b2c3d4e5f6789';

/// `firebase.json` as `flutterfire configure` of flutterfire_cli 1.4.1
/// writes it for an app for Android and iOS in [project]: on one line, the
/// id of the project for each platform and for the options of Dart
/// (`writeToFirebaseJson` in `lib/src/common/utils.dart` there, with the
/// paths of `lib/src/firebase/firebase_android_writes.dart`,
/// `firebase_apple_writes.dart` and `firebase_dart_configuration_write.dart`).
String _configuredFor(String project) => jsonEncode({
      'flutter': {
        'platforms': {
          'android': {
            'default': {
              'projectId': project,
              'appId': _androidApp,
              'fileOutput': 'android/app/google-services.json',
            },
          },
          'ios': {
            'default': {
              'projectId': project,
              'appId': _iosApp,
              'uploadDebugSymbols': false,
              'fileOutput': 'ios/Runner/GoogleService-Info.plist',
            },
          },
          'dart': {
            'lib/firebase_options.dart': {
              'projectId': project,
              'configurations': {'android': _androidApp, 'ios': _iosApp},
            },
          },
        },
      },
    });

/// `firebase.json` as flutterfire writes it for an app whose Android build
/// types and whose iOS build configurations and targets have service files
/// of their own, in the projects [android], [debug], [release] and
/// [target], next to keys of the Firebase CLI, which flutterfire keeps: the
/// id of a project is then under the name of the build type, of the build
/// configuration or of the target.
String _configuredByBuild({
  required String android,
  required String debug,
  required String release,
  required String target,
}) =>
    jsonEncode({
      'hosting': {'public': 'build/web'},
      'firestore': {'rules': 'firestore.rules'},
      'flutter': {
        'platforms': {
          'android': {
            'buildConfigurations': {
              'src/staging': {
                'projectId': android,
                'appId': _androidApp,
                'fileOutput': 'android/app/src/staging/google-services.json',
              },
            },
          },
          'ios': {
            'buildConfigurations': {
              'Debug': {
                'projectId': debug,
                'appId': _iosApp,
                'uploadDebugSymbols': false,
                'fileOutput': 'ios/Debug/GoogleService-Info.plist',
              },
              'Release': {
                'projectId': release,
                'appId': _iosApp,
                'uploadDebugSymbols': true,
                'fileOutput': 'ios/Release/GoogleService-Info.plist',
              },
            },
            'targets': {
              'Runner': {
                'projectId': target,
                'appId': _iosApp,
                'uploadDebugSymbols': false,
                'fileOutput': 'ios/Runner/GoogleService-Info.plist',
              },
            },
          },
        },
      },
    });

/// The configuration that the script gives the Firebase CLI for an app
/// that signs in with an address and a password, and for one that also
/// signs in anonymous users.
const _emailPassword = '{"auth":{"providers":{"emailPassword":true}}}';
const _withAnonymous =
    '{"auth":{"providers":{"emailPassword":true,"anonymous":true}}}';

/// How the Firebase console enables the methods in [project], as the
/// script tells after a failure.
String _inConsole([String project = '_']) =>
    'The Firebase console enables the methods too, under Authentication > '
    'Sign-in method: '
    'https://console.firebase.google.com/project/$project/authentication/'
    'providers';

/// The line with which the script says what it enables, in [project], for
/// an app in [mode].
String _enabling(String project, AuthMode mode) => 'Enabling Email/Password'
    '${mode == AuthMode.anonymous ? ' and Anonymous' : ''} in the Firebase '
    'project $project (the mode of the app is ${mode.name}).';

/// The first line of what the script tells after the Firebase CLI failed
/// with [code].
String _failed(int code) =>
    'The Firebase CLI did not enable the sign-in methods (exit code $code).';

/// What the script tells of the account after a failure, when its
/// arguments name none.
const _maybeAnotherAccount = '- If it ran as the wrong account: this script '
    'runs the Firebase CLI in a temporary directory, where an account that '
    '"firebase login:use" chose for the directory of the app does not '
    'apply. To name the account, run: $enableSignInCommand --account <email>';

/// What the script tells of the log of the Firebase CLI after a failure.
const _withDebug = '- Its log, firebase-debug.log, was in that temporary '
    'directory, which this script removes. To see what the Firebase CLI '
    'did, run: $enableSignInCommand --debug';

/// Why the script cannot tell the mode of the app.
const _cannotTell = 'Cannot tell the sign-in mode of the app, by which this '
    'script enables Anonymous or leaves it out';

/// A call of the stand-in for the Firebase CLI: its arguments, the
/// directory it ran in, the files there, by name, with their texts, and
/// whether it may check for a newer version.
typedef _Call = ({
  List<String> arguments,
  String directory,
  Map<String, String> files,
  bool checksForUpdates,
});

/// What a run of the script left: its exit code, what it and the Firebase
/// CLI printed, and the calls of the Firebase CLI.
typedef _Run = ({int code, String output, String errors, List<_Call> calls});

/// What a Firebase CLI may print for `--version`, with `|` between its
/// lines: notices that have versions, one at the start of its line, and
/// then its own version.
const _withNotices = 'Update available 15.5.0 -> 16.2.0|9.0.0 is no longer '
    'supported.|16.2.0';

/// The call that the stand-in noted on [line].
_Call _callOf(String line) {
  final call = jsonDecode(line) as Map<String, Object?>;
  return (
    arguments: (call['arguments']! as List<Object?>).cast<String>(),
    directory: call['directory']! as String,
    files: (call['files']! as Map<String, Object?>).cast<String, String>(),
    checksForUpdates: call['checksForUpdates']! as bool,
  );
}

void main() {
  /// The app of the module in each mode of the auth role.
  final rendered = <AuthMode, RenderedApp>{};

  /// A directory of the test, with links resolved: `bin` with the Firebase
  /// CLI, `none` without it, `temp` for the temporary files of the script,
  /// and `elsewhere`, which is no directory of an app.
  late Directory machine;
  late DartApp app;

  /// The path of [name] in [machine], as the system writes it.
  String inMachine(String name) =>
      '${machine.path}${Platform.pathSeparator}$name';

  setUpAll(() async {
    const modules = [
      FlutterCoreModule(),
      FirebaseCoreModule(),
      FirebaseAuthModule(),
    ];
    for (final mode in AuthMode.values) {
      final result = await ContractHarness(ModuleRegistry(modules)).check(
        ContractCase(
          'firebase_auth in the mode ${mode.name}',
          requested: const [FirebaseAuthModule.id],
          roleOptions: {AuthRole.modeOption.name: mode.name},
        ),
      );
      expect(result.errors, isEmpty, reason: mode.name);
      expect(
        authRole.modeIn(authRole.hookInput(result.hook!)),
        mode,
        reason: 'The app is rendered in the mode that the test asked for.',
      );
      rendered[mode] = result.app!;
    }
  });

  setUp(() {
    machine = Directory(
      Directory.systemTemp
          .createTempSync('smf_enable_sign_in_')
          .resolveSymbolicLinksSync(),
    );
    for (final name in ['bin', 'none', 'temp', 'elsewhere']) {
      Directory(inMachine(name)).createSync();
    }
    // The Firebase CLI is a command of the shell on every system, as npm
    // installs it, which runs the program next to it.
    final bin = '${inMachine('bin')}${Platform.pathSeparator}';
    File('${bin}stand_in.dart').writeAsStringSync(_standIn);
    if (Platform.isWindows) {
      File('${bin}firebase.cmd').writeAsStringSync(_batch, encoding: ascii);
    } else {
      File('${bin}firebase').writeAsStringSync(_shell);
      expect(Process.runSync('chmod', ['+x', '${bin}firebase']).exitCode, 0);
    }
    app = DartApp.write(rendered[AuthMode.required]!);
  });

  tearDown(() {
    app.delete();
    machine.deleteSync(recursive: true);
  });

  /// The path of `firebase.json` of [app], as the script names it.
  String configOf(DartApp app) => '${app.path}/firebase.json';

  /// The file in which the stand-in notes its calls.
  File calls() => File(inMachine('calls'));

  /// The calls that the stand-in noted so far.
  List<_Call> callsSoFar() => [
        if (calls().existsSync())
          for (final line in calls().readAsLinesSync()) _callOf(line),
      ];

  /// Starts the script of [of], or of the app of the test, with
  /// [arguments], as `dart tool/enable_firebase_sign_in.dart` in the
  /// directory of the app, or in [workingDirectory] with [script], the path
  /// of the script there, or its path in the app.
  ///
  /// The `PATH` of the script is the directory with the Firebase CLI, or an
  /// empty one unless [withFirebase], and its temporary files go into a
  /// directory of the test. [standIn] has the variables of the stand-in.
  /// The script does not get `DEBUG` or `NO_UPDATE_NOTIFIER` of the machine
  /// of the test: what the Firebase CLI gets of them is the test's and the
  /// script's to say.
  Future<Process> start({
    DartApp? of,
    List<String> arguments = const [],
    Map<String, String> standIn = const {},
    bool withFirebase = true,
    String? workingDirectory,
    String? script,
  }) {
    final target = of ?? app;
    final changes = {
      'PATH': inMachine(withFirebase ? 'bin' : 'none'),
      'TMPDIR': inMachine('temp'),
      'TEMP': inMachine('temp'),
      'TMP': inMachine('temp'),
      'SMF_TEST_DART': Platform.resolvedExecutable,
      'STAND_IN_CALLS': calls().path,
      ...standIn,
    };
    // The names of the variables of Windows are in any case, such as
    // `Path`, so a variable of the test replaces the one of the machine
    // whatever its case.
    final replaced = {
      for (final name in changes.keys) name.toUpperCase(),
      'DEBUG',
      'NO_UPDATE_NOTIFIER',
    };
    return Process.start(
      Platform.resolvedExecutable,
      [
        if (workingDirectory == null)
          enableSignInScript
        else
          script ?? '${target.path}/$enableSignInScript',
        ...arguments,
      ],
      workingDirectory: workingDirectory ?? target.path,
      environment: {
        for (final MapEntry(:key, :value) in Platform.environment.entries)
          if (!replaced.contains(key.toUpperCase())) key: value,
        ...changes,
      },
      includeParentEnvironment: false,
    );
  }

  /// What [process], a run of the script, leaves when it ends, once it
  /// removed its temporary directory.
  Future<_Run> finish(Process process) async {
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.transform(utf8.decoder).join();
    final code = await process.exitCode;
    final printed = (await output).replaceAll('\r\n', '\n');
    final failed = (await errors).replaceAll('\r\n', '\n');
    expect(
      Directory(inMachine('temp')).listSync(),
      isEmpty,
      reason: 'The script removes its temporary directory.\n$failed',
    );
    return (code: code, output: printed, errors: failed, calls: callsSoFar());
  }

  /// Runs the script as [start] starts it, and forgets the calls of the
  /// stand-in afterwards, for the next run of the test.
  Future<_Run> run({
    DartApp? of,
    List<String> arguments = const [],
    Map<String, String> standIn = const {},
    bool withFirebase = true,
    String? workingDirectory,
    String? script,
  }) async {
    final result = await finish(
      await start(
        of: of,
        arguments: arguments,
        standIn: standIn,
        withFirebase: withFirebase,
        workingDirectory: workingDirectory,
        script: script,
      ),
    );
    if (calls().existsSync()) calls().deleteSync();
    return result;
  }

  /// The arguments of the calls of [run], each on a line.
  List<String> commandsOf(_Run run) => [
        for (final call in run.calls) call.arguments.join(' '),
      ];

  /// The files and directories right in the directory of [app], by name.
  Set<String> entriesOf(DartApp app) => {
        for (final entity in Directory(app.path).listSync())
          entity.uri.pathSegments.lastWhere((segment) => segment.isNotEmpty),
      };

  /// The file of the session of [app], which has the mode of the app.
  File sessionOf(DartApp app) => File('${app.path}/${AuthRole.sessionFile}');

  group('the script of the app', () {
    test(
        'is the file of the brick of the module, with what the auth role '
        'says of the mode: its file, how a tool reads the mode there, and '
        'the mode with anonymous users', () {
      final script = rendered[AuthMode.required]!.files[enableSignInScript]!;

      expect(script.owner, const ModuleOrigin(FirebaseAuthModule.id));
      expect(
        script.text,
        allOf(
          contains("const _sessionFile = '${AuthRole.sessionFile}';"),
          contains("const _anonymous = '${AuthMode.anonymous.name}';"),
          contains("const _firstCli = '$firstFirebaseCliWithSignIn';"),
          contains("const _command = '$enableSignInCommand';"),
          contains(
            'final _modeDeclaration = RegExp(\n'
            '  $modeDeclarationCode,\n'
            '  multiLine: true,\n'
            ');\n',
          ),
          isNot(contains('{{')),
        ),
      );
      // The expression of the role, whole, in raw strings of the script.
      expect(
        [
          for (final string
              in RegExp("r'([^']*)'").allMatches(modeDeclarationCode))
            string[1],
        ].join(),
        AuthRole.modeDeclaration,
      );
      expect(
        modeDeclarationCode.split('\n').map((line) => line.length),
        everyElement(lessThanOrEqualTo(78)),
      );
      // The check of the machine and the script ask for the same version.
      expect(firebaseCliWithSignIn.minimum, firstFirebaseCliWithSignIn);
    });

    test('is the same in every mode of the auth role', () {
      final scripts = {
        for (final app in rendered.values) app.files[enableSignInScript]!.text,
      };

      expect(scripts, hasLength(1));
    });

    test(
        'enables Email/Password in the project of flutterfire configure: it '
        'runs the Firebase CLI in a temporary directory, for its version '
        'too, with a configuration of its own there, and without its check '
        'for a newer version', () async {
      final config = File(configOf(app))
        ..writeAsStringSync(_configuredFor('smf-app'));
      final before = entriesOf(app);

      final result = await run();

      expect(result.code, 0, reason: result.errors);
      expect(commandsOf(result), [
        '--version',
        'deploy --only auth --project=smf-app --non-interactive',
      ]);
      // Both calls ran in one directory of the script, which had nothing
      // but the configuration of the deploy, and is removed.
      final [version, deploy] = result.calls;
      expect(
        Directory(version.directory).parent.uri,
        Directory(inMachine('temp')).uri,
      );
      expect(
        version.directory.split(RegExp(r'[/\\]')).last,
        startsWith('firebase_sign_in_'),
      );
      expect(deploy.directory, version.directory);
      expect(version.files, isEmpty);
      expect(deploy.files, {'firebase.json': _emailPassword});
      expect(Directory(deploy.directory).existsSync(), isFalse);
      expect(
        [version.checksForUpdates, deploy.checksForUpdates],
        [false, false],
        reason: 'The Firebase CLI checks for a newer version in a process '
            'of its own, which goes on after the command. On Windows, the '
            'directory of a process that runs cannot be removed, so the '
            'script turns the check off.',
      );
      // The script says what it enables and where, and then the Firebase
      // CLI has the terminal.
      expect(result.output.split('\n'), [
        _enabling('smf-app', AuthMode.required),
        'stand-in: deploying',
        '',
      ]);
      expect(result.errors, 'stand-in: on the standard error\n');
      // Nothing of the app changed: flutterfire and a later firebase deploy
      // of the app find what they left.
      expect(config.readAsStringSync(), _configuredFor('smf-app'));
      expect(entriesOf(app), before);
      expect(File('${app.path}/.firebaserc').existsSync(), isFalse);
    });

    test(
        'changes no file of the app when the Firebase CLI keeps its log, as '
        'with DEBUG set: the log is in the temporary directory, from the '
        'call for the version on', () async {
      File(configOf(app)).writeAsStringSync(_configuredFor('smf-app'));
      final before = entriesOf(app);

      // The script is run in another directory too, where the Firebase CLI
      // must leave nothing either.
      for (final workingDirectory in [null, inMachine('elsewhere')]) {
        final result = await run(
          standIn: {'DEBUG': 'true'},
          workingDirectory: workingDirectory,
        );

        expect(result.code, 0, reason: result.errors);
        expect(result.calls.last.files, {
          'firebase-debug.log': '[--version]\n',
          'firebase.json': _emailPassword,
        });
        expect(entriesOf(app), before);
        expect(Directory(inMachine('elsewhere')).listSync(), isEmpty);
      }
    });

    test(
        'enables what the mode of the app needs: Anonymous too in the mode '
        'anonymous, and only Email/Password in the others', () async {
      final found = <AuthMode, (String, String)>{};
      for (final mode in AuthMode.values) {
        final ofMode = DartApp.write(rendered[mode]!);
        try {
          File(configOf(ofMode)).writeAsStringSync(_configuredFor('smf-app'));
          final result = await run(of: ofMode);
          expect(result.code, 0, reason: '${mode.name}: ${result.errors}');
          found[mode] = (
            result.calls.last.files['firebase.json']!,
            result.output.split('\n').first,
          );
        } finally {
          ofMode.delete();
        }
      }

      expect(found, {
        AuthMode.required: (
          _emailPassword,
          'Enabling Email/Password in the Firebase project smf-app (the mode '
              'of the app is required).',
        ),
        AuthMode.guest: (
          _emailPassword,
          'Enabling Email/Password in the Firebase project smf-app (the mode '
              'of the app is guest).',
        ),
        AuthMode.anonymous: (
          _withAnonymous,
          'Enabling Email/Password and Anonymous in the Firebase project '
              'smf-app (the mode of the app is anonymous).',
        ),
      });
    });

    test(
        'follows the mode that the developer of the app changed in the file '
        'of the auth role, as the role says to read it', () async {
      File(configOf(app)).writeAsStringSync(_configuredFor('smf-app'));
      final session = sessionOf(app);
      const generated = 'const AuthMode authMode = AuthMode.required;';
      final text = session.readAsStringSync();
      expect(text, contains('\n$generated\n'));

      final configs = <String, String>{};
      for (final changed in [
        'const AuthMode authMode = AuthMode.anonymous;',
        // As a developer may write it, and as dart format may leave it.
        'const authMode = AuthMode.anonymous;',
        'const AuthMode authMode =\n    AuthMode.anonymous;',
        'const AuthMode authMode = AuthMode.guest;',
        // A declaration within a comment decides nothing.
        '// const AuthMode authMode = AuthMode.anonymous;\n$generated',
        '/*\nconst AuthMode authMode = AuthMode.anonymous;\n*/\n$generated',
      ]) {
        session.writeAsStringSync(text.replaceFirst(generated, changed));
        // What the script reads is what the role reads.
        final ofRole = authRole.modeWrittenIn(session.readAsStringSync());
        expect(ofRole, isNotNull, reason: changed);
        final result = await run();
        expect(result.code, 0, reason: '$changed: ${result.errors}');
        expect(
          result.output,
          startsWith('${_enabling('smf-app', ofRole!)}\n'),
          reason: changed,
        );
        configs[changed] = result.calls.last.files['firebase.json']!;
      }

      expect(configs.values, [
        _withAnonymous,
        _withAnonymous,
        _withAnonymous,
        _emailPassword,
        _emailPassword,
        _emailPassword,
      ]);
    });

    test(
        'stops before the Firebase CLI when the file of the auth role does '
        'not tell the mode, names the file that it read, and tells of the '
        'Firebase console', () async {
      File(configOf(app)).writeAsStringSync(_configuredFor('smf-app'));
      final session = sessionOf(app);
      const generated = 'const AuthMode authMode = AuthMode.required;';
      const computed = 'final AuthMode authMode = modeOfBuild();';
      final text = session.readAsStringSync();
      final noDeclaration = '$_cannotTell: ${session.path} does not have '
          'one declaration such as "$generated", which starts its line and '
          'has a mode of the app as its value.\n'
          '${_inConsole()}\n';

      for (final (name, changed) in [
        ('a mode that is computed', computed),
        ('two modes', '$generated\nconst AuthMode authMode = AuthMode.guest;'),
        // It would enable Email/Password alone for an app that may need
        // Anonymous too.
        ('no mode', 'const AuthMode authMode = AuthMode.anonymus;'),
        (
          'a mode within a comment only',
          '/*\nconst AuthMode authMode = AuthMode.anonymous;\n*/\n$computed',
        ),
      ]) {
        session.writeAsStringSync(text.replaceFirst(generated, changed));
        expect(
          authRole.modeWrittenIn(session.readAsStringSync()),
          isNull,
          reason: name,
        );

        final result = await run();

        expect(result.code, 1, reason: name);
        expect(result.errors, noDeclaration, reason: name);
        expect(result.output, isEmpty, reason: name);
        expect(result.calls, isEmpty, reason: name);
      }

      // As Windows PowerShell 5 writes a file with `>`.
      session.writeAsBytesSync([0xFF, 0xFE, ...utf8.encode(text)]);
      final unreadable = await run();

      expect(unreadable.code, 1);
      expect(
        unreadable.errors,
        allOf(
          startsWith(
            '${session.path} could not be read as a text in UTF-8 (',
          ),
          endsWith(').\n'),
          isNot(contains('#0 ')),
        ),
      );
      expect(unreadable.calls, isEmpty);

      session.deleteSync();
      final missing = await run();

      expect(missing.code, 1);
      expect(
        missing.errors,
        '$_cannotTell: ${session.path} is missing.\n${_inConsole()}\n',
      );
      expect(missing.calls, isEmpty);
    });

    test(
        'reads the project wherever flutterfire writes its id: for a build '
        'type of Android, and for a build configuration or a target of iOS',
        () async {
      File(configOf(app)).writeAsStringSync(
        _configuredByBuild(
          android: 'smf-app',
          debug: 'smf-app',
          release: 'smf-app',
          target: 'smf-app',
        ),
      );

      final result = await run();

      expect(result.code, 0, reason: result.errors);
      expect(
        commandsOf(result).last,
        'deploy --only auth --project=smf-app --non-interactive',
      );
    });

    test(
        'stops when the app is configured for several projects, and tells '
        'how to name one', () async {
      File(configOf(app)).writeAsStringSync(
        _configuredByBuild(
          android: 'smf-staging',
          debug: 'smf-dev',
          release: 'smf-app',
          target: 'smf-dev',
        ),
      );

      final result = await run();

      expect(result.code, 1);
      expect(
        result.errors,
        '${configOf(app)} has several Firebase projects (smf-staging, '
        'smf-dev, smf-app). Name one: $enableSignInCommand --project <id>\n',
      );
      expect(result.calls, isEmpty);

      // With the project named, the script does not read the file.
      final named = await run(arguments: ['--project', 'smf-dev']);

      expect(named.code, 0, reason: named.errors);
      expect(
        commandsOf(named).last,
        'deploy --only auth --project=smf-dev --non-interactive',
      );
      expect(
        named.output,
        startsWith('${_enabling('smf-dev', AuthMode.required)}\n'),
      );
    });

    test(
        'stops in an app that flutterfire has not configured, and tells to '
        'run it or to name the project', () async {
      const orName = 'or name the project: $enableSignInCommand --project '
          '<id>';
      final config = File(configOf(app));

      final missing = await run();

      expect(missing.code, 1);
      expect(
        missing.errors,
        '${config.path} is missing, so the app is not configured for '
        'Firebase yet. Run "flutterfire configure" first (see README.md), '
        '$orName\n',
      );
      expect(missing.output, isEmpty);
      expect(missing.calls, isEmpty);
      expect(config.existsSync(), isFalse);

      // A file of the Firebase CLI alone, or one in which flutterfire has
      // written no project yet, as before it knows the platforms. It
      // writes the id of a project into maps only.
      for (final text in [
        '{"hosting": {"public": "build/web", "projectId": "of-hosting"}}',
        '{"flutter": {"platforms": {}}}',
        '{"flutter": {"platforms": {"dart": {"projectId": 7}}}}',
        '{"flutter": {"platforms": [{"projectId": "in-a-list"}]}}',
        '["flutter"]',
      ]) {
        config.writeAsStringSync(text);

        final result = await run();

        expect(result.code, 1, reason: text);
        expect(
          result.errors,
          '${config.path} has no Firebase project of "flutterfire '
          'configure". Run it first (see README.md), $orName\n',
          reason: text,
        );
        expect(result.calls, isEmpty, reason: text);
        expect(config.readAsStringSync(), text);
      }
    });

    test(
        'stops at a firebase.json that is not JSON, that is no text in '
        'UTF-8, or whose project is no id of a project, and passes nothing '
        'of it to the Firebase CLI', () async {
      const again = 'Run "flutterfire configure" again (see README.md), or '
          'name the project: $enableSignInCommand --project <id>';
      final config = File(configOf(app))..writeAsStringSync('{"flutter": ');

      final broken = await run();

      expect(broken.code, 1);
      expect(
        broken.errors,
        allOf(
          startsWith('${config.path} is not JSON ('),
          endsWith('). $again\n'),
        ),
      );
      expect(broken.calls, isEmpty);

      // As Windows PowerShell 5 writes a file with `>`: in UTF-16.
      config.writeAsBytesSync([
        0xFF,
        0xFE,
        for (final unit in _configuredFor('smf-app').codeUnits) ...[unit, 0],
      ]);
      final unreadable = await run();

      expect(unreadable.code, 1);
      expect(
        unreadable.errors,
        allOf(
          startsWith('${config.path} could not be read as a text in UTF-8 ('),
          endsWith(').\n'),
          isNot(contains('#0 ')),
        ),
      );
      expect(unreadable.calls, isEmpty);

      for (final project in [
        'My Project',
        'smf-app & calc',
        'smf_app',
        '',
        '-smf',
        '--debug',
      ]) {
        config.writeAsStringSync(_configuredFor(project));

        final result = await run();

        expect(result.code, 1, reason: project);
        expect(
          result.errors,
          '${config.path} has "$project" as its Firebase project, which is '
          'no id of a project. $again\n',
          reason: project,
        );
        expect(result.calls, isEmpty, reason: project);
      }
    });

    test(
        'gives the Firebase CLI the project that it says, and no other: the '
        'last one that its arguments name before --, in each form that the '
        'Firebase CLI takes, and the other arguments as they are', () async {
      File(configOf(app)).writeAsStringSync(_configuredFor('smf-app'));
      const own = 'deploy --only auth';

      final found = <String, (String, String)>{};
      for (final arguments in [
        <String>[],
        ['--account', 'someone@example.com'],
        ['--debug', '--account=someone@example.com'],
        // Each form of the project.
        ['--project', 'aaa-app'],
        ['--project=aaa-app'],
        ['-P', 'aaa-app'],
        ['-Paaa-app'],
        // The Firebase CLI takes the last project of its arguments.
        ['--project', 'aaa-app', '--project', 'bbb-app'],
        ['-P', 'aaa-app', '--project=bbb-app', '--debug', '-Pccc-app'],
        ['--debug', '--project', 'aaa-app', '--account', 'me@example.com'],
        // What comes after -- is no option of the Firebase CLI.
        ['--project', 'aaa-app', '--', '--project', 'bbb-app'],
        ['--', '--project', 'bbb-app'],
        // The Firebase CLI would take --project for the account here, and
        // no project at all. It gets the project that the script says, and
        // refuses the account that is left without a value.
        ['--account', '--project', 'bbb-app'],
      ]) {
        final result = await run(arguments: arguments);
        expect(result.code, 0, reason: '$arguments: ${result.errors}');
        final said = RegExp(r'in the Firebase project (\S+) \(')
            .firstMatch(result.output.split('\n').first)![1]!;
        found[arguments.join(' ')] = (said, commandsOf(result).last);
      }

      expect(found, {
        '': ('smf-app', '$own --project=smf-app --non-interactive'),
        '--account someone@example.com': (
          'smf-app',
          '$own --project=smf-app --non-interactive --account '
              'someone@example.com',
        ),
        '--debug --account=someone@example.com': (
          'smf-app',
          '$own --project=smf-app --non-interactive --debug '
              '--account=someone@example.com',
        ),
        '--project aaa-app': (
          'aaa-app',
          '$own --project=aaa-app --non-interactive',
        ),
        '--project=aaa-app': (
          'aaa-app',
          '$own --project=aaa-app --non-interactive',
        ),
        '-P aaa-app': ('aaa-app', '$own --project=aaa-app --non-interactive'),
        '-Paaa-app': ('aaa-app', '$own --project=aaa-app --non-interactive'),
        '--project aaa-app --project bbb-app': (
          'bbb-app',
          '$own --project=bbb-app --non-interactive',
        ),
        '-P aaa-app --project=bbb-app --debug -Pccc-app': (
          'ccc-app',
          '$own --project=ccc-app --non-interactive --debug',
        ),
        '--debug --project aaa-app --account me@example.com': (
          'aaa-app',
          '$own --project=aaa-app --non-interactive --debug --account '
              'me@example.com',
        ),
        '--project aaa-app -- --project bbb-app': (
          'aaa-app',
          '$own --project=aaa-app --non-interactive -- --project bbb-app',
        ),
        '-- --project bbb-app': (
          'smf-app',
          '$own --project=smf-app --non-interactive -- --project bbb-app',
        ),
        '--account --project bbb-app': (
          'bbb-app',
          '$own --project=bbb-app --non-interactive --account',
        ),
      });
    });

    test(
        'stops at arguments whose project it cannot give the Firebase CLI: '
        'one without a value, one that is no id of a project, and short '
        'options in one argument that may name a project', () async {
      File(configOf(app)).writeAsStringSync(_configuredFor('smf-app'));
      String noId(String named) =>
          'The arguments name "$named" as the Firebase project, which is no '
          'id of a project.\n';
      String unclear(String option) =>
          'Cannot tell whether "$option" names a Firebase project. Name the '
          'project with --project <id>, apart from the other options.\n';

      final told = <String, String>{};
      for (final arguments in [
        ['--project'],
        ['--debug', '-P'],
        ['--project', 'aaa-app', '--project'],
        ['--project='],
        ['--project', '--debug'],
        ['-P', 'My Project'],
        ['--project=aaa-app', '--project', 'bbb_app'],
        // As the Firebase CLI reads --json and the project bbb-app.
        ['-jP', 'bbb-app'],
        ['-jPbbb-app'],
        // It would read the message "Patch" here, which the script cannot
        // know of every option.
        ['-mPatch'],
      ]) {
        final result = await run(arguments: arguments);

        expect(result.code, 1, reason: '$arguments');
        expect(result.output, isEmpty, reason: '$arguments');
        expect(result.calls, isEmpty, reason: '$arguments');
        told[arguments.join(' ')] = result.errors;
      }

      expect(told, {
        '--project': '--project needs the id of a Firebase project after '
            'it.\n',
        '--debug -P': '-P needs the id of a Firebase project after it.\n',
        '--project aaa-app --project': '--project needs the id of a Firebase '
            'project after it.\n',
        '--project=': noId(''),
        '--project --debug': noId('--debug'),
        '-P My Project': noId('My Project'),
        '--project=aaa-app --project bbb_app': noId('bbb_app'),
        '-jP bbb-app': unclear('-jP'),
        '-jPbbb-app': unclear('-jPbbb-app'),
        '-mPatch': unclear('-mPatch'),
      });
    });

    test('needs no firebase.json for a project that its arguments name',
        () async {
      final named = await run(arguments: ['--project', 'another-app']);

      expect(named.code, 0, reason: named.errors);
      expect(
        commandsOf(named).last,
        'deploy --only auth --project=another-app --non-interactive',
      );
      expect(File(configOf(app)).existsSync(), isFalse);
    });

    test('runs from any directory, for the app that it is a file of', () async {
      File(configOf(app)).writeAsStringSync(_configuredFor('smf-app'));

      final result = await run(workingDirectory: inMachine('elsewhere'));

      expect(result.code, 0, reason: result.errors);
      expect(
        commandsOf(result).last,
        'deploy --only auth --project=smf-app --non-interactive',
      );
      expect(Directory(inMachine('elsewhere')).listSync(), isEmpty);
    });

    test(
      'runs through a link to it, for the app that it is a file of',
      () async {
        File(configOf(app)).writeAsStringSync(_configuredFor('smf-app'));
        final link = Link('${inMachine('elsewhere')}/enable.dart')
          ..createSync('${app.path}/$enableSignInScript');

        final result = await run(
          workingDirectory: inMachine('elsewhere'),
          script: link.path,
        );

        expect(result.code, 0, reason: result.errors);
        expect(
          commandsOf(result).last,
          'deploy --only auth --project=smf-app --non-interactive',
        );
      },
      // A link needs a right of its own on Windows.
      testOn: '!windows',
    );

    test(
        'exits with the code of a Firebase CLI that fails, removes its '
        'temporary directory, and tells what may have gone wrong: the '
        'account, where the log was, and the Firebase console', () async {
      File(configOf(app)).writeAsStringSync(_configuredFor('smf-app'));
      String namedAccount(String account) =>
          '- The arguments name the account $account for it. "firebase '
          'login:list" shows the accounts that the Firebase CLI has.';

      final told = <String, List<String>>{};
      for (final arguments in [
        <String>[],
        ['--account', 'nobody@example.com'],
        ['--account=nobody@example.com'],
        // The Firebase CLI takes the last account.
        ['--account', 'first@example.com', '--account=last@example.com'],
        // An account without a value is none, and what comes after -- is
        // no option.
        ['--account'],
        ['--', '--account', 'nobody@example.com'],
        ['--debug'],
        ['--debug', '--account', 'nobody@example.com'],
      ]) {
        final result = await run(
          arguments: arguments,
          standIn: {'STAND_IN_DEPLOY_CODE': '2'},
        );

        expect(result.code, 2, reason: '$arguments');
        expect(result.calls, hasLength(2));
        expect(Directory(result.calls.last.directory).existsSync(), isFalse);
        expect(
          result.output.split('\n').skip(1),
          ['stand-in: deploying', ''],
        );
        final lines = result.errors.split('\n');
        expect(lines.first, 'stand-in: on the standard error');
        expect(lines.last, isEmpty);
        told[arguments.join(' ')] = lines.sublist(1, lines.length - 1);
      }

      final console = '- ${_inConsole('smf-app')}';
      expect(told, {
        '': [_failed(2), _maybeAnotherAccount, _withDebug, console],
        '--account nobody@example.com': [
          _failed(2),
          namedAccount('nobody@example.com'),
          _withDebug,
          console,
        ],
        '--account=nobody@example.com': [
          _failed(2),
          namedAccount('nobody@example.com'),
          _withDebug,
          console,
        ],
        '--account first@example.com --account=last@example.com': [
          _failed(2),
          namedAccount('last@example.com'),
          _withDebug,
          console,
        ],
        '--account': [_failed(2), _maybeAnotherAccount, _withDebug, console],
        '-- --account nobody@example.com': [
          _failed(2),
          _maybeAnotherAccount,
          _withDebug,
          console,
        ],
        // The Firebase CLI printed its log already.
        '--debug': [_failed(2), _maybeAnotherAccount, console],
        '--debug --account nobody@example.com': [
          _failed(2),
          namedAccount('nobody@example.com'),
          console,
        ],
      });
      expect(File(configOf(app)).readAsStringSync(), _configuredFor('smf-app'));
    });

    test(
      'tells when it cannot remove its temporary directory, and exits with '
      'the code of the Firebase CLI all the same',
      () async {
        File(configOf(app)).writeAsStringSync(_configuredFor('smf-app'));

        for (final code in [0, 2]) {
          // The stand-in removes the directory, so the script fails to.
          final result = await run(
            standIn: {
              'STAND_IN_REMOVES_DIRECTORY': '1',
              'STAND_IN_DEPLOY_CODE': '$code',
            },
          );

          expect(result.code, code);
          final directory = result.calls.last.directory;
          expect(
            result.errors.split('\n'),
            contains(
              allOf(
                startsWith(
                  'The temporary directory $directory of this script is '
                  'left: ',
                ),
                endsWith('.'),
              ),
            ),
            reason: 'exit code $code',
          );
        }
      },
      // On Windows, a process cannot remove the directory that it runs in,
      // which is why the script may fail to remove it there.
      testOn: '!windows',
    );

    test(
      'after Ctrl+C, lets the Firebase CLI end, removes its temporary '
      'directory and exits with 130, whichever call of the Firebase CLI '
      'runs',
      () async {
        File(configOf(app)).writeAsStringSync(_configuredFor('smf-app'));

        for (final (waits, running) in [('version', 1), ('deploy', 2)]) {
          final process = await start(standIn: {'STAND_IN_WAITS': waits});
          final ended = finish(process);
          // The Firebase CLI runs once it noted its call.
          for (var tries = 0; callsSoFar().length < running; tries++) {
            expect(tries, lessThan(600), reason: 'no call for $waits');
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
          final directory = Directory(callsSoFar().last.directory);
          expect(directory.existsSync(), isTrue);

          // The signal goes to the script alone, as from another process:
          // the script passes it on to the Firebase CLI.
          expect(process.kill(ProcessSignal.sigint), isTrue);
          final result = await ended;

          expect(result.code, 130, reason: '$waits: ${result.errors}');
          expect(result.calls, hasLength(running), reason: waits);
          expect(directory.existsSync(), isFalse, reason: waits);
          // Nothing of a failure: the user knows what stopped the script.
          expect(result.errors, isEmpty, reason: waits);
          expect(
            result.output,
            waits == 'version'
                ? isEmpty
                : '${_enabling('smf-app', AuthMode.required)}\n',
            reason: waits,
          );
          calls().deleteSync();
        }
      },
      // Windows has no signal that one process sends another: Ctrl+C in a
      // terminal reaches the script and the Firebase CLI there.
      testOn: '!windows',
    );

    test(
        'stops on a machine without the Firebase CLI, and tells where to get '
        'it', () async {
      File(configOf(app)).writeAsStringSync(_configuredFor('smf-app'));

      final result = await run(withFirebase: false);

      expect(result.code, 1);
      expect(
        result.errors,
        allOf(
          startsWith('The Firebase CLI did not run ('),
          endsWith(
            '). Install it, or put it on the PATH: '
            'https://firebase.google.com/docs/cli\n'
            '${_inConsole('smf-app')}\n',
          ),
        ),
      );
      expect(result.output, isEmpty);
      expect(result.calls, isEmpty);
    });

    test(
        'stops when the Firebase CLI does not tell its version, with what '
        'it printed', () async {
      File(configOf(app)).writeAsStringSync(_configuredFor('smf-app'));

      final result = await run(
        standIn: {
          'STAND_IN_VERSION_CODE': '3',
          'STAND_IN_VERSION_ERRORS': 'node: bad option\n',
        },
      );

      expect(result.code, 1);
      expect(
        result.errors,
        'The Firebase CLI did not run (exit code 3: node: bad option). '
        'Install it, or put it on the PATH: '
        'https://firebase.google.com/docs/cli\n'
        '${_inConsole('smf-app')}\n',
      );
      expect(commandsOf(result), ['--version']);

      final silent = await run(standIn: {'STAND_IN_VERSION_CODE': '1'});

      expect(
        silent.errors,
        startsWith('The Firebase CLI did not run (exit code 1). Install it'),
      );
    });

    test(
        'stops at a Firebase CLI that is older than the command, by the '
        'rule of the check of the machine, tells how to update it, and does '
        'not run it', () async {
      File(configOf(app)).writeAsStringSync(_configuredFor('smf-app'));

      for (final (printed, version) in [
        ('15.5.1', '15.5.1'),
        ('14.27.0', '14.27.0'),
        ('9.23.3', '9.23.3'),
        // The last line that is a version is that of the Firebase CLI.
        ('16.0.0|15.5.1', '15.5.1'),
        // A pre-release of the first version may lack the command.
        ('15.6.0-rc.1', '15.6.0-rc.1'),
        ('15.6.0-rc.1+build.5', '15.6.0-rc.1+build.5'),
      ]) {
        final result = await run(standIn: {'STAND_IN_VERSION': printed});

        expect(result.code, 1, reason: version);
        expect(
          result.errors,
          'The Firebase CLI of this machine is $version, and enabling '
          'sign-in methods needs 15.6.0 or later. Update it with "npm '
          'install -g firebase-tools" if npm installed it, or see '
          'https://firebase.google.com/docs/cli#update-cli\n'
          '${_inConsole('smf-app')}\n',
          reason: version,
        );
        expect(result.output, isEmpty, reason: version);
        expect(commandsOf(result), ['--version'], reason: version);
      }
    });

    test(
        'runs the first Firebase CLI with the command and every later one, '
        'by the last version that it prints, and one whose version it '
        'cannot read', () async {
      File(configOf(app)).writeAsStringSync(_configuredFor('smf-app'));

      for (final version in [
        '15.6.0',
        '15.6.1',
        '15.14.0',
        '16.0.0',
        // With notices before the version, which have versions too, and
        // after a line that is another version.
        _withNotices,
        '15.5.1|15.6.0',
        // A build of the first version, and a pre-release of a later one.
        '15.6.0+build.5',
        '15.6.1-rc.1',
        '16.0.0-beta.2',
        // Nothing that the script reads as a version: the Firebase CLI
        // tells itself what it cannot do.
        'a development build',
        '99999999999999999999.0.0',
        '15.6',
      ]) {
        final result = await run(standIn: {'STAND_IN_VERSION': version});

        expect(result.code, 0, reason: '$version: ${result.errors}');
        expect(
          commandsOf(result),
          [
            '--version',
            'deploy --only auth --project=smf-app --non-interactive',
          ],
          reason: version,
        );
      }
    });
  });
}
