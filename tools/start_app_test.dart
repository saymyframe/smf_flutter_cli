// Tests .github/scripts/start_app.sh, which builds an app with the start
// check as its entry, launches it on a device and reads the result that the
// check writes, in the jobs of CI that start the apps. On Android, with
// commands in place of flutter, adb and aapt2 of the Android SDK, and on
// macOS for an iOS simulator too, with a command in place of xcrun.
//
// No test waits for the time to pass. The script tells the time by SECONDS
// of bash, which the tests move on by the seconds that the build, a command
// of the device and each sleep of the script stand for. So the start gets
// minutes after a build of an hour, far more than the dozen processes that
// the script starts before it launches the app take on a busy machine,
// where seconds that pass for real would make the tests either slow or
// flaky.
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

  /// The clock of a command of the device with the word [word]. The script
  /// limits such a command with perl, which gets the limit in seconds and
  /// then the command: as a function of the shell of the script, perl moves
  /// SECONDS on by [seconds], or by the limit when that is less, and then
  /// ends as the command that ran out of its time does, with 142.
  String slowCommand(String word, int seconds) => '''
perl() {
  case " \$* " in
    *" $word "*)
      if [ "\$3" -lt $seconds ]; then
        SECONDS=\$((SECONDS + \$3))
        return 142
      fi
      SECONDS=\$((SECONDS + $seconds))
      ;;
  esac
  command perl "\$@"
}
''';

  /// Runs start_app.sh for the emulator, or for a simulator with the
  /// [platform] `ios`, with [seconds] in the directory of the app, with a
  /// build that takes [buildSeconds] by the clock of the script and ends
  /// with [buildCode], and a start check that writes [result], or nothing.
  /// The command of the device that has the word [slow] takes [slowSeconds]
  /// by that clock.
  ProcessResult run({
    required int seconds,
    String platform = 'android',
    int buildSeconds = 0,
    int buildCode = 0,
    String? slow,
    int slowSeconds = 0,
    String? result,
  }) {
    command('bin/flutter', '''
[ $buildCode -eq 0 ] || exit $buildCode
mkdir -p build/app/outputs/flutter-apk build/ios/iphonesimulator/Runner.app
: > build/app/outputs/flutter-apk/app-debug.apk
cat > build/ios/iphonesimulator/Runner.app/Info.plist << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.example.app</string>
<key>CFBundleExecutable</key><string>Runner</string>
</dict></plist>
PLIST''');
    // The clock: flutter and sleep as functions of the shell of the script,
    // which bash reads from the file of BASH_ENV before the script, since
    // only that shell can set its SECONDS. A build that the script ran in
    // another process would take no time here, which the first test fails
    // on.
    File('${temp.path}/clock.sh').writeAsStringSync('''
flutter() {
  SECONDS=\$((SECONDS + $buildSeconds))
  command flutter "\$@"
}
sleep() { SECONDS=\$((SECONDS + \$1)); }
${slow == null ? '' : slowCommand(slow, slowSeconds)}''');
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
    // xcrun simctl <command>: the app runs as a process of the Mac, here
    // the one of the tests, and its start check wrote the result, if any,
    // to tmp/ of the container of its data.
    command('bin/xcrun', '''
case "\$2" in
  get_app_container) echo "${temp.path}/data" ;;
  launch) echo "com.example.app: $pid" ;;
  spawn) echo "flutter: printed by the app" ;;
esac''');
    if (result != null) {
      File('${temp.path}/result').writeAsStringSync('$result\n');
      File('${temp.path}/data/tmp/smf_start_check')
        ..createSync(recursive: true)
        ..writeAsStringSync('$result\n');
    }
    return Process.runSync(
      'bash',
      [script, platform, 'emulator-5554', '$seconds'],
      workingDirectory: app,
      environment: {
        'PATH': '${temp.path}/bin:${Platform.environment['PATH']}',
        'BASH_ENV': '${temp.path}/clock.sh',
        'ANDROID_HOME': '${temp.path}/sdk',
      },
    );
  }

  test(
      'gives the seconds to the start of the app once it is built, however '
      'long the build takes', () {
    final result = run(seconds: 240, buildSeconds: 3600, result: 'passed');

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    final passed = RegExp('The start check of the app passed [0-9]+ s after '
            r'the app was launched, ([0-9]+) s after the script started\.\n')
        .firstMatch('${result.stdout}');
    expect(passed, isNotNull, reason: '${result.stdout}');
    expect(
      int.parse(passed!.group(1)!),
      greaterThanOrEqualTo(3600),
      reason: 'The build takes an hour by SECONDS, the clock of the script.',
    );
  });

  test(
      'fails when the start check writes no result in the seconds after the '
      'build, and prints what the app printed', () {
    final result = run(seconds: 60, buildSeconds: 3600);

    expect(result.exitCode, 1);
    expect(
      '${result.stdout}',
      allOf(
        contains('flutter: printed by the app'),
        matches(
          RegExp('::error::The start check of the app wrote no result in the '
              '60 s of the start of the app, [0-9]+ s of them after the app '
              r'was launched\.\n$'),
        ),
      ),
    );
  });

  test('does not count the install of the app in the seconds of its start', () {
    final result =
        run(seconds: 30, slow: 'install', slowSeconds: 60, result: 'passed');

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    final took = RegExp(r'^adb install took ([0-9]+) s\.$', multiLine: true)
        .firstMatch('${result.stdout}');
    expect(took, isNotNull, reason: '${result.stdout}');
    expect(
      int.parse(took!.group(1)!),
      greaterThanOrEqualTo(60),
      reason: 'The install takes a minute by SECONDS, the clock of the script, '
          'twice the seconds of the start.',
    );
  });

  test(
      'fails when the device does not install the app in the time that it '
      'has for that', () {
    final result =
        run(seconds: 30, slow: 'install', slowSeconds: 3600, result: 'passed');

    expect(result.exitCode, 1);
    expect(
      '${result.stdout}',
      matches(
        RegExp('^Starting .*\n::error::adb install did not finish in the '
            r'[0-9]+ s that the device has to install the app\.\n$'),
      ),
    );
  });

  test(
      'fails when the device does not launch the app in the seconds of its '
      'start', () {
    final result =
        run(seconds: 30, slow: 'start', slowSeconds: 3600, result: 'passed');

    expect(result.exitCode, 1);
    expect(
      '${result.stdout}',
      endsWith('::error::adb shell am start did not finish in the 30 s of the '
          'start of the app.\n'),
    );
  });

  test(
    'does not count the install of the app on an iOS simulator in the '
    'seconds of its start',
    () {
      final result = run(
        platform: 'ios',
        seconds: 240,
        slow: 'install',
        slowSeconds: 300,
        result: 'passed',
      );

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      final took =
          RegExp(r'^xcrun simctl install took ([0-9]+) s\.$', multiLine: true)
              .firstMatch('${result.stdout}');
      expect(took, isNotNull, reason: '${result.stdout}');
      expect(
        int.parse(took!.group(1)!),
        greaterThanOrEqualTo(300),
        reason: 'The install takes 5 minutes by SECONDS, the clock of the '
            'script, more than the seconds of the start.',
      );
      expect(
        '${result.stdout}',
        allOf(
          contains('xcrun simctl terminate took '),
          contains('xcrun simctl uninstall took '),
          contains('The start check of the app passed '),
        ),
      );
    },
    testOn: 'mac-os',
  );

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
