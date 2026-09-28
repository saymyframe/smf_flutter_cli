// The install script of Windows, run for real with Windows PowerShell, as
// the check of the Firebase CLI runs it. It installs the Firebase CLI with
// npm and adds its directory to the PATH of the user, so it runs only where
// SMF_INSTALL_FIREBASE_CLI is 1, such as on a machine of CI that is thrown
// away after the run, which has Node.js 20 or newer.
@TestOn('windows')
library;

import 'dart:convert';
import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/src/preflight/install_scripts.dart';
import 'package:test/test.dart';

void main() {
  final enabled = Platform.environment['SMF_INSTALL_FIREBASE_CLI'] == '1';
  final script = InstallScript.of(HostOperatingSystem.windows)!;
  late Directory temporary;

  setUp(() => temporary = Directory.systemTemp.createTempSync('smf_script_'));
  tearDown(() => temporary.deleteSync(recursive: true));

  /// Runs the script as the check does, with [path] as the `PATH`.
  ProcessResult run(String path) {
    final file = File('${temporary.path}\\${script.fileName}')
      ..writeAsStringSync(script.text);
    final result = Process.runSync(
      script.shell,
      [...script.arguments, file.path],
      environment: {'Path': path},
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    printOnFailure('${result.stdout}${result.stderr}');
    return result;
  }

  /// Runs `firebase --version` with the firebase command of [directory].
  ProcessResult firebaseVersion(String directory) => Process.runSync(
        '$directory\\firebase.cmd',
        ['--version'],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

  group(
    'the Windows script',
    () {
      final path = Platform.environment['PATH']!;

      test(
          'installs the Firebase CLI with npm, and prints its directory, '
          'where firebase runs', () {
        final result = run(path);

        expect(result.exitCode, 0);
        final directories = binDirsIn('${result.stdout}');
        expect(directories, isNotEmpty);
        expect(firebaseVersion(directories.first).exitCode, 0);
      });

      test('installs nothing when a firebase command runs', () {
        final installed = binDirsIn('${run(path).stdout}').first;

        final result = run('$installed;$path');

        expect(result.exitCode, 0);
        expect('${result.stdout}', isNot(contains('added')));
        expect(binDirsIn('${result.stdout}').first, installed);
        expect(notesIn('${result.stdout}'), isEmpty);
      });

      test(
          'installs the Firebase CLI over a firebase command that does not '
          'run, and prints the directory of the one that does', () {
        // Such as a Firebase CLI on a Node.js that is too old for it.
        final broken = Directory('${temporary.path}\\broken')..createSync();
        File('${broken.path}\\firebase.cmd').writeAsStringSync(
          '@echo off\r\n'
          'echo The Firebase CLI needs a newer Node.js. 1>&2\r\n'
          'exit /b 1\r\n',
        );

        final result = run('${broken.path};$path');

        expect(result.exitCode, 0);
        final directories = binDirsIn('${result.stdout}');
        expect(directories.first, isNot(broken.path));
        expect(firebaseVersion(directories.first).exitCode, 0);
      });
    },
    skip: enabled ? null : 'Set SMF_INSTALL_FIREBASE_CLI to 1 to run it.',
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
