// The event of the app that CI starts on a device: the answer of
// .github/scripts/start_app.sh of the repository to the request of the check
// that the probe of the module starts in the start check of the app
// (checkDelivery of integration_test/posthog/probe.dart of its app test). The
// check records an event with the analytics service of the module, with a
// nonce of its own in a property, and has PostHog send it at once; its
// request has the nonce, the distinct id of the user of the device and the
// flavor of the build. The test asks the query API of PostHog for that event
// in the project of CI, with a personal API key that may query the project,
// until PostHog has it, and checks that it is the event of the app. Only
// PostHog sees whether the event arrived, so the exit code of the test is
// the verdict on the answer, and the app gives none.
//
// It runs only with the path of the request in SMF_START_REQUEST, which
// start_app.sh gives the command of the answer, and it needs the id of the
// project in SMF_POSTHOG_PROJECT_ID and the path of a file with the key in
// SMF_POSTHOG_KEY, as CI gives them; SMF_POSTHOG_API names the host of the
// API of the region of the project, https://us.posthog.com by default. An
// empty variable counts as missing (see AnswerSettings). With a request and
// without any of the others, it fails and names what is missing: a skip would
// pass the answer. It never prints the key, and a failure tells what it means
// and what to do (see support/posthog_query.dart, whose tests run
// everywhere).
@TestOn('vm')
library;

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'support/posthog_query.dart';

void main() {
  final settings = AnswerSettings.of(Platform.environment);
  final request = settings.request;

  test(
    'PostHog has the event that the app sent, from its analytics service',
    () async {
      final missing = settings.missing;
      if (missing.isNotEmpty) {
        fail(
          'The app sent an event to PostHog and asked for the check of it in '
          'SMF_START_REQUEST, but what reads it is not set: '
          '${missing.join('; ')}.',
        );
      }
      final key = File(settings.keyFile!).readAsStringSync().trim();
      if (key.isEmpty) fail('The file of SMF_POSTHOG_KEY has no key.');
      final client = http.Client();
      try {
        final asked = EventRequest.parse(File(request!).readAsStringSync());
        final found = await checkEvent(
          client,
          api: settings.api,
          projectId: settings.projectId!,
          key: key,
          request: asked,
        );
        // In the log of the run, which has no secret: the event, the project
        // and the flavor.
        // ignore: avoid_print
        print(found);
      } on EventNotReceived catch (error) {
        fail(error.meaning);
      } finally {
        client.close();
      }
    },
    skip: request == null
        ? 'Checks the event that the app that CI starts sent to PostHog, with '
            'the request of the app in SMF_START_REQUEST, which start_app.sh '
            'gives its answer, the id of the PostHog project of CI in '
            'SMF_POSTHOG_PROJECT_ID, and a personal API key that may query '
            'the project in the file of SMF_POSTHOG_KEY.'
        : false,
    timeout: const Timeout(Duration(seconds: 285)),
  );
}
