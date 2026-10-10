// The probe of the firebase_auth module, which the start check runs on a
// device once the first screen of the app settled: the only place where
// the platform side of the plugin is the Firebase SDK. The start-up of the
// app took the user whom the SDK kept on the device, and the session of
// the app follows the SDK from then on. So the probe compares who the
// session says uses the app with the user that the plugin has now: nobody,
// an anonymous user or the user of an account, with the same id.
//
// It only reads. It signs nobody in, creates no user and makes no request
// to the server, so it holds on a device without a network, in every mode
// of the app, whoever is signed in there, and whichever probes ran before
// it. It uses no test framework. The test of the module runs it too
// (probe_test.dart).
import 'package:firebase_auth/firebase_auth.dart';
import 'package:{{app_name}}/core/auth/app_session.dart';

/// The probe of the start check: the problems of [problemsOfSession]. It
/// waits for no screen, so it leaves [settle] out.
Future<List<String>> probeFirebaseAuth(
  Future<void> Function() settle,
) async =>
    problemsOfSession();

/// What the session of the app says of its user otherwise than Firebase
/// Authentication has it on this device: none while they agree.
List<String> problemsOfSession() {
  final ofSession = switch (appSession.value) {
    SignedOutSession() => 'nobody',
    AnonymousSession(:final uid) => 'the anonymous user $uid',
    AccountSession(:final uid) => 'the account $uid',
  };
  final ofFirebase = switch (FirebaseAuth.instance.currentUser) {
    null => 'nobody',
    User(isAnonymous: true, :final uid) => 'the anonymous user $uid',
    User(:final uid) => 'the account $uid',
  };
  return [
    if (ofSession != ofFirebase)
      'The session of the app has $ofSession, and Firebase Authentication '
          'has $ofFirebase signed in on this device.',
  ];
}
