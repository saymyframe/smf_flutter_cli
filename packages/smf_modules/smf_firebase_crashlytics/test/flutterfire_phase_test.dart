// The build phase for Crashlytics of an app with Crashlytics, after
// `tool/configure_firebase.dart` configured it on macOS with the real
// flutterfire: the script of the module that the script runs after flutterfire
// must have fixed the phase for flutter build ipa, which needs a whole archive
// to fail otherwise. It needs an app that flutterfire configured for iOS, so it
// runs only with one in SMF_CONFIGURED_APP, as CI gives it after the test of
// firebase_core that configures the app, and before it starts the app on the
// iOS simulator. It reads the app, and the command of its README finds nothing
// to do. CI gives it the app with every module of each provider of the app
// entry, one in each job, and it skips an app that does not depend on
// firebase_crashlytics, to which flutterfire adds no such phase.
@TestOn('mac-os')
library;

import 'dart:convert';
import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_crashlytics/src/crashlytics_phase.dart';
import 'package:test/test.dart';

import 'support/app_pubspec.dart';
import 'support/crashlytics_phases.dart';

void main() {
  final app = Platform.environment['SMF_CONFIGURED_APP'];

  test(
    'the script that configures a flavor leaves the phase for Crashlytics '
    'that flutterfire added pointed at the upload script in the app',
    () {
      final project = File('$app/${AppEntryRole.xcodeProjectFile}');
      final text = project.readAsStringSync();

      expect(
        text,
        isNot(contains(crashlyticsScriptInBuildDirectory)),
        reason: 'The phase still looks for the upload script in the build '
            'directory of Xcode, so flutter build ipa fails in it.',
      );
      expect(
        crashlyticsScriptInApp.allMatches(text),
        hasLength(2),
        reason: 'flutterfire configure added no phase for Crashlytics with '
            'the path that the module fixes, as that of flutterfire_cli 1.4.1 '
            'has it: compare the phases of test/support/crashlytics_phases.dart.',
      );
      // A run of flutterfire takes its phases out of the target and adds them
      // again, and each flavor has three such runs: one phase of each name is
      // left, and it reads the build configuration of the build.
      for (final name in [crashlyticsPhaseName, bundleServiceFilePhaseName]) {
        expect(
          '/* $name */ = {'.allMatches(text),
          hasLength(1),
          reason: 'The phase $name',
        );
      }
      expect(text, contains(r'--build-configuration=${CONFIGURATION}'));

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
        'Nothing to fix in ${AppEntryRole.xcodeProjectFile}\n',
      );
      expect(project.readAsStringSync(), text);
    },
    skip: app == null
        ? 'Needs an app with firebase_crashlytics that flutterfire configured '
            'for iOS in SMF_CONFIGURED_APP.'
        : !dependsOn(app, 'firebase_crashlytics')
            ? 'The app in SMF_CONFIGURED_APP does not depend on '
                'firebase_crashlytics, so flutterfire adds no build phase for '
                'Crashlytics to it.'
            : null,
  );
}
