// flutterfire configure of an app with Firebase for one platform, in a
// Firebase project, without questions: the script that the README of the
// app gives, for the default flavor, with the project, the key of a service
// account of the project and the platform, as CI runs it before it starts the
// app on a device; only macOS configures iOS. It needs the Firebase CLI, the
// FlutterFire CLI and a
// Firebase project, so it runs only with an app generated with
// firebase_core in SMF_FIREBASE_APP, the id of the project in
// SMF_FIREBASE_PROJECT, the path of the key in SMF_FIREBASE_SERVICE_ACCOUNT
// and the platform, android or ios, in SMF_FIREBASE_PLATFORM, as CI gives
// them; the test changes the app. CI gives it the app with every module of
// each provider of the app entry, one in each job, and it skips an app that
// does not depend on firebase_core, which has nothing for flutterfire to
// configure.
//
// flutterfire registers the Android or iOS app in the project when the
// project has no app with its id yet, and otherwise takes the first app
// with the id. The test fails when the project has more than one, which
// runs that register the app at the same time can leave: each run could get
// the options of another. So only a run with SMF_FIREBASE_REGISTER=1, which
// CI gives only the runs of the workflow Build, lets flutterfire register
// the app; any other run fails before flutterfire when the project has no
// app with the id (see configurationProblem).
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'support/app_pubspec.dart';
import 'support/firebase_apps.dart';

/// The platform of `firebase apps:list` for each platform of the app.
const _firebasePlatforms = {'android': 'ANDROID', 'ios': 'IOS'};

/// The value of the property [name] of the options of [platform] in
/// [options], the text of the options of a flavor, or `null` without them.
String? _option(String options, String platform, String name) {
  final block = RegExp(
    'static const FirebaseOptions $platform = FirebaseOptions\\(([^;]*)\\);',
  ).firstMatch(options)?[1];
  return block == null
      ? null
      : RegExp("$name: '([^']*)'").firstMatch(block)?[1];
}

/// The id of [flavor] on [platform], from the script [script] of the app,
/// which gives it to flutterfire, or `null` without it.
String? _idOf(String script, String flavor, String platform) => RegExp(
      "'$flavor':\\s*\\([^)]*\\b$platform:\\s*'([^']+)'",
    ).firstMatch(script)?[1];

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
  final register = environment['SMF_FIREBASE_REGISTER'] == '1';

  test(
    'flutterfire configure with the command of the README fills in the '
    'options of the platform from the only Firebase app with its id in the '
    'project, which only a run that may register the app lets flutterfire '
    'register',
    () async {
      expect(_firebasePlatforms.keys, contains(platform));
      if (platform == 'ios') {
        expect(
          Platform.isMacOS,
          isTrue,
          reason: 'flutterfire configures the iOS app only on macOS.',
        );
      }
      final flavor = AppEntryRole.defaultFlavor.name;
      final readme = File('$app/README.md').readAsStringSync();
      final command = RegExp(
        r'^dart (tool/configure_firebase\.dart) \S+ --project=<id>$',
        multiLine: true,
      ).firstMatch(readme)?[1];
      expect(command, isNotNull, reason: 'The README gives no command.');
      final arguments = [
        command!,
        flavor,
        '--project=$project',
        '--service-account=$serviceAccount',
        '--platforms=$platform',
      ];
      final id =
          _idOf(File('$app/$command').readAsStringSync(), flavor, platform!);
      expect(
        id,
        isNotNull,
        reason: 'The script gives flutterfire no id of $flavor on $platform.',
      );

      // The Firebase apps of the platform in the project with the id, as
      // flutterfire lists them to find the app.
      Future<List<String>> firebaseApps() async => firebaseAppIdsOf(
            await _run(
              'firebase',
              [
                'apps:list',
                _firebasePlatforms[platform]!,
                '--project=$project',
                '--json',
              ],
              environment: {'GOOGLE_APPLICATION_CREDENTIALS': serviceAccount!},
            ),
            id!,
          );

      // Before flutterfire, which registers the app when the project has
      // none with the id.
      if (configurationProblem(
        appIds: await firebaseApps(),
        project: project!,
        platform: platform,
        id: id!,
        register: register,
      )
          case final problem?) {
        fail(problem);
      }

      final configured = await _run('dart', arguments, directory: app);
      printOnFailure(configured);

      final optionsFile = 'lib/firebase_options_$flavor.dart';
      final options = File('$app/$optionsFile').readAsStringSync();
      // flutterfire writes the options in a format of its own, and the script
      // formats them, so that the check of the format of the app passes.
      await _run(
        'dart',
        ['format', '--output=none', '--set-exit-if-changed', optionsFile],
        directory: app,
      );
      expect(_option(options, platform, 'projectId'), project);
      expect(options, contains('return $platform;'));
      final appId = _option(options, platform, 'appId');
      expect(appId, isNotNull);

      // The one Firebase app with the id, which flutterfire found or
      // registered: another run that registered one at the same time would
      // leave a second.
      final withId = await firebaseApps();
      expect(
        withId,
        [appId],
        reason: configurationProblem(
              appIds: withId,
              project: project,
              platform: platform,
              id: id,
              register: true,
            ) ??
            'flutterfire configured the app with the Firebase app $appId, '
                'but the project has ${withId.join(', ')} with the id $id.',
      );

      if (platform == 'android') {
        final services = jsonDecode(
          File('$app/android/app/src/$flavor/google-services.json')
              .readAsStringSync(),
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
        File('$app/ios/flavors/$flavor/GoogleService-Info.plist')
            .readAsStringSync(),
        allOf(
          contains('<string>$appId</string>'),
          contains('<string>$id</string>'),
        ),
      );
    },
    skip: [app, project, serviceAccount, platform].contains(null)
        ? 'Needs an app with firebase_core in SMF_FIREBASE_APP, a Firebase '
            'project in SMF_FIREBASE_PROJECT, the key of a service account '
            'of the project in SMF_FIREBASE_SERVICE_ACCOUNT and the platform '
            'in SMF_FIREBASE_PLATFORM.'
        : !dependsOn(app!, 'firebase_core')
            ? 'The app in SMF_FIREBASE_APP does not depend on firebase_core, '
                'so it has nothing for flutterfire to configure.'
            : null,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
