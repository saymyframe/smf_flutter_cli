// flutterfire configure of an app with Firebase for one platform, in a
// Firebase project, without questions: the command that the README of the
// app gives, with the project, the key of a service account of the project
// and the platform, as CI runs it before it starts the app on a device. For
// iOS, which only macOS configures, the test then fixes the build phase for
// Crashlytics with the command of the README, as SMF does after it
// configures an app. It needs the Firebase CLI, the FlutterFire CLI and a
// Firebase project, so it runs only with an app generated with
// firebase_core in SMF_FIREBASE_APP, the id of the project in
// SMF_FIREBASE_PROJECT, the path of the key in SMF_FIREBASE_SERVICE_ACCOUNT
// and the platform, android or ios, in SMF_FIREBASE_PLATFORM, as CI gives
// them; the test changes the app.
//
// flutterfire registers the Android or iOS app in the project when the
// project has no app with its id yet, and otherwise takes the first app
// with the id. The test fails when the project has more than one, which
// runs that register the app at the same time can leave: each run could get
// the options of another.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/src/crashlytics_phase.dart';
import 'package:smf_firebase_core/src/preflight/flutterfire_cli.dart';
import 'package:test/test.dart';

/// The option of `flutterfire configure` that gives the id of the app of
/// each platform.
const _idOptions = {
  'android': '--android-package-name',
  'ios': '--ios-bundle-id',
};

/// The platform of `firebase apps:list` for each platform of the app.
const _firebasePlatforms = {'android': 'ANDROID', 'ios': 'IOS'};

/// The value of the property [name] of the options of [platform] in
/// `lib/firebase_options.dart`, [options], or `null` without them.
String? _option(String options, String platform, String name) {
  final block = RegExp(
    'static const FirebaseOptions $platform = FirebaseOptions\\(([^;]*)\\);',
  ).firstMatch(options)?[1];
  return block == null
      ? null
      : RegExp("$name: '([^']*)'").firstMatch(block)?[1];
}

/// Runs [executable] with [arguments] in [directory] and fails the test,
/// with what it printed, if it fails.
Future<String> _run(
  String executable,
  List<String> arguments, {
  String? directory,
  Map<String, String>? environment,
}) async {
  final result = await Process.run(
    executable,
    arguments,
    workingDirectory: directory,
    environment: environment,
    runInShell: Platform.isWindows,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  expect(
    result.exitCode,
    0,
    reason: '$executable ${arguments.first}: ${result.stdout}${result.stderr}',
  );
  return '${result.stdout}';
}

void main() {
  final environment = Platform.environment;
  final app = environment['SMF_FIREBASE_APP'];
  final project = environment['SMF_FIREBASE_PROJECT'];
  final serviceAccount = environment['SMF_FIREBASE_SERVICE_ACCOUNT'];
  final platform = environment['SMF_FIREBASE_PLATFORM'];

  test(
    'flutterfire configure with the command of the README fills in the '
    'options of the platform from the only Firebase app with its id in the '
    'project',
    () async {
      expect(_idOptions.keys, contains(platform));
      if (platform == 'ios') {
        expect(
          Platform.isMacOS,
          isTrue,
          reason: 'flutterfire configures the iOS app only on macOS.',
        );
      }
      final readme = File('$app/README.md').readAsStringSync();
      final command = RegExp(r'^flutterfire (configure .*)$', multiLine: true)
          .firstMatch(readme)?[1];
      expect(command, isNotNull, reason: 'The README gives no command.');
      final arguments = [
        for (final argument in command!.split(' '))
          argument.startsWith('--platforms=')
              ? '--platforms=$platform'
              : argument,
        '--project=$project',
        '--service-account=$serviceAccount',
        '--yes',
      ];
      final idOption = '${_idOptions[platform]}=';
      final id = [
        for (final argument in arguments)
          if (argument.startsWith(idOption))
            argument.substring(idOption.length),
      ].singleOrNull;
      expect(
        id,
        isNotNull,
        reason: 'The command gives no $idOption, and flutterfire would read '
            'the id from the files of the app.',
      );

      final configured = await _run(
        flutterfireTool.executable,
        flutterfireTool.argumentsFor(arguments),
        directory: app,
      );
      printOnFailure(configured);

      final options = File('$app/lib/firebase_options.dart').readAsStringSync();
      expect(_option(options, platform!, 'projectId'), project);
      expect(options, contains('return $platform;'));
      final appId = _option(options, platform, 'appId');
      expect(appId, isNotNull);

      // The Firebase apps of the platform in the project, as flutterfire
      // lists them to find the app.
      final listed = await _run(
        'firebase',
        [
          'apps:list',
          _firebasePlatforms[platform]!,
          '--project=$project',
          '--json',
        ],
        environment: {'GOOGLE_APPLICATION_CREDENTIALS': serviceAccount!},
      );
      final apps = (jsonDecode(listed.substring(listed.indexOf('{')))
          as Map<String, Object?>)['result']! as List<Object?>;
      final withId = [
        for (final firebaseApp in apps.cast<Map<String, Object?>>())
          if ((firebaseApp['packageName'] ?? firebaseApp['bundleId']) == id)
            firebaseApp['appId'],
      ];
      expect(
        withId,
        [appId],
        reason: 'The Firebase project $project should have one $platform app '
            'with the id $id, but has ${withId.length}: ${withId.join(', ')}. '
            'flutterfire takes the first, so the options may change from run '
            'to run; delete the others in the Firebase console.',
      );

      if (platform == 'android') {
        final services = jsonDecode(
          File('$app/android/app/google-services.json').readAsStringSync(),
        ) as Map<String, Object?>;
        expect(
          [
            for (final client in (services['client']! as List<Object?>)
                .cast<Map<String, Object?>>())
              (client['client_info']!
                  as Map<String, Object?>)['mobilesdk_app_id'],
          ],
          contains(appId),
        );
        return;
      }
      expect(
        File('$app/ios/Runner/GoogleService-Info.plist').readAsStringSync(),
        allOf(
          contains('<string>$appId</string>'),
          contains('<string>$id</string>'),
        ),
      );
      // The phase for Crashlytics that flutterfire adds, fixed for
      // flutter build ipa, as the README says.
      expect(readme, contains('```bash\n$crashlyticsPhaseFixCommand\n```'));
      final fixed = await _run(
        '/bin/sh',
        ['-c', crashlyticsPhaseFixCommand],
        directory: app,
      );
      printOnFailure(fixed);
      expect(
        File('$app/${AppEntryRole.xcodeProjectFile}').readAsStringSync(),
        isNot(contains(crashlyticsScriptInBuildDirectory)),
      );
    },
    skip: [app, project, serviceAccount, platform].contains(null)
        ? 'Needs an app with firebase_core in SMF_FIREBASE_APP, a Firebase '
            'project in SMF_FIREBASE_PROJECT, the key of a service account '
            'of the project in SMF_FIREBASE_SERVICE_ACCOUNT and the platform '
            'in SMF_FIREBASE_PLATFORM.'
        : null,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
