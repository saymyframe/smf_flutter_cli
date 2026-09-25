@TestOn('vm')
library;

import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:smf_flutter_cli/version.dart';
import 'package:test/test.dart';

/// Runs `bin/smf_flutter.dart` in its own Dart VM, with only [path] as the
/// `PATH`, so the real exit code and output of the executable are checked.
Future<ProcessResult> _smf(
  List<String> arguments, {
  String path = '',
  Map<String, String> environment = const {},
}) async {
  final lib = await Isolate.resolvePackageUri(
    Uri.parse('package:smf_flutter_cli/'),
  );
  final packageConfig = await Isolate.packageConfig;
  return Process.run(
    Platform.resolvedExecutable,
    [
      '--packages=${packageConfig!.toFilePath()}',
      p.join(p.dirname(lib!.toFilePath()), 'bin', 'smf_flutter.dart'),
      ...arguments,
    ],
    environment: {
      'PATH': path,
      if (Platform.environment['TMPDIR'] case final temporary?)
        'TMPDIR': temporary,
      ...environment,
    },
    includeParentEnvironment: false,
  );
}

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
  late Directory temporary;

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
