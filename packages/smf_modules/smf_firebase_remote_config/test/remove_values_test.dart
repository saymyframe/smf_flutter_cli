// The cleanup of Remote Config of the Firebase project of CI after the app
// that CI starts with Firebase on an Android emulator: it removes from the
// template the parameters of the check that this run published, which
// publish_value_test.dart noted in the file of the run, and the parameters of
// the check that are more than two hours old, as those that a cancelled job
// left. It keeps every other parameter, condition and group of the template
// as it was, and publishes nothing when nothing is to go. A job publishes its
// parameter minutes before it removes it, so the cleanup of one job never
// removes the parameter of another job that runs.
//
// It runs only with the path of the file of the run in
// SMF_REMOTE_CONFIG_PUBLISHED, which a step of CI gives it after the start of
// the app, whether the answer published anything or not, and it needs the
// id of the project in SMF_FIREBASE_PROJECT and the path of the key in
// SMF_FIREBASE_SERVICE_ACCOUNT: without either of them, it fails and names
// what is missing. It never prints the access token or a part of the key,
// and a failure tells what it means and what to do (see
// support/remote_config_template.dart, whose tests run everywhere).
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

import 'support/remote_config_template.dart';

void main() {
  final environment = Platform.environment;
  final published = environment['SMF_REMOTE_CONFIG_PUBLISHED'];
  final project = environment['SMF_FIREBASE_PROJECT'];
  final key = environment['SMF_FIREBASE_SERVICE_ACCOUNT'];

  test(
    'Remote Config has no value of the run and no stale value of the check '
    'any more',
    () async {
      const keyIs = 'the path of the key of a service account of that project';
      final missing = [
        if (project == null)
          'SMF_FIREBASE_PROJECT, the id of the Firebase project of the app',
        if (key == null) 'SMF_FIREBASE_SERVICE_ACCOUNT, $keyIs',
      ];
      if (missing.isNotEmpty) {
        fail(
          'The values of remote config of the run are in '
          'SMF_REMOTE_CONFIG_PUBLISHED, but what removes them is not set: '
          '${missing.join('; ')}.',
        );
      }
      final names = publishedNamesIn(File(published!));
      try {
        final client = await clientOf(File(key!).readAsStringSync());
        try {
          final version = await changeTemplate(
            client,
            project: project!,
            change: (parameters) =>
                withoutValues(parameters, names, DateTime.now().toUtc()),
          );
          // In the log of the run, which has no secret: the parameters of
          // the check and the version of the template, with the project.
          // ignore: avoid_print
          print(
            version == null
                ? 'Remote Config of $project has no value of the run and no '
                    'stale value of the check: nothing to remove.'
                : 'Remote Config of $project published version $version of '
                    'its template without ${names.isEmpty ? 'the stale values '
                        'of the check' : names.join(', ')}.',
          );
        } finally {
          client.close();
        }
      } on TemplateNotChanged catch (error) {
        fail(error.meaning);
      }
    },
    skip: published == null
        ? 'Removes the values of remote config that a run of CI published, '
            'with the path of the file of the run in '
            'SMF_REMOTE_CONFIG_PUBLISHED, the id of the Firebase project in '
            'SMF_FIREBASE_PROJECT and the key of a service account of that '
            'project in SMF_FIREBASE_SERVICE_ACCOUNT.'
        : false,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
