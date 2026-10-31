// flutterfire configure of an app with Firebase for one platform, in a
// Firebase project, without questions: the script that the README of the app
// gives, for the flavor that a plain build gives and for the flavor that a user
// ships, with the project, the key of a service account of the project and the
// platform, as CI runs it before it starts the app on a device; only macOS
// configures iOS, with a run of flutterfire for each build configuration. It
// needs the Firebase CLI, the FlutterFire CLI and a Firebase project, so it
// runs only with an app generated with firebase_core in SMF_FIREBASE_APP, the
// id of the project in SMF_FIREBASE_PROJECT, the path of the key in
// SMF_FIREBASE_SERVICE_ACCOUNT and the platform, android or ios, in
// SMF_FIREBASE_PLATFORM, as CI gives them; the test changes the app. CI gives
// it the app with every module of each provider of the app entry, one in each
// job, and it skips an app that does not depend on firebase_core, which has
// nothing for flutterfire to configure.
//
// flutterfire registers the Android or iOS app of a flavor in the project when
// the project has no app with its id yet, and otherwise takes the first app
// with the id. The test fails when the project has more than one, which runs
// that register the app at the same time can leave: each run could get the
// options of another. So only a run with SMF_FIREBASE_REGISTER=1, which CI
// gives only the runs of the workflow Build, lets flutterfire register the
// apps; any other run fails before flutterfire when the project has no app with
// the id of one of the flavors (see configurationProblem).
//
// On macOS the script runs flutterfire once for each build configuration, so
// the test also fails when a run does not see the app that the run before it
// registered, whichever way that shows: Firebase refuses the second app, and
// the script fails (see registerRefusedHint), or the project has two.
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

/// Runs [executable] with [arguments] in [directory] and fails the test,
/// with what it printed, if it fails.
Future<String> _run(
  String executable,
  List<String> arguments, {
  String? directory,
  Map<String, String>? environment,
  String hint = '',
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
    reason: '$executable ${arguments.first}: ${result.stdout}${result.stderr}'
        '$hint',
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
    'the command of the README configures the flavors dev and prod, each with '
    'its own options and files from the only Firebase app with its id in the '
    'project, which only a run that may register the apps lets flutterfire '
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
      const flavors = [AppEntryRole.defaultFlavor, AppEntryRole.releaseFlavor];
      final readme = File('$app/README.md').readAsStringSync();
      final command = RegExp(
        r'^dart (tool/configure_firebase\.dart) \S+ --project=<id>$',
        multiLine: true,
      ).firstMatch(readme)?[1];
      expect(command, isNotNull, reason: 'The README gives no command.');
      final script = File('$app/$command').readAsStringSync();
      final ids = <AppFlavor, String>{};
      for (final flavor in flavors) {
        final id = flavorIdIn(script, flavor.name, platform!);
        if (id == null) {
          fail(
            'The script gives flutterfire no id of ${flavor.name} on '
            '$platform.',
          );
        }
        ids[flavor] = id;
      }
      expect(
        ids.values.toSet(),
        hasLength(flavors.length),
        reason: 'Each flavor needs an id of its own, and so a Firebase app of '
            'its own: $ids',
      );

      // The Firebase apps of the platform in the project with an id, as
      // flutterfire lists them to find the app.
      Future<List<String>> firebaseApps(String id) async => firebaseAppIdsOf(
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
            id,
          );

      // Before any run of flutterfire, which registers the app of a flavor
      // when the project has none with its id.
      for (final MapEntry(key: flavor, value: id) in ids.entries) {
        if (configurationProblem(
          appIds: await firebaseApps(id),
          project: project!,
          platform: platform!,
          id: id,
          register: register,
        )
            case final problem?) {
          fail('The flavor ${flavor.name}: $problem');
        }
      }

      for (final flavor in flavors) {
        final configured = await _run(
          'dart',
          [
            command!,
            flavor.name,
            '--project=$project',
            '--service-account=$serviceAccount',
            '--platforms=$platform',
          ],
          directory: app,
          hint: registerRefusedHint,
        );
        printOnFailure(configured);
      }

      // Once both flavors are configured, so that the second has left the
      // first as it was.
      final firebaseJson = File('$app/firebase.json').readAsStringSync();
      for (final MapEntry(key: flavor, value: id) in ids.entries) {
        final optionsFile = 'lib/firebase_options_${flavor.name}.dart';
        final options = File('$app/$optionsFile').readAsStringSync();
        // flutterfire writes the options in a format of its own, and the
        // script formats them, so that the check of the format of the app
        // passes.
        await _run(
          'dart',
          ['format', '--output=none', '--set-exit-if-changed', optionsFile],
          directory: app,
        );
        expect(_option(options, platform!, 'projectId'), project);
        expect(options, contains('return $platform;'));
        final appId = _option(options, platform, 'appId');
        expect(appId, isNotNull);

        // The one Firebase app with the id, which flutterfire found or
        // registered.
        if (registeredAppsProblem(
          appIds: await firebaseApps(id),
          appId: appId!,
          project: project!,
          platform: platform,
          id: id,
        )
            case final problem?) {
          fail('The flavor ${flavor.name}: $problem');
        }

        final problems = [
          ...firebaseJsonProblems(
            firebaseJson: firebaseJson,
            flavor: flavor,
            platform: platform,
            appId: appId,
            project: project,
          ),
          if (platform == 'android')
            if (googleServicesProblem(
              File('$app/android/app/src/${flavor.name}/google-services.json')
                  .readAsStringSync(),
              appId,
              id,
            )
                case final problem?)
              problem,
          if (platform == 'ios')
            ...servicePlistProblems(
              File('$app/ios/flavors/${flavor.name}/GoogleService-Info.plist')
                  .readAsStringSync(),
              appId,
              id,
              project,
            ),
        ];
        if (problems.isNotEmpty) {
          fail('The flavor ${flavor.name}:\n${problems.join('\n')}');
        }
      }
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
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
