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
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

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

void main() {
  final app = Platform.environment['SMF_RELEASE_APP'];

  test('the tool arguments are the lines of the variable, but the empty ones',
      () {
    expect(
      _argumentsOf('--dart-define-from-file=.env\n\ntwo words\n'),
      ['--dart-define-from-file=.env', 'two words'],
    );
    expect(_argumentsOf(''), isEmpty);
    expect(_argumentsOf(null), isEmpty);
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
      expect(printed, contains(EnvRole.releaseErrorOf(toolArguments)));

      final built = await _releaseBuild(app, withToolArguments: true);
      expect(
        built.exitCode,
        0,
        reason: 'A release build with $toolArguments failed: '
            '${built.stdout}${built.stderr}',
      );
    },
    skip: app == null
        ? 'Needs an app with keys of the env role in SMF_RELEASE_APP, and '
            'Flutter with the Android SDK.'
        : null,
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
