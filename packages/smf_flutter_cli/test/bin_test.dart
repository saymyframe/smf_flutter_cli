@TestOn('vm')
library;

import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:smf_flutter_cli/version.dart';
import 'package:test/test.dart';

/// The kernel of `bin/smf_flutter.dart`, which [_compile] writes once, so
/// that each run starts without compiling the CLI again.
late String _kernel;

Future<void> _compile(Directory directory) async {
  final lib = await Isolate.resolvePackageUri(
    Uri.parse('package:smf_flutter_cli/'),
  );
  final packageConfig = await Isolate.packageConfig;
  _kernel = p.join(directory.path, 'smf.dill');
  final result = await Process.run(Platform.resolvedExecutable, [
    'compile',
    'kernel',
    '--packages=${packageConfig!.toFilePath()}',
    p.join(p.dirname(lib!.toFilePath()), 'bin', 'smf_flutter.dart'),
    '-o',
    _kernel,
  ]);
  if (result.exitCode != 0) {
    throw StateError('The CLI does not compile: ${result.stderr}');
  }
}

/// Runs the CLI in its own Dart VM, with only [path] as the `PATH`, so the
/// real exit code and output of the executable are checked.
Future<ProcessResult> _smf(
  List<String> arguments, {
  String path = '',
  Map<String, String> environment = const {},
}) =>
    Process.run(
      Platform.resolvedExecutable,
      [_kernel, ...arguments],
      environment: {
        'PATH': path,
        // What the Dart VM and temporary files need, on Windows too.
        for (final name in [
          'TMPDIR',
          'TEMP',
          'TMP',
          'SYSTEMROOT',
          'SystemRoot',
        ])
          if (Platform.environment[name] case final value?) name: value,
        ...environment,
      },
      includeParentEnvironment: false,
    );

/// A Flutter SDK in [directory] whose `flutter` and `dart` write their
/// arguments and working directory to `calls.log` next to them and
/// succeed; returns its `bin`.
String _fakeSdk(Directory directory) {
  final bin = p.join(directory.path, 'flutter', 'bin');
  Directory(p.join(bin, 'cache', 'dart-sdk')).createSync(recursive: true);
  File(p.join(bin, 'cache', 'flutter.version.json')).writeAsStringSync(
    '{"flutterVersion": "3.44.2", "dartSdkVersion": "3.12.2"}',
  );
  for (final name in ['flutter', 'dart']) {
    final file = File(p.join(bin, name))
      ..writeAsStringSync(
        '#!/bin/sh\necho "$name \$* in \$PWD" >> "${p.join(bin, 'calls.log')}"\n',
      );
    Process.runSync('chmod', ['+x', file.path]);
  }
  return bin;
}

void main() {
  const timeout = Timeout(Duration(minutes: 2));
  late Directory kernel;
  late Directory temporary;

  setUpAll(() async {
    kernel = Directory.systemTemp.createTempSync('smf_bin_kernel_');
    await _compile(kernel);
  });
  tearDownAll(() => kernel.deleteSync(recursive: true));

  setUp(() => temporary = Directory.systemTemp.createTempSync('smf_bin_'));
  tearDown(() => temporary.deleteSync(recursive: true));

  test(
    'prints the version and exits with 0',
    () async {
      final result = await _smf(['--version']);

      expect(result.exitCode, 0);
      expect(result.stdout, '$packageVersion\n');
    },
    timeout: timeout,
  );

  test(
    'reports an unknown command as a usage error with exit code 64',
    () async {
      final result = await _smf(['bogus']);

      expect(result.exitCode, 64);
      expect(
        result.stderr,
        contains('Could not find a command named "bogus".'),
      );
      expect(result.stderr, isNot(contains('Unhandled exception')));
    },
    timeout: timeout,
  );

  test(
    'lists the options of create and of the roles',
    () async {
      final result = await _smf(['create', '--help']);

      expect(result.exitCode, 0);
      expect(
        result.stdout,
        allOf(contains('--on-conflict'), contains('--start=<path>')),
      );
    },
    timeout: timeout,
  );

  test(
    'stops before generating anything without a Flutter SDK',
    () async {
      final result = await _smf([
        'create',
        'my_app',
        '--no-input',
        '-o',
        temporary.path,
      ]);

      expect(result.exitCode, 1);
      expect(result.stderr, contains('Flutter SDK is missing.'));
      expect(temporary.listSync(), isEmpty);
    },
    timeout: timeout,
  );

  group(
    'with a Flutter SDK',
    () {
      late String sdk;

      setUp(() => sdk = _fakeSdk(temporary));

      List<String> calls() => File(p.join(sdk, 'calls.log')).readAsLinesSync();

      test(
        'creates the app, says how to run it and where the community is',
        () async {
          final output = p.join(temporary.path, 'apps');

          final result = await _smf(
            [
              'create',
              'my_app',
              '--org',
              'com.example',
              '--no-input',
              '-o',
              output,
            ],
            path: sdk,
          );

          expect(result.exitCode, 0, reason: '${result.stderr}');
          final app = p.join(output, 'my_app');
          expect(result.stdout, contains('Created my_app in $app.'));
          expect(result.stdout, contains('Created an SMF App!'));
          expect(File(p.join(app, 'lib', 'main.dart')).existsSync(), isTrue);
          expect(
            File(p.join(app, 'pubspec.yaml')).readAsStringSync(),
            startsWith('name: my_app\n'),
          );
          // The shell reports the directories with links resolved.
          final resolved = Directory(app).resolveSymbolicLinksSync();
          expect(calls().first, startsWith('flutter pub get in '));
          expect(calls().first, isNot(contains(p.dirname(resolved))));
          expect(calls().last, 'flutter pub get in $resolved');
        },
        timeout: timeout,
      );

      test(
        '--explain says what would happen and creates nothing',
        () async {
          final result = await _smf(
            ['create', 'my_app', '--explain', '-o', temporary.path],
            path: sdk,
          );

          expect(result.exitCode, 0, reason: '${result.stderr}');
          expect(result.stdout, contains('flutter_core'));
          expect(
            Directory(p.join(temporary.path, 'my_app')).existsSync(),
            isFalse,
          );
          expect(File(p.join(sdk, 'calls.log')).existsSync(), isFalse);
        },
        timeout: timeout,
      );

      test(
        '--explain shows the module chosen to manage the state',
        () async {
          final result = await _smf(
            [
              'create',
              'my_app',
              '--explain',
              '-m',
              'riverpod',
              '-o',
              temporary.path,
            ],
            path: sdk,
          );

          expect(result.exitCode, 0, reason: '${result.stderr}');
          // The version of flutter_riverpod is the module's to choose.
          expect(
            result.stdout,
            allOf(
              contains('  riverpod: requested\n'),
              contains('  state_management: riverpod\n'),
              matches(
                RegExp(
                  r'^  flutter_riverpod \S+ \(riverpod\)$',
                  multiLine: true,
                ),
              ),
            ),
          );
          expect(
            Directory(p.join(temporary.path, 'my_app')).existsSync(),
            isFalse,
          );
        },
        timeout: timeout,
      );

      test(
        '--explain shows the module chosen to route the app',
        () async {
          final result = await _smf(
            [
              'create',
              'my_app',
              '--explain',
              '-m',
              'go_router',
              '-o',
              temporary.path,
            ],
            path: sdk,
          );

          expect(result.exitCode, 0, reason: '${result.stderr}');
          // The version of go_router is the module's to choose.
          expect(
            result.stdout,
            allOf(
              contains('  go_router: requested\n'),
              contains('  router: go_router\n'),
              matches(
                RegExp(r'^  go_router \S+ \(go_router\)$', multiLine: true),
              ),
            ),
          );
          expect(
            Directory(p.join(temporary.path, 'my_app')).existsSync(),
            isFalse,
          );
        },
        timeout: timeout,
      );

      test(
        '--explain shows the router that a feature gets without asking',
        () async {
          final result = await _smf(
            [
              'create',
              'my_app',
              '--explain',
              '-m',
              'home',
              '-o',
              temporary.path,
            ],
            path: sdk,
          );

          expect(result.exitCode, 0, reason: '${result.stderr}');
          // go_router is the only module that provides the router.
          expect(
            result.stdout,
            allOf(
              contains('  home: requested\n'),
              contains(
                '  go_router: the only provider of the router (home requires '
                'the router)\n',
              ),
              contains('  router: go_router\n'),
            ),
          );
          expect(
            Directory(p.join(temporary.path, 'my_app')).existsSync(),
            isFalse,
          );
        },
        timeout: timeout,
      );

      test(
        '--explain shows the module chosen for the layout',
        () async {
          final result = await _smf(
            [
              'create',
              'my_app',
              '--explain',
              '-m',
              'bottom_tabs',
              '-o',
              temporary.path,
            ],
            path: sdk,
          );

          expect(result.exitCode, 0, reason: '${result.stderr}');
          // The layout requires the router, which only go_router provides.
          expect(
            result.stdout,
            allOf(
              contains('  bottom_tabs: requested\n'),
              contains(
                '  go_router: the only provider of the router (bottom_tabs '
                'requires the router)\n',
              ),
              contains('  layout: bottom_tabs\n'),
              contains('  router: go_router\n'),
            ),
          );
          expect(
            Directory(p.join(temporary.path, 'my_app')).existsSync(),
            isFalse,
          );
        },
        timeout: timeout,
      );

      test(
        '--explain shows the module chosen for dependency injection',
        () async {
          final result = await _smf(
            [
              'create',
              'my_app',
              '--explain',
              '-m',
              'get_it',
              '-o',
              temporary.path,
            ],
            path: sdk,
          );

          expect(result.exitCode, 0, reason: '${result.stderr}');
          // The version of get_it is the module's to choose.
          expect(
            result.stdout,
            allOf(
              contains('  get_it: requested\n'),
              contains('  di: get_it\n'),
              matches(
                RegExp(r'^  get_it \S+ \(get_it\)$', multiLine: true),
              ),
            ),
          );
          expect(
            Directory(p.join(temporary.path, 'my_app')).existsSync(),
            isFalse,
          );
        },
        timeout: timeout,
      );

      test(
        '--explain shows the module chosen for the events',
        () async {
          final result = await _smf(
            [
              'create',
              'my_app',
              '--explain',
              '-m',
              'event_bus',
              '-o',
              temporary.path,
            ],
            path: sdk,
          );

          expect(result.exitCode, 0, reason: '${result.stderr}');
          // The version of event_bus is the module's to choose.
          expect(
            result.stdout,
            allOf(
              contains('  event_bus: requested\n'),
              contains('  events: event_bus\n'),
              matches(
                RegExp(r'^  event_bus \S+ \(event_bus\)$', multiLine: true),
              ),
            ),
          );
          expect(
            Directory(p.join(temporary.path, 'my_app')).existsSync(),
            isFalse,
          );
        },
        timeout: timeout,
      );

      test(
        '--explain shows what Firebase needs of the machine and runs after '
        'generation, and installs nothing',
        () async {
          final result = await _smf(
            [
              'create',
              'my_app',
              '--explain',
              '-m',
              'firebase_core',
              '-o',
              temporary.path,
            ],
            path: sdk,
          );

          expect(result.exitCode, 0, reason: '${result.stderr}');
          // The machine of the test has neither the Firebase CLI nor the
          // FlutterFire CLI, whose global packages its dart does not list.
          expect(
            result.stdout,
            allOf([
              contains('  firebase_core: requested\n'),
              contains(
                'After generation\n'
                '  dart pub global run flutterfire_cli:flutterfire configure '
                '--platforms=android,ios --overwrite-firebase-options '
                '(firebase_core)\n',
              ),
              contains(
                '  ✗ Firebase CLI (for firebase_core): missing\n'
                '    Install it with "npm install -g firebase-tools", or see '
                'https://firebase.google.com/docs/cli.\n',
              ),
              contains(
                '  ✗ Firebase login (for firebase_core): missing\n'
                '    Install the Firebase CLI, then log in with "firebase '
                'login", or on a remote machine, such as over SSH, with '
                '"firebase login --no-localhost".\n',
              ),
              contains(
                '  ✗ FlutterFire CLI (for firebase_core): missing\n'
                '    Activate it with "dart pub global activate '
                'flutterfire_cli 1.4.1".\n'
                '    An interactive run offers to install it.\n',
              ),
              // Its PATH has no Ruby; elsewhere, the Xcode project is left
              // for a Mac.
              contains(
                Platform.isMacOS
                    ? '  ✗ Xcode project tools of flutterfire (for '
                        'firebase_core): missing\n'
                    : '  ✗ Setup of the Xcode project on a Mac (for '
                        'firebase_core): missing\n',
              ),
            ]),
          );
          // Only the read-only commands of the checks ran.
          expect(
            File(p.join(sdk, 'calls.log')).readAsLinesSync(),
            everyElement(startsWith('dart pub global list in ')),
          );
          expect(
            Directory(p.join(temporary.path, 'my_app')).existsSync(),
            isFalse,
          );
        },
        timeout: timeout,
      );

      test(
        'the start of the app is a route of the app',
        () async {
          final result = await _smf(
            [
              'create',
              'my_app',
              '--no-input',
              '-m',
              'go_router',
              '--start',
              '/home',
              '-o',
              temporary.path,
            ],
            path: sdk,
          );

          expect(result.exitCode, 64);
          expect(
            result.stderr,
            contains('The app has no routes, so it cannot start on /home.'),
          );

          final withHome = await _smf(
            [
              'create',
              'my_app',
              '--no-input',
              '-m',
              'home',
              '--start',
              '/settings',
              '-o',
              temporary.path,
            ],
            path: sdk,
          );

          expect(withHome.exitCode, 64);
          expect(
            withHome.stderr,
            contains(
              'The app has no route /settings to start on. Routes: /home.',
            ),
          );
          expect(
            Directory(p.join(temporary.path, 'my_app')).existsSync(),
            isFalse,
          );

          final started = await _smf(
            [
              'create',
              'my_app',
              '--no-input',
              '-m',
              'home',
              '--start',
              '/home',
              '-o',
              temporary.path,
            ],
            path: sdk,
          );

          expect(started.exitCode, 0, reason: '${started.stderr}');
          expect(
            File(
              p.join(
                temporary.path,
                'my_app',
                'lib',
                'core',
                'router',
                'app_router_factory.dart',
              ),
            ).readAsStringSync(),
            contains("initialLocation: '/home',"),
          );
        },
        timeout: timeout,
      );

      test(
        '--on-conflict decides what happens to an existing directory',
        () async {
          final old = File(p.join(temporary.path, 'my_app', 'old.txt'))
            ..createSync(recursive: true);
          final arguments = [
            'create',
            'my_app',
            '--no-input',
            '-o',
            temporary.path,
          ];

          final asked = await _smf(arguments, path: sdk);
          expect(asked.exitCode, 64);
          expect(
            asked.stderr,
            contains('Choose what to do with --on-conflict'),
          );

          final copied =
              await _smf([...arguments, '--on-conflict', 'copy'], path: sdk);
          expect(copied.exitCode, 0, reason: '${copied.stderr}');
          expect(
            File(p.join(temporary.path, 'my_app copy', 'lib', 'main.dart'))
                .existsSync(),
            isTrue,
          );

          final replaced =
              await _smf([...arguments, '--on-conflict', 'replace'], path: sdk);
          expect(replaced.exitCode, 0, reason: '${replaced.stderr}');
          expect(old.existsSync(), isFalse);
          expect(
            File(p.join(temporary.path, 'my_app', 'lib', 'main.dart'))
                .existsSync(),
            isTrue,
          );

          final cancelled =
              await _smf([...arguments, '--on-conflict', 'cancel'], path: sdk);
          expect(cancelled.exitCode, 1);
          expect(cancelled.stderr, contains('the run was cancelled'));
        },
        timeout: timeout,
      );
    },
    testOn: '!windows',
  );
}
