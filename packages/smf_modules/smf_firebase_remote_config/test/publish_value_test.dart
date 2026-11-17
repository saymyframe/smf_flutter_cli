// A value published in Remote Config of the Firebase project of the app that
// CI starts with Firebase on an Android emulator: the answer of
// .github/scripts/start_app.sh of the repository to the request of the probe
// of the module in the start check of the app
// (integration_test/firebase_remote_config/probe.dart of its app test). The
// request has the name of a parameter of the check and its value. The test
// adds the parameter to the template of Remote Config with the REST API and
// the key of a service account of the project, and keeps every other
// parameter, condition and group of the template as it was. It notes the
// name of the parameter in the file of the run first, from which
// remove_values_test.dart removes it again once the app has run. Whether the
// value became active in the app, the app tells start_app.sh itself.
//
// It runs only with the path of the request in SMF_START_REQUEST, which
// start_app.sh gives the command of the answer, and it needs the id of the
// project in SMF_FIREBASE_PROJECT, the path of the key in
// SMF_FIREBASE_SERVICE_ACCOUNT and the path of the file of the run in
// SMF_REMOTE_CONFIG_PUBLISHED, as CI gives them: with a request and without
// any of them, it fails and names what is missing, rather than leave the
// app waiting for a value. start_app.sh may run it again for one request,
// and it then publishes the same parameter again. It never prints the
// access token or a part of the key, and a failure tells what it means and
// what to do (see support/remote_config_template.dart, whose tests run
// everywhere).
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

import 'support/remote_config_template.dart';

void main() {
  final environment = Platform.environment;
  final request = environment['SMF_START_REQUEST'];
  final project = environment['SMF_FIREBASE_PROJECT'];
  final key = environment['SMF_FIREBASE_SERVICE_ACCOUNT'];
  final published = environment['SMF_REMOTE_CONFIG_PUBLISHED'];

  test(
    'Remote Config publishes the value that the app asked for',
    () async {
      const keyIs = 'the path of the key of a service account of that project';
      const fileIs = 'the path of the file in which the run notes what it '
          'publishes, so that a later step removes it';
      final missing = [
        if (project == null)
          'SMF_FIREBASE_PROJECT, the id of the Firebase project of the app',
        if (key == null) 'SMF_FIREBASE_SERVICE_ACCOUNT, $keyIs',
        if (published == null) 'SMF_REMOTE_CONFIG_PUBLISHED, $fileIs',
      ];
      if (missing.isNotEmpty) {
        fail(
          'The app asked for a value of remote config in SMF_START_REQUEST, '
          'but what publishes it is not set: ${missing.join('; ')}.',
        );
      }
      try {
        final asked = ValueRequest.parse(File(request!).readAsStringSync());
        // Noted first, so that the step that removes the values of the run
        // finds the parameter also when the answer of the publish is lost.
        notePublished(File(published!), asked.parameter);
        final client = await clientOf(File(key!).readAsStringSync());
        try {
          final version = await changeTemplate(
            client,
            project: project!,
            change: (parameters) =>
                withValue(parameters, asked, DateTime.now().toUtc()),
          );
          // In the log of the run, which has no secret: the parameter and
          // the version of the template, with the project.
          // ignore: avoid_print
          print(
            'Remote Config of $project published ${asked.parameter} as '
            'version $version of its template.',
          );
        } finally {
          client.close();
        }
      } on TemplateNotChanged catch (error) {
        fail(error.meaning);
      }
    },
    skip: request == null
        ? 'Publishes a value in Remote Config for the app that CI starts, '
            'with the request of the app in SMF_START_REQUEST, which '
            'start_app.sh gives its answer, the id of its Firebase project in '
            'SMF_FIREBASE_PROJECT, the key of a service account of that '
            'project in SMF_FIREBASE_SERVICE_ACCOUNT and the file of the run '
            'in SMF_REMOTE_CONFIG_PUBLISHED.'
        : false,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
