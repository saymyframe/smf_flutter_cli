// flutter build ipa of the flavor that a user ships, for an app with
// Crashlytics, with the build phases that `flutterfire configure` adds on macOS
// and the phase for Crashlytics fixed by the command of the README of the app,
// as the script that configures a flavor runs it. It needs Flutter, Xcode and
// the gem xcodeproj, so it runs only with an app generated with
// firebase_crashlytics in SMF_CRASHLYTICS_APP, as CI gives it; the test changes
// the app. It needs no Firebase project, so a stand-in takes the place of the
// flutterfire that the phases run. CI gives it the app with every module of
// each provider of the app entry, one in each job, and it skips an app that
// does not depend on firebase_crashlytics, to which flutterfire adds no such
// phase. The archive is a release build, which an app with values in .env
// builds only with the arguments of the flutter tool that give it them: CI
// gives the test those of the app in SMF_TOOL_ARGUMENTS, one on each line.
@TestOn('mac-os')
library;

import 'dart:convert';
import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_crashlytics/src/crashlytics_phase.dart';
import 'package:test/test.dart';

import 'support/app_pubspec.dart';
import 'support/ruby.dart';

/// A `flutterfire` that stands in for the two commands that the phases run,
/// which need the Firebase project that `flutterfire configure` registered the
/// app in.
///
/// For `bundle-service-file` it copies the `GoogleService-Info.plist` of the
/// flavor of the build configuration to its destination. For
/// `upload-crashlytics-symbols` it checks first, as that does, that the upload
/// script of Crashlytics is where the phase says. It writes what it got to
/// [log].
String _flutterfire(String log) => '''
#!/bin/sh
for argument in "\$@"; do
  case "\$argument" in
    --upload-symbols-script-path=*) script="\${argument#*=}" ;;
    --plist-destination=*) destination="\${argument#*=}" ;;
    --apple-project-path=*) project="\${argument#*=}" ;;
    --build-configuration=*) configuration="\${argument#*=}" ;;
  esac
done
case "\$1" in
  bundle-service-file)
    echo "bundle \$configuration" >> "$log"
    cp "\$project/flavors/\${configuration#*-}/GoogleService-Info.plist" "\$destination/"
    ;;
  upload-crashlytics-symbols)
    echo "upload \$configuration \$script" >> "$log"
    if [ ! -f "\$script" ]; then
      echo "Could not find the Crashlytics upload symbols script at \\"\$script\\"." >&2
      exit 1
    fi
    ;;
esac
''';

/// The arguments of the `flutter` tool that build [app] with its values,
/// one on each line of [given], as CI gives them in `SMF_TOOL_ARGUMENTS`
/// from the file that its matrix tool writes next to the app.
///
/// Without them, it fails for an app that has a line of a key in its
/// `.env`, whose archive needs them, and gives none to any other app.
List<String> toolArgumentsOf(String app, String? given) {
  if (given != null) {
    return [
      for (final line in const LineSplitter().convert(given))
        if (line.isNotEmpty) line,
    ];
  }
  final values = File('$app/${EnvRole.dotEnvFile}');
  if (values.existsSync() &&
      RegExp(r'^[A-Za-z_]\w*=', multiLine: true)
          .hasMatch(values.readAsStringSync())) {
    fail(
      'The app in SMF_CRASHLYTICS_APP has keys in ${EnvRole.dotEnvFile}, so '
      'its archive, a release build, needs the arguments of the flutter tool '
      'that give it their values. Give them in SMF_TOOL_ARGUMENTS, one on '
      'each line, as .github/scripts/each_app.sh --tool-arguments does with '
      'the file that the --create of the matrix tool writes next to the app.',
    );
  }
  return const [];
}

void main() {
  final app = Platform.environment['SMF_CRASHLYTICS_APP'];

  group('the arguments of the flutter tool of the app', () {
    late Directory temp;

    setUp(() => temp = Directory.systemTemp.createTempSync('smf_archive_'));
    tearDown(() => temp.deleteSync(recursive: true));

    test('come from the lines of the variable, without the empty ones', () {
      expect(
        toolArgumentsOf(temp.path, '--dart-define-from-file=.env\n\ntwo words'),
        ['--dart-define-from-file=.env', 'two words'],
      );
      expect(toolArgumentsOf(temp.path, ''), isEmpty);
    });

    test(
        'are none without the variable for an app without keys in .env, and '
        'fail the test for an app with them', () {
      expect(toolArgumentsOf(temp.path, null), isEmpty);
      File('${temp.path}/${EnvRole.dotEnvFile}')
          .writeAsStringSync('# The values of the app.\n');
      expect(toolArgumentsOf(temp.path, null), isEmpty);

      File('${temp.path}/${EnvRole.dotEnvFile}')
          .writeAsStringSync('# The key of a service.\nSERVICE_KEY=\n');
      expect(
        () => toolArgumentsOf(temp.path, null),
        throwsA(
          isA<TestFailure>().having(
            (failure) => failure.message,
            'message',
            startsWith(
              'The app in SMF_CRASHLYTICS_APP has keys in .env, so its '
              'archive, a release build, needs the arguments of the flutter '
              'tool that give it their values. Give them in '
              'SMF_TOOL_ARGUMENTS, ',
            ),
          ),
        ),
      );
    });
  });

  test(
    'flutter build ipa of a flavor finds the upload script of Crashlytics once '
    'the command of the README fixed the phase that flutterfire added, and '
    'archives the app with the file of the flavor',
    () async {
      final toolArguments = toolArgumentsOf(
        app!,
        Platform.environment['SMF_TOOL_ARGUMENTS'],
      );
      const flavor = AppEntryRole.releaseFlavor;
      const plist = 'smf test plist of the flavor';
      File('$app/ios/flavors/${flavor.name}/GoogleService-Info.plist')
        ..createSync(recursive: true)
        ..writeAsStringSync(plist);
      // flutterfire configure adds the phases with the gem xcodeproj on macOS.
      final ruby = rubyOnPath()!;
      addBundleServiceFilePhase(ruby, app);
      addCrashlyticsPhase(ruby, app, '1.4.1');
      expect(
        File('$app/README.md').readAsStringSync(),
        contains('```bash\n$crashlyticsPhaseFixCommand\n```'),
      );

      final fix = Process.runSync(
        '/bin/sh',
        ['-c', crashlyticsPhaseFixCommand],
        workingDirectory: app,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      expect(fix.exitCode, 0, reason: '${fix.stderr}');
      expect(
        fix.stdout,
        'Fixed the Crashlytics phase in ${AppEntryRole.xcodeProjectFile}\n',
      );

      final bin = Directory.systemTemp.createTempSync('smf_flutterfire_');
      addTearDown(() => bin.deleteSync(recursive: true));
      final log = File('${bin.path}/calls.log');
      final flutterfire = File('${bin.path}/flutterfire')
        ..writeAsStringSync(_flutterfire(log.path));
      Process.runSync('chmod', ['+x', flutterfire.path]);

      // The phases run the flutterfire on the PATH that they get.
      final build = await Process.run(
        'flutter',
        [
          'build',
          'ipa',
          '--no-codesign',
          '--flavor',
          flavor.name,
          ...toolArguments,
        ],
        workingDirectory: app,
        environment: {'PATH': '${bin.path}:${Platform.environment['PATH']}'},
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

      expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
      final calls = log.readAsLinesSync();
      final configuration = 'Release-${flavor.name}';
      expect(calls, hasLength(2), reason: '$calls');
      expect(calls, contains('bundle $configuration'));
      final upload = calls.singleWhere((call) => call.startsWith('upload '));
      expect(
        upload,
        allOf(
          startsWith('upload $configuration '),
          endsWith(
            '/ios/../build/ios/SourcePackages/checkouts/firebase-ios-sdk/'
            'Crashlytics/run',
          ),
        ),
      );
      expect(
        File(
          '$app/build/ios/archive/Runner.xcarchive/Products/Applications/'
          'Runner.app/GoogleService-Info.plist',
        ).readAsStringSync(),
        plist,
      );
    },
    skip: app == null
        ? 'Needs an app with firebase_crashlytics in SMF_CRASHLYTICS_APP.'
        : !dependsOn(app, 'firebase_crashlytics')
            ? 'The app in SMF_CRASHLYTICS_APP does not depend on '
                'firebase_crashlytics, so flutterfire adds no build phase '
                'for Crashlytics to it.'
            : null,
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
