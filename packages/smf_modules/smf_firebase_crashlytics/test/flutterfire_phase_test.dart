// The build phase for Crashlytics that `flutterfire configure` added to an
// app with Crashlytics on macOS, fixed for flutter build ipa with the command
// of the README of the app, as SMF does right after it configures an app.
// It needs an app that flutterfire configured for iOS, so it runs only with
// one in SMF_CONFIGURED_APP, as CI gives it after the test of firebase_core
// that configures the app, and before it starts the app on the iOS
// simulator; the test changes the app. CI gives it the app with every module
// of each provider of the app entry, one in each job, and it skips an app
// that does not depend on firebase_crashlytics, to which flutterfire adds no
// such phase.
@TestOn('mac-os')
library;

import 'dart:convert';
import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_crashlytics/src/crashlytics_phase.dart';
import 'package:test/test.dart';

import 'support/app_pubspec.dart';

void main() {
  final app = Platform.environment['SMF_CONFIGURED_APP'];

  test(
    'the command of the README points the phase for Crashlytics that '
    'flutterfire configure added at the upload script in the app',
    () {
      final project = File('$app/${AppEntryRole.xcodeProjectFile}');
      expect(
        project.readAsStringSync(),
        contains(crashlyticsScriptInBuildDirectory),
        reason: 'flutterfire configure added no phase for Crashlytics that '
            'looks for the upload script in the build directory of Xcode, as '
            'that of flutterfire_cli 1.4.1 does.',
      );
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
      final fixed = project.readAsStringSync();
      expect(fixed, isNot(contains(crashlyticsScriptInBuildDirectory)));
      expect(fixed, contains(crashlyticsScriptInApp));
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
