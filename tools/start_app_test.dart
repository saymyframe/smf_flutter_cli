// Tests .github/scripts/start_app.sh, which builds an app with the start
// check as its entry, launches it on a device and reads the result that the
// check writes, in the jobs of CI that start the apps. On Android, with
// commands in place of flutter, adb and aapt2 of the Android SDK; the
// script handles the time and the result of the check on iOS the same way.
@TestOn('!windows')
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  late String script;
  late Directory temp;
  late String app;

  setUpAll(() {
    final top = Process.runSync('git', ['rev-parse', '--show-toplevel']);
    expect(top.exitCode, 0, reason: '${top.stderr}');
    script = '${'${top.stdout}'.trim()}/.github/scripts/start_app.sh';
  });

  setUp(() {
    temp = Directory(
      Directory.systemTemp
          .createTempSync('start_app_')
          .resolveSymbolicLinksSync(),
    );
    app = '${temp.path}/app';
    File('$app/integration_test/start_check.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('void main() {}\n');
  });
  tearDown(() => temp.deleteSync(recursive: true));

  /// A command at [path] in the temporary directory that runs [body] with
  /// sh.
  void command(String path, String body) {
    final file = File('${temp.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync('#!/bin/sh\n$body\n');
    Process.runSync('chmod', ['+x', file.path]);
  }

  /// Runs start_app.sh for the emulator with [seconds] in the directory of
  /// the app, with a build that takes [buildSeconds] and ends with
  /// [buildCode], and a start check that writes [result], or nothing.
  ProcessResult run({
    required int seconds,
    int buildSeconds = 0,
    int buildCode = 0,
    String? result,
  }) {
    command('bin/flutter', '''
sleep $buildSeconds
[ $buildCode -eq 0 ] || exit $buildCode
mkdir -p build/app/outputs/flutter-apk
: > build/app/outputs/flutter-apk/app-debug.apk''');
    command('sdk/build-tools/35.0.0/aapt2', '''
echo "package: name='com.example.app' versionCode='1'"
echo "launchable-activity: name='com.example.app.MainActivity'"''');
    // adb -s <device> <command>: the app runs, and its start check wrote
    // the result, if any, to the file that run-as reads.
    command('sdk/platform-tools/adb', '''
shift 2
case "\$1 \$2" in
  "shell pidof") echo 4242 ;;
  "shell run-as") cat "${temp.path}/result" 2> /dev/null || true ;;
  "logcat -d") echo "flutter: printed by the app" ;;
esac''');
    if (result != null) {
      File('${temp.path}/result').writeAsStringSync('$result\n');
    }
    return Process.runSync(
      'bash',
      [script, 'android', 'emulator-5554', '$seconds'],
      workingDirectory: app,
      environment: {
        'PATH': '${temp.path}/bin:${Platform.environment['PATH']}',
        'ANDROID_HOME': '${temp.path}/sdk',
      },
    );
  }

  test(
      'gives the seconds to the start of the app once it is built, however '
      'long the build takes', () {
    final result = run(seconds: 2, buildSeconds: 3, result: 'passed');

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(
      '${result.stdout}',
      matches(
        RegExp('The start check of the app passed [0-9]+ s after the app was '
            'launched'),
      ),
    );
  });

  test(
      'fails when the start check writes no result in the seconds after the '
      'build, and prints what the app printed', () {
    final result = run(seconds: 2, buildSeconds: 1);

    expect(result.exitCode, 1);
    expect(
      '${result.stdout}',
      allOf(
        contains('flutter: printed by the app'),
        matches(
          RegExp('::error::The start check of the app wrote no result in the '
              '2 s of the start of the app, [0-9]+ s of them after the app '
              r'was launched\.\n$'),
        ),
      ),
    );
  });

  test('fails with the problems that the start check found', () {
    final result = run(seconds: 30, result: 'failed: main() threw a bug');

    expect(result.exitCode, 1);
    expect(
      '${result.stdout}',
      endsWith('::error::The start check of the app failed: main() threw a '
          'bug\n'),
    );
  });

  test('fails when the build fails, before it launches the app', () {
    final result = run(seconds: 30, buildCode: 3, result: 'passed');

    expect(result.exitCode, 1);
    expect(
      '${result.stdout}',
      '::error::flutter build apk failed with the exit code 3.\n',
    );
  });
}
