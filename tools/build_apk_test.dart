// Tests .github/scripts/build_apk.sh, which builds an app with `flutter
// build apk` in the jobs of CI that build for Android, and builds it again
// when the build failed because a package of the Android SDK did not
// download: the Gradle plugin of Android downloads the NDK of Flutter in
// each such build, and a download that breaks off fails it. A command in
// place of flutter fails as such a build does, a number of times, and
// notes each call. The script waits between its attempts, which the tests
// stand in for with a sleep that only notes how long it would have taken.
// The SDK of the app is a directory of the test, which the command in place
// of flutter changes as the Gradle plugin of Android does.
@TestOn('!windows')
library;

import 'dart:io';

import 'package:test/test.dart';

/// What the SDK manager prints in a build of Gradle when a package that it
/// downloaded is an archive that it cannot open.
const _brokenDownload =
    'Warning: An error occurred while preparing SDK package NDK (Side by '
    'side) 28.2.13676358: Error on ZipFile unknown archive.';

/// What a build of Gradle prints when the Gradle plugin of Android could
/// not install the NDK of Flutter because its download broke off, as it did
/// in a nightly run with Flutter 3.44.3.
const _brokenNdk = '''
Warning: An error occurred while preparing SDK package NDK (Side by side) 28.2.13676358: Error reading Zip content from a SeekableByteChannel.:
java.io.IOException: Error reading Zip content from a SeekableByteChannel
\tat com.android.repository.util.InstallerUtil.unzip(InstallerUtil.java:101)
"Install NDK (Side by side) 28.2.13676358 v.28.2.13676358" failed.

FAILURE: Build failed with an exception.

* What went wrong:
A problem occurred configuring project ':app'.
> com.android.builder.sdk.InstallFailedException: Failed to install the following SDK components:
      ndk;28.2.13676358 NDK (Side by side) 28.2.13676358
  Install the missing components using the SDK manager in Android Studio.
''';

void main() {
  late String script;
  late Directory temp;

  setUpAll(() {
    final top = Process.runSync('git', ['rev-parse', '--show-toplevel']);
    expect(top.exitCode, 0, reason: '${top.stderr}');
    script = '${'${top.stdout}'.trim()}/.github/scripts/build_apk.sh';
  });

  setUp(
    () => temp = Directory(
      Directory.systemTemp
          .createTempSync('build_apk_')
          .resolveSymbolicLinksSync(),
    ),
  );
  tearDown(() => temp.deleteSync(recursive: true));

  /// Runs build_apk.sh with [arguments], with a flutter whose first
  /// [failures] builds print [output] and end with [code], and whose builds
  /// after them pass. With [leavesNdk], each of those builds leaves the
  /// directory of the NDK of Flutter in the SDK of the app without the NDK,
  /// as a download that breaks off does, and a build fails at once while
  /// that directory has no NDK, as the Gradle plugin of Android does.
  ProcessResult run(
    List<String> arguments, {
    int failures = 0,
    String output = _brokenDownload,
    int code = 1,
    bool leavesNdk = false,
  }) {
    File('${temp.path}/output').writeAsStringSync('$output\n');
    final ndk = '${temp.path}/sdk/ndk/28.2.13676358';
    final flutter = File('${temp.path}/bin/flutter')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
#!/bin/sh
echo "\$*" >> "${temp.path}/calls"
calls=\$(wc -l < "${temp.path}/calls" | tr -d " ")
echo "Running Gradle task 'assembleDebug'..."
if [ -d '$ndk' ] && [ ! -f '$ndk/source.properties' ]; then
  echo '[CXX1101] NDK at $ndk did not have a source.properties file' >&2
  echo 'BUILD FAILED in 1s'
  exit 1
fi
if [ "\$calls" -le $failures ]; then
  if $leavesNdk; then
    mkdir -p '$ndk/.installer'
  fi
  cat '${temp.path}/output' >&2
  echo 'BUILD FAILED in 1m 31s'
  exit $code
fi
echo 'Built build/app/outputs/flutter-apk/app-debug.apk'
''');
    Process.runSync('chmod', ['+x', flutter.path]);
    File(
      '${temp.path}/clock.sh',
    ).writeAsStringSync('sleep() { echo "\$1" >> "${temp.path}/sleeps"; }\n');
    return Process.runSync(
      'bash',
      [script, ...arguments],
      workingDirectory: temp.path,
      environment: {
        'PATH': '${temp.path}/bin:${Platform.environment['PATH']}',
        'BASH_ENV': '${temp.path}/clock.sh',
      },
    );
  }

  /// The arguments of each call of flutter.
  List<String> calls() {
    final file = File('${temp.path}/calls');
    return file.existsSync() ? file.readAsLinesSync() : const [];
  }

  /// The seconds of each wait of the script.
  List<String> sleeps() {
    final file = File('${temp.path}/sleeps');
    return file.existsSync() ? file.readAsLinesSync() : const [];
  }

  test('builds the app once when the build passes', () {
    final result = run(['--debug', '-t', 'integration_test/start_check.dart']);

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(calls(), [
      'build apk --debug -t integration_test/start_check.dart',
    ]);
    expect(
      '${result.stdout}',
      contains('Built build/app/outputs/flutter-apk/app-debug.apk\n'),
    );
    expect(sleeps(), isEmpty);
  });

  test(
      'builds the app again when a package of the Android SDK did not '
      'download, and prints the output of each build', () {
    final result = run(['--debug'], failures: 2);

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(calls(), [
      'build apk --debug',
      'build apk --debug',
      'build apk --debug',
    ]);
    expect(sleeps(), ['15', '15']);
    final stdout = '${result.stdout}';
    expect(
      RegExp(RegExp.escape(_brokenDownload)).allMatches(stdout),
      hasLength(2),
    );
    expect(
      stdout,
      allOf(
        contains(
          '::warning::A package of the Android SDK did not download in '
          'flutter build apk, attempt 1 of 3; trying again.\n',
        ),
        contains('attempt 2 of 3; trying again.\n'),
        endsWith('Built build/app/outputs/flutter-apk/app-debug.apk\n'),
      ),
    );
  });

  test(
      'fails with the exit code of the build once three builds did not '
      'download a package of the Android SDK', () {
    final result = run(['--debug'], failures: 3, code: 3);

    expect(result.exitCode, 3);
    expect(calls(), hasLength(3));
    expect(sleeps(), ['15', '15']);
    expect('${result.stdout}', endsWith('BUILD FAILED in 1m 31s\n'));
  });

  test(
      'removes what a download that broke off left of a package of the '
      'Android SDK before it builds the app again', () {
    File('${temp.path}/android/local.properties')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        'sdk.dir=${temp.path}/sdk\nflutter.sdk=${temp.path}/flutter\n',
      );
    final installed =
        File('${temp.path}/sdk/ndk/27.0.12077973/source.properties')
          ..createSync(recursive: true);
    final platform = File('${temp.path}/sdk/platforms/android-35/android.jar')
      ..createSync(recursive: true);

    final result = run(
      ['--debug'],
      failures: 1,
      output: _brokenNdk,
      leavesNdk: true,
    );

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(calls(), ['build apk --debug', 'build apk --debug']);
    expect(
      Directory('${temp.path}/sdk/ndk/28.2.13676358').existsSync(),
      isFalse,
    );
    expect(installed.existsSync(), isTrue);
    expect(platform.existsSync(), isTrue);
    expect(
      '${result.stdout}',
      contains(
        'Removing ${temp.path}/sdk/ndk/28.2.13676358, which the SDK manager '
        'left without the package ndk;28.2.13676358.\n',
      ),
    );
  });

  test('fails at once on any other failure of the build', () {
    final result = run(
      ['--debug'],
      failures: 1,
      output: 'lib/main.dart:3:1: Error: Expected a semicolon.',
      code: 2,
    );

    expect(result.exitCode, 2);
    expect(calls(), hasLength(1));
    expect(sleeps(), isEmpty);
    expect('${result.stdout}', isNot(contains('::warning::')));
  });
}
