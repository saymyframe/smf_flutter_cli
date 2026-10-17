// A push message to the app that CI starts with Firebase on an Android
// emulator: the answer of .github/scripts/start_app.sh of the repository to
// the request of the probe of the module in the start check of the app
// (integration_test/firebase_messaging/probe.dart of its app test). The
// request has the address of the device, which is the registration token
// of Firebase Cloud Messaging there, and the title, the text and the data
// of the message. The test sends the message with the HTTP v1 API of
// Firebase Cloud Messaging and the key of a service account of the
// Firebase project of the app, and passes once Firebase Cloud Messaging
// took it. Whether the message reached the app, the app tells start_app.sh
// itself.
//
// It needs the request, a Firebase project and a key of it, so it runs
// only with the path of the request in SMF_START_REQUEST, which
// start_app.sh gives the command of the answer, the id of the project in
// SMF_FIREBASE_PROJECT and the path of the key in
// SMF_FIREBASE_SERVICE_ACCOUNT, as CI gives them. It never prints the
// address or the key, and a failure tells what it means and what to do
// (see support/fcm_send.dart, whose tests run everywhere).
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

import 'support/fcm_send.dart';

void main() {
  final environment = Platform.environment;
  final request = environment['SMF_START_REQUEST'];
  final project = environment['SMF_FIREBASE_PROJECT'];
  final key = environment['SMF_FIREBASE_SERVICE_ACCOUNT'];

  test(
    'Firebase Cloud Messaging takes the push message that the app asked for',
    () async {
      try {
        final asked = PushRequest.parse(File(request!).readAsStringSync());
        final client = await clientOf(File(key!).readAsStringSync());
        try {
          final name = await send(client, project: project!, request: asked);
          // In the log of the run, which has no secret: the name of the
          // message, with the project.
          // ignore: avoid_print
          print('Firebase Cloud Messaging took the push message as $name.');
        } finally {
          client.close();
        }
      } on PushNotSent catch (error) {
        fail(error.meaning);
      }
    },
    skip: request == null || project == null || key == null
        ? 'Sends a push message to the app that CI starts, with the request '
            'of the app in SMF_START_REQUEST, which start_app.sh gives its '
            'answer, the id of its Firebase project in SMF_FIREBASE_PROJECT '
            'and the key of a service account of that project in '
            'SMF_FIREBASE_SERVICE_ACCOUNT.'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
