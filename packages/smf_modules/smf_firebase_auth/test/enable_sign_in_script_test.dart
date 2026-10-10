// The script that enables the sign-in methods runs here for real, as the
// step of the module and a user run it: with the Dart VM, in the files of
// an app that the module rendered, in each mode of the auth role. A
// stand-in for the Firebase CLI is on its PATH, a Dart program that notes
// how it was called, so nothing reaches Firebase.
@TestOn('vm')
library;

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
/// `STAND_IN_CALLS` names a line of JSON for each call: its arguments, and
/// for a call other than `--version` the directory it ran in, the files
/// there, with their texts, and whether it may check for a newer version,
/// which the Firebase CLI does unless `NO_UPDATE_NOTIFIER` is set.
///
/// `--version` prints the lines of `STAND_IN_VERSION`, which `|` separates,
/// or 15.14.0, and what `STAND_IN_VERSION_ERRORS` has on the standard
/// error, and exits with `STAND_IN_VERSION_CODE`. Any other call prints a
/// line on each stream and exits with `STAND_IN_DEPLOY_CODE`. With
/// `STAND_IN_REMOVES_DIRECTORY`, it removes the directory it ran in first.
const _standIn = r'''
import 'dart:convert';
import 'dart:io';

void main(List<String> arguments) {
  final environment = Platform.environment;
  final asksVersion = arguments.length == 1 && arguments.single == '--version';
  final directory = Directory.current;
  File(environment['STAND_IN_CALLS']!).writeAsStringSync(
    '${jsonEncode({
      'arguments': arguments,
      if (!asksVersion) ...{
        'directory': directory.resolveSymbolicLinksSync(),
        'files': {
          for (final file in directory.listSync().whereType<File>())
            file.uri.pathSegments.last: file.readAsStringSync(),
        },
        'checksForUpdates': !environment.containsKey('NO_UPDATE_NOTIFIER'),
      },
    })}\n',
    mode: FileMode.append,
  );
  if (asksVersion) {
    final version = environment['STAND_IN_VERSION'] ?? '15.14.0';
    stdout.writeln(version.split('|').join('\n'));
    stderr.write(environment['STAND_IN_VERSION_ERRORS'] ?? '');
    exitCode = int.parse(environment['STAND_IN_VERSION_CODE'] ?? '0');
    return;
  }
  stdout.writeln('stand-in: deploying');
  stderr.writeln('stand-in: on the standard error');
  if (environment.containsKey('STAND_IN_REMOVES_DIRECTORY')) {
    directory.deleteSync(recursive: true);
  }
  exitCode = int.parse(environment['STAND_IN_DEPLOY_CODE'] ?? '0');
}
''';

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

/// A call of the stand-in for the Firebase CLI: its arguments, and for a
/// call other than `--version` the directory it ran in, the files there,
/// by name, with their texts, and whether it may check for a newer version.
typedef _Call = ({
  List<String> arguments,
  String? directory,
  Map<String, String>? files,
  bool? checksForUpdates,
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
    directory: call['directory'] as String?,
    files: (call['files'] as Map<String, Object?>?)?.cast<String, String>(),
    checksForUpdates: call['checksForUpdates'] as bool?,
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
      Directory('${machine.path}/$name').createSync();
    }
    final program = File('${machine.path}/stand_in.dart')
      ..writeAsStringSync(_standIn);
    // The Firebase CLI is a command of the shell on every system, as npm
    // installs it, which runs the program with the Dart VM of the tests.
    final dart = Platform.resolvedExecutable;
    if (Platform.isWindows) {
      File('${machine.path}/bin/firebase.cmd').writeAsStringSync(
        '@echo off\r\n"$dart" "${program.path}" %*\r\n',
      );
    } else {
      final command = File('${machine.path}/bin/firebase')
        ..writeAsStringSync(
          '#!/bin/sh\nexec "$dart" "${program.path}" "\$@"\n',
        );
      expect(Process.runSync('chmod', ['+x', command.path]).exitCode, 0);
    }
    app = DartApp.write(rendered[AuthMode.required]!);
  });

  tearDown(() {
    app.delete();
    machine.deleteSync(recursive: true);
  });

  /// The path of `firebase.json` of [app], as the script names it.
  String configOf(DartApp app) => '${app.path}/firebase.json';

  /// Runs the script of [app], or of the app of the test, with [arguments],
  /// as `dart tool/enable_firebase_sign_in.dart` in the directory of the
  /// app, or in [workingDirectory] with the path of the script.
  ///
  /// The `PATH` of the script is the directory with the Firebase CLI, or an
  /// empty one unless [withFirebase], and its temporary files go into a
  /// directory of the test. [standIn] has the variables of the stand-in.
  Future<_Run> run({
    DartApp? of,
    List<String> arguments = const [],
    Map<String, String> standIn = const {},
    bool withFirebase = true,
    String? workingDirectory,
  }) async {
    final target = of ?? app;
    final calls = File('${machine.path}/calls');
    final temp = '${machine.path}/temp';
    final changes = {
      'PATH': '${machine.path}/${withFirebase ? 'bin' : 'none'}',
      'TMPDIR': temp,
      'TEMP': temp,
      'TMP': temp,
      'STAND_IN_CALLS': calls.path,
      ...standIn,
    };
    // The names of the variables of Windows are in any case, such as
    // `Path`, so a variable of the test replaces the one of the machine
    // whatever its case.
    final replaced = {for (final name in changes.keys) name.toUpperCase()};
    final result = await Process.run(
      Platform.resolvedExecutable,
      [
        if (workingDirectory == null)
          enableSignInScript
        else
          '${target.path}/$enableSignInScript',
        ...arguments,
      ],
      workingDirectory: workingDirectory ?? target.path,
      environment: {
        for (final MapEntry(:key, :value) in Platform.environment.entries)
          if (!replaced.contains(key.toUpperCase())) key: value,
        ...changes,
      },
      includeParentEnvironment: false,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    expect(
      Directory(temp).listSync(),
      isEmpty,
      reason: 'The script removes its temporary directory.',
    );
    return (
      code: result.exitCode,
      output: (result.stdout as String).replaceAll('\r\n', '\n'),
      errors: (result.stderr as String).replaceAll('\r\n', '\n'),
      calls: [
        if (calls.existsSync())
          for (final line in calls.readAsLinesSync()) _callOf(line),
      ],
    );
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

  group('the script of the app', () {
    test(
        'is the file of the brick of the module, with the file of the auth '
        'role that has the mode and the first Firebase CLI with the command',
        () {
      final script = rendered[AuthMode.required]!.files[enableSignInScript]!;

      expect(script.owner, const ModuleOrigin(FirebaseAuthModule.id));
      expect(
        script.text,
        allOf(
          contains("const _sessionFile = '${AuthRole.sessionFile}';"),
          contains("const _firstCli = '$firstFirebaseCliWithSignIn';"),
          contains("const _command = '$enableSignInCommand';"),
          isNot(contains('{{')),
        ),
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
        'enables Email/Password in the project of flutterfire configure, '
        'with a configuration of its own in a temporary directory, and '
        'leaves the app as it is', () async {
      final config = File(configOf(app))
        ..writeAsStringSync(_configuredFor('smf-app'));
      final before = entriesOf(app);

      final result = await run();

      expect(result.code, 0, reason: result.errors);
      expect(commandsOf(result), [
        '--version',
        'deploy --only auth --project smf-app --non-interactive',
      ]);
      // The Firebase CLI ran in a directory of the script, which had the
      // configuration and nothing else, and is removed.
      final deploy = result.calls.last;
      expect(
        Directory(deploy.directory!).parent.uri,
        Directory('${machine.path}/temp').uri,
      );
      expect(
        deploy.directory!.split(RegExp(r'[/\\]')).last,
        startsWith('firebase_sign_in_'),
      );
      expect(deploy.files, {'firebase.json': _emailPassword});
      expect(Directory(deploy.directory!).existsSync(), isFalse);
      expect(
        deploy.checksForUpdates,
        isFalse,
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
            result.calls.last.files!['firebase.json']!,
            result.output.split('\n').first,
          );
          File('${machine.path}/calls').deleteSync();
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
        'of the auth role', () async {
      File(configOf(app)).writeAsStringSync(_configuredFor('smf-app'));
      final session = File('${app.path}/${AuthRole.sessionFile}');
      const generated = 'const AuthMode authMode = AuthMode.required;';
      expect(session.readAsStringSync(), contains('\n$generated\n'));

      final configs = <String, String>{};
      for (final changed in [
        'const AuthMode authMode = AuthMode.anonymous;',
        // As a developer may write it, and as dart format may leave it.
        'const authMode = AuthMode.anonymous;',
        'const AuthMode authMode =\n    AuthMode.anonymous;',
        'const AuthMode authMode = AuthMode.guest;',
        // A line that is not code decides nothing.
        '// const AuthMode authMode = AuthMode.anonymous;\n$generated',
      ]) {
        session.writeAsStringSync(
          rendered[AuthMode.required]!
              .files[AuthRole.sessionFile]!
              .text
              .replaceFirst(generated, changed),
        );
        final result = await run();
        expect(result.code, 0, reason: '$changed: ${result.errors}');
        configs[changed] = result.calls.last.files!['firebase.json']!;
        File('${machine.path}/calls').deleteSync();
      }

      expect(configs.values, [
        _withAnonymous,
        _withAnonymous,
        _withAnonymous,
        _emailPassword,
        _emailPassword,
      ]);
    });

    test(
        'stops before the Firebase CLI when it cannot read the mode of the '
        'app, and tells of the Firebase console', () async {
      File(configOf(app)).writeAsStringSync(_configuredFor('smf-app'));
      final session = File('${app.path}/${AuthRole.sessionFile}');
      final generated = session.readAsStringSync();
      const unreadable = 'Cannot tell the sign-in mode of the app, by which '
          'this script enables Anonymous or leaves it out: '
          '${AuthRole.sessionFile} does not have one line such as "const '
          'AuthMode authMode = AuthMode.required;".\n';

      for (final (name, change) in <(String, void Function())>[
        (
          'a mode that is computed',
          () {
            session.writeAsStringSync(
              generated.replaceFirst(
                'const AuthMode authMode = AuthMode.required;',
                'final AuthMode authMode = modeOfBuild();',
              ),
            );
          }
        ),
        (
          'two modes',
          () {
            session.writeAsStringSync(
              '$generated\nconst AuthMode authMode = AuthMode.guest;\n',
            );
          }
        ),
        ('no file', session.deleteSync),
      ]) {
        change();

        final result = await run();

        expect(result.code, 1, reason: name);
        expect(result.errors, '$unreadable${_inConsole()}\n', reason: name);
        expect(result.output, isEmpty, reason: name);
        expect(result.calls, isEmpty, reason: name);
      }
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
        'deploy --only auth --project smf-app --non-interactive',
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
        'deploy --only auth --non-interactive --project smf-dev',
      );
      expect(
        named.output,
        startsWith('Enabling Email/Password in the Firebase project smf-dev '),
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
      // written no project yet, as before it knows the platforms.
      for (final text in [
        '{"hosting": {"public": "build/web", "projectId": "of-hosting"}}',
        '{"flutter": {"platforms": {}}}',
        '{"flutter": {"platforms": {"dart": {"projectId": 7}}}}',
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
        'stops at a firebase.json that is not JSON, or whose project is no '
        'id of a project, and passes nothing of it to the Firebase CLI',
        () async {
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
        'gives the Firebase CLI its arguments as they are, after its own, '
        'and its own project unless they name one', () async {
      File(configOf(app)).writeAsStringSync(_configuredFor('smf-app'));
      const own = 'deploy --only auth';
      final commands = <String, String>{};
      for (final arguments in [
        ['--account', 'someone@example.com'],
        ['--debug', '--account=someone@example.com'],
        ['--project', 'another-app', '--debug'],
        ['--project=another-app'],
        ['-P', 'another-app'],
        ['-Panother-app'],
      ]) {
        final result = await run(arguments: arguments);
        expect(result.code, 0, reason: '$arguments: ${result.errors}');
        commands[arguments.join(' ')] = commandsOf(result).last;
        final named = arguments.join().contains('another-app');
        expect(
          result.output.split('\n').first,
          _enabling(named ? 'another-app' : 'smf-app', AuthMode.required),
          reason: '$arguments',
        );
        File('${machine.path}/calls').deleteSync();
      }

      expect(commands, {
        '--account someone@example.com':
            '$own --project smf-app --non-interactive --account '
                'someone@example.com',
        '--debug --account=someone@example.com':
            '$own --project smf-app --non-interactive --debug '
                '--account=someone@example.com',
        '--project another-app --debug':
            '$own --non-interactive --project another-app --debug',
        '--project=another-app': '$own --non-interactive --project=another-app',
        '-P another-app': '$own --non-interactive -P another-app',
        '-Panother-app': '$own --non-interactive -Panother-app',
      });
    });

    test(
        'needs no firebase.json for a project that its arguments name, and '
        'leaves a project without a value to the Firebase CLI', () async {
      final named = await run(arguments: ['--project', 'another-app']);

      expect(named.code, 0, reason: named.errors);
      expect(
        commandsOf(named).last,
        'deploy --only auth --non-interactive --project another-app',
      );
      expect(File(configOf(app)).existsSync(), isFalse);
      File('${machine.path}/calls').deleteSync();

      final unnamed = await run(arguments: ['--project']);

      expect(
        commandsOf(unnamed).last,
        'deploy --only auth --non-interactive --project',
      );
    });

    test('runs from any directory, for the app that it is a file of', () async {
      File(configOf(app)).writeAsStringSync(_configuredFor('smf-app'));

      final result = await run(workingDirectory: '${machine.path}/elsewhere');

      expect(result.code, 0, reason: result.errors);
      expect(
        commandsOf(result).last,
        'deploy --only auth --project smf-app --non-interactive',
      );
      expect(Directory('${machine.path}/elsewhere').listSync(), isEmpty);
    });

    test(
        'exits with the code of a Firebase CLI that fails, removes its '
        'temporary directory, and tells of the account and of the Firebase '
        'console', () async {
      File(configOf(app)).writeAsStringSync(_configuredFor('smf-app'));

      final result = await run(standIn: {'STAND_IN_DEPLOY_CODE': '2'});

      expect(result.code, 2);
      expect(result.calls, hasLength(2));
      expect(Directory(result.calls.last.directory!).existsSync(), isFalse);
      expect(result.output.split('\n').skip(1), ['stand-in: deploying', '']);
      expect(
        result.errors,
        'stand-in: on the standard error\n'
        'The Firebase CLI did not enable the sign-in methods (exit code 2).\n'
        '- It ran as the default account of "firebase login:list": an '
        'account that "firebase login:use" chose for the directory of the '
        'app does not apply in the temporary directory in which this script '
        'runs the Firebase CLI. For another account, run: '
        '$enableSignInCommand --account <email>\n'
        '- Its log, firebase-debug.log, was in that directory, which this '
        'script removes. To see what the Firebase CLI did, run: '
        '$enableSignInCommand --debug\n'
        '- ${_inConsole('smf-app')}\n',
      );
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
          final directory = result.calls.last.directory!;
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
          File('${machine.path}/calls').deleteSync();
        }
      },
      // On Windows, a process cannot remove the directory that it runs in,
      // which is why the script may fail to remove it there.
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

      File('${machine.path}/calls').deleteSync();
      final silent = await run(standIn: {'STAND_IN_VERSION_CODE': '1'});

      expect(
        silent.errors,
        startsWith('The Firebase CLI did not run (exit code 1). Install it'),
      );
    });

    test(
        'stops at a Firebase CLI that is older than the command, tells how '
        'to update it, and does not run it', () async {
      File(configOf(app)).writeAsStringSync(_configuredFor('smf-app'));

      for (final (printed, version) in [
        ('15.5.1', '15.5.1'),
        ('14.27.0', '14.27.0'),
        ('9.23.3', '9.23.3'),
        // The last line that is a version is that of the Firebase CLI.
        ('16.0.0|15.5.1', '15.5.1'),
      ]) {
        final result = await run(standIn: {'STAND_IN_VERSION': printed});

        expect(result.code, 1, reason: version);
        expect(
          result.errors,
          'The Firebase CLI of this machine is $version, and enabling '
          'sign-in methods needs 15.6.0 or later. Update it with "npm '
          'install -g firebase-tools" if npm installed it, or see '
          'https://firebase.google.com/docs/cli#update-cli.\n'
          '${_inConsole('smf-app')}\n',
          reason: version,
        );
        expect(result.output, isEmpty, reason: version);
        expect(commandsOf(result), ['--version'], reason: version);
        File('${machine.path}/calls').deleteSync();
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
        '15.6.0-rc.1',
        // Nothing that the script reads as a version: the Firebase CLI
        // tells itself what it cannot do.
        'a development build',
        '99999999999.0.0',
      ]) {
        final result = await run(standIn: {'STAND_IN_VERSION': version});

        expect(result.code, 0, reason: '$version: ${result.errors}');
        expect(
          commandsOf(result),
          [
            '--version',
            'deploy --only auth --project smf-app --non-interactive',
          ],
          reason: version,
        );
        File('${machine.path}/calls').deleteSync();
      }
    });
  });
}
