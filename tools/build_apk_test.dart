// Tests .github/scripts/build_apk.sh, which builds an app with `flutter
// build apk` in the jobs of CI that build for Android, and builds it again
// when the build failed because a package of the Android SDK did not
// download: the Gradle plugin of Android downloads the NDK of Flutter in
// each such build, and a download that breaks off fails it. A command in
// place of flutter fails as such a build does, a number of times, and
// notes each call. The script waits between its attempts, which the tests
// stand in for with a sleep that only notes how long it would have taken.
@TestOn('!windows')
library;

import 'dart:io';

import 'package:test/test.dart';

/// What the SDK manager prints in a build of Gradle when a package that it
/// downloaded is an archive that it cannot open.
const _brokenDownload =
    'Warning: An error occurred while preparing SDK package NDK (Side by '
    'side) 28.2.13676358: Error on ZipFile unknown archive.';

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
  /// after them pass.
  ProcessResult run(
    List<String> arguments, {
    int failures = 0,
    String output = _brokenDownload,
    int code = 1,
  }) {
    final flutter = File('${temp.path}/bin/flutter')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
#!/bin/sh
echo "\$*" >> "${temp.path}/calls"
calls=\$(wc -l < "${temp.path}/calls" | tr -d " ")
echo "Running Gradle task 'assembleDebug'..."
if [ "\$calls" -le $failures ]; then
  echo '$output' >&2
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
