/// The Firebase apps of a Firebase project, as the Firebase CLI lists
/// them, for the test that configures an app of CI with flutterfire: it
/// finds the Firebase app of the app by the id of the app, and registers
/// one when the project has none.
library;

import 'dart:convert';

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
