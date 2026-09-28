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

  /// Runs the script as the check does, with [path] as the `PATH` and the
  /// variables of [environment], and reads its output as the check does.
  ProcessResult run(
    String path, [
    Map<String, String> environment = const {},
  ]) {
    final file = File('${temporary.path}\\${script.fileName}')
      ..writeAsStringSync(script.text);
    final result = Process.runSync(
      script.shell,
      [...script.arguments, file.path],
      environment: {'Path': path, ...environment},
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    printOnFailure('${result.stdout}${result.stderr}');
    return result;
  }

  /// [directory] with links resolved: Windows may name a directory by its
  /// short name, such as `RUNNER~1`, which the script does not print.
  String resolved(String directory) =>
      Directory(directory).resolveSymbolicLinksSync();

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
          'installs the Firebase CLI with npm over a firebase command that '
          'does not run, prints the directory of the one that does, whatever '
          'letters its name has, and installs nothing once it runs', () {
        // Such as a Firebase CLI on a Node.js that is too old for it.
        final broken = Directory('${temporary.path}\\broken')..createSync();
        File('${broken.path}\\firebase.cmd').writeAsStringSync(
          '@echo off\r\n'
          'echo The Firebase CLI needs a newer Node.js. 1>&2\r\n'
          'exit /b 1\r\n',
        );
        // The global directory of npm is in the profile of the user, whose
        // name may have any letters.
        final prefix = '${temporary.path}\\npm – Євген é';
        final npm = {'npm_config_prefix': prefix};

        final installed = run('${broken.path};$path', npm);

        expect(installed.exitCode, 0);
        final directory = binDirsIn('${installed.stdout}').first;
        expect(resolved(directory), resolved(prefix));
        expect(
          notesIn('${installed.stdout}'),
          contains('Added $prefix to the PATH of the user, for new terminals.'),
        );
        expect(firebaseVersion(prefix).exitCode, 0);

        final again = run('$prefix;$path', npm);

        expect(again.exitCode, 0);
        expect('${again.stdout}', isNot(contains('added')));
        expect(resolved(binDirsIn('${again.stdout}').first), resolved(prefix));
        expect(notesIn('${again.stdout}'), isEmpty);
      });
    },
    skip: enabled ? null : 'Set SMF_INSTALL_FIREBASE_CLI to 1 to run it.',
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
