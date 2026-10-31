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
import 'package:xml/xml.dart';

import 'support/dart_app.dart';
import 'support/sign_in_ways.dart';

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
/// or 15.34.0, and what `STAND_IN_VERSION_ERRORS` has on the standard
/// error, and exits with `STAND_IN_VERSION_CODE`. `deploy` prints a line on
/// each stream and exits with `STAND_IN_DEPLOY_CODE`. With
/// `STAND_IN_REMOVES_DIRECTORY`, it removes the directory it ran in first.
/// When `STAND_IN_WAITS` names the call, `version` or the command, such as
/// `deploy`, it waits once it has noted the call, until a signal ends it.
///
/// `login:list` prints that it is logged in as `STAND_IN_ACCOUNT`, or warns
/// that it has no account, as the Firebase CLI does. The commands for the
/// apps answer with JSON, as with `--json`: `apps:android:sha:list` lists
/// the hashes of `STAND_IN_SHAS`, which commas separate, as Firebase has
/// them, `apps:android:sha:create` creates one, and `apps:sdkconfig` gives
/// the Firebase file of its platform, `ANDROID` or `IOS`, from the
/// directory that `STAND_IN_FILES` names: `<platform>.<n>` for its n-th
/// call for the platform if there is one, or else `<platform>`. When
/// `STAND_IN_FAILS` names the command, it fails with an error in JSON and
/// the exit code 2.
const _standIn = r"""
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final environment = Platform.environment;
  final asksVersion = arguments.length == 1 && arguments.single == '--version';
  final command = asksVersion ? 'version' : arguments.first;
  final directory = Directory.current;
  final calls = File(environment['STAND_IN_CALLS']!);
  final earlier = calls.existsSync() ? calls.readAsLinesSync() : <String>[];
  calls.writeAsStringSync(
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
  if (environment['STAND_IN_WAITS'] == command) {
    await Future<void>.delayed(const Duration(minutes: 2));
  }
  void answer(Object? result) =>
      stdout.write(jsonEncode({'status': 'success', 'result': result}));
  var code = 0;
  if (environment['STAND_IN_FAILS'] == command) {
    stdout.write(
      jsonEncode({'status': 'error', 'error': 'stand-in: $command failed'}),
    );
    code = 2;
  } else if (asksVersion) {
    final version = environment['STAND_IN_VERSION'] ?? '15.34.0';
    stdout.writeln(version.split('|').join('\n'));
    stderr.write(environment['STAND_IN_VERSION_ERRORS'] ?? '');
    code = int.parse(environment['STAND_IN_VERSION_CODE'] ?? '0');
  } else if (command == 'login:list') {
    final account = environment['STAND_IN_ACCOUNT'];
    if (account == null) {
      stderr.writeln('No authorized accounts, run "firebase login"');
    } else {
      stdout.writeln('Logged in as $account');
      stdout.writeln();
      stdout.writeln(
        'Other available accounts (switch with "firebase login:use")',
      );
      stdout.writeln(' - someone.else@example.com');
    }
  } else if (command == 'apps:android:sha:list') {
    answer([
      for (final (index, hash)
          in (environment['STAND_IN_SHAS'] ?? '').split(',').indexed)
        if (hash.isNotEmpty)
          {
            'name': 'projects/p/androidApps/${arguments[1]}/sha/$index',
            'shaHash': hash,
            'certType': hash.length == 40 ? 'SHA_1' : 'SHA_256',
          },
    ]);
  } else if (command == 'apps:android:sha:create') {
    answer({
      'name': 'projects/p/androidApps/${arguments[1]}/sha/new',
      'shaHash': arguments[2],
    });
  } else if (command == 'apps:sdkconfig') {
    final platform = arguments[1];
    final call = 1 +
        earlier.where((line) {
          final called = (jsonDecode(line) as Map)['arguments'] as List;
          return called.length > 1 &&
              called[0] == 'apps:sdkconfig' &&
              called[1] == platform;
        }).length;
    final files = environment['STAND_IN_FILES']!;
    final file = [File('$files/$platform.$call'), File('$files/$platform')]
        .firstWhere((file) => file.existsSync());
    answer({
      'fileName': platform == 'IOS'
          ? 'GoogleService-Info.plist'
          : 'google-services.json',
      'fileContents': file.readAsStringSync(),
    });
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

/// The fingerprints of the debug key of the stand-in for keytool, as
/// keytool prints them.
const _sha1 = '5E:8F:16:06:2E:A3:CD:2C:4A:0D:54:78:76:BA:A6:F3:8C:AB:F6:25';
const _sha256 = 'FA:C6:17:45:DC:09:03:78:6F:B9:ED:E6:2A:96:2B:39:'
    '9F:73:48:F0:BB:6F:89:9B:83:32:66:75:91:03:3B:9C';

/// The line with which the script tells the fingerprints of the debug key,
/// which the test that CI runs reads.
const _keyHashes =
    'The SHA-1 of the key is $_sha1, and its SHA-256 is $_sha256.';

/// The stand-in for keytool. It appends its arguments to the file that
/// `STAND_IN_KEYTOOL_CALLS` names, as a line of JSON.
///
/// When its directory has a file named `broken`, it does not run, as the
/// keytool of macOS on a machine without a JDK that macOS knows. Otherwise
/// `-help` exits with 0, `-genkeypair` writes a file to its keystore, and
/// `-list` prints the fingerprints [_sha1] and [_sha256] of a keystore that
/// exists, among the other lines of keytool. When `STAND_IN_KEYTOOL_WAITS`
/// names its first argument, it waits once it has noted the call, until a
/// signal ends it.
const _keytoolStandIn = '''
import 'dart:convert';
import 'dart:io';

void main(List<String> arguments) {
  final environment = Platform.environment;
  File(environment['STAND_IN_KEYTOOL_CALLS']!).writeAsStringSync(
    '\${jsonEncode(arguments)}\\n',
    mode: FileMode.append,
    flush: true,
  );
  if (File.fromUri(Platform.script.resolve('broken')).existsSync()) {
    stderr.writeln('Unable to locate a Java Runtime.');
    exitCode = 1;
    return;
  }
  if (environment['STAND_IN_KEYTOOL_WAITS'] == arguments.first) {
    sleep(const Duration(minutes: 5));
  }
  if (arguments.first == '-help') {
    stdout.writeln('Key and Certificate Management Tool');
    return;
  }
  final keystore = File(arguments[arguments.indexOf('-keystore') + 1]);
  if (arguments.first == '-genkeypair') {
    keystore.writeAsStringSync('a debug key of the stand-in');
    return;
  }
  if (!keystore.existsSync()) {
    stdout.writeln('keytool error: Keystore file does not exist');
    exitCode = 1;
    return;
  }
  stdout
    ..writeln('Alias name: androiddebugkey')
    ..writeln('Owner: C=US, O=Android, CN=Android Debug')
    ..writeln('Certificate fingerprints:')
    ..writeln('\\t SHA1: $_sha1')
    ..writeln('\\t SHA256: $_sha256')
    ..writeln('Signature algorithm name: SHA256withRSA');
}
''';

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

/// The command with which the script tells to configure a flavor of the app.
const _configure =
    'dart ${FirebaseCoreModule.configureScript} <flavor> --project=<id>';

/// The Firebase apps of the flavor [flavor] of the tests on each platform.
String _androidAppOf(String flavor) => '1:1234567890:android:$flavor';
String _iosAppOf(String flavor) => '1:1234567890:ios:$flavor';

/// `firebase.json` as `tool/configure_firebase.dart` leaves it, with
/// flutterfire_cli 1.4.1, in an app whose flavors are configured for the
/// projects of [projects], by the name of each flavor: an iOS app that three
/// build configurations name, and an Android app under a key that depends on
/// the machine, `src/<flavor>`, `android/app/src/<flavor>` for an app in a
/// directory called `app`, or `src\<flavor>` on Windows
/// (`firebase_android_writes.dart` there), so nothing reads that key.
String _configuredByFlavors(Map<String, String> projects) {
  const androidKeys = ['src/', 'android/app/src/', r'src\'];
  return jsonEncode({
    'flutter': {
      'platforms': {
        'android': {
          'buildConfigurations': {
            for (final (index, MapEntry(key: flavor, value: project))
                in projects.entries.indexed)
              '${androidKeys[index % androidKeys.length]}$flavor': {
                'projectId': project,
                'appId': _androidAppOf(flavor),
                'fileOutput': 'android/app/src/$flavor/google-services.json',
              },
          },
        },
        'ios': {
          'buildConfigurations': {
            for (final MapEntry(key: flavor, value: project)
                in projects.entries)
              for (final mode in const ['Debug', 'Profile', 'Release'])
                '$mode-$flavor': {
                  'projectId': project,
                  'appId': _iosAppOf(flavor),
                  'uploadDebugSymbols': true,
                  'fileOutput': 'ios/flavors/$flavor/GoogleService-Info.plist',
                },
          },
        },
        'dart': {
          for (final MapEntry(key: flavor, value: project) in projects.entries)
            'lib/firebase_options_$flavor.dart': {
              'projectId': project,
              'configurations': {
                'android': _androidAppOf(flavor),
                'ios': _iosAppOf(flavor),
              },
            },
        },
      },
    },
  });
}

/// The configuration that the script gives the Firebase CLI for an app
/// that signs in with an address and a password, and for one that also
/// signs in anonymous users.
const _emailPassword = '{"auth":{"providers":{"emailPassword":true}}}';
const _withAnonymous =
    '{"auth":{"providers":{"emailPassword":true,"anonymous":true}}}';

/// The file of the app with the URL schemes of the iOS app.
const _infoPlist = 'ios/Runner/Info.plist';

/// The Firebase files of the apps of the tests, where flutterfire writes
/// them.
const _androidFile = 'android/app/google-services.json';
const _iosFile = 'ios/Runner/GoogleService-Info.plist';

/// The URL scheme of the client of Google of the iOS app of the tests, its
/// id reversed.
const _scheme = 'com.googleusercontent.apps.1234567890-0a1b2c3d4e5f';

/// The client of the server of Google, an OAuth client of the type 3.
const _server = <String, Object>{
  'client_id': '1234567890-server.apps.googleusercontent.com',
  'client_type': 3,
};

/// `google-services.json` of the Android app of the tests as Firebase gives
/// it: with the client of the server of Google once Google is enabled, if
/// [withServer].
String _googleServices({required bool withServer}) =>
    '${const JsonEncoder.withIndent('  ').convert({
          'project_info': {
            'project_number': '1234567890',
            'project_id': 'smf-app',
          },
          'client': [
            {
              'client_info': {
                'mobilesdk_app_id': _androidApp,
                'android_client_info': {
                  'package_name': 'com.example.contract_app',
                },
              },
              'oauth_client': [if (withServer) _server],
              'api_key': [
                {'current_key': 'AIzaKeyOfTheTests'},
              ],
            },
          ],
          'configuration_version': '1',
        })}\n';

/// The type of the document of a plist.
const _doctype = '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" '
    '"http://www.apple.com/DTDs/PropertyList-1.0.dtd">';

/// `GoogleService-Info.plist` of the iOS app of the tests as Firebase gives
/// it: with the client of Google of the iOS app once Google is enabled, if
/// [withClient].
String _serviceInfo({required bool withClient}) => [
      '<?xml version="1.0" encoding="UTF-8"?>',
      _doctype,
      '<plist version="1.0">',
      '<dict>',
      if (withClient) ...[
        '\t<key>CLIENT_ID</key>',
        '\t<string>1234567890-0a1b2c3d4e5f.apps.googleusercontent.com</string>',
        '\t<key>REVERSED_CLIENT_ID</key>',
        '\t<string>$_scheme</string>',
      ],
      '\t<key>API_KEY</key>',
      '\t<string>AIzaKeyOfTheTests</string>',
      '\t<key>GOOGLE_APP_ID</key>',
      '\t<string>$_iosApp</string>',
      '</dict>',
      '</plist>',
      '',
    ].join('\n');

/// The URL type of [_scheme] as the script writes it into the Info.plist of
/// an app, each line after [indent] and ending with [newline].
String _urlType(String indent, {String newline = '\n'}) => [
      '$indent<dict>',
      '$indent\t<key>CFBundleTypeRole</key>',
      '$indent\t<string>Editor</string>',
      '$indent\t<key>CFBundleURLSchemes</key>',
      '$indent\t<array>',
      '$indent\t\t<string>$_scheme</string>',
      '$indent\t</array>',
      '$indent</dict>',
    ].map((line) => '$line$newline').join();

/// The entries of the dictionary of the plist [text], each key with its
/// value as XML, in their order.
Map<String, String> _plistOf(String text) {
  final elements = XmlDocument.parse(text)
      .rootElement
      .childElements
      .single
      .childElements
      .toList();
  return {
    for (var index = 0; index < elements.length; index += 2)
      elements[index].innerText:
          elements[index + 1].toXmlString().replaceAll(RegExp(r'\s'), ''),
  };
}

/// The URL schemes of each URL type of the Info.plist [text], read as a
/// plist.
List<List<String>> _urlSchemesOf(String text) {
  final elements = XmlDocument.parse(text)
      .rootElement
      .childElements
      .single
      .childElements
      .toList();
  final key = elements.indexWhere(
    (element) =>
        element.name.local == 'key' && element.innerText == 'CFBundleURLTypes',
  );
  if (key < 0) return const [];
  final types = elements[key + 1];
  expect(types.name.local, 'array');
  return [
    for (final type in types.childElements)
      () {
        expect(type.name.local, 'dict');
        final entries = type.childElements.toList();
        final schemes = entries.indexWhere(
          (element) => element.innerText == 'CFBundleURLSchemes',
        );
        return [
          for (final scheme in entries[schemes + 1].childElements)
            scheme.innerText,
        ];
      }(),
  ];
}

/// Where Android Studio has keytool on this system, which the script takes
/// when the PATH and JAVA_HOME have none.
String _androidStudioKeytool() => Platform.isMacOS
    ? '/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool'
    : Platform.isWindows
        ? '${Platform.environment['ProgramFiles'] ?? r'C:\Program Files'}'
            r'\Android\Android Studio\jbr\bin\keytool.exe'
        : '/opt/android-studio/jbr/bin/keytool';

/// The page of the Firebase console with the sign-in methods of [project].
String _consoleOf(String project) =>
    'https://console.firebase.google.com/project/$project/authentication/'
    'providers';

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

  /// The apps of the module in the mode required with the ways to sign in
  /// of the modules of the tests, by the names of those ways.
  final withWays = <String, RenderedApp>{};

  /// A directory of the test, with links resolved: `bin` with the Firebase
  /// CLI, `none` without it, `jdk` with keytool in `bin`, `broken` with a
  /// keytool in `bin` that does not run, `files` with the Firebase files
  /// that the Firebase CLI gives, `android` for the debug key, `home` for a
  /// home directory, `temp` for the temporary files of the script, and
  /// `elsewhere`, which is no directory of an app.
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
    final harness = ContractHarness(
      ModuleRegistry([...modules, ...WayOfTest.all]),
    );
    for (final (name, ways) in [
      ('google', [WayOfTest.google]),
      ('google alone', [WayOfTest.googleAlone]),
      ('apple', [WayOfTest.apple]),
      ('google and apple', [WayOfTest.google, WayOfTest.apple]),
    ]) {
      final result = await harness.check(
        ContractCase(
          'firebase_auth with $name',
          requested: [FirebaseAuthModule.id, for (final way in ways) way.id],
        ),
      );
      expect(result.errors, isEmpty, reason: name);
      withWays[name] = result.app!;
    }
  });

  setUp(() {
    machine = Directory(
      Directory.systemTemp
          .createTempSync('smf_enable_sign_in_')
          .resolveSymbolicLinksSync(),
    );
    for (final name in [
      'bin',
      'none',
      'jdk/bin',
      'broken/bin',
      'files',
      'android',
      'home',
      'temp',
      'elsewhere',
    ]) {
      Directory(inMachine(name)).createSync(recursive: true);
    }
    // The Firebase CLI and keytool are commands of the shell on every
    // system, as npm installs the Firebase CLI, each of which runs the
    // program next to it.
    for (final (directory, command, program) in [
      ('bin', 'firebase', _standIn),
      ('jdk/bin', 'keytool', _keytoolStandIn),
      ('broken/bin', 'keytool', _keytoolStandIn),
    ]) {
      final at = '${inMachine(directory)}${Platform.pathSeparator}';
      File('${at}stand_in.dart').writeAsStringSync(program);
      if (Platform.isWindows) {
        File('$at$command.cmd').writeAsStringSync(_batch, encoding: ascii);
      } else {
        File('$at$command').writeAsStringSync(_shell);
        expect(Process.runSync('chmod', ['+x', '$at$command']).exitCode, 0);
      }
    }
    File(inMachine('broken/bin/broken')).createSync();
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

  /// The file in which the stand-in for keytool notes its calls.
  File keytoolCalls() => File(inMachine('keytool_calls'));

  /// The arguments of each call of keytool so far, each on a line.
  List<String> keytoolCallsSoFar() => [
        if (keytoolCalls().existsSync())
          for (final line in keytoolCalls().readAsLinesSync())
            (jsonDecode(line) as List<Object?>).join(' '),
      ];

  /// Starts the script of [of], or of the app of the test, with
  /// [arguments], as `dart tool/enable_firebase_sign_in.dart` in the
  /// directory of the app, or in [workingDirectory] with [script], the path
  /// of the script there, or its path in the app.
  ///
  /// The `PATH` of the script is the directory with the Firebase CLI, or an
  /// empty one unless [withFirebase], and the directories of [keytools],
  /// and its temporary files go into a directory of the test. [standIn] has
  /// the variables of the stand-ins. The script does not get `DEBUG` or
  /// `NO_UPDATE_NOTIFIER` of the machine of the test: what the Firebase CLI
  /// gets of them is the test's and the script's to say. Nor does it get
  /// what tells where the machine has the debug key of Android or a JDK:
  /// its debug key is in `android` of the test, unless [standIn] says
  /// otherwise.
  Future<Process> start({
    DartApp? of,
    List<String> arguments = const [],
    Map<String, String> standIn = const {},
    bool withFirebase = true,
    List<String> keytools = const [],
    String? workingDirectory,
    String? script,
  }) {
    final target = of ?? app;
    final changes = {
      'PATH': [
        inMachine(withFirebase ? 'bin' : 'none'),
        for (final keytool in keytools) inMachine(keytool),
      ].join(Platform.isWindows ? ';' : ':'),
      'TMPDIR': inMachine('temp'),
      'TEMP': inMachine('temp'),
      'TMP': inMachine('temp'),
      'SMF_TEST_DART': Platform.resolvedExecutable,
      'STAND_IN_CALLS': calls().path,
      'STAND_IN_KEYTOOL_CALLS': keytoolCalls().path,
      'STAND_IN_FILES': inMachine('files'),
      'ANDROID_USER_HOME': inMachine('android'),
      ...standIn,
    };
    // The names of the variables of Windows are in any case, such as
    // `Path`, so a variable of the test replaces the one of the machine
    // whatever its case.
    final replaced = {
      for (final name in changes.keys) name.toUpperCase(),
      'DEBUG',
      'NO_UPDATE_NOTIFIER',
      'JAVA_HOME',
      'ANDROID_PREFS_ROOT',
      'ANDROID_SDK_HOME',
      'TEST_TMPDIR',
      'XDG_CONFIG_HOME',
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
    List<String> keytools = const [],
    String? workingDirectory,
    String? script,
  }) async {
    final result = await finish(
      await start(
        of: of,
        arguments: arguments,
        standIn: standIn,
        withFirebase: withFirebase,
        keytools: keytools,
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
        'stops when the app is configured for several projects, and gives '
        'the command for each', () async {
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
        'smf-dev, smf-app), since flavors of the app may have projects of '
        'their own. A run of this script enables the methods in one project, '
        'so run it once for each:\n'
        '$enableSignInCommand --project smf-staging\n'
        '$enableSignInCommand --project smf-dev\n'
        '$enableSignInCommand --project smf-app\n',
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
        'stops in an app with no configured flavor, and tells to configure '
        'one or to name the project', () async {
      const orName = 'or name the project: $enableSignInCommand --project '
          '<id>';
      final config = File(configOf(app));

      final missing = await run();

      expect(missing.code, 1);
      expect(
        missing.errors,
        '${config.path} is missing, so no flavor of the app is configured for '
        'Firebase yet. Configure one first with "$_configure" (see README.md), '
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
          '${config.path} names no Firebase project. Configure a flavor first '
          'with "$_configure" (see README.md), $orName\n',
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
      const again = 'Configure a flavor again with "$_configure" (see '
          'README.md), or name the project: $enableSignInCommand --project '
          '<id>';
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
        'after a failure for a project that its arguments name, gives the '
        'commands with that project, since without it an app with several '
        'projects stops', () async {
      File(configOf(app)).writeAsStringSync(
        _configuredByFlavors(const {'dev': 'smf-dev', 'prod': 'smf-prod'}),
      );

      final result = await run(
        arguments: ['--project', 'smf-prod'],
        standIn: {'STAND_IN_DEPLOY_CODE': '2'},
      );

      expect(result.code, 2);
      expect(
        result.errors.split('\n'),
        containsAll([
          _failed(2),
          _maybeAnotherAccount.replaceFirst(
            '--account <email>',
            '--project smf-prod --account <email>',
          ),
          _withDebug.replaceFirst('--debug', '--project smf-prod --debug'),
        ]),
      );
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
        'stops at a Firebase CLI that is older than 15.34.0, such as 15.33.0, '
        'by the rule of the check of the machine, tells how to update it, '
        'and does not run it', () async {
      File(configOf(app)).writeAsStringSync(_configuredFor('smf-app'));

      for (final (printed, version) in [
        // The last version before the first one, whose command adds a web
        // app to a project that has only Android and iOS apps.
        ('15.33.0', '15.33.0'),
        ('15.6.0', '15.6.0'),
        ('15.5.1', '15.5.1'),
        ('14.27.0', '14.27.0'),
        ('9.23.3', '9.23.3'),
        // The last line that is a version is that of the Firebase CLI.
        ('16.0.0|15.33.0', '15.33.0'),
        // A pre-release of the first version may lack what it has.
        ('15.34.0-rc.1', '15.34.0-rc.1'),
        ('15.34.0-rc.1+build.5', '15.34.0-rc.1+build.5'),
      ]) {
        final result = await run(standIn: {'STAND_IN_VERSION': printed});

        expect(result.code, 1, reason: version);
        expect(
          result.errors,
          'The Firebase CLI of this machine is $version, and enabling '
          'sign-in methods needs 15.34.0 or later. Update it with "npm '
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
        'runs the first Firebase CLI that it may run and every later one, '
        'by the last version that it prints, and one whose version it '
        'cannot read', () async {
      File(configOf(app)).writeAsStringSync(_configuredFor('smf-app'));

      for (final version in [
        '15.34.0',
        '15.34.1',
        '15.40.0',
        '16.0.0',
        // With notices before the version, which have versions too, and
        // after a line that is another version.
        _withNotices,
        '15.33.0|15.34.0',
        // A build of the first version, and a pre-release of a later one.
        '15.34.0+build.5',
        '15.34.1-rc.1',
        '16.0.0-beta.2',
        // Nothing that the script reads as a version: the Firebase CLI
        // tells itself what it cannot do.
        'a development build',
        '99999999999999999999.0.0',
        '15.34',
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

  group('the script of an app with ways to sign in', () {
    /// The app with the ways to sign in [ways], in place of the app of the
    /// test, with its Info.plist, as flutterfire configured it for smf-app.
    void useAppWith(String ways) {
      app.delete();
      final of = withWays[ways]!;
      app = DartApp.write(of);
      File('${app.path}/$_infoPlist')
        ..createSync(recursive: true)
        ..writeAsStringSync(of.files[_infoPlist]!.text);
      File(configOf(app)).writeAsStringSync(_configuredFor('smf-app'));
    }

    /// Has the Firebase CLI give the Firebase files of the apps: with the
    /// clients of Google if [clients], and for Android without the client
    /// of the server in its first [androidLate] answers.
    void serveFiles({bool clients = true, int androidLate = 0}) {
      File(inMachine('files/ANDROID'))
          .writeAsStringSync(_googleServices(withServer: clients));
      File(inMachine('files/IOS'))
          .writeAsStringSync(_serviceInfo(withClient: clients));
      for (var call = 1; call <= androidLate; call++) {
        File(inMachine('files/ANDROID.$call'))
            .writeAsStringSync(_googleServices(withServer: false));
      }
    }

    /// The file of the app of the test at [path].
    File fileOf(String path) => File('${app.path}/$path');

    /// The debug key in `android` of the test, where the script finds it.
    final keystore = '${Platform.pathSeparator}debug.keystore';

    /// The hashes that Firebase lists for a debug key with the
    /// fingerprints of the stand-in for keytool: in lower case and without
    /// colons.
    final registered =
        [_sha1, _sha256].map((hash) => hash.replaceAll(':', '').toLowerCase());

    /// What the script tells after a step failed once it enabled the
    /// methods.
    const rest = 'What this script did before that stays done, and running '
        'it again does the rest: $enableSignInCommand';

    /// The options of the calls of the Firebase CLI for the apps.
    const json = '--project=smf-app --non-interactive --json';

    test(
        'enables Google with the name of the app and the email address of '
        'the account of the Firebase CLI for its consent screen, registers '
        'the SHA-1 and SHA-256 of the debug key, creating the key as the '
        'Android Gradle plugin does, downloads the Firebase files and writes '
        'the URL scheme of the iOS app; and then, run again, changes '
        'nothing', () async {
      useAppWith('google');
      serveFiles();
      final config = File(configOf(app)).readAsStringSync();
      final plist = fileOf(_infoPlist).readAsStringSync();
      final key = '${inMachine('android')}$keystore';

      final result = await run(
        keytools: ['jdk/bin'],
        standIn: {'STAND_IN_ACCOUNT': 'dev@example.com'},
      );

      expect(result.code, 0, reason: result.errors);
      expect(commandsOf(result), [
        '--version',
        'login:list',
        'deploy --only auth --project=smf-app --non-interactive',
        'apps:android:sha:list $_androidApp $json',
        'apps:android:sha:create $_androidApp $_sha1 $json',
        'apps:android:sha:create $_androidApp $_sha256 $json',
        'apps:sdkconfig ANDROID $_androidApp $json',
        'apps:sdkconfig IOS $_iosApp $json',
      ]);
      expect(
        jsonDecode(result.calls[2].files['firebase.json']!),
        {
          'auth': {
            'providers': {
              'emailPassword': true,
              'googleSignIn': {
                'oAuthBrandDisplayName': 'Contract App',
                'supportEmail': 'dev@example.com',
              },
            },
          },
        },
        reason: 'Without the two fields, the Firebase CLI waited for Google '
            'for 180 seconds and failed.',
      );
      expect(
        [for (final call in result.calls) call.checksForUpdates],
        everyElement(isFalse),
      );
      // As the Android Gradle plugin 9 creates the key.
      final genkeypair = '-genkeypair -keystore $key -storepass android '
          '-alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 '
          '-sigalg SHA256withRSA -validity 10950 -dname CN=Android '
          'Debug,O=Android,C=US';
      final list =
          '-list -v -keystore $key -alias androiddebugkey -storepass android';
      expect(keytoolCallsSoFar(), ['-help', genkeypair, list]);
      expect(File(key).existsSync(), isTrue);
      expect(
        result.output,
        'Enabling Email/Password and Google in the Firebase project smf-app '
        '(the mode of the app is required).\n'
        'Google shows the name "Contract App" and the support email '
        'dev@example.com on its consent screen.\n'
        'stand-in: deploying\n'
        'Registering the SHA-1 and SHA-256 of the Android debug key of this '
        'machine, $key, for the Android app $_androidApp.\n'
        'There is no debug key yet, so this script creates it, as the first '
        'debug build would.\n'
        '$_keyHashes\n'
        'Registered them for the Android app $_androidApp.\n'
        'Downloading the Firebase files of the app again, with the clients of '
        'Google: $_androidFile and $_iosFile.\n'
        'Wrote $_androidFile and $_iosFile.\n'
        'Writing the URL scheme of Google, $_scheme, into $_infoPlist.\n',
      );
      expect(result.errors, 'stand-in: on the standard error\n');
      // The files of Firebase as Firebase gives them, where flutterfire
      // wrote them.
      expect(
        fileOf(_androidFile).readAsStringSync(),
        _googleServices(withServer: true),
      );
      expect(
        fileOf(_iosFile).readAsStringSync(),
        _serviceInfo(withClient: true),
      );
      // The URL type of the scheme at the end of the dictionary of the
      // file, and nothing else changed there.
      final written = fileOf(_infoPlist).readAsStringSync();
      expect(
        written,
        plist.replaceFirst(
          '</dict>\n</plist>',
          '\t<key>CFBundleURLTypes</key>\n'
              '\t<array>\n'
              '${_urlType('\t\t')}'
              '\t</array>\n'
              '</dict>\n</plist>',
        ),
      );
      expect(_urlSchemesOf(written), [
        [_scheme],
      ]);
      expect(
        {..._plistOf(written)}..remove('CFBundleURLTypes'),
        _plistOf(plist),
      );
      expect(File(configOf(app)).readAsStringSync(), config);
      expect(File('${app.path}/.firebaserc').existsSync(), isFalse);

      // Run again, with the hashes registered, which Firebase lists in its
      // own form.
      final modified = fileOf(_androidFile).lastModifiedSync();
      final again = await run(
        keytools: ['jdk/bin'],
        standIn: {
          'STAND_IN_ACCOUNT': 'dev@example.com',
          'STAND_IN_SHAS': registered.join(','),
        },
      );

      expect(again.code, 0, reason: again.errors);
      expect(commandsOf(again), [
        '--version',
        'login:list',
        'deploy --only auth --project=smf-app --non-interactive',
        'apps:android:sha:list $_androidApp $json',
        'apps:sdkconfig ANDROID $_androidApp $json',
        'apps:sdkconfig IOS $_iosApp $json',
      ]);
      expect(keytoolCallsSoFar().skip(3), ['-help', list]);
      expect(
        again.output.split('\n').sublist(3).join('\n'),
        'Registering the SHA-1 and SHA-256 of the Android debug key of this '
        'machine, $key, for the Android app $_androidApp.\n'
        '$_keyHashes\n'
        'The Android app $_androidApp has them already.\n'
        'Downloading the Firebase files of the app again, with the clients of '
        'Google: $_androidFile and $_iosFile.\n'
        'The files of the app are as Firebase has them already.\n'
        '$_infoPlist has the URL scheme of Google already.\n',
      );
      expect(fileOf(_infoPlist).readAsStringSync(), written);
      expect(fileOf(_androidFile).lastModifiedSync(), modified);
    });

    test(
        'gives Google the account that the arguments name, and asks the '
        'Firebase CLI for no account then', () async {
      useAppWith('google alone');

      final result = await run(
        arguments: ['--account', 'named@example.com'],
        standIn: {'STAND_IN_ACCOUNT': 'dev@example.com'},
      );

      expect(result.code, 0, reason: result.errors);
      const deploy = 'deploy --only auth --project=smf-app --non-interactive';
      expect(commandsOf(result), [
        '--version',
        '$deploy --account named@example.com',
      ]);
      expect(jsonDecode(result.calls.last.files['firebase.json']!), {
        'auth': {
          'providers': {
            'emailPassword': true,
            'googleSignIn': {
              'oAuthBrandDisplayName': 'Contract App',
              'supportEmail': 'named@example.com',
            },
          },
        },
      });
      // A way to sign in of Google that needs nothing of the project: the
      // script only enables it.
      expect(
          result.output.split('\n').skip(1).first,
          'Google shows the name "Contract App" and the support email '
          'named@example.com on its consent screen.');
      expect(keytoolCallsSoFar(), isEmpty);
    });

    test(
        'leaves Google out, says so and exits with 0 when the Firebase CLI '
        'runs as no user account, as with a service account', () async {
      useAppWith('google alone');

      final result = await run();

      expect(result.code, 0, reason: result.errors);
      expect(commandsOf(result), [
        '--version',
        'login:list',
        'deploy --only auth --project=smf-app --non-interactive',
      ]);
      expect(result.calls.last.files['firebase.json'], _emailPassword);
      final named = await run(arguments: ['--project', 'other-app']);

      expect(named.code, 0, reason: named.errors);
      expect(
        named.output.split('\n').first,
        contains(
          'To enable Google, run: $enableSignInCommand --project other-app '
          '--account <email>, ',
        ),
      );
      expect(
        result.output,
        'Google is left out: its consent screen needs a support email, the '
        'email address of a user account of the Firebase CLI, and the '
        'Firebase CLI runs as none here, as with a service account. To enable '
        'Google, run: $enableSignInCommand --account <email>, or enable it in '
        'the Firebase console: ${_consoleOf('smf-app')}\n'
        '${_enabling('smf-app', AuthMode.required)}\n'
        'stand-in: deploying\n',
      );
    });

    test(
        'with Google left out, writes the Firebase files and the URL scheme '
        'once they have the clients of Google, as in a project in which '
        'Google is enabled, and leaves them and exits with 0 when they do '
        'not', () async {
      useAppWith('google');
      serveFiles(clients: false);
      File('${inMachine('android')}$keystore').writeAsStringSync('a key');
      final plist = fileOf(_infoPlist).readAsStringSync();
      final shas = {'STAND_IN_SHAS': registered.join(',')};

      final without = await run(keytools: ['jdk/bin'], standIn: shas);

      expect(without.code, 0, reason: without.errors);
      // One download each, since this run did not enable Google.
      expect(commandsOf(without).skip(3), [
        'apps:android:sha:list $_androidApp $json',
        'apps:sdkconfig ANDROID $_androidApp $json',
        'apps:sdkconfig IOS $_iosApp $json',
      ]);
      expect(
        without.output.split('\n').skip(7).join('\n'),
        'The files of the app are as Firebase has them already.\n'
        'Firebase has no clients of Google, as in a project in which Google is '
        'not enabled, so this script has not written $_androidFile and '
        '$_iosFile, and writes no URL scheme. Enable Google, and run this '
        'script again.\n',
      );
      expect(fileOf(_androidFile).existsSync(), isFalse);
      expect(fileOf(_iosFile).existsSync(), isFalse);
      expect(fileOf(_infoPlist).readAsStringSync(), plist);

      serveFiles();
      final enabled = await run(keytools: ['jdk/bin'], standIn: shas);

      expect(enabled.code, 0, reason: enabled.errors);
      expect(enabled.output.split('\n').skip(7), [
        'Wrote $_androidFile and $_iosFile.',
        'Writing the URL scheme of Google, $_scheme, into $_infoPlist.',
        '',
      ]);
      expect(_urlSchemesOf(fileOf(_infoPlist).readAsStringSync()), [
        [_scheme],
      ]);
    });

    test(
        'downloads a Firebase file again right after it enabled Google, '
        'until the file has the clients of Google', () async {
      useAppWith('google');
      serveFiles(androidLate: 1);
      File('${inMachine('android')}$keystore').writeAsStringSync('a key');

      final result = await run(
        keytools: ['jdk/bin'],
        standIn: {
          'STAND_IN_ACCOUNT': 'dev@example.com',
          'STAND_IN_SHAS': registered.join(','),
        },
      );

      expect(result.code, 0, reason: result.errors);
      expect(commandsOf(result).skip(4), [
        'apps:sdkconfig ANDROID $_androidApp $json',
        'apps:sdkconfig IOS $_iosApp $json',
        'apps:sdkconfig ANDROID $_androidApp $json',
      ]);
      expect(
        fileOf(_androidFile).readAsStringSync(),
        _googleServices(withServer: true),
      );
    });

    test(
        'fails once it has asked three times more for a file that still '
        'lacks the clients of Google, and leaves that file', () async {
      useAppWith('google');
      serveFiles(androidLate: 4);
      File('${inMachine('android')}$keystore').writeAsStringSync('a key');

      final result = await run(
        keytools: ['jdk/bin'],
        standIn: {
          'STAND_IN_ACCOUNT': 'dev@example.com',
          'STAND_IN_SHAS': registered.join(','),
        },
      );

      expect(result.code, 1);
      expect(
        [
          for (final command in commandsOf(result))
            if (command.startsWith('apps:sdkconfig')) command.split(' ')[1],
        ],
        ['ANDROID', 'IOS', 'ANDROID', 'ANDROID', 'ANDROID'],
      );
      expect(
        result.errors,
        'stand-in: on the standard error\n'
        'Firebase has not added the clients of Google yet, so this script '
        'has not written $_androidFile.\n'
        '$rest\n',
      );
      expect(fileOf(_androidFile).existsSync(), isFalse);
      expect(fileOf(_iosFile).existsSync(), isTrue);
    });

    test(
        'adds the URL scheme to the URL types that the Info.plist has, also '
        'to none, in a file indented one level further and in one with the '
        'line breaks of Windows, and stops '
        'with what to add by hand at one in another form', () async {
      useAppWith('google');
      serveFiles();
      File('${inMachine('android')}$keystore').writeAsStringSync('a key');
      final plist = fileOf(_infoPlist).readAsStringSync();
      const end = '</dict>\n</plist>';
      const deepLink = '\t\t<dict>\n'
          '\t\t\t<key>CFBundleURLSchemes</key>\n'
          '\t\t\t<array>\n'
          '\t\t\t\t<string>myapp</string>\n'
          '\t\t\t</array>\n'
          '\t\t</dict>\n';
      final shas = {'STAND_IN_SHAS': registered.join(',')};
      final oldGoogle = _urlType('\t\t').replaceFirst(
        _scheme,
        'com.googleusercontent.apps.1234567890-of-another-client',
      );

      final indented = plist
          .split('\n')
          .map(
            (line) => line.isEmpty || line.startsWith(RegExp('<[?!]|</?plist'))
                ? line
                : '\t$line',
          )
          .join('\n');

      final added = <String, String>{};
      for (final (name, before, after) in [
        (
          'a URL type of the app',
          plist.replaceFirst(
            end,
            '\t<key>CFBundleURLTypes</key>\n\t<array>\n$deepLink\t</array>\n'
            '$end',
          ),
          plist.replaceFirst(
            end,
            '\t<key>CFBundleURLTypes</key>\n\t<array>\n$deepLink'
            '${_urlType('\t\t')}\t</array>\n$end',
          ),
        ),
        (
          // That of another client of Google, such as of another project,
          // which the script keeps.
          'a scheme of Google of another client',
          plist.replaceFirst(
            end,
            '\t<key>CFBundleURLTypes</key>\n\t<array>\n$oldGoogle'
            '\t</array>\n$end',
          ),
          plist.replaceFirst(
            end,
            '\t<key>CFBundleURLTypes</key>\n\t<array>\n$oldGoogle'
            '${_urlType('\t\t')}\t</array>\n$end',
          ),
        ),
        (
          'no URL type',
          plist.replaceFirst(
            end,
            '\t<key>CFBundleURLTypes</key>\n\t<array/>\n$end',
          ),
          plist.replaceFirst(
            end,
            '\t<key>CFBundleURLTypes</key>\n\t<array>\n'
            '${_urlType('\t\t')}\t</array>\n$end',
          ),
        ),
        (
          // A tool may write the whole file anew, one level further in.
          'every line of the dictionary one level further in',
          indented,
          indented.replaceFirst(
            '\t</dict>\n</plist>',
            '\t\t<key>CFBundleURLTypes</key>\n\t\t<array>\n'
                '${_urlType('\t\t\t')}\t\t</array>\n\t</dict>\n</plist>',
          ),
        ),
        (
          'line breaks of Windows',
          plist.replaceAll('\n', '\r\n'),
          plist
              .replaceFirst(
                end,
                '\t<key>CFBundleURLTypes</key>\n\t<array>\n'
                '${_urlType('\t\t')}\t</array>\n$end',
              )
              .replaceAll('\n', '\r\n'),
        ),
      ]) {
        fileOf(_infoPlist).writeAsStringSync(before);

        final result = await run(keytools: ['jdk/bin'], standIn: shas);

        expect(result.code, 0, reason: '$name: ${result.errors}');
        added[name] = fileOf(_infoPlist).readAsStringSync();
        expect(added[name], after, reason: name);
      }
      expect(_urlSchemesOf(added['a URL type of the app']!), [
        ['myapp'],
        [_scheme],
      ]);
      expect(_urlSchemesOf(added['no URL type']!), [
        [_scheme],
      ]);
      expect(
        _urlSchemesOf(
          added['every line of the dictionary one level further in']!,
        ),
        [
          [_scheme],
        ],
      );
      expect(_urlSchemesOf(added['a scheme of Google of another client']!), [
        ['com.googleusercontent.apps.1234567890-of-another-client'],
        [_scheme],
      ]);

      // Forms that the script does not know, which it leaves as they are.
      const types = '\t<key>CFBundleURLTypes</key>\n\t<array>\n$deepLink'
          '\t</array>\n';
      for (final (name, unknown) in [
        (
          'URL types that are no array',
          plist.replaceFirst(
            end,
            '\t<key>CFBundleURLTypes</key>\n\t<dict/>\n$end',
          ),
        ),
        ('two keys of URL types', plist.replaceFirst(end, '$types$types$end')),
        (
          // Without the indent of the key, for the URL types that go into
          // its empty array.
          'a key of empty URL types that does not start its line',
          plist.replaceFirst(
            end,
            '\t<key>A</key><true/><key>CFBundleURLTypes</key>\n\t<array/>\n'
            '$end',
          ),
        ),
        (
          'no end of the dictionary of the file',
          plist.substring(0, plist.indexOf(end)),
        ),
        (
          'an end of the dictionary that does not start its line',
          plist.replaceFirst(end, '<true/></dict>\n</plist>'),
        ),
      ]) {
        fileOf(_infoPlist).writeAsStringSync(unknown);

        final stopped = await run(keytools: ['jdk/bin'], standIn: shas);

        expect(stopped.code, 1, reason: name);
        expect(
          stopped.errors,
          'stand-in: on the standard error\n'
          '$_infoPlist is not in a form in which this script can add the URL '
          'scheme. Add this to CFBundleURLTypes there by hand:\n'
          '${_urlType('')}'
          '$rest\n',
          reason: name,
        );
        expect(fileOf(_infoPlist).readAsStringSync(), unknown, reason: name);
      }
    });

    test(
        'finds the debug key where the Android Gradle plugin keeps it: in '
        'ANDROID_USER_HOME, or else in .android of ANDROID_SDK_HOME, of '
        'XDG_CONFIG_HOME or of the home directory, the first that exists',
        () async {
      useAppWith('google');
      final home = inMachine('home');
      Directory(inMachine('xdg')).createSync();
      Directory(inMachine('sdk')).createSync();
      final noUserHome = {
        'ANDROID_USER_HOME': '',
        'HOME': home,
        'USERPROFILE': home,
        // The script stops right after keytool.
        'STAND_IN_FAILS': 'apps:android:sha:list',
      };
      final sep = Platform.pathSeparator;

      final found = <String>[];
      for (final variables in [
        {
          'ANDROID_USER_HOME': inMachine('android'),
          'STAND_IN_FAILS': 'apps:android:sha:list',
        },
        noUserHome,
        {...noUserHome, 'XDG_CONFIG_HOME': inMachine('xdg')},
        {...noUserHome, 'XDG_CONFIG_HOME': inMachine('nowhere')},
        {
          ...noUserHome,
          'ANDROID_SDK_HOME': inMachine('sdk'),
          'XDG_CONFIG_HOME': inMachine('xdg'),
        },
      ]) {
        if (keytoolCalls().existsSync()) keytoolCalls().deleteSync();
        final result = await run(keytools: ['jdk/bin'], standIn: variables);
        expect(result.code, 1, reason: '$variables: ${result.errors}');
        final list = keytoolCallsSoFar().last.split(' ');
        found.add(list[list.indexOf('-keystore') + 1]);
      }

      expect(found, [
        '${inMachine('android')}${sep}debug.keystore',
        '$home$sep.android${sep}debug.keystore',
        '${inMachine('xdg')}$sep.android${sep}debug.keystore',
        '$home$sep.android${sep}debug.keystore',
        '${inMachine('sdk')}$sep.android${sep}debug.keystore',
      ]);
      // The script created the key where it did not find one, with the
      // directory of the preferences of the Android tools.
      for (final key in found) {
        expect(File(key).existsSync(), isTrue, reason: key);
      }
    });

    test(
      'takes keytool from JAVA_HOME when the PATH has none that runs, as on '
      'macOS without a JDK that macOS knows',
      () async {
        useAppWith('google');

        final result = await run(
          keytools: ['broken/bin'],
          standIn: {
            'JAVA_HOME': inMachine('jdk'),
            'STAND_IN_FAILS': 'apps:android:sha:list',
          },
        );

        expect(result.code, 1);
        expect(
          result.errors,
          contains(
            'The Firebase CLI did not list the SHA certificate hashes of the '
            'Android app $_androidApp (exit code 2): stand-in: '
            'apps:android:sha:list failed\n',
          ),
        );
        // The one on the PATH does not run, and the one of JAVA_HOME
        // creates the key and reads it.
        expect([
          for (final call in keytoolCallsSoFar()) call.split(' ').first,
        ], [
          '-help',
          '-help',
          '-genkeypair',
          '-list',
        ]);
      },
      // keytool of JAVA_HOME is keytool.exe on Windows, which no stand-in
      // of the tests is.
      testOn: '!windows',
    );

    test(
      'stops once it enabled the methods when no keytool runs, and tells '
      'where it looked and that running it again does the rest',
      () async {
        useAppWith('google');

        final result = await run(
          keytools: ['broken/bin'],
          standIn: {'STAND_IN_ACCOUNT': 'dev@example.com'},
        );

        expect(result.code, 1);
        expect(commandsOf(result), [
          '--version',
          'login:list',
          'deploy --only auth --project=smf-app --non-interactive',
        ]);
        expect(
          result.errors,
          'stand-in: on the standard error\n'
          'keytool, which reads the debug key, was not found on the PATH, in '
          'JAVA_HOME or in Android Studio at ${_androidStudioKeytool()}. '
          'Install a JDK or Android Studio, or put keytool on the PATH, and '
          'run this script again.\n'
          '$rest\n',
        );
        expect(File('${inMachine('android')}$keystore').existsSync(), isFalse);
      },
      // Where Android Studio has keytool, the script takes it.
      skip: File(_androidStudioKeytool()).existsSync()
          ? 'This machine has keytool in Android Studio, which the script '
              'takes.'
          : null,
    );

    test(
        'stops at a call of the Firebase CLI that fails once it enabled the '
        'methods, with its error, the account and that running it again '
        'does the rest', () async {
      useAppWith('google');
      File('${inMachine('android')}$keystore').writeAsStringSync('a key');

      final told = <String, String>{};
      for (final arguments in [
        <String>[],
        ['--account', 'named@example.com'],
      ]) {
        final result = await run(
          arguments: arguments,
          keytools: ['jdk/bin'],
          standIn: {
            'STAND_IN_ACCOUNT': 'dev@example.com',
            'STAND_IN_SHAS': registered.first,
            'STAND_IN_FAILS': 'apps:android:sha:create',
          },
        );

        expect(result.code, 1, reason: '$arguments');
        told[arguments.join(' ')] = result.errors;
        if (arguments.isNotEmpty) {
          expect(
            commandsOf(result).last,
            'apps:android:sha:create $_androidApp $_sha256 $json '
            '--account=named@example.com',
          );
        }
      }

      const failed = 'stand-in: on the standard error\n'
          'The Firebase CLI did not register $_sha256 for the Android app '
          '$_androidApp (exit code 2): stand-in: apps:android:sha:create '
          'failed\n';
      expect(told, {
        '': '$failed$_maybeAnotherAccount\n$rest\n',
        '--account named@example.com': '$failed- The arguments name the '
            'account named@example.com for it. "firebase login:list" shows '
            'the accounts that the Firebase CLI has.\n$rest\n',
      });
    });

    test(
        'enables the methods in a project that its arguments name, and sets '
        'up nothing there for Google, since firebase.json names no app of '
        'that project', () async {
      useAppWith('google');
      final plist = fileOf(_infoPlist).readAsStringSync();

      final result = await run(
        arguments: ['--project', 'other-app'],
        keytools: ['jdk/bin'],
        standIn: {'STAND_IN_ACCOUNT': 'dev@example.com'},
      );

      expect(result.code, 0, reason: result.errors);
      expect(commandsOf(result), [
        '--version',
        'login:list',
        'deploy --only auth --project=other-app --non-interactive',
      ]);
      expect(
        result.output.split('\n').skip(3).join('\n'),
        'firebase.json of the app names no app of the project other-app, so '
        'this run registers no debug key, downloads no Firebase file and '
        'writes no URL scheme there. To set up a flavor of the app in that '
        'project, run "dart ${FirebaseCoreModule.configureScript} <flavor> '
        '--project=other-app" first, and then this script again.\n',
      );
      expect(keytoolCallsSoFar(), isEmpty);
      expect(fileOf(_infoPlist).readAsStringSync(), plist);
    });

    group('in an app whose flavors are configured', () {
      /// The URL scheme of the client of Google of an iOS app of the project
      /// `smf-dev`, next to [_scheme].
      const devScheme = 'com.googleusercontent.apps.1234567890-dev';

      /// The Firebase file of the iOS app in `smf-dev`.
      String devServiceInfo() =>
          _serviceInfo(withClient: true).replaceAll(_scheme, devScheme);

      /// [path] of the Firebase file of a flavor, and whether the app has it.
      String androidFileOf(String flavor) =>
          'android/app/src/$flavor/google-services.json';
      String iosFileOf(String flavor) =>
          'ios/flavors/$flavor/GoogleService-Info.plist';

      /// The options of the calls of the Firebase CLI for [project].
      String jsonFor(String project) =>
          '--project=$project --non-interactive --json';

      setUp(() {
        useAppWith('google');
        File('${inMachine('android')}$keystore').writeAsStringSync('a key');
      });

      test(
          'stops at several projects and names each, also with an account, '
          'and changes nothing', () async {
        final config = _configuredByFlavors(const {
          'dev': 'smf-dev',
          'staging': 'smf-staging',
          'prod': 'smf-prod',
        });
        File(configOf(app)).writeAsStringSync(config);

        final result = await run(arguments: ['--account', 'dev@example.com']);

        expect(result.code, 1);
        expect(
          result.errors,
          '${configOf(app)} has several Firebase projects (smf-dev, '
          'smf-staging, smf-prod), since flavors of the app may have projects '
          'of their own. A run of this script enables the methods in one '
          'project, so run it once for each:\n'
          '$enableSignInCommand --project smf-dev\n'
          '$enableSignInCommand --project smf-staging\n'
          '$enableSignInCommand --project smf-prod\n',
        );
        expect(result.calls, isEmpty);
        expect(File(configOf(app)).readAsStringSync(), config);
      });

      test(
          'reads the one project of the flavors that are configured, under '
          'any key of the Android app', () async {
        for (final flavors in const [
          {'dev': 'smf-dev'},
          {'first': 'smf-dev', 'dev': 'smf-dev'},
          {'first': 'smf-dev', 'second': 'smf-dev', 'dev': 'smf-dev'},
        ]) {
          File(configOf(app)).writeAsStringSync(_configuredByFlavors(flavors));
          serveFiles();

          final result = await run(
            keytools: ['jdk/bin'],
            standIn: {
              'STAND_IN_ACCOUNT': 'dev@example.com',
              'STAND_IN_SHAS': registered.join(','),
            },
          );

          expect(result.code, 0, reason: result.errors);
          expect(
            commandsOf(result),
            contains(
              'apps:sdkconfig ANDROID ${_androidAppOf('dev')} '
              '${jsonFor('smf-dev')}',
            ),
            reason: '$flavors',
          );
        }
      });

      test(
          'with --project, registers the debug key, downloads each Firebase '
          'file once and writes the URL scheme for the flavor of that project '
          'alone, next to the scheme of the other project', () async {
        File(configOf(app)).writeAsStringSync(
          _configuredByFlavors(const {
            'dev': 'smf-dev',
            'staging': 'smf-staging',
          }),
        );
        serveFiles();
        File(inMachine('files/IOS')).writeAsStringSync(devServiceInfo());

        final dev = await run(
          arguments: ['--project', 'smf-dev'],
          keytools: ['jdk/bin'],
          standIn: {
            'STAND_IN_ACCOUNT': 'dev@example.com',
            'STAND_IN_SHAS': registered.join(','),
          },
        );

        expect(dev.code, 0, reason: dev.errors);
        expect(
          _urlSchemesOf(fileOf(_infoPlist).readAsStringSync()),
          [
            [devScheme],
          ],
        );
        expect(fileOf(androidFileOf('dev')).existsSync(), isTrue);
        expect(fileOf(iosFileOf('dev')).readAsStringSync(), devServiceInfo());
        expect(fileOf(androidFileOf('staging')).existsSync(), isFalse);
        expect(fileOf(iosFileOf('staging')).existsSync(), isFalse);

        File(inMachine('files/IOS'))
            .writeAsStringSync(_serviceInfo(withClient: true));

        final staging = await run(
          arguments: ['--project', 'smf-staging'],
          keytools: ['jdk/bin'],
          standIn: {'STAND_IN_ACCOUNT': 'dev@example.com'},
        );

        expect(staging.code, 0, reason: staging.errors);
        final android = _androidAppOf('staging');
        final options = jsonFor('smf-staging');
        expect(commandsOf(staging), [
          '--version',
          'login:list',
          'deploy --only auth --project=smf-staging --non-interactive',
          'apps:android:sha:list $android $options',
          'apps:android:sha:create $android $_sha1 $options',
          'apps:android:sha:create $android $_sha256 $options',
          'apps:sdkconfig ANDROID $android $options',
          // Once, though three build configurations name the iOS app.
          'apps:sdkconfig IOS ${_iosAppOf('staging')} $options',
        ]);
        expect(
          fileOf(iosFileOf('staging')).readAsStringSync(),
          _serviceInfo(withClient: true),
        );
        expect(fileOf(androidFileOf('staging')).existsSync(), isTrue);
        // The file of the other flavor stays as it was.
        expect(fileOf(iosFileOf('dev')).readAsStringSync(), devServiceInfo());
        // One Info.plist for all the flavors, with a scheme for each.
        expect(
          _urlSchemesOf(fileOf(_infoPlist).readAsStringSync()),
          [
            [devScheme],
            [_scheme],
          ],
        );
      });

      test(
          'with two flavors in the project, sets up the apps of both, with '
          'a URL scheme for each iOS app', () async {
        File(configOf(app)).writeAsStringSync(
          _configuredByFlavors(const {
            'dev': 'smf-app',
            'staging': 'smf-app',
            'prod': 'smf-prod',
          }),
        );
        serveFiles();
        File(inMachine('files/IOS.1')).writeAsStringSync(devServiceInfo());
        File(inMachine('files/IOS.2'))
            .writeAsStringSync(_serviceInfo(withClient: true));

        final result = await run(
          arguments: ['--project', 'smf-app'],
          keytools: ['jdk/bin'],
          standIn: {
            'STAND_IN_ACCOUNT': 'dev@example.com',
            'STAND_IN_SHAS': registered.join(','),
          },
        );

        expect(result.code, 0, reason: result.errors);
        expect(
          commandsOf(result).skip(3),
          [
            'apps:android:sha:list ${_androidAppOf('dev')} $json',
            'apps:android:sha:list ${_androidAppOf('staging')} $json',
            'apps:sdkconfig ANDROID ${_androidAppOf('dev')} $json',
            'apps:sdkconfig ANDROID ${_androidAppOf('staging')} $json',
            'apps:sdkconfig IOS ${_iosAppOf('dev')} $json',
            'apps:sdkconfig IOS ${_iosAppOf('staging')} $json',
          ],
        );
        expect(
          _urlSchemesOf(fileOf(_infoPlist).readAsStringSync()),
          [
            [devScheme],
            [_scheme],
          ],
        );
        expect(fileOf(androidFileOf('prod')).existsSync(), isFalse);
      });

      test('a step that fails tells to run the script again for that project',
          () async {
        File(configOf(app)).writeAsStringSync(
          _configuredByFlavors(const {'dev': 'smf-dev', 'prod': 'smf-prod'}),
        );
        serveFiles();

        final result = await run(
          arguments: ['--project', 'smf-prod'],
          keytools: ['jdk/bin'],
          standIn: {
            'STAND_IN_ACCOUNT': 'dev@example.com',
            'STAND_IN_FAILS': 'apps:android:sha:list',
          },
        );

        expect(result.code, 1);
        expect(
          result.errors,
          allOf(
            contains(
              'To name the account, run: $enableSignInCommand --project '
              'smf-prod --account <email>\n',
            ),
            endsWith(
              'What this script did before that stays done, and running it '
              'again does the rest: $enableSignInCommand --project '
              'smf-prod\n',
            ),
          ),
        );
      });
    });

    test(
        'stops at a Firebase file that firebase.json puts outside the app, by '
        'a relative path and by an absolute one', () async {
      useAppWith('google');
      serveFiles();
      File('${inMachine('android')}$keystore').writeAsStringSync('a key');
      final absolute = '${inMachine('elsewhere')}'
          '${Platform.pathSeparator}google-services.json';

      for (final outside in ['../outside/google-services.json', absolute]) {
        File(configOf(app)).writeAsStringSync(
          _configuredFor('smf-app').replaceFirst(
            '"android/app/google-services.json"',
            jsonEncode(outside),
          ),
        );

        final result = await run(
          keytools: ['jdk/bin'],
          standIn: {
            'STAND_IN_ACCOUNT': 'dev@example.com',
            'STAND_IN_SHAS': registered.join(','),
          },
        );

        expect(result.code, 1, reason: outside);
        expect(
          result.errors,
          'stand-in: on the standard error\n'
          'firebase.json of the app names "$outside" as a Firebase file of '
          'the app, which is outside the app.\n'
          '$rest\n',
          reason: outside,
        );
      }
      expect(
        File('${app.path}/../outside/google-services.json').existsSync(),
        isFalse,
      );
      expect(File(absolute).existsSync(), isFalse);
    });

    test(
        'stops at a file of the app that it cannot write, with what is done: '
        'a directory where a Firebase file goes, and an Info.plist that is '
        'read-only', () async {
      useAppWith('google');
      serveFiles();
      File('${inMachine('android')}$keystore').writeAsStringSync('a key');
      final standIn = {
        'STAND_IN_ACCOUNT': 'dev@example.com',
        'STAND_IN_SHAS': registered.join(','),
      };
      Directory('${app.path}/$_androidFile').createSync(recursive: true);

      final directory = await run(keytools: ['jdk/bin'], standIn: standIn);

      expect(directory.code, 1);
      expect(
        directory.errors,
        allOf(
          startsWith(
            'stand-in: on the standard error\n'
            '$_androidFile could not be written (',
          ),
          endsWith(').\n$rest\n'),
          isNot(contains('#0 ')),
        ),
      );

      if (Platform.isWindows) return;
      Directory('${app.path}/$_androidFile').deleteSync();
      final plist = fileOf(_infoPlist);
      final text = plist.readAsStringSync();
      expect(Process.runSync('chmod', ['444', plist.path]).exitCode, 0);

      final readOnly = await run(keytools: ['jdk/bin'], standIn: standIn);

      expect(readOnly.code, 1);
      expect(
        readOnly.errors,
        allOf(
          startsWith(
            'stand-in: on the standard error\n'
            '$_infoPlist could not be written (',
          ),
          contains(
            '). Add this to CFBundleURLTypes there by hand:\n'
            '${_urlType('')}'
            '$rest\n',
          ),
          isNot(contains('#0 ')),
        ),
      );
      expect(plist.readAsStringSync(), text);
    });

    test(
      'after Ctrl+C, lets the process that runs end, removes its temporary '
      'directory and exits with 130, also while it registers the debug key, '
      'downloads a Firebase file or reads the debug key with keytool',
      () async {
        useAppWith('google');
        serveFiles();
        File('${inMachine('android')}$keystore').writeAsStringSync('a key');

        for (final (variable, waits, isRunning) in [
          (
            'STAND_IN_WAITS',
            'apps:android:sha:list',
            () => callsSoFar().any(
                  (call) => call.arguments.first == 'apps:android:sha:list',
                ),
          ),
          (
            'STAND_IN_WAITS',
            'apps:sdkconfig',
            () => callsSoFar().any(
                  (call) => call.arguments.first == 'apps:sdkconfig',
                ),
          ),
          (
            'STAND_IN_KEYTOOL_WAITS',
            '-list',
            () => keytoolCallsSoFar().any((call) => call.startsWith('-list')),
          ),
        ]) {
          if (keytoolCalls().existsSync()) keytoolCalls().deleteSync();
          final process = await start(
            keytools: ['jdk/bin'],
            standIn: {
              'STAND_IN_ACCOUNT': 'dev@example.com',
              'STAND_IN_SHAS': registered.join(','),
              variable: waits,
            },
          );
          final ended = finish(process);
          for (var tries = 0; !isRunning(); tries++) {
            expect(tries, lessThan(600), reason: 'no call for $waits');
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
          final directory = Directory(callsSoFar().last.directory);
          expect(directory.existsSync(), isTrue);

          expect(process.kill(ProcessSignal.sigint), isTrue);
          final result = await ended;

          expect(result.code, 130, reason: '$waits: ${result.errors}');
          expect(directory.existsSync(), isFalse, reason: waits);
          // Nothing of a failure: the user knows what stopped the script.
          expect(
            result.errors,
            'stand-in: on the standard error\n',
            reason: waits,
          );
          calls().deleteSync();
        }
      },
      // Windows has no signal that one process sends another.
      testOn: '!windows',
    );

    test(
        'tells in an app with Apple how to enable it in the Firebase console, '
        'which the Firebase CLI cannot do, and asks it for no account',
        () async {
      useAppWith('apple');

      final result = await run();

      expect(result.code, 0, reason: result.errors);
      expect(commandsOf(result), [
        '--version',
        'deploy --only auth --project=smf-app --non-interactive',
      ]);
      expect(result.calls.last.files['firebase.json'], _emailPassword);
      expect(
        result.output,
        '${_enabling('smf-app', AuthMode.required)}\n'
        'stand-in: deploying\n'
        'Apple is enabled in the Firebase console, which the Firebase CLI '
        'cannot do: ${_consoleOf('smf-app')}\nThe deletion of an account of '
        'Apple also needs the Services ID and the OAuth code flow '
        'configuration of Apple there; see the section Firebase '
        'Authentication of README.md.\n',
      );

      // Nothing of Apple after the Firebase CLI failed.
      final failed = await run(standIn: {'STAND_IN_DEPLOY_CODE': '2'});

      expect(failed.code, 2);
      expect(failed.output, isNot(contains('Apple')));
    });

    test(
        'has the code that enables Google only in an app with a way to sign '
        'in of Google, the line for Apple only in one with a way to sign in '
        'of Apple, and the code that sets up what the ways to sign in need '
        'only in an app with one that needs something, on lines of their own '
        'between those of the script of an app without them', () {
      String scriptOf(RenderedApp app) => app.files[enableSignInScript]!.text;
      final without = scriptOf(rendered[AuthMode.required]!);
      const marks = {
        'Google': "'googleSignIn': {",
        'Apple': 'String _appleInConsole(',
        'the setup': 'const _needs = ',
        'the debug key': "'-genkeypair',",
        'the URL scheme': '<key>CFBundleURLTypes</key>',
      };
      Set<String> marksOf(String script) => {
            for (final MapEntry(:key, :value) in marks.entries)
              if (script.contains(value)) key,
          };

      expect(marksOf(without), isEmpty);
      expect(marksOf(scriptOf(withWays['apple']!)), {'Apple'});
      expect(marksOf(scriptOf(withWays['google alone']!)), {'Google'});
      expect(
        marksOf(scriptOf(withWays['google']!)),
        marks.keys.toSet().difference({'Apple'}),
      );
      expect(
        marksOf(scriptOf(withWays['google and apple']!)),
        marks.keys.toSet(),
      );
      // Each line of the script of an app without ways to sign in is in the
      // script of one with them, in its order, but for the line that tells
      // what the script enables, which names Google there.
      const first = r"      'Enabling Email/Password${anonymous ? ' and "
          "Anonymous' : ''} in the '";
      const second =
          r"      'Firebase project $project (the mode of the app is $mode).',";
      const enabling = [first, second];
      expect(without.split('\n'), containsAll(enabling));
      for (final ways in withWays.keys) {
        final lines = scriptOf(withWays[ways]!).split('\n');
        var at = 0;
        for (final line in without.split('\n')) {
          if (ways.startsWith('google') && enabling.contains(line)) continue;
          at = lines.indexOf(line, at);
          expect(at, isNonNegative, reason: '$ways: $line');
          at++;
        }
      }
    });
  });
}
