// The event of the app that CI starts on a device: the answer of
// .github/scripts/start_app.sh of the repository to the request of the check
// that the probe of the module starts in the start check of the app
// (checkDelivery of integration_test/sentry/probe.dart of its app test). The
// check reports an error with the reporter of the module, and its request
// has the id of the event in Sentry, the nonce in the text of the error and
// the environment of the event. The test asks the API of Sentry for that
// event in the project of CI, with a token that may read the project, until
// Sentry has it, and checks that it is the event of the app. Only Sentry sees
// whether the event arrived, so the exit code of the test is the verdict on
// the answer, and the app gives none.
//
// It runs only with the path of the request in SMF_START_REQUEST, which
// start_app.sh gives the command of the answer, and it needs the slugs of
// the organization and of the project in SMF_SENTRY_ORG and
// SMF_SENTRY_PROJECT and the path of a file with the token in
// SMF_SENTRY_TOKEN, as CI gives them; SMF_SENTRY_API names the host of the
// API of the region of the organization, https://sentry.io by default. With
// a request and without any of the others, it fails and names what is
// missing: a skip would pass the answer. It never prints the token, and a
// failure tells what it means and what to do (see support/sentry_events.dart,
// whose tests run everywhere).
@TestOn('vm')
library;

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'support/sentry_events.dart';

void main() {
  final environment = Platform.environment;
  final request = environment['SMF_START_REQUEST'];
  final api = environment['SMF_SENTRY_API'] ?? defaultApiOfSentry;
  final org = environment['SMF_SENTRY_ORG'];
  final project = environment['SMF_SENTRY_PROJECT'];
  final tokenFile = environment['SMF_SENTRY_TOKEN'];

  test(
    'Sentry has the event that the app sent, from its reporter',
    () async {
      const tokenIs =
          'the path of a file with a token that may read that project';
      final missing = [
        if (org == null)
          'SMF_SENTRY_ORG, the slug of the Sentry organization of CI',
        if (project == null)
          'SMF_SENTRY_PROJECT, the slug of the Sentry project of CI',
        if (tokenFile == null) 'SMF_SENTRY_TOKEN, $tokenIs',
      ];
      if (missing.isNotEmpty) {
        fail(
          'The app sent an event to Sentry and asked for the check of it in '
          'SMF_START_REQUEST, but what reads it is not set: '
          '${missing.join('; ')}.',
        );
      }
      final token = File(tokenFile!).readAsStringSync().trim();
      if (token.isEmpty) fail('The file of SMF_SENTRY_TOKEN has no token.');
      final client = http.Client();
      try {
        final asked = EventRequest.parse(File(request!).readAsStringSync());
        final found = await checkEvent(
          client,
          api: api,
          org: org!,
          project: project!,
          token: token,
          request: asked,
        );
        // In the log of the run, which has no secret: the event, the project
        // and the environment.
        // ignore: avoid_print
        print(found);
      } on EventNotReceived catch (error) {
        fail(error.meaning);
      } finally {
        client.close();
      }
    },
    skip: request == null
        ? 'Checks the event that the app that CI starts sent to Sentry, with '
            'the request of the app in SMF_START_REQUEST, which start_app.sh '
            'gives its answer, the slugs of the Sentry organization and '
            'project of CI in SMF_SENTRY_ORG and SMF_SENTRY_PROJECT, and a '
            'token that may read the project in the file of SMF_SENTRY_TOKEN.'
        : false,
    timeout: const Timeout(Duration(seconds: 285)),
  );
}
