// Premium access for the app that CI starts on a device: the answer of
// .github/scripts/start_app.sh of the repository to the request of the
// check of the access that the probe of the module starts in the start
// check of the app (checkAccess of integration_test/revenuecat/probe.dart
// of its app test). The request has the app user id of the device in
// RevenueCat, the identifier of the entitlement and when the access is to
// end. The test grants the entitlement to that customer with the REST API
// v2 of RevenueCat and a secret key of the project of CI, and passes once
// RevenueCat granted it. Whether the access reached the app, the app tells
// start_app.sh itself.
//
// It runs only with the path of the request in SMF_START_REQUEST, which
// start_app.sh gives the command of the answer, and it needs the path of a
// file with the secret key in SMF_REVENUECAT_SECRET_KEY, as CI gives it:
// with a request and without the key, it fails and names what is missing,
// rather than leave the app waiting for the access. It never prints the
// key, and a failure tells what it means and what to do (see
// support/revenuecat_grant.dart, whose tests run everywhere).
@TestOn('vm')
library;

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'support/revenuecat_grant.dart';

void main() {
  final environment = Platform.environment;
  final request = environment['SMF_START_REQUEST'];
  final key = environment['SMF_REVENUECAT_SECRET_KEY'];

  test(
    'RevenueCat grants the premium access that the app asked for',
    () async {
      if (key == null) {
        fail(
          'The app asked for premium access in SMF_START_REQUEST, but '
          'SMF_REVENUECAT_SECRET_KEY, the path of a file with a V2 secret key '
          'of the RevenueCat project of CI, is not set.',
        );
      }
      final secretKey = File(key).readAsStringSync().trim();
      if (secretKey.isEmpty) {
        fail('The file of SMF_REVENUECAT_SECRET_KEY has no secret key.');
      }
      final client = http.Client();
      try {
        final asked = AccessRequest.parse(File(request!).readAsStringSync());
        final done = await grantAccess(
          client,
          secretKey: secretKey,
          request: asked,
        );
        // In the log of the run, which has no secret: the customer, the
        // entitlement, its end and the project.
        // ignore: avoid_print
        print(done);
      } on AccessNotGranted catch (error) {
        fail(error.meaning);
      } finally {
        client.close();
      }
    },
    skip: request == null
        ? 'Grants premium access to the app that CI starts, with the request '
            'of the app in SMF_START_REQUEST, which start_app.sh gives its '
            'answer, and a V2 secret key of the RevenueCat project of CI in '
            'the file of SMF_REVENUECAT_SECRET_KEY.'
        : false,
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
