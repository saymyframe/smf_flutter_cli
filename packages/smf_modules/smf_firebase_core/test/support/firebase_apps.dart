/// The Firebase apps of a Firebase project, as the Firebase CLI lists
/// them, and what flutterfire writes of them into an app, for the test that
/// configures flavors of an app of CI with flutterfire: flutterfire finds the
/// Firebase app of a flavor by its id, and registers one when the project has
/// none.
library;

import 'dart:convert';

import 'package:smf_contracts/smf_contracts.dart';

/// The id of [flavor] on [platform], `android` or `ios`, in [script], the text
/// of the script of the app that gives the id to flutterfire, or `null`
/// without it.
String? flavorIdIn(String script, String flavor, String platform) => RegExp(
      "'$flavor':\\s*\\([^)]*\\b$platform:\\s*'([^']+)'",
    ).firstMatch(script)?[1];

/// The app ids of the Firebase apps in [listed], what
/// `firebase apps:list <platform> --project=<project> --json` prints, whose
/// Android package name or iOS bundle id is [id]: the apps that flutterfire
/// finds for an app with that id. The Firebase CLI may print other lines
/// before the JSON.
List<String> firebaseAppIdsOf(String listed, String id) {
  final json = jsonDecode(listed.substring(listed.indexOf('{')));
  final apps = (json as Map<String, Object?>)['result']! as List<Object?>;
  return [
    for (final app in apps.cast<Map<String, Object?>>())
      if ((app['packageName'] ?? app['bundleId']) == id) '${app['appId']}',
  ];
}

/// Why flutterfire may not configure the app with the id [id] for
/// [platform] in the Firebase project [project], whose Firebase apps with
/// that id are [appIds]; `null` if it may.
///
/// flutterfire registers a Firebase app when the project has none with the
/// id, and otherwise takes the first. Runs that register one at the same
/// time, such as the jobs of the nightly run for each version of Flutter,
/// would leave the project with several, and each run could get the
/// options of another. So only a run that may [register], of the workflow
/// Build, configures an app that the project does not have yet, and no run
/// configures an app that the project has more than once.
String? configurationProblem({
  required List<String> appIds,
  required String project,
  required String platform,
  required String id,
  required bool register,
}) =>
    switch (appIds) {
      [_, _, ...] => 'The Firebase project $project should have one '
          '$platform app with the id $id, but has ${appIds.length}: '
          '${appIds.join(', ')}. flutterfire takes the first, so the options '
          'may change from run to run; delete the others in the Firebase '
          'console.',
      [] when !register => 'The Firebase project $project has no $platform '
          'app with the id $id, and only the runs of the workflow Build '
          'register the apps of CI in it, with SMF_FIREBASE_REGISTER=1, so '
          'that runs at the same time, such as the jobs of the nightly run, '
          'do not register one each. Run Build first, such as by hand on '
          'this branch.',
      _ => null,
    };

/// What a failure of the script of the app that configures a flavor may mean,
/// for the message of a test that runs it.
///
/// On macOS the script runs flutterfire once for each build configuration, and
/// flutterfire registers an app when the project does not list one with the id.
/// Firebase answers a second app with one id with HTTP 409, for Android and for
/// iOS, which the Firebase CLI prints as `Failed to create iOS app`.
const registerRefusedHint = '\nIf flutterfire failed on apps:create after the '
    'first run for a flavor, the project did not list the app of the run '
    'before it yet, and Firebase refused a second app with its id: the script '
    'has to wait between its runs.';

/// Why the Firebase apps with the id [id] that the project lists once
/// flutterfire configured a flavor are wrong; `null` if they are the one app
/// [appId] of the options of the flavor.
String? registeredAppsProblem({
  required List<String> appIds,
  required String appId,
  required String project,
  required String platform,
  required String id,
}) =>
    switch (appIds) {
      [final only] when only == appId => null,
      [_, _, ...] => 'The Firebase project $project should have one $platform '
          'app with the id $id once flutterfire ran, but has ${appIds.length}: '
          '${appIds.join(', ')}, and the options have $appId. Either a run of '
          'flutterfire did not see the app that the run before it registered, '
          'so that the script has to wait between its runs, or another job '
          'registered one at the same time. Delete the others in the Firebase '
          'console.',
      _ => 'flutterfire configured the app with the Firebase app $appId, but '
          'the project $project lists '
          '${appIds.isEmpty ? 'no app' : appIds.join(', ')} with the id $id.',
    };

/// What is wrong with [firebaseJson], the text of `firebase.json` of an app,
/// for [flavor] on [platform] with the Firebase app [appId] of [project].
///
/// It finds the Android app by its `fileOutput`, and never by its key, which
/// depends on the directory of the app and on the system. On iOS it asks of
/// every build configuration of the flavor the same Firebase app, since the
/// script makes a run of flutterfire for each.
List<String> firebaseJsonProblems({
  required String firebaseJson,
  required AppFlavor flavor,
  required String platform,
  required String appId,
  required String project,
}) {
  final platforms = _at(jsonDecode(firebaseJson), ['flutter', 'platforms']);
  final options = 'lib/firebase_options_${flavor.name}.dart';
  final ofOptions = _at(platforms, ['dart', options]);
  final projectOfOptions = _at(ofOptions, ['projectId']);
  final appOfOptions = _at(ofOptions, ['configurations', platform]);
  final problems = [
    if (projectOfOptions != project)
      'firebase.json names $projectOfOptions as the project of $options.',
    if (appOfOptions != appId)
      'firebase.json names $appOfOptions as the $platform app of $options.',
  ];
  void check(String name, Object? entry, String file) {
    if (entry == null) {
      problems.add('firebase.json has nothing for $name: no run wrote it.');
      return;
    }
    if (_at(entry, ['projectId']) != project) {
      problems.add(
        'firebase.json names ${_at(entry, ['projectId'])} as the project of '
        '$name, and not $project.',
      );
    }
    if (_at(entry, ['appId']) != appId) {
      problems.add(
        'firebase.json names ${_at(entry, ['appId'])} as the Firebase app of '
        '$name, and not $appId: a run of flutterfire took another app than '
        'the options have.',
      );
    }
    if (_at(entry, ['fileOutput']) != file) {
      problems.add(
        'firebase.json names ${_at(entry, ['fileOutput'])} as the file of '
        '$name, and not $file.',
      );
    }
  }

  if (platform == 'android') {
    final file = 'android/app/src/${flavor.name}/google-services.json';
    final configurations = _at(platforms, ['android', 'buildConfigurations']);
    final entries = [
      if (configurations is Map)
        for (final entry in configurations.values)
          if (_at(entry, ['fileOutput']) == file) entry,
    ];
    if (entries.length != 1) {
      problems.add(
        'firebase.json should have one Android app with the file $file, but '
        'has ${entries.length}.',
      );
    }
    for (final entry in entries) {
      check(file, entry, file);
    }
  } else {
    for (final configuration in flavor.xcodeConfigurations) {
      check(
        'the build configuration $configuration',
        _at(platforms, ['ios', 'buildConfigurations', configuration]),
        'ios/flavors/${flavor.name}/GoogleService-Info.plist',
      );
    }
  }
  return problems;
}

/// What is wrong with [services], the text of a `google-services.json`, for
/// the Firebase app [appId] with the application id [id]. The file lists
/// clients for other Android apps of the project too.
String? googleServicesProblem(String services, String appId, String id) {
  final clients = _at(jsonDecode(services), ['client']);
  final client = [
    if (clients is List)
      for (final client in clients)
        if (_at(client, ['client_info', 'mobilesdk_app_id']) == appId) client,
  ].firstOrNull;
  if (client == null) return 'google-services.json has no client of $appId.';
  final name =
      _at(client, ['client_info', 'android_client_info', 'package_name']);
  return name == id
      ? null
      : 'google-services.json gives $appId the package name $name, and not '
          '$id.';
}

/// What is wrong with [plist], the text of a `GoogleService-Info.plist`, for
/// the Firebase app [appId] with the bundle id [id] in [project].
List<String> servicePlistProblems(
  String plist,
  String appId,
  String id,
  String project,
) =>
    [
      for (final (key, value) in [
        ('GOOGLE_APP_ID', appId),
        ('BUNDLE_ID', id),
        ('PROJECT_ID', project),
      ])
        if (!RegExp('<key>$key</key>\\s*<string>${RegExp.escape(value)}'
                '</string>')
            .hasMatch(plist))
          'GoogleService-Info.plist does not have $value as its $key.',
    ];

/// What [path] leads to in [json], or `null` where it leads nowhere.
Object? _at(Object? json, List<String> path) {
  var node = json;
  for (final key in path) {
    node = node is Map ? node[key] : null;
  }
  return node;
}
