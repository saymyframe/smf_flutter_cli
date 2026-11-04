// The probe of the google_sign_in module, which the start check runs on a
// device once the first screen of the app settled: the only place where
// the app delegate of the iOS app and the files that it reads are the real
// ones. The tests of the module run it over the mocks too (probe_test.dart).
//
// On iOS, the Google Sign-In SDK stops the app, rather than fail, when the
// app lacks the iOS client of Google or its URL scheme, so googleCredential()
// first asks the app delegate what the SDK finds. The probe asks the same:
// the app delegate must answer, and an app with an iOS client of Google must
// have what the SDK needs of it, a client id that is not empty and its URL
// scheme. Then a tap on the button of Google shows the sheet of Google. An
// app without an iOS client, as one whose Firebase project has no Google
// sign-in yet, is no problem: a sign-in there fails with notConfigured and
// tells what is missing. On Android there is nothing to probe.
//
// It uses no test framework. It only reads: it signs nobody in and shows no
// sheet, so it holds on a device without a network or a Google account.
import 'package:{{app_name}}/core/google_sign_in/google_sign_in.dart';

/// The probe of the start check: what keeps Google sign-in from asking the
/// Google Sign-In SDK on iOS in an app that is set up for it. It waits for
/// no screen, so it leaves [settle] out.
Future<List<String>> probeGoogleSignIn(
  Future<void> Function() settle,
) async {
  final setup = await readGoogleSignInIosSetup();
  final problem = setup?.problem;
  if (setup == null || problem == null) return const [];
  if (!setup.answered) {
    return ['Google sign-in fails on iOS whatever the setup: $problem.'];
  }
  // No client at all: the app is not set up for Google sign-in yet.
  if (setup.clientId == null) return const [];
  return [
    'The iOS app has an iOS client of Google, but Google sign-in fails with '
        'notConfigured: $problem.',
  ];
}
