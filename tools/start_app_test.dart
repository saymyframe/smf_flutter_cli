// Tests .github/scripts/start_app.sh, which builds an app with the start
// check as its entry, launches it on a device and reads the result that the
// check writes, in the jobs of CI that start the apps. On Android, as a
// debug app and as a release app, with commands in place of flutter, adb
// and aapt2 of the Android SDK, and on macOS for an iOS simulator too, with
// a command in place of xcrun. The script builds the app with the arguments
// that the matrix tool writes next to the start check. With answers too:
// the script runs a command of CI for each request that the app writes once
// its start check passed, of the answers that the app asks for, and reads
// the verdict of the app on it.
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
    // The arguments that build the app, none here, which the matrix tool
    // writes next to the start check.
    File('$app/integration_test/start_build_arguments').writeAsStringSync('');
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
  /// [platform] `ios`, with [seconds] in the directory of the app, and with
  /// the build [mode] after them if it is given, with a build that takes
  /// [buildSeconds] by the clock of the script and ends with [buildCode],
  /// and a start check that writes [result], or nothing, to the file of the
  /// app and to the log of the device. The first [brokenDownloads] builds
  /// fail as one of Gradle does when a package of the Android SDK did not
  /// download. The command of the device that has the word [slow] takes
  /// [slowSeconds] by that clock. The emulator has the ABI [abi], and with
  /// [stopped] the app does not run once it is launched, as when it
  /// crashes at start-up. The app writes [files] into its temporary
  /// directory, by their names, once it is launched, where [stale] files of
  /// an earlier run are before that, and the [answers] go after the mode.
  /// The app asks for the answers [asked], those of [answers] by default, in
  /// the list of the answers next to its start check, unless it has no such
  /// list, [listsAnswers] `false`. Each sleep of the script stands for
  /// [sleepSeconds], so that a test of a wait of minutes polls the device a
  /// dozen times rather than hundreds.
  ProcessResult run({
    required int seconds,
    String platform = 'android',
    String? mode,
    int buildSeconds = 0,
    int buildCode = 0,
    int brokenDownloads = 0,
    String? slow,
    int slowSeconds = 0,
    String? result,
    String abi = 'x86_64',
    bool stopped = false,
    Map<String, String> files = const {},
    Map<String, String> stale = const {},
    List<String> answers = const [],
    List<String>? asked,
    bool listsAnswers = true,
    int sleepSeconds = 1,
  }) {
    if (listsAnswers) {
      final names = asked ?? [for (final given in answers) given.split('=')[0]];
      File('$app/integration_test/start_answers').writeAsStringSync(
        [for (final name in names) '$name\n'].join(),
      );
    }
    // Notes its arguments, one build on each line.
    command('bin/flutter', '''
echo "\$*" >> "${temp.path}/builds"
if [ "\$(wc -l < "${temp.path}/builds" | tr -d " ")" -le $brokenDownloads ]; then
  echo 'Warning: An error occurred while preparing SDK package NDK (Side by side) 28.2.13676358: Error on ZipFile unknown archive.'
  exit 1
fi
[ $buildCode -eq 0 ] || exit $buildCode
mkdir -p build/app/outputs/flutter-apk build/ios/iphonesimulator/Runner.app
: > build/app/outputs/flutter-apk/app-debug.apk
: > build/app/outputs/flutter-apk/app-release.apk
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
sleep() { SECONDS=\$((SECONDS + $sleepSeconds)); }
${slow == null ? '' : slowCommand(slow, slowSeconds)}''');
    command('sdk/build-tools/35.0.0/aapt2', '''
echo "package: name='com.example.app' versionCode='1'"
echo "launchable-activity: name='com.example.app.MainActivity'"''');
    // adb -s <device> <command>: the device installs the APK, pm clear
    // removes the data of the app, and the app runs as the process 4242,
    // but with [stopped]. Once launched, it writes its files, the result of
    // its start check among them, to its temporary directory, code_cache/
    // of its data, whose files run-as reads only for a debug app, and its
    // start check prints the result to the log of the device. The
    // log also has the line of the start check of an earlier run, of
    // another process, as the debug app that CI starts before the release
    // one leaves it there: `logcat --pid=` leaves the lines of the other
    // processes out.
    final deviceResult = '${temp.path}/device/code_cache/smf_start_check';
    command('sdk/platform-tools/adb', '''
shift 2
case "\$1 \$2" in
  "install -r") echo "\$3" > "${temp.path}/installed" ;;
  "shell getprop") echo $abi ;;
  "shell pidof") ${stopped ? ':' : 'echo 4242'} ;;
  "shell pm")
    rm -rf "${temp.path}/device/code_cache"
    mkdir -p "${temp.path}/device/code_cache"
    ;;
  "shell am")
    if [ "\$3" = start ]; then
      mkdir -p "${temp.path}/device/code_cache"
      cp -R "${temp.path}/written/." "${temp.path}/device/code_cache/" 2> /dev/null || true
    fi
    ;;
  "shell run-as")
    case "\$(cat "${temp.path}/installed")" in
      *release*)
        echo "run-as: package not debuggable: \$3" >&2
        exit 1
        ;;
    esac
    cat "${temp.path}/device/\$5"
    ;;
  "logcat -d")
    {
      echo "10-17 00:00:00.000  1111  1111 I flutter: SMF_START_CHECK: passed"
      echo "10-17 00:00:01.000  4242  4242 I flutter: printed by the app"
      if [ -f "$deviceResult" ]; then
        echo "10-17 00:00:02.000  4242  4242 I flutter: SMF_START_CHECK: \$(cat "$deviceResult")"
      fi
    } | case "\$3" in
      --pid=*) grep "  \${3#--pid=}  " ;;
      *) cat ;;
    esac
    ;;
esac''');
    // xcrun simctl <command>: the app runs as a process of the Mac, here
    // the one of the tests, and its start check wrote the result, if any,
    // to its temporary directory, tmp/ of the container of its data.
    command('bin/xcrun', '''
case "\$2" in
  get_app_container) echo "${temp.path}/data" ;;
  launch) echo "com.example.app: $pid" ;;
  spawn) echo "flutter: printed by the app" ;;
esac''');
    // What the app writes once it is launched: on Android when adb starts
    // it, and on an iOS simulator, whose install is a new one, already.
    for (final MapEntry(:key, :value) in {
      if (result != null) 'smf_start_check': result,
      ...files,
    }.entries) {
      for (final directory in ['written', 'data/tmp']) {
        File('${temp.path}/$directory/$key')
          ..createSync(recursive: true)
          ..writeAsStringSync('$value\n');
      }
    }
    for (final MapEntry(:key, :value) in stale.entries) {
      File('${temp.path}/device/code_cache/$key')
        ..createSync(recursive: true)
        ..writeAsStringSync('$value\n');
    }
    return Process.runSync(
      'bash',
      [
        script,
        platform,
        'emulator-5554',
        '$seconds',
        if (mode != null) mode,
        ...answers,
      ],
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
    expect(
      File('${temp.path}/builds').readAsLinesSync(),
      ['build apk --debug -t integration_test/start_check.dart'],
    );
    expect(
      File('${temp.path}/installed').readAsStringSync(),
      'build/app/outputs/flutter-apk/app-debug.apk\n',
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

  test(
      'builds the app for Android again when a package of the Android SDK '
      'did not download', () {
    final result = run(seconds: 30, brokenDownloads: 1, result: 'passed');

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(File('${temp.path}/builds').readAsLinesSync(), hasLength(2));
    expect(
      '${result.stdout}',
      allOf(
        contains(
          '::warning::A package of the Android SDK did not download in '
          'flutter build apk, attempt 1 of 3; trying again.\n',
        ),
        contains('The start check of the app passed '),
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

  group('with the arguments of the build', () {
    const check = 'integration_test/start_check.dart';
    // The arguments that give the build the values of the app, as the
    // matrix tool writes them from the provider of the values of the app.
    const arguments = ['--dart-define-from-file=.env', '--dart-define=A=b'];

    void writeArguments() =>
        File('$app/integration_test/start_build_arguments').writeAsStringSync(
          '${arguments.join('\n')}\n',
        );

    test(
        'builds a debug app and a release app for Android with the '
        'arguments that the matrix tool wrote next to the start check', () {
      writeArguments();

      final debug = run(seconds: 30, result: 'passed');
      final release = run(seconds: 30, mode: 'release', result: 'passed');

      expect(debug.exitCode, 0, reason: '${debug.stdout}${debug.stderr}');
      expect(
        release.exitCode,
        0,
        reason: '${release.stdout}${release.stderr}',
      );
      final given = arguments.join(' ');
      expect(File('${temp.path}/builds').readAsLinesSync(), [
        'build apk --debug -t $check $given',
        'build apk --release --target-platform android-x64 -t $check $given',
      ]);
    });

    test(
      'builds an app for an iOS simulator with them',
      () {
        writeArguments();

        final result = run(platform: 'ios', seconds: 30, result: 'passed');

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(
          File('${temp.path}/builds').readAsLinesSync(),
          ['build ios --simulator --debug -t $check ${arguments.join(' ')}'],
        );
      },
      testOn: 'mac-os',
    );

    test(
        'fails before the build when the app has no list of them, which the '
        'matrix tool adds with the start check', () {
      File('$app/integration_test/start_build_arguments').deleteSync();

      final result = run(seconds: 30, result: 'passed');

      expect(result.exitCode, 1);
      expect(
        '${result.stdout}',
        '::error::$app has no integration_test/start_build_arguments: add the '
            'start check with the --add-app-tests of '
            'packages/smf_flutter_cli/tool/matrix.dart.\n',
      );
      expect(File('${temp.path}/builds').existsSync(), isFalse);
    });
  });

  group('as a release app', () {
    const check = 'integration_test/start_check.dart';

    for (final (abi, target) in [
      ('x86_64', 'android-x64'),
      ('arm64-v8a', 'android-arm64'),
      ('armeabi-v7a', 'android-arm'),
    ]) {
      test(
          'builds it for the ABI $abi of the device only, and reads the '
          'result of its start check from the log of the device', () {
        final result =
            run(seconds: 240, mode: 'release', abi: abi, result: 'passed');

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(
          File('${temp.path}/builds').readAsLinesSync(),
          ['build apk --release --target-platform $target -t $check'],
        );
        expect(
          File('${temp.path}/installed').readAsStringSync(),
          'build/app/outputs/flutter-apk/app-release.apk\n',
        );
        expect(
          '${result.stdout}',
          contains('The start check of the app passed '),
          reason: 'run-as cannot read the files of a release app, which is '
              'not debuggable, so the result comes from the log.',
        );
      });
    }

    test('builds it again when a package of the Android SDK did not download',
        () {
      final result = run(
        seconds: 30,
        mode: 'release',
        brokenDownloads: 1,
        result: 'passed',
      );

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(
        File('${temp.path}/builds').readAsLinesSync(),
        List.filled(
          2,
          'build apk --release --target-platform android-x64 -t $check',
        ),
      );
      expect(
        '${result.stdout}',
        contains(
          '::warning::A package of the Android SDK did not download in '
          'flutter build apk, attempt 1 of 3; trying again.\n',
        ),
      );
    });

    test('fails with the problems that the start check printed', () {
      final result = run(
        seconds: 30,
        mode: 'release',
        result: 'failed: main() threw a bug',
      );

      expect(result.exitCode, 1);
      expect(
        '${result.stdout}',
        endsWith('::error::The start check of the app failed: main() threw a '
            'bug\n'),
      );
    });

    test(
        'does not take the line that the start check of an earlier run left '
        'in the log of the device for its result', () {
      final result = run(seconds: 60, mode: 'release');

      expect(result.exitCode, 1);
      expect(
        '${result.stdout}',
        matches(
          RegExp('::error::The start check of the app wrote no result in the '
              '60 s of the start of the app, [0-9]+ s of them after the app '
              r'was launched\.\n$'),
        ),
        reason: 'The log has `SMF_START_CHECK: passed` of another process.',
      );
    });

    test(
        'fails when the app stops before its start check printed a result, '
        'as when it crashes at start-up', () {
      final result = run(seconds: 60, mode: 'release', stopped: true);

      expect(result.exitCode, 1);
      expect(
        '${result.stdout}',
        allOf(
          contains('What the app printed:'),
          matches(
            RegExp('::error::The app stopped [0-9]+ s after it was launched, '
                r'before its start check wrote a result\.\n$'),
          ),
        ),
      );
    });

    test(
        'fails before the build on a device of an ABI that Flutter builds no '
        'release app for', () {
      final result =
          run(seconds: 30, mode: 'release', abi: 'x86', result: 'passed');

      expect(result.exitCode, 1);
      expect(
        '${result.stdout}',
        "::error::Flutter builds no release app for the ABI 'x86' of the "
            'device emulator-5554.\n',
      );
      expect(File('${temp.path}/builds').existsSync(), isFalse);
    });

    test('is not built for an iOS simulator, and no other mode is', () {
      final ios = run(platform: 'ios', seconds: 30, mode: 'release');
      final profile = run(seconds: 30, mode: 'profile');

      expect(ios.exitCode, 64);
      expect(
        '${ios.stderr}',
        'Flutter builds no release app for an iOS simulator: start it in '
            'debug.\n',
      );
      expect(profile.exitCode, 64);
      expect('${profile.stderr}', startsWith('Usage: '));
      expect(File('${temp.path}/builds').existsSync(), isFalse);
    });
  });

  group('with answers', () {
    const request = 'smf_start_request_messages';
    const report = 'smf_start_report_messages';
    // What the app asks for: what only the app and CI are to know, such as
    // the address of the device, which no line of the log may have.
    const asked = '{"address":"the-address-of-the-device"}';

    /// The answer [name], a command of the shell that notes the path, the
    /// text and the permissions of the request that it gets, the directory
    /// that it runs in, and that it ran, and then runs [then], such as one
    /// that writes the verdict of the app.
    String answer(String name, [String then = ':']) =>
        '$name=echo "\$SMF_START_REQUEST" >> "${temp.path}/$name.paths" && '
        'cat "\$SMF_START_REQUEST" >> "${temp.path}/$name.asked" && '
        'ls -l "\$SMF_START_REQUEST" | cut -c 1-10 >> "${temp.path}/$name.mode" && '
        'pwd -P >> "${temp.path}/$name.directory" && '
        'echo $name >> "${temp.path}/answered" && $then';

    /// A command that writes [verdict] into the file [name] of the
    /// temporary directory of the app on Android, as the app does once the
    /// answer reached it.
    String verdict(String name, String verdict) =>
        'echo "$verdict" > "${temp.path}/device/code_cache/$name"';

    /// The lines of the file [name] of the temporary directory of the test,
    /// or none if there is no such file.
    List<String> linesOf(String name) {
      final file = File('${temp.path}/$name');
      return file.existsSync() ? file.readAsLinesSync() : const [];
    }

    test(
        'runs the answer once the start check passed, once, with the request '
        'of the app in a file that it removes, and passes on the verdict of '
        'the app, without the request', () {
      final result = run(
        seconds: 240,
        result: 'passed',
        files: {request: asked},
        answers: [answer('messages', verdict(report, 'passed'))],
      );

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(linesOf('messages.asked'), [asked]);
      expect(linesOf('answered'), ['messages']);
      expect(
        linesOf('messages.mode'),
        ['-rw-------'],
        reason: 'Only the user of the script may read the copy of the '
            'request.',
      );
      expect(linesOf('messages.directory'), [app]);
      final paths = linesOf('messages.paths');
      expect(paths, hasLength(1));
      expect(
        File(paths.single).existsSync(),
        isFalse,
        reason: 'The request may have what only the app and CI are to know.',
      );
      expect(
        '${result.stdout}',
        allOf(
          matches(
            RegExp(
              r'The start check of the app passed .*\n'
              'The app asked for the answer messages [0-9]+ s after its '
              r'start check passed\.\n'
              r'The answer messages took [0-9]+ s\.\n'
              'The check of the answer messages in the app passed [0-9]+ s '
              r'after its start check passed\.\n',
            ),
          ),
          isNot(contains('the-address-of-the-device')),
        ),
      );
    });

    test('runs the answers one after another, after a debug mode', () {
      final result = run(
        seconds: 240,
        mode: 'debug',
        result: 'passed',
        files: {
          'smf_start_request_first': '{}',
          'smf_start_request_second': '{}',
        },
        answers: [
          answer('first', verdict('smf_start_report_first', 'passed')),
          answer('second', verdict('smf_start_report_second', 'passed')),
        ],
      );

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(linesOf('answered'), ['first', 'second']);
    });

    test(
        'fails with the verdict of the app on the answer, and prints what the '
        'app printed', () {
      final result = run(
        seconds: 240,
        result: 'passed',
        files: {request: asked},
        answers: [
          answer('messages', verdict(report, 'failed: no message came')),
        ],
      );

      expect(result.exitCode, 1);
      expect(
        '${result.stdout}',
        allOf(
          contains('What the app printed:'),
          endsWith('::error::The check of the answer messages in the app '
              'failed: no message came\n'),
        ),
      );
    });

    test(
        'fails when the answer fails, without waiting for the verdict, and '
        'removes the request', () {
      final result = run(
        seconds: 240,
        result: 'passed',
        files: {request: asked},
        answers: [answer('messages', 'exit 3')],
      );

      expect(result.exitCode, 1);
      expect(
        '${result.stdout}',
        allOf(
          contains('What the app printed:'),
          endsWith('::error::The answer messages failed with the exit code '
              '3.\n'),
        ),
      );
      expect(File(linesOf('messages.paths').single).existsSync(), isFalse);
    });

    test('gives the answer 300 s by the clock of the script, and no more', () {
      ProcessResult taking(int seconds) => run(
            seconds: 240,
            result: 'passed',
            files: {request: asked},
            answers: [answer('messages', verdict(report, 'passed'))],
            slow: 'env',
            slowSeconds: seconds,
          );
      final inTime = taking(299);
      final tooLong = taking(301);

      expect(inTime.exitCode, 0, reason: '${inTime.stdout}${inTime.stderr}');
      final took =
          RegExp(r'^The answer messages took ([0-9]+) s\.$', multiLine: true)
              .firstMatch('${inTime.stdout}');
      expect(took, isNotNull, reason: '${inTime.stdout}');
      expect(int.parse(took!.group(1)!), greaterThanOrEqualTo(299));
      expect(tooLong.exitCode, 1);
      expect(
        '${tooLong.stdout}',
        allOf(
          contains('What the app printed:'),
          endsWith('::error::The answer messages did not finish in 300 s.\n'),
        ),
      );
    });

    test(
        'takes no verdict that an earlier run left, which pm clear removes '
        'with the data of the app', () {
      final result = run(
        seconds: 240,
        result: 'passed',
        stale: {report: 'passed'},
        files: {request: asked},
        answers: [
          answer('messages', verdict(report, 'failed: no message came')),
        ],
      );

      expect(result.exitCode, 1);
      expect(
        '${result.stdout}',
        endsWith('::error::The check of the answer messages in the app '
            'failed: no message came\n'),
      );
      expect(linesOf('answered'), ['messages']);
    });

    test(
        'takes the verdict of an app that gives it without a request, and '
        'runs no answer then', () {
      final failed = run(
        seconds: 240,
        result: 'passed',
        files: {report: 'failed: the app got no address'},
        answers: [answer('messages')],
      );
      final passed = run(
        seconds: 240,
        result: 'passed',
        files: {report: 'passed'},
        answers: [answer('messages')],
      );

      expect(failed.exitCode, 1);
      expect(
        '${failed.stdout}',
        endsWith('::error::The check of the answer messages in the app '
            'failed: the app got no address\n'),
      );
      expect(passed.exitCode, 0, reason: '${passed.stdout}${passed.stderr}');
      expect(linesOf('answered'), isEmpty);
    });

    test(
        'fails when the app asks for no answer in the time that it has for '
        'that, and prints what the app printed', () {
      final result = run(
        seconds: 240,
        result: 'passed',
        answers: [answer('messages')],
        sleepSeconds: 10,
      );

      expect(result.exitCode, 1);
      expect(
        '${result.stdout}',
        allOf(
          contains('What the app printed:'),
          endsWith('::error::The app did not ask for the answer messages in '
              'the 150 s after its start check passed: a probe of its start '
              'check writes the request smf_start_request_messages into the '
              'temporary directory of the app.\n'),
        ),
      );
      expect(linesOf('answered'), isEmpty);
    });

    test(
        'runs the answer again when the app gives no verdict in its time '
        'after it, with the same request, and passes on the verdict that '
        'comes then', () {
      final result = run(
        seconds: 240,
        result: 'passed',
        files: {request: asked},
        answers: [
          answer(
            'messages',
            '[ "\$(wc -l < "${temp.path}/answered" | tr -d " ")" -lt 2 ] || '
                '${verdict(report, 'passed')}',
          ),
        ],
        sleepSeconds: 10,
      );

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(linesOf('answered'), ['messages', 'messages']);
      expect(linesOf('messages.asked'), [asked, asked]);
      for (final path in linesOf('messages.paths')) {
        expect(File(path).existsSync(), isFalse, reason: path);
      }
      expect(
        '${result.stdout}',
        allOf(
          contains(
            '::warning::The app gave no verdict on the answer messages in the '
            '150 s after the answer, attempt 1 of 3; running the answer '
            'again, since what it sent may not have reached the app.\n',
          ),
          isNot(contains('attempt 2 of 3')),
          matches(
            RegExp(
              'The check of the answer messages in the app passed [0-9]+ s '
              r'after its start check passed\.\n',
            ),
          ),
        ),
      );
    });

    test(
        'fails when the app gives no verdict in its time after each of three '
        'answers', () {
      final result = run(
        seconds: 240,
        result: 'passed',
        files: {request: asked},
        answers: [answer('messages')],
        sleepSeconds: 10,
      );

      expect(result.exitCode, 1);
      expect(linesOf('answered'), ['messages', 'messages', 'messages']);
      expect(
        '${result.stdout}',
        allOf(
          contains('attempt 1 of 3; running the answer again'),
          contains('attempt 2 of 3; running the answer again'),
          isNot(contains('attempt 3 of 3')),
          endsWith('::error::The app wrote no verdict on the answer messages '
              'in the 150 s after each of the 3 answers: its check of the '
              'answer writes smf_start_report_messages into the temporary '
              'directory of the app.\n'),
        ),
      );
    });

    test(
        'fails when the app stops before it asks for the answer, or before it '
        'gives its verdict', () {
      final beforeRequest = run(
        seconds: 240,
        result: 'passed',
        answers: [answer('messages')],
        stopped: true,
      );
      final beforeVerdict = run(
        seconds: 240,
        result: 'passed',
        files: {request: asked},
        answers: [answer('messages')],
        stopped: true,
      );

      expect(beforeRequest.exitCode, 1);
      expect(
        '${beforeRequest.stdout}',
        matches(
          RegExp('::error::The app stopped [0-9]+ s after its start check '
              r'passed, before it asked for the answer messages\.\n$'),
        ),
      );
      expect(beforeVerdict.exitCode, 1);
      expect(
        '${beforeVerdict.stdout}',
        allOf(
          contains('What the app printed:'),
          matches(
            RegExp('::error::The app stopped [0-9]+ s after the answer '
                r'messages began, before it gave its verdict on it\.\n$'),
          ),
        ),
      );
    });

    test(
        'runs only the answers that the app asks for, and skips each other '
        'with a notice', () {
      final result = run(
        seconds: 240,
        result: 'passed',
        files: {'smf_start_request_second': '{}'},
        answers: [
          answer('first', verdict('smf_start_report_first', 'passed')),
          answer('second', verdict('smf_start_report_second', 'passed')),
          answer('third', verdict('smf_start_report_third', 'passed')),
        ],
        asked: ['second', 'fourth'],
      );
      final none = run(
        seconds: 240,
        result: 'passed',
        answers: [answer('first')],
        asked: [],
      );

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(none.exitCode, 0, reason: '${none.stdout}${none.stderr}');
      expect(linesOf('answered'), ['second']);
      expect(
        '${result.stdout}',
        allOf(
          contains(
            '::notice::The app asks for no answer first: no probe of it lists '
            'it in integration_test/start_answers, so the script skips it.\n',
          ),
          contains(
            '::notice::The app asks for no answer third: no probe of it lists '
            'it in integration_test/start_answers, so the script skips it.\n',
          ),
          contains('The check of the answer second in the app passed '),
          isNot(contains('answer fourth')),
        ),
      );
      expect(
        '${none.stdout}',
        allOf(
          contains('::notice::The app asks for no answer first: '),
          contains('The start check of the app passed '),
        ),
      );
    });

    test(
        'fails before the build when the app has no list of the answers that '
        'it asks for, which the matrix tool adds with the start check', () {
      final result = run(
        seconds: 240,
        result: 'passed',
        files: {request: asked},
        answers: [answer('messages', verdict(report, 'passed'))],
        listsAnswers: false,
      );
      final without = run(seconds: 30, result: 'passed', listsAnswers: false);

      expect(result.exitCode, 1);
      expect(
        '${result.stdout}',
        '::error::$app has no integration_test/start_answers, which lists the '
            'answers that the probes of the app ask for: add the start check '
            'with the --add-app-tests of '
            'packages/smf_flutter_cli/tool/matrix.dart.\n',
      );
      expect(linesOf('answered'), isEmpty);
      expect(
        without.exitCode,
        0,
        reason: 'Without answers, the script needs no list of them: '
            '${without.stdout}${without.stderr}',
      );
      expect(File('${temp.path}/builds').readAsLinesSync(), hasLength(1));
    });

    test(
        'takes answers for a debug app only, each with a name of small '
        'letters, digits and underscores, a command and a name of its own', () {
      final release = run(
        seconds: 30,
        mode: 'release',
        answers: [answer('messages')],
      );

      expect(release.exitCode, 64);
      expect(
        '${release.stderr}',
        'The script cannot read the files of a release app, so it answers '
            'no request of one: start it in debug.\n',
      );
      for (final answers in [
        ['=echo'],
        ['messages='],
        ['Messages=echo'],
        ['messages'],
        ['messages=echo', 'messages=echo'],
      ]) {
        final refused = run(seconds: 30, answers: answers);

        expect(refused.exitCode, 64, reason: '$answers');
        expect('${refused.stderr}', startsWith('Usage: '), reason: '$answers');
      }
      expect(File('${temp.path}/builds').existsSync(), isFalse);
    });

    test(
      'runs an answer on an iOS simulator, with the request from the '
      'temporary directory of the app',
      () {
        final result = run(
          platform: 'ios',
          seconds: 240,
          result: 'passed',
          files: {request: asked},
          answers: [
            answer(
              'messages',
              'echo passed > "${temp.path}/data/tmp/$report"',
            ),
          ],
        );

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(linesOf('messages.asked'), [asked]);
        expect(
          '${result.stdout}',
          contains('The check of the answer messages in the app passed '),
        );
      },
      testOn: 'mac-os',
    );
  });
}
