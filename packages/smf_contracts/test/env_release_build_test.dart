// flutter build apk --release of a generated app with keys in .env: without
// the arguments of the flutter tool that give the app the values of .env, the
// build stops with the text of the env role, and with them it builds. The
// stop holds only while the compiler of a release build of Flutter evaluates
// the constant of the check of the role, which no test with the Dart SDK alone
// shows for a release of Flutter, so CI runs this test with each. It needs
// Flutter and the Android SDK, so it runs only with an app in SMF_RELEASE_APP,
// with the tool arguments of the app in SMF_TOOL_ARGUMENTS, one on each line,
// as CI gives them with .github/scripts/each_app.sh --env SMF_RELEASE_APP
// --tool-arguments from the file that its matrix tool writes next to the app.
// It builds for x86_64 alone.
//
// A command gives the app the values that .env has when it runs. So the
// build with the tool arguments gives every key of .env a value of the test,
// which the libapp.so of the APK must have. Then the same app is built once
// more with another value, as a developer does after an edit of .env, and
// the libapp.so of the APK must have the new value and not the one of the
// build before. Flutter 3.44.0 to 3.44.4 put the libapp.so of the release
// build before into the APK of an app with flavors, as every SMF app is, and
// a job of CI may have built the app as a release before the test, so the
// test of the values skips with them. The test puts .env back when it ends.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'dart_files.dart';

/// The arguments in [given], one on each line, without the empty lines.
List<String> _argumentsOf(String? given) => [
      for (final line in const LineSplitter().convert(given ?? ''))
        if (line.isNotEmpty) line,
    ];

/// Builds the app at [app] as a release for x86_64: with the arguments of
/// the flutter tool that give the app its values, which CI gives the test in
/// SMF_TOOL_ARGUMENTS, when [withToolArguments], and without them otherwise.
Future<ProcessResult> _releaseBuild(
  String app, {
  required bool withToolArguments,
}) =>
    Process.run(
      'flutter',
      [
        'build',
        'apk',
        '--release',
        '--target-platform',
        'android-x64',
        ...(withToolArguments
            ? _argumentsOf(Platform.environment['SMF_TOOL_ARGUMENTS'])
            : const <String>[]),
      ],
      workingDirectory: app,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );

/// A line of a key in `.env.example`.
final _keyLine = RegExp(r'^[A-Za-z_]\w*=', multiLine: true);

/// A line of a key in `.env`, with the key in its first group.
final _keyWithValue = RegExp(r'^([A-Za-z_]\w*)=.*$', multiLine: true);

/// [env], the text of a `.env`, with [value] as the value of each key.
String _withValue(String env, String value) =>
    env.replaceAllMapped(_keyWithValue, (line) => '${line[1]}=$value');

/// The version of the Flutter on the `PATH`, such as `3.44.9`, as
/// `flutter --version --machine` reports it, or `null` if it cannot tell.
String? _flutterVersion() {
  try {
    final result = Process.runSync(
      'flutter',
      ['--version', '--machine'],
      stdoutEncoding: utf8,
    );
    if (result.exitCode != 0) return null;
    // Flutter may print more around the JSON, such as the notice about
    // analytics that follows it on the first run.
    final output = result.stdout as String;
    final start = output.indexOf('{');
    final end = output.lastIndexOf('}');
    if (start < 0 || end < start) return null;
    final json = jsonDecode(output.substring(start, end + 1));
    return json is Map<String, Object?> && json['frameworkVersion'] is String
        ? json['frameworkVersion']! as String
        : null;
  } on Object {
    return null;
  }
}

/// Whether Flutter [version] puts the libapp.so of the release build before
/// into the APK of a second release build of an app with flavors: 3.44.0 to
/// 3.44.4 do, and their pre-releases.
bool _shipsLibappOfBuildBefore(String? version) =>
    RegExp(r'^3\.44\.[0-4](?:[-+].*)?$').hasMatch(version ?? '');

/// Why the second build skips with Flutter [version].
String _libappOfBuildBefore(String? version) =>
    'Flutter $version puts the libapp.so of the release build before into '
    'the APK of a second release build of an app with flavors '
    '(flutter/flutter#187388), which Flutter 3.44.5 fixed '
    '(flutter/flutter#188516).';

/// Whether the libapp.so of the release APK that the last build of the app
/// at [app] made for x86_64 has each of [values], as a text of the app that
/// the compiler kept, such as a value of `.env`. A map rather than the file,
/// so that a failure does not print the megabytes of the file.
Future<Map<String, bool>> _valuesInLibapp(
  String app,
  List<String> values,
) async {
  final outputs = Directory('$app/build/app/outputs/flutter-apk');
  final apks = [
    if (outputs.existsSync())
      for (final file in outputs.listSync().whereType<File>())
        if (RegExp(r'^app.*-release\.apk$')
            .hasMatch(file.uri.pathSegments.last))
          file.path,
  ];
  expect(apks, hasLength(1), reason: 'The release APKs in ${outputs.path}');
  final unzipped = await Process.run(
    'unzip',
    ['-p', apks.single, 'lib/x86_64/libapp.so'],
    stdoutEncoding: null,
    stderrEncoding: utf8,
  );
  expect(
    unzipped.exitCode,
    0,
    reason: '${apks.single} has no lib/x86_64/libapp.so: ${unzipped.stderr}',
  );
  // Each byte a character, so that a text of one-byte characters is a part
  // of the file as the compiler wrote it.
  final libapp = latin1.decode(unzipped.stdout as List<int>);
  return {for (final value in values) value: libapp.contains(value)};
}

void main() {
  final app = Platform.environment['SMF_RELEASE_APP'];
  final flutterVersion = app == null ? null : _flutterVersion();
  const needsApp = 'Needs an app with keys of the env role in '
      'SMF_RELEASE_APP, and Flutter with the Android SDK.';

  // The values of the two builds with the tool arguments, which no build of
  // an earlier run of the test has.
  final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final first = 'smf-first-build-$stamp';
  final second = 'smf-second-build-$stamp';
  final env = File('$app/${EnvRole.dotEnvFile}');
  String? envBefore;
  tearDownAll(() {
    if (envBefore case final text?) env.writeAsStringSync(text);
  });

  test('the tool arguments are the lines of the variable, but the empty ones',
      () {
    expect(
      _argumentsOf('--dart-define-from-file=.env\n\ntwo words\n'),
      ['--dart-define-from-file=.env', 'two words'],
    );
    expect(_argumentsOf(''), isEmpty);
    expect(_argumentsOf(null), isEmpty);
  });

  test('a value goes into every line of a key of .env, and nowhere else', () {
    expect(
      _withValue('# A comment=no\nONE=\n\nTWO="a b" # c\nthree_3=x\n', 'v'),
      '# A comment=no\nONE=v\n\nTWO=v\nthree_3=v\n',
    );
  });

  test('only Flutter 3.44.0 to 3.44.4 ship the libapp.so of the build before',
      () {
    for (final version in ['3.44.0', '3.44.2', '3.44.4', '3.44.0-0.1.pre']) {
      expect(_shipsLibappOfBuildBefore(version), isTrue, reason: version);
    }
    for (final version in [
      '3.44.5',
      '3.44.9',
      '3.44.10',
      '3.47.0',
      '3.50.0',
      '3.4.4',
      '13.44.2',
      '',
      null,
    ]) {
      expect(_shipsLibappOfBuildBefore(version), isFalse, reason: version);
    }
    expect(
      _libappOfBuildBefore('3.44.2'),
      allOf(contains('Flutter 3.44.2 '), contains('3.44.5'), contains('#')),
    );
  });

  test(
    'a release build of an app with keys stops without the tool arguments of '
    'the env role, with the text of the role, and builds with them',
    () async {
      final example = File('$app/${EnvRole.exampleFile}');
      expect(
        example.existsSync() && _keyLine.hasMatch(example.readAsStringSync()),
        isTrue,
        reason: 'SMF_RELEASE_APP names an app without a key in '
            '${EnvRole.exampleFile}, whose release build needs no values.',
      );
      final toolArguments =
          _argumentsOf(Platform.environment['SMF_TOOL_ARGUMENTS']);
      expect(
        toolArguments,
        isNotEmpty,
        reason: 'SMF_TOOL_ARGUMENTS gives none of the arguments of the '
            'flutter tool that give the app its values, so a build with them '
            'would be the build without them.',
      );

      final without = await _releaseBuild(app!, withToolArguments: false);
      final printed = '${without.stdout}${without.stderr}';
      expect(
        without.exitCode,
        isNot(0),
        reason: 'A release build without $toolArguments built: $printed',
      );
      expect(
        printed,
        contains(compilerQuoteOf(EnvRole.releaseErrorOf(toolArguments))),
      );

      // With a value of the test in every key, which the test after this one
      // looks for in the APK and then changes.
      expect(
        env.existsSync(),
        isTrue,
        reason: 'The app has no ${EnvRole.dotEnvFile}.',
      );
      envBefore = env.readAsStringSync();
      env.writeAsStringSync(_withValue(envBefore!, first));
      final built = await _releaseBuild(app, withToolArguments: true);
      expect(
        built.exitCode,
        0,
        reason: 'A release build with $toolArguments failed: '
            '${built.stdout}${built.stderr}',
      );
    },
    skip: app == null ? needsApp : null,
    timeout: const Timeout(Duration(minutes: 20)),
  );

  test(
    'a release build has the values that .env has when it runs, and so has a '
    'second build after an edit of .env, without those of the build before',
    () async {
      // The first build is the one of the test before.
      expect(
        await _valuesInLibapp(app!, [first]),
        {first: true},
        reason: 'The APK of the release build of the test before lacks '
            '$first, the value of every key in ${EnvRole.dotEnvFile} when it '
            'ran (Flutter $flutterVersion).',
      );
      env.writeAsStringSync(_withValue(envBefore!, second));
      final built = await _releaseBuild(app, withToolArguments: true);
      expect(
        built.exitCode,
        0,
        reason: 'The second release build failed: '
            '${built.stdout}${built.stderr}',
      );
      expect(
        await _valuesInLibapp(app, [first, second]),
        {first: false, second: true},
        reason: 'The APK of the second release build has the values of the '
            'build before or lacks those that ${EnvRole.dotEnvFile} had when '
            'it ran (Flutter $flutterVersion).',
      );
    },
    skip: app == null
        ? needsApp
        : _shipsLibappOfBuildBefore(flutterVersion)
            ? _libappOfBuildBefore(flutterVersion)
            : null,
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
