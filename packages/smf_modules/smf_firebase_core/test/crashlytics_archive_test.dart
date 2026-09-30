// flutter build ipa of an app with Crashlytics after flutterfire configured
// it on macOS and the command of the README of the app fixed the build phase
// for Crashlytics that flutterfire adds. It needs Flutter, Xcode and the gem
// xcodeproj, so it runs only with an app generated with firebase_crashlytics
// in SMF_CRASHLYTICS_APP, as CI gives it; the test changes the app. CI gives
// it the app with every module of each provider of the app entry, one in
// each job, and it skips an app that does not depend on
// firebase_crashlytics, to which flutterfire adds no such phase.
@TestOn('mac-os')
library;

import 'dart:convert';
import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/src/crashlytics_phase.dart';
import 'package:test/test.dart';

import 'support/app_pubspec.dart';
import 'support/ruby.dart';

/// A `flutterfire` that stands in for `flutterfire upload-crashlytics-symbols`,
/// which the phase runs and which needs the Firebase project that
/// `flutterfire configure` registered the app in: it checks first, as that
/// does, that the upload script of Crashlytics is where the phase says, and
/// writes its path to [log].
String _flutterfire(String log) => '''
#!/bin/sh
for argument in "\$@"; do
  case "\$argument" in
    --upload-symbols-script-path=*) script="\${argument#*=}" ;;
  esac
done
echo "\$script" >> "$log"
if [ ! -f "\$script" ]; then
  echo "Could not find the Crashlytics upload symbols script at \\"\$script\\"." >&2
  exit 1
fi
''';

void main() {
  final app = Platform.environment['SMF_CRASHLYTICS_APP'];

  test(
    'flutter build ipa finds the upload script of Crashlytics once the '
    'command of the README fixed the phase that flutterfire added',
    () async {
      // flutterfire configure adds the phase with the gem xcodeproj on macOS.
      final ruby = rubyOnPath()!;
      addCrashlyticsPhase(ruby, app!, '1.4.1');
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
      final log = File('${bin.path}/scripts.log');
      final flutterfire = File('${bin.path}/flutterfire')
        ..writeAsStringSync(_flutterfire(log.path));
      Process.runSync('chmod', ['+x', flutterfire.path]);

      // The phase runs the flutterfire on the PATH that it gets.
      final build = await Process.run(
        'flutter',
        ['build', 'ipa', '--no-codesign'],
        workingDirectory: app,
        environment: {'PATH': '${bin.path}:${Platform.environment['PATH']}'},
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

      expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
      final script = log.readAsLinesSync().single;
      expect(
        script,
        endsWith(
          '/ios/../build/ios/SourcePackages/checkouts/firebase-ios-sdk/'
          'Crashlytics/run',
        ),
      );
      expect(File(script).existsSync(), isTrue);
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
